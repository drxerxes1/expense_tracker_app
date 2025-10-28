// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:org_wallet/models/due.dart';
import 'package:org_wallet/services/dues_service.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/officer.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';

class AddEditDueScreen extends StatefulWidget {
  final DueModel? existing;
  final String orgId;
  const AddEditDueScreen({super.key, this.existing, required this.orgId});

  @override
  State<AddEditDueScreen> createState() => _AddEditDueScreenState();
}

class _AddEditDueScreenState extends State<AddEditDueScreen> {
  late final DuesService _duesService;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  DateTime _dueDate = DateTime.now();
  String _frequency = 'monthly';
  bool _saving = false;

  // payment status map userId -> paid (read-only for display)
  final Map<String, bool> _paid = {};

  @override
  void initState() {
    super.initState();
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
        final createdDue = await _duesService.createDueWithId(due: due);
        
        // Create payment placeholders for all organization members
        await _duesService.createPaymentPlaceholders(widget.orgId, createdDue.id, amount);
        
        SnackBarHelper.showSuccess(
          context,
          message: 'Due created',
        );
        // After creating, load payments (there will be none) and enable list
        Navigator.of(context).pop(true);
      } else {
        await _duesService.updateDueWithMap(
          orgId: widget.orgId,
          dueId: widget.existing!.id,
          updates: {
            'name': name,
            'amount': amount,
            'frequency': _frequency,
            'dueDate': Timestamp.fromDate(_dueDate),
          },
        );
        SnackBarHelper.showSuccess(
          context,
          message: 'Due updated',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      SnackBarHelper.showError(
        context,
        message: 'Error saving: $e',
      );
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
        title: Text(
          widget.existing == null ? 'Add Due' : 'Edit Due',
          style: const TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: false,
        backgroundColor: TWColors.slate.shade200,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Form Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Due Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: TWColors.slate.shade800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Name Field
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Due Name',
                          hintText: 'e.g., Monthly Membership Fee',
                          prefixIcon: const Icon(Icons.label_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: TWColors.slate.shade50,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Due name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Amount Field
                      TextFormField(
                        controller: _amountCtrl,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          hintText: '0.00',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: TWColors.slate.shade50,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final parsed = double.tryParse(v ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Due Date Field
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: TWColors.slate.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: TWColors.slate.shade50,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: TWColors.slate.shade600),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Due Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: TWColors.slate.shade600,
                                    ),
                                  ),
                                  Text(
                                    _dueDate.toLocal().toString().split(' ')[0],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _dueDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) setState(() => _dueDate = picked);
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Change'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Frequency Field
                      DropdownButtonFormField<String>(
                        value: _frequency,
                        decoration: InputDecoration(
                          labelText: 'Frequency',
                          prefixIcon: const Icon(Icons.schedule),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: TWColors.slate.shade50,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                          DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                          DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                        ],
                        onChanged: (v) => setState(() => _frequency = v ?? _frequency),
                      ),
                      const SizedBox(height: 24),
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: TWColors.blue.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.existing == null ? 'Create Due' : 'Update Due',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Member Payment Management Section
            if (widget.existing != null) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, color: TWColors.slate.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Member Payments',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: TWColors.slate.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'View member payment status for this due',
                        style: TextStyle(
                          fontSize: 14,
                          color: TWColors.slate.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 400,
                        child: StreamBuilder<QuerySnapshot>(
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
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No members found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add members to your organization first',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            
                            return ListView.builder(
                              itemCount: approvedDocs.length,
                              itemBuilder: (context, i) {
                                final m = approvedDocs[i].data() as Map<String, dynamic>;
                                final userId = (m['userId'] ?? '').toString();
                                final name = (m['name'] ?? m['email'] ?? userId).toString();
                                final role = (m['role'] ?? '').toString();
                                final paid = _paid[userId] == true;
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: paid ? Colors.green.shade200 : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: paid 
                                          ? Colors.green.shade100 
                                          : Colors.grey.shade200,
                                      child: Icon(
                                        paid ? Icons.check : Icons.person,
                                        color: paid 
                                            ? Colors.green.shade700 
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: paid ? Colors.green.shade800 : null,
                                      ),
                                    ),
                                    subtitle: role.isNotEmpty 
                                        ? Text(
                                            role,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          )
                                        : null,
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: paid 
                                            ? Colors.green.shade100 
                                            : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: paid 
                                              ? Colors.green.shade300 
                                              : Colors.orange.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            paid ? Icons.check_circle : Icons.pending,
                                            size: 16,
                                            color: paid 
                                                ? Colors.green.shade700 
                                                : Colors.orange.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            paid ? 'Paid' : 'Unpaid',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: paid 
                                                  ? Colors.green.shade700 
                                                  : Colors.orange.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Empty state for new dues
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.save_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Save the due to manage member payments',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'After creating the due, you can track which members have paid',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
