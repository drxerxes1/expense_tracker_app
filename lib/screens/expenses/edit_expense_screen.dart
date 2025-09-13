// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/expense.dart';
import 'package:org_wallet/models/audit_trail.dart';

class EditExpenseScreen extends StatefulWidget {
  final Expense expense;

  const EditExpenseScreen({super.key, required this.expense});

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _reasonController = TextEditingController();
  ExpenseCategory _selectedCategory = ExpenseCategory.other;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.expense.amount.toString();
    _noteController.text = widget.expense.note;
    _selectedCategory = widget.expense.category;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _updateExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestore = FirebaseFirestore.instance;

      if (authService.currentOrgId == null) {
        throw Exception('No organization selected');
      }

      // Update expense
      final updatedExpense = widget.expense.copyWith(
        amount: double.parse(_amountController.text),
        category: _selectedCategory,
        note: _noteController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await firestore
          .collection('expenses')
          .doc(widget.expense.id)
          .update(updatedExpense.toMap());

      // Create audit trail
      final auditDoc = firestore.collection('auditTrail').doc();
      final auditTrail = AuditTrail(
        id: auditDoc.id,
        expenseId: widget.expense.id,
        action: AuditAction.edited,
        reason: _reasonController.text.trim(),
        by: authService.firebaseUser!.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await auditDoc.set(auditTrail.toMap());

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating expense: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Expense'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Icon(
                  Icons.edit,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Edit Expense',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Update expense details and provide a reason for the change',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Amount Field
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                    hintText: '0.00',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Category Field
                DropdownButtonFormField<ExpenseCategory>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  items: ExpenseCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(category),
                            color: _getCategoryColor(category),
                          ),
                          const SizedBox(width: 12),
                          Text(category.categoryDisplayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Note Field
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    prefixIcon: Icon(Icons.note),
                    border: OutlineInputBorder(),
                    hintText: 'Description or reason for this expense',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a note';
                    }
                    if (value.length < 5) {
                      return 'Note must be at least 5 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Reason for Edit Field
                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Edit *',
                    prefixIcon: Icon(Icons.edit_note),
                    border: OutlineInputBorder(),
                    hintText:
                        'Please provide a reason for editing this expense',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please provide a reason for editing';
                    }
                    if (value.length < 10) {
                      return 'Reason must be at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Update Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateExpense,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update Expense'),
                ),
                const SizedBox(height: 20),

                // Info Text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'All expense edits are tracked in the audit trail for transparency and compliance.',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Colors.orange;
      case ExpenseCategory.transportation:
        return Colors.blue;
      case ExpenseCategory.utilities:
        return Colors.green;
      case ExpenseCategory.entertainment:
        return Colors.purple;
      case ExpenseCategory.healthcare:
        return Colors.red;
      case ExpenseCategory.education:
        return Colors.indigo;
      case ExpenseCategory.shopping:
        return Colors.pink;
      case ExpenseCategory.other:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Icons.restaurant;
      case ExpenseCategory.transportation:
        return Icons.directions_car;
      case ExpenseCategory.utilities:
        return Icons.power;
      case ExpenseCategory.entertainment:
        return Icons.movie;
      case ExpenseCategory.healthcare:
        return Icons.local_hospital;
      case ExpenseCategory.education:
        return Icons.school;
      case ExpenseCategory.shopping:
        return Icons.shopping_cart;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }
}
