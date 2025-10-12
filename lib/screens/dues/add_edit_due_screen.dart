// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/models/due.dart';
import 'package:org_wallet/models/due_payment.dart';
import 'package:org_wallet/services/due_service.dart';
import 'package:org_wallet/services/dues_service.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/officer.dart';

class AddEditDueScreen extends StatefulWidget {
  final DueModel? existing;
  final String orgId;
  const AddEditDueScreen({super.key, this.existing, required this.orgId});

  @override
  State<AddEditDueScreen> createState() => _AddEditDueScreenState();
}

class _AddEditDueScreenState extends State<AddEditDueScreen> {
  late final DueService _dueService;
  late final DuesService _duesService;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  DateTime _dueDate = DateTime.now();
  String _frequency = 'monthly';
  bool _saving = false;

  // payment status map userId -> paid
  final Map<String, bool> _paid = {};
  // Map of session-created payment doc ids for undoing creations: userId -> docId
  final Map<String, String> _sessionCreatedDocIds = {};

  @override
  void initState() {
    super.initState();
    _dueService = DueService();
    _duesService = DuesService();
    // initialize text controllers with existing values when editing
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _amountCtrl = TextEditingController(
      text: widget.existing != null ? widget.existing!.amount.toString() : '',
    );
    if (widget.existing != null) {
      _dueDate = widget.existing!.dueDate;
      _frequency = widget.existing!.frequency;
      // Load paid status for all members for this due
      _loadPaidMembers();
    }
  }

