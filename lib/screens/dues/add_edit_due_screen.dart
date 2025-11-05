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
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30)); // Default 1 month ahead
  String _frequency = 'monthly';
  bool _saving = false;
  int _totalDuesCount = 1;

  // payment count map userId -> number of payments made
  final Map<String, int> _paymentCounts = {};

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
      _startDate = widget.existing!.startDate ?? widget.existing!.dueDate;
      _endDate = widget.existing!.endDate ?? widget.existing!.dueDate.add(const Duration(days: 30));
      _frequency = widget.existing!.frequency;
      _totalDuesCount = widget.existing!.totalDuesCount;
      // Load payment counts for all members for this due
      _loadPaymentCounts();
    } else {
      // Calculate initial dues count
      _totalDuesCount = _calculateDuesCount(_startDate, _endDate, _frequency);
    }
  }
  
  /// Calculate the number of dues between start and end dates based on frequency
  int _calculateDuesCount(DateTime start, DateTime end, String frequency) {
    if (end.isBefore(start)) return 0;
    
    switch (frequency.toLowerCase()) {
      case 'weekly':
        return ((end.difference(start).inDays) / 7).ceil();
      case 'monthly':
        int months = (end.year - start.year) * 12 + (end.month - start.month);
        return months > 0 ? months : 1;
      case 'quarterly':
        int months = (end.year - start.year) * 12 + (end.month - start.month);
        return (months / 3).ceil();
      case 'yearly':
        int years = end.year - start.year;
        return years > 0 ? years : 1;
      default:
        return 1;
    }
  }

  Future<void> _loadPaymentCounts() async {
    final dueId = widget.existing?.id;
    if (dueId == null) return;
    final payments = await _duesService.listDuePayments(widget.orgId, dueId);
    
    // Count only actual payments (those with paidAt set)
    final counts = <String, int>{};
    for (final p in payments) {
      // Only count if payment has been actually made (paidAt is not null)
      if (p.paidAt != null) {
        counts[p.userId] = (counts[p.userId] ?? 0) + 1;
      }
    }
    
    setState(() {
      _paymentCounts.clear();
      _paymentCounts.addAll(counts);
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
          dueDate: _startDate, // Use startDate as dueDate for backward compatibility
          startDate: _startDate,
          endDate: _endDate,
          totalDuesCount: _totalDuesCount,
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
            'dueDate': Timestamp.fromDate(_startDate),
            'startDate': Timestamp.fromDate(_startDate),
            'endDate': Timestamp.fromDate(_endDate),
            'totalDuesCount': _totalDuesCount,
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
                      
                      // Start Date Field
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: TWColors.slate.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: widget.existing != null ? TWColors.slate.shade100 : TWColors.slate.shade50,
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
                                    'Start Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: TWColors.slate.shade600,
                                    ),
                                  ),
                                  Text(
                                    _startDate.toLocal().toString().split(' ')[0],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: widget.existing != null ? TWColors.slate.shade500 : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.existing == null)
                              TextButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _startDate,
                                    firstDate: DateTime(2000),
                                    lastDate: _endDate,
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _startDate = picked;
                                      _totalDuesCount = _calculateDuesCount(_startDate, _endDate, _frequency);
                                    });
                                  }
                                },
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Change'),
                              )
                            else
                              Icon(Icons.lock_outline, size: 16, color: TWColors.slate.shade400),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // End Date Field
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: TWColors.slate.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: TWColors.slate.shade50,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event, color: TWColors.slate.shade600),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: TWColors.slate.shade600,
                                    ),
                                  ),
                                  Text(
                                    _endDate.toLocal().toString().split(' ')[0],
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
                                  initialDate: _endDate,
                                  firstDate: _startDate,
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _endDate = picked;
                                    _totalDuesCount = _calculateDuesCount(_startDate, _endDate, _frequency);
                                  });
                                }
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
                          fillColor: widget.existing != null ? TWColors.slate.shade100 : TWColors.slate.shade50,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                          DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                          DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                        ],
                        onChanged: widget.existing != null ? null : (v) {
                          setState(() {
                            _frequency = v ?? _frequency;
                            _totalDuesCount = _calculateDuesCount(_startDate, _endDate, _frequency);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Info message when editing
                      if (widget.existing != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: TWColors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: TWColors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: TWColors.amber.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Start date and frequency cannot be changed after creation',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: TWColors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.existing != null)
                        const SizedBox(height: 16),
                      
                      // Computed Dues Count Display
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: TWColors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: TWColors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: TWColors.blue.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Payment Periods',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: TWColors.blue.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'This due will have $_totalDuesCount payment${_totalDuesCount > 1 ? "s" : ""}.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: TWColors.blue.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: TWColors.slate.shade900,
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
                        'View member payment progress for this due',
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
                              
                              // Check if status is approved
                              bool isApproved = false;
                              if (status is String) {
                                isApproved = status == 'approved';
                              } else if (status is int) {
                                isApproved = status == OfficerStatus.approved.index;
                              }
                              if (!isApproved) return false;
                              
                              // Exclude moderators from the list
                              final role = (m['role'] ?? '').toString().toLowerCase();
                              final roleString = role.contains('.') ? role.split('.').last : role;
                              final isModerator = roleString == 'moderator';
                              
                              return !isModerator;
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
                                final paidCount = _paymentCounts[userId] ?? 0;
                                final totalCount = _totalDuesCount;
                                final isFullyPaid = paidCount >= totalCount;
                                final progress = totalCount > 0 ? paidCount / totalCount : 0.0;
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isFullyPaid ? Colors.green.shade300 : Colors.grey.shade200,
                                      width: isFullyPaid ? 2 : 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: isFullyPaid 
                                          ? Colors.green.shade100 
                                          : Colors.grey.shade200,
                                      child: Icon(
                                        isFullyPaid ? Icons.check_circle : Icons.person,
                                        color: isFullyPaid 
                                            ? Colors.green.shade700 
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isFullyPaid ? Colors.green.shade800 : Colors.black,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (role.isNotEmpty) ...[
                                          Text(
                                            role,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Text(
                                          'Progress: $paidCount / $totalCount payments',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isFullyPaid 
                                                ? Colors.green.shade600 
                                                : Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            isFullyPaid 
                                                ? Colors.green.shade500 
                                                : Colors.blue.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: isFullyPaid
                                        ? Icon(
                                            Icons.check_circle,
                                            color: Colors.green.shade700,
                                            size: 28,
                                          )
                                        : null,
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
