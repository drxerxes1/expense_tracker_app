import 'package:org_wallet/models/category.dart';
// ...existing code...
// ...existing code...
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/services/auth_service.dart';
// import 'package:org_wallet/models/expense.dart';
import 'package:org_wallet/models/audit_trail.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  CategoryModel? _selectedCategory;
  List<CategoryModel> _categories = [];
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final orgId = authService.currentOrgId;
    if (orgId == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('categories')
        .get();
    setState(() {
      _categories = snap.docs.map((d) => CategoryModel.fromFirestore(d)).toList();
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
    });
  }
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _addExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestore = FirebaseFirestore.instance;

      if (authService.currentOrgId == null) {
        throw Exception('No organization selected');
      }

      // Create transaction using TransactionService
      final orgId = authService.currentOrgId;
      final userId = authService.firebaseUser?.uid;
      if (orgId == null || userId == null || _selectedCategory == null) {
        throw Exception('Missing organization, user, or category');
      }
      final amount = double.parse(_amountController.text);
      final note = _noteController.text.trim();
  // ...existing code...
      final txDoc = firestore
        .collection('organizations')
        .doc(orgId)
        .collection('transactions')
        .doc();
      await txDoc.set({
        'id': txDoc.id,
        'orgId': orgId,
        'amount': amount,
        'categoryId': _selectedCategory!.id,
        'note': note,
        'addedBy': userId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Create audit trail
      final auditDoc = firestore.collection('auditTrail').doc();
      final auditTrail = AuditTrail(
        id: auditDoc.id,
        expenseId: txDoc.id,
        action: AuditAction.created,
        reason: '',
        by: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await auditDoc.set(auditTrail.toMap());

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction added successfully!'),
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
            content: Text('Error adding transaction: $e'),
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
  title: const Text('Add Transaction'),
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
                  Icons.add_circle_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Add New Transaction',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Record a new transaction for your organization',
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
                DropdownButtonFormField<CategoryModel>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem<CategoryModel>(
                      value: category,
                      child: Row(
                        children: [
                          Icon(Icons.category, color: Colors.teal),
                          const SizedBox(width: 12),
                          Text(category.name + ' (${category.type.toShortString()})'),
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
                const SizedBox(height: 30),

                // Add Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _addExpense,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Transaction'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Category color/icon helpers can be refactored to use category name/type if needed
}