  Future<void> _loadPaidMembers() async {
    final dueId = widget.existing?.id;
    if (dueId == null) return;
    final payments = await _duesService.listDuePayments(widget.orgId, dueId);
    setState(() {
      for (final p in payments) {
        _paid[p.userId] = true;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    try {
      if (widget.existing == null) {
        final due = DueModel.create(
          orgId: widget.orgId,
          name: name,
          amount: amount,
          frequency: _frequency,
          dueDate: _dueDate,
          createdBy: auth.user?.id ?? '',
        );
        await _dueService.createDue(due);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Due created')));
        // After creating, load payments (there will be none) and enable list
        Navigator.of(context).pop(true);
      } else {
        await _dueService.updateDue(widget.orgId, widget.existing!.id, {
          'name': name,
          'amount': amount,
          'frequency': _frequency,
          'dueDate': Timestamp.fromDate(_dueDate),
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Due updated')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Due' : 'Edit Due'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final parsed = double.tryParse(v ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Enter valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Due date: ${_dueDate.toLocal().toString().split(' ')[0]}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _dueDate = picked);
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _frequency,
                    items: const [
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text('Monthly'),
                      ),
                      DropdownMenuItem(
                        value: 'quarterly',
                        child: Text('Quarterly'),
                      ),
                      DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                    ],
                    onChanged: (v) =>
                        setState(() => _frequency = v ?? _frequency),
                    decoration: const InputDecoration(labelText: 'Frequency'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const CircularProgressIndicator()
                              : Text(
                                  widget.existing == null ? 'Save' : 'Update',
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: widget.existing == null
                  ? const Center(
                      child: Text('Save the due to enable member payment list'),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      // Query by orgId only and normalize status client-side.
                      stream: FirebaseFirestore.instance
                          .collection('officers')
                          .where('orgId', isEqualTo: widget.orgId)
                          .snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final docs = snap.data?.docs ?? [];
                        final approvedDocs = docs.where((doc) {
                          final m = doc.data() as Map<String, dynamic>;
                          final status = m['status'];
                          if (status == null) return false;
                          if (status is String) return status == 'approved';
                          if (status is int) {
                            return status == OfficerStatus.approved.index;
                          }
                          return false;
                        }).toList();
                        if (approvedDocs.isEmpty) {
                          return const Center(child: Text('No members'));
                        }
                        return ListView.builder(
                          itemCount: approvedDocs.length,
                          itemBuilder: (context, i) {
                            final m =
                                approvedDocs[i].data() as Map<String, dynamic>;
                            final userId = (m['userId'] ?? '').toString();
                            final name = (m['name'] ?? m['email'] ?? userId)
                                .toString();
                            final paid = _paid[userId] == true;
                            return ListTile(
                              title: Text(name),
                              trailing: paid
                                  ? const Chip(label: Text('Paid'))
                                  : const Text('Unpaid'),
                              onTap: () async {
                                if (widget.existing == null) return;
                                final dueId = widget.existing!.id;
                                final createdDocId =
                                    _sessionCreatedDocIds[userId];
                                if (paid) {
                                  // Attempt to delete session-created or existing payment
                                  try {
                                    if (createdDocId != null) {
                                      await FirebaseFirestore.instance
                                          .collection('organizations')
                                          .doc(widget.orgId)
                                          .collection('dues')
                                          .doc(dueId)
                                          .collection('due_payments')
                                          .doc(createdDocId)
                                          .delete();
                                      _sessionCreatedDocIds.remove(userId);
                                    } else {
                                      // try delete doc with id == userId
                                      final docRef = FirebaseFirestore.instance
                                          .collection('organizations')
                                          .doc(widget.orgId)
                                          .collection('dues')
                                          .doc(dueId)
                                          .collection('due_payments')
                                          .doc(userId);
                                      final doc = await docRef.get();
                                      if (doc.exists) {
                                        await docRef.delete();
                                      } else {
                                        final q = await FirebaseFirestore
                                            .instance
                                            .collection('organizations')
                                            .doc(widget.orgId)
                                            .collection('dues')
                                            .doc(dueId)
                                            .collection('due_payments')
                                            .where('userId', isEqualTo: userId)
                                            .limit(1)
                                            .get();
                                        if (q.docs.isNotEmpty) {
                                          await q.docs.first.reference.delete();
                                        } else {
                                          throw Exception(
                                            'Payment doc not found',
                                          );
                                        }
                                      }
                                    }
                                    setState(() => _paid.remove(userId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Payment removed'),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to remove payment: $e',
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  // create payment with fallback
                                  try {
                                    final payment = DuePaymentModel(
                                      id: userId,
                                      dueId: dueId,
                                      userId: userId,
                                      transactionId: '',
                                      amount:
                                          double.tryParse(_amountCtrl.text) ??
                                          widget.existing?.amount ??
                                          0.0,
                                      paidAt: DateTime.now(),
                                      createdAt: DateTime.now(),
                                      updatedAt: DateTime.now(),
                                    );
                                    final created = await _duesService
                                        .createDuePayment(
                                          orgId: widget.orgId,
                                          payment: payment,
                                        );
                                    setState(() {
                                      _paid[userId] = true;
                                      _sessionCreatedDocIds[userId] =
                                          created.id;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Payment recorded'),
                                      ),
                                    );
                                  } catch (e) {
                                    try {
                                      final paymentsColl = FirebaseFirestore
                                          .instance
                                          .collection('organizations')
                                          .doc(widget.orgId)
                                          .collection('dues')
                                          .doc(dueId)
                                          .collection('due_payments');
                                      final now = DateTime.now();
                                      final ref = await paymentsColl.add({
                                        'dueId': dueId,
                                        'userId': userId,
                                        'transactionId': '',
                                        'amount':
                                            double.tryParse(_amountCtrl.text) ??
                                            widget.existing?.amount ??
                                            0.0,
                                        'paidAt': Timestamp.fromDate(now),
                                        'createdAt': Timestamp.fromDate(now),
                                        'updatedAt': Timestamp.fromDate(now),
                                      });
                                      setState(() {
                                        _paid[userId] = true;
                                        _sessionCreatedDocIds[userId] = ref.id;
                                      });
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Payment recorded'),
                                        ),
                                      );
                                    } catch (e2) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to record payment: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
