// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/services/dues_service.dart';
import 'package:org_wallet/models/due_payment.dart';
import 'package:org_wallet/models/due.dart';
import 'package:org_wallet/models/officer.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';

class CollectionTab extends StatefulWidget {
  final String orgId;
  final ValueChanged<double>? onAmountChanged;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final ValueChanged<String?>? onSelectedDueChanged;
  final bool createPaymentsImmediately;
  // Optional: when opening an existing collection transaction, pass the dueId
  // that was used for that transaction so the tab can preselect it.
  final String? initialDueId;
  // Optional: current transaction id (for edit). Payments whose transactionId
  // matches this id should be included even if their paidAt falls outside the
  // current period.
  final String? currentTransactionId;
  const CollectionTab({
    super.key,
    required this.orgId,
    this.onAmountChanged,
    this.onSelectionChanged,
    this.onSelectedDueChanged,
    this.createPaymentsImmediately = true,
    this.initialDueId,
    this.currentTransactionId,
  });

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
  final Map<String, double> _memberAmounts = {}; // userId -> amount
  StreamSubscription<QuerySnapshot>? _paymentsSub;
  // Track which userIds we created payments for during this session to avoid duplicates
  final Set<String> _sessionPaidUserIds = {};
  // Map userId -> created payment doc id (may be userId or auto-id) for undo
  final Map<String, String> _sessionCreatedDocIds = {};
  // Track userIds that already had payments before this session (loaded from Firestore)
  final Set<String> _existingPaidUserIds = {};

  @override
  void initState() {
    super.initState();
    // prefer initialDueId if provided
    if (widget.initialDueId != null) _selectedDueId = widget.initialDueId;
    _loadDues();
  }

