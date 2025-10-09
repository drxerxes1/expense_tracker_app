// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/services/dues_service.dart';
import 'package:org_wallet/models/due_payment.dart';
import 'package:org_wallet/models/due.dart';
import 'package:org_wallet/models/officer.dart';

class CollectionTab extends StatefulWidget {
  final String orgId;
  final ValueChanged<double>? onAmountChanged;
  const CollectionTab({super.key, required this.orgId, this.onAmountChanged});

  @override
  State<CollectionTab> createState() => _CollectionTabState();
}

class _CollectionTabState extends State<CollectionTab> {
  final DuesService _duesService = DuesService();
  final Map<String, bool> _selected = {}; // userId -> checked
  final Map<String, bool> _processing = {};
  double _totalCollected = 0.0;
  String? _selectedDueId;
  List<DueModel> _dues = [];
  // Track which userIds we created payments for during this session to avoid duplicates
  final Set<String> _sessionPaidUserIds = {};
  // Track userIds that already had payments before this session (loaded from Firestore)
  final Set<String> _existingPaidUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadDues();
  }

  Future<void> _loadDues() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.orgId)
          .collection('dues')
          .get();
      final dues = snap.docs.map((d) => DueModel.fromFirestore(d)).toList();
      if (!mounted) return;
      setState(() {
        _dues = dues;
        if (_dues.isNotEmpty && _selectedDueId == null) {
          _selectedDueId = _dues.first.id;
        }
        // Load existing payments for the initially selected due
        if (_selectedDueId != null) {
          _loadPaidForDue(_selectedDueId!);
        }
        _recalculateTotalForSelectedMembers();
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _toggleMember(
    String userId,
    String userName,
    bool checked,
  ) async {
    if (!checked) {
      setState(() {
        _selected.remove(userId);
      });
      // For simplicity we don't rollback payments when unchecked
      return;
    }

    setState(() {
      _processing[userId] = true;
    });

    try {
      if (!checked) return;

      if (_selectedDueId == null) {
        throw Exception('No due selected');
      }

      // get selected due (use cached list if available)
      DueModel? selectedDue;
      try {
        selectedDue = _dues.firstWhere((d) => d.id == _selectedDueId);
      } catch (_) {}
      if (selectedDue == null) {
        final doc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.orgId)
            .collection('dues')
            .doc(_selectedDueId)
            .get();
        if (doc.exists) selectedDue = DueModel.fromFirestore(doc);
      }
      if (selectedDue == null) throw Exception('Selected due not found');
      final dueAmount = selectedDue.amount;

      // Check if a payment already exists for this user+due (idempotency)
      final alreadyPaid = await _hasExistingPayment(userId, selectedDue.id);
      if (alreadyPaid || _sessionPaidUserIds.contains(userId)) {
        // mark selected for UI, but do not add to total since already paid
        setState(() {
          _selected[userId] = true;
        });
        // if this was an existing payment, add to existingPaid set
        if (alreadyPaid) _existingPaidUserIds.add(userId);
        return;
      }

      // Use userId as payment id to ensure uniqueness per due (DuesService uses the doc id)
      final payment = DuePaymentModel(
        id: userId,
        dueId: selectedDue.id,
        userId: userId,
        transactionId: '',
        amount: dueAmount,
        paidAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _duesService.createDuePayment(orgId: widget.orgId, payment: payment);

      setState(() {
        _selected[userId] = true;
        _sessionPaidUserIds.add(userId);
        _totalCollected += dueAmount;
      });
      if (widget.onAmountChanged != null) widget.onAmountChanged!(_totalCollected);
      // After creating payment, recalc to ensure consistency
      _recalculateTotalForSelectedMembers();
      if (widget.onAmountChanged != null) widget.onAmountChanged!(_totalCollected);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error collecting for $userName: $e')),
      );
    } finally {
      setState(() {
        _processing.remove(userId);
      });
    }
  }

  Future<void> _loadPaidForDue(String dueId) async {
    try {
      final payments = await _duesService.listDuePayments(widget.orgId, dueId);
      if (!mounted) return;
      setState(() {
        _existingPaidUserIds.clear();
        for (final p in payments) {
          _existingPaidUserIds.add(p.userId);
        }
        // session-created payments remain in their set; UI will merge both when showing 'Paid'
      });
      _recalculateTotalForSelectedMembers();
    } catch (_) {
      // ignore
    }
  }

  Future<bool> _hasExistingPayment(String userId, String dueId) async {
    try {
      // check for a payment doc with id == userId under the due's subcollection
      final doc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.orgId)
          .collection('dues')
          .doc(dueId)
          .collection('due_payments')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // Recalculate total based on selected members and currently selected due
  void _recalculateTotalForSelectedMembers() {
    if (_selectedDueId == null) {
      setState(() => _totalCollected = 0.0);
      if (widget.onAmountChanged != null) widget.onAmountChanged!(_totalCollected);
      return;
    }
    double dueAmount = 0.0;
    try {
      dueAmount = _dues.firstWhere((d) => d.id == _selectedDueId).amount;
    } catch (_) {
      dueAmount = 0.0;
    }
    final selectedCount = _selected.values.where((v) => v).length;
    setState(() {
      _totalCollected = selectedCount * dueAmount;
    });
    if (widget.onAmountChanged != null) widget.onAmountChanged!(_totalCollected);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    if (!auth.isPresident()) {
      return const Center(child: Text('Only Presidents can use collection'));
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Due: '),
              const SizedBox(width: 8),
              Expanded(
                child: _dues.isEmpty
                    ? FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('organizations')
                            .doc(widget.orgId)
                            .collection('dues')
                            .get(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 24,
                              width: 24,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          final docs = snap.data?.docs ?? [];
                          _dues = docs
                              .map((d) => DueModel.fromFirestore(d))
                              .toList();
                          if (_dues.isNotEmpty && _selectedDueId == null) {
                            _selectedDueId = _dues.first.id;
                          }
                          return DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedDueId,
                            items: _dues
                                .map(
                                  (du) => DropdownMenuItem(
                                    value: du.id,
                                    child: Text(du.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) async {
                              setState(() {
                                _selectedDueId = v;
                              });
                              if (v != null) {
                                await _loadPaidForDue(v);
                                _recalculateTotalForSelectedMembers();
                              }
                            },
                          );
                        },
                      )
                    : DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedDueId,
                        items: _dues
                            .map(
                              (du) => DropdownMenuItem(
                                value: du.id,
                                child: Text(du.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) async {
                          setState(() {
                            _selectedDueId = v;
                          });
                          if (v != null) {
                            await _loadPaidForDue(v);
                            _recalculateTotalForSelectedMembers();
                          }
                        },
                      ),
              ),
              const SizedBox(width: 8),
              // Amount field is managed by parent. We notify parent via onAmountChanged when totals update.
            ],
          ),
          const SizedBox(height: 8),
          // Use shrinkWrap list so this tab can be placed inside a scrollable parent
          StreamBuilder<QuerySnapshot>(
            // Query only by orgId; status representations vary (string vs index),
            // so filter approved members client-side to handle both forms.
            stream: FirebaseFirestore.instance
                .collection('officers')
                .where('orgId', isEqualTo: widget.orgId)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              // normalize/filter approved
              final approved = docs.where((doc) {
                final m = doc.data() as Map<String, dynamic>;
                final status = m['status'];
                if (status == null) return false;
                if (status is String) return status == 'approved';
                if (status is int) return status == OfficerStatus.approved.index;
                return false;
              }).toList();
              if (approved.isEmpty) return const Center(child: Text('No members'));
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: approved.length,
                itemBuilder: (context, i) {
                  final m = approved[i].data() as Map<String, dynamic>;
                  final userId = (m['userId'] ?? '').toString();
                  final name = (m['name'] ?? m['email'] ?? userId).toString();
                  final processing = _processing[userId] == true;
                  final isPaid = _existingPaidUserIds.contains(userId) || _sessionPaidUserIds.contains(userId);
                  return CheckboxListTile(
                    value: isPaid ? true : _selected[userId] == true,
                    title: Text(name),
                    subtitle: Text(m['role'] ?? ''),
                    secondary: processing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(),
                          )
                        : (isPaid
                            ? Chip(
                                label: const Text('Paid'),
                                backgroundColor: Colors.greenAccent.shade100,
                              )
                            : null),
                    onChanged: isPaid
                        ? null
                        : (v) {
                            if (v == true) {
                              _toggleMember(userId, name, true);
                            } else {
                              setState(() {
                                _selected.remove(userId);
                                // subtract amount immediately for UI consistency
                                _recalculateTotalForSelectedMembers();
                              });
                              if (widget.onAmountChanged != null) widget.onAmountChanged!(_totalCollected);
                            }
                          },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