  @override
  void dispose() {
    _paymentsSub?.cancel();
    super.dispose();
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
        // Load existing payments for the initially selected due (subscribe)
        if (_selectedDueId != null) {
          _subscribeToDuePayments(_selectedDueId!);
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
    // If createPaymentsImmediately is false (we're in Add Transaction flow),
    // only update selection state locally and notify parent; do not write payments yet.
    if (widget.createPaymentsImmediately == false) {
      setState(() {
        if (!checked) {
          _selected.remove(userId);
        } else {
          _selected[userId] = true;
        }
      });
      if (widget.onSelectionChanged != null) widget.onSelectionChanged!(_selected.keys.toSet());
      _recalculateTotalForSelectedMembers();
      if (widget.onAmountChanged != null) widget.onAmountChanged!(_totalCollected);
      return;
    }

    if (!checked) {
      setState(() {
        _selected.remove(userId);
      });
      // For simplicity we don't rollback payments when unchecked (immediate-mode)
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

      // Try to create the payment using the DuesService (doc id == userId).
      // If that fails due to permission rules (e.g., president writing another user's doc id),
      // fall back to creating an auto-id payment document that contains the userId field.
      bool created = false;
      String? createdDocId;
      try {
        final payment = DuePaymentModel(
          id: userId,
          dueId: selectedDue.id,
          userId: userId,
          transactionId: widget.currentTransactionId ?? '',
          amount: dueAmount,
          paidAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final createdPayment = await _duesService.createDuePaymentWithTransaction(
          orgId: widget.orgId,
          payment: payment,
          transactionId: widget.currentTransactionId,
        );
        created = true;
        createdDocId = createdPayment.id;
      } catch (e) {
        // Fallback: create an auto-id payment doc with userId field set
        try {
          final createdPayment = await _duesService.createDuePaymentWithAutoId(
            orgId: widget.orgId,
            dueId: selectedDue.id,
            userId: userId,
            amount: dueAmount,
            transactionId: widget.currentTransactionId,
          );
          created = true;
          createdDocId = createdPayment.id;
        } catch (e2) {
          // if fallback also fails, rethrow original error to be shown to user
          rethrow;
        }
      }

      if (created) {
        setState(() {
          _selected[userId] = true;
          _sessionPaidUserIds.add(userId);
          if (createdDocId != null) _sessionCreatedDocIds[userId] = createdDocId;
        });
        // Recalculate total after creating payment
        _recalculateTotalForSelectedMembers();
      }
    } catch (e) {
      SnackBarHelper.showError(
        context,
        message: 'Error collecting for $userName: $e',
      );
    } finally {
      setState(() {
        _processing.remove(userId);
      });
    }
  }


  void _subscribeToDuePayments(String dueId) {
    // cancel existing
    _paymentsSub?.cancel();

    // find due model if available
    DueModel? due;
    try {
      due = _dues.firstWhere((d) => d.id == dueId);
    } catch (_) {
      due = null;
    }

    final coll = FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.orgId)
        .collection('dues')
        .doc(dueId)
        .collection('due_payments');

    _paymentsSub = coll.snapshots().listen((snap) {
      // compute which userIds have a payment that falls within the current period
      final Set<String> paidNow = {};
      for (final doc in snap.docs) {
        final p = DuePaymentModel.fromFirestore(doc);
        final paidAt = p.paidAt ?? p.createdAt;
        // include payments that are either in the current period OR attached to
        // the current transaction id (so saved transactions display their payments)
        final attachedToCurrentTx = widget.currentTransactionId != null && p.transactionId == widget.currentTransactionId;
        if (paidAt == null && !attachedToCurrentTx) continue;
        if (due == null) {
          paidNow.add(p.userId);
          _memberAmounts[p.userId] = p.amount;
        } else {
          if (_isPaymentInCurrentPeriod(paidAt!, due) || attachedToCurrentTx) {
            paidNow.add(p.userId);
            _memberAmounts[p.userId] = p.amount;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _existingPaidUserIds
          ..clear()
          ..addAll(paidNow);
      });
      _recalculateTotalForSelectedMembers();
      // Notify parent about which members are currently paid (merge session-created)
      if (widget.onSelectionChanged != null) {
        final Set<String> merged = {}..addAll(_existingPaidUserIds)..addAll(_sessionPaidUserIds);
        widget.onSelectionChanged!(merged);
      }
      if (widget.onAmountChanged != null) {
        widget.onAmountChanged!(_totalCollected);
      }
    }, onError: (_) {
      // ignore subscription errors for now
    });
  }

  @override
  void didUpdateWidget(covariant CollectionTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the initially-requested due changed after mount, update selection
    if (widget.initialDueId != oldWidget.initialDueId && widget.initialDueId != null) {
      _selectedDueId = widget.initialDueId;
      _subscribeToDuePayments(_selectedDueId!);
    }
    // If the currentTransactionId changed, resubscribe so attached payments are included
    if (widget.currentTransactionId != oldWidget.currentTransactionId && _selectedDueId != null) {
      _subscribeToDuePayments(_selectedDueId!);
    }
  }

  bool _isPaymentInCurrentPeriod(DateTime paidAt, DueModel due) {
    final freq = due.frequency.toLowerCase();
    final dueDate = due.dueDate;
    
    if (freq == 'weekly') {
      // Check if payment falls within the same week as the due date
      final dueStart = _startOfWeek(dueDate);
      final dueEnd = dueStart.add(const Duration(days: 7));
      return !paidAt.isBefore(dueStart) && paidAt.isBefore(dueEnd);
    }
    
    if (freq == 'monthly') {
      // Check if payment falls within the same month as the due date
      return paidAt.year == dueDate.year && paidAt.month == dueDate.month;
    }
    
    if (freq == 'quarterly') {
      // Check if payment falls within the same quarter as the due date
      final dueQuarter = _getQuarter(dueDate);
      final paymentQuarter = _getQuarter(paidAt);
      return paidAt.year == dueDate.year && dueQuarter == paymentQuarter;
    }
    
    if (freq == 'yearly') {
      // Check if payment falls within the same year as the due date
      return paidAt.year == dueDate.year;
    }
    
    // Custom frequency: treat payments as in-period if they occur on the same day-of-month as due.dueDate
    // within the same month/year. This is an assumption; adjust logic if you track custom windows differently.
    try {
      return paidAt.year == dueDate.year && paidAt.month == dueDate.month && paidAt.day == dueDate.day;
    } catch (_) {
      return false;
    }
  }

  int _getQuarter(DateTime date) {
    return ((date.month - 1) / 3).floor() + 1;
  }

  DateTime _startOfWeek(DateTime d) {
    // ISO week start: Monday
    final weekday = d.weekday; // Monday = 1
    final start = DateTime(d.year, d.month, d.day).subtract(Duration(days: weekday - 1));
    return DateTime(start.year, start.month, start.day);
  }

  // Expose selected user ids for parent when in delayed mode
  Set<String> getSelectedUserIds() => _selected.keys.toSet();

  String? get selectedDueId => _selectedDueId;

  Future<bool> _hasExistingPayment(String userId, String dueId) async {
    try {
      // Get the due to check payment periods
      DueModel? due;
      try {
        due = _dues.firstWhere((d) => d.id == dueId);
      } catch (_) {
        // Fallback: fetch due from Firestore
        final dueDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.orgId)
            .collection('dues')
            .doc(dueId)
            .get();
        if (dueDoc.exists) {
          due = DueModel.fromFirestore(dueDoc);
        }
      }
      
      if (due == null) return false;

      // check for a payment doc with id == userId under the due's subcollection
      final paymentsColl = FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.orgId)
          .collection('dues')
          .doc(dueId)
          .collection('due_payments');

      // 1) Check doc with id == userId (the fast path used elsewhere)
      final doc = await paymentsColl.doc(userId).get();
      if (doc.exists) {
        final payment = DuePaymentModel.fromFirestore(doc);
        final paidAt = payment.paidAt ?? payment.createdAt;
        if (paidAt != null && _isPaymentInCurrentPeriod(paidAt, due)) {
          return true;
        }
      }

      // 2) Fallback: some payments may be created with auto-ids and include a userId field.
      // Query for any payment with the same userId and check if it's in the correct period
      final q = await paymentsColl.where('userId', isEqualTo: userId).get();
      for (final paymentDoc in q.docs) {
        final payment = DuePaymentModel.fromFirestore(paymentDoc);
        final paidAt = payment.paidAt ?? payment.createdAt;
        if (paidAt != null && _isPaymentInCurrentPeriod(paidAt, due)) {
          return true;
        }
      }
      
      return false;
    } catch (_) {
      return false;
    }
  }

  // Recalculate total based on selected members and currently selected due
  void _recalculateTotalForSelectedMembers() {
    if (_selectedDueId == null) {
      setState(() => _totalCollected = 0.0);
      if (widget.onAmountChanged != null) {
        widget.onAmountChanged!(_totalCollected);
      }
      return;
    }
    double dueAmount = 0.0;
    try {
      dueAmount = _dues.firstWhere((d) => d.id == _selectedDueId).amount;
    } catch (_) {
      dueAmount = 0.0;
    }
    double total = 0.0;
    
    // Get all unique members who should be counted
    final Set<String> allSelected = {};
    
    // Add session-selected members (newly selected in this session)
    allSelected.addAll(_selected.keys.where((k) => _selected[k] == true));
    
    // Add existing paid members (but avoid double-counting session members)
    for (final userId in _existingPaidUserIds) {
      if (!_sessionPaidUserIds.contains(userId)) {
        allSelected.add(userId);
      }
    }
    
    // Calculate total using per-member amounts when available
    for (final userId in allSelected) {
      final amt = _memberAmounts[userId] ?? dueAmount;
      total += amt;
    }
    setState(() {
      _totalCollected = total;
    });
    if (widget.onAmountChanged != null) {
      widget.onAmountChanged!(_totalCollected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    if (!auth.hasCollectionAccess()) {
      return const Center(child: Text('Only officers can manage collections'));
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
                                // Reset total when switching dues
                                _totalCollected = 0.0;
                                // Clear session selections when switching dues
                                _selected.clear();
                                _sessionPaidUserIds.clear();
                                _sessionCreatedDocIds.clear();
                              });
                              if (v != null) {
                                _subscribeToDuePayments(v);
                                _recalculateTotalForSelectedMembers();
                                // Notify parent about due change
                                if (widget.onSelectedDueChanged != null) {
                                  widget.onSelectedDueChanged!(v);
                                }
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
                            // Reset total when switching dues
                            _totalCollected = 0.0;
                            // Clear session selections when switching dues
                            _selected.clear();
                            _sessionPaidUserIds.clear();
                            _sessionCreatedDocIds.clear();
                          });
                          if (v != null) {
                            _subscribeToDuePayments(v);
                            _recalculateTotalForSelectedMembers();
                            // Notify parent about due change
                            if (widget.onSelectedDueChanged != null) {
                              widget.onSelectedDueChanged!(v);
                            }
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
                if (status is int) {
                  return status == OfficerStatus.approved.index;
                }
                return false;
              }).toList();
              if (approved.isEmpty) {
                return const Center(child: Text('No members'));
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: approved.length,
                itemBuilder: (context, i) {
                  final m = approved[i].data() as Map<String, dynamic>;
                  final userId = (m['userId'] ?? '').toString();
                  final name = (m['name'] ?? m['email'] ?? userId).toString();
                  final processing = _processing[userId] == true;
                  final bool isExistingPaid = _existingPaidUserIds.contains(userId);
                  final bool isSessionPaid = _sessionPaidUserIds.contains(userId);
                  final bool isPaid = isExistingPaid || isSessionPaid;
                  // Only allow interaction if the payment was created this session OR not already existing
                  final bool canToggle = !isExistingPaid || isSessionPaid;

                  // compute member amount to display
                  double memberAmt = 0.0;
                  if (_memberAmounts.containsKey(userId)) {
                    memberAmt = _memberAmounts[userId]!;
                  } else if (_selectedDueId != null) {
                    try {
                      final due = _dues.firstWhere((d) => d.id == _selectedDueId);
                      memberAmt = due.amount;
                    } catch (_) {
                      memberAmt = 0.0;
                    }
                  }

                  return CheckboxListTile(
                    value: isPaid ? true : _selected[userId] == true,
                    enabled: canToggle,
                    title: Text(name, style: canToggle ? null : TextStyle(color: Colors.grey[600])),
                    subtitle: Text('${m['role'] ?? ''}${memberAmt > 0 ? ' · ${memberAmt.toStringAsFixed(2)}' : ''}'),
                    secondary: processing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(),
                          )
                        : (isPaid
                            ? Chip(
                                label: const Text('Paid'),
                                backgroundColor: isExistingPaid ? Colors.grey.shade300 : Colors.greenAccent.shade100,
                              )
                            : null),
                    onChanged: canToggle
                        ? (v) async {
                            // if already paid (existing) and created this session, allow undo by deleting the session-created doc
                            final createdDocId = _sessionCreatedDocIds[userId];
                            if (isPaid) {
                              if (createdDocId != null) {
                                // We created this payment in this session: delete it to uncheck
                                setState(() {
                                  _processing[userId] = true;
                                });
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('organizations')
                                      .doc(widget.orgId)
                                      .collection('dues')
                                      .doc(_selectedDueId)
                                      .collection('due_payments')
                                      .doc(createdDocId)
                                      .delete();
                                  setState(() {
                                    _sessionCreatedDocIds.remove(userId);
                                    _sessionPaidUserIds.remove(userId);
                                    _selected.remove(userId);
                                    _recalculateTotalForSelectedMembers();
                                  });
                                  if (widget.onAmountChanged != null) widget.onAmountChanged!(_totalCollected);
                                } catch (e) {
                                  SnackBarHelper.showError(
                                    context,
                                    message: 'Failed to remove payment: $e',
                                  );
                                } finally {
                                  setState(() {
                                    _processing.remove(userId);
                                  });
                                }
                              } else {
                                // shouldn't happen because canToggle prevents toggling existing payments
                              }
                              return;
                            }

                            // Not paid yet: toggle selection
                            if (v == true) {
                              _toggleMember(userId, name, true);
                            } else {
                              setState(() {
                                _selected.remove(userId);
                                _recalculateTotalForSelectedMembers();
                              });
                              if (widget.onAmountChanged != null) widget.onAmountChanged!(_totalCollected);
                            }
                          }
                        : null,
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
