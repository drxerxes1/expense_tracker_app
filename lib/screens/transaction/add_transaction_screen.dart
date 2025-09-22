import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:org_wallet/widgets/calculator_keypad.dart';
import 'package:org_wallet/models/category.dart';
import 'package:org_wallet/constants/default_categories.dart';
import 'package:intl/intl.dart';
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

enum TransactionType { expense, fund }

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  CategoryModel? _selectedCategory;
  List<CategoryModel> _categories = [];
  TransactionType _selectedType = TransactionType.expense;
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String _amount = '';
  String _expression = '';

  void _updateCategories() {
    // If no custom categories, use defaults based on tab
    if (_categories.isEmpty) {
      if (_selectedType == TransactionType.expense) {
        _categories = List<CategoryModel>.from(defaultExpenseCategories);
      } else {
        _categories = List<CategoryModel>.from(defaultFundCategories);
      }
    } else {
      // Filter categories by type for current tab
      _categories = _categories
          .where((cat) => cat.type == (_selectedType == TransactionType.expense ? CategoryType.expense : CategoryType.fund))
          .toList();
      // If still empty, fallback to defaults
      if (_categories.isEmpty) {
        if (_selectedType == TransactionType.expense) {
          _categories = List<CategoryModel>.from(defaultExpenseCategories);
        } else {
          _categories = List<CategoryModel>.from(defaultFundCategories);
        }
      }
    }
    // Always select first category
    if (_categories.isNotEmpty) {
      _selectedCategory = _categories.first;
    } else {
      _selectedCategory = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedType = _tabController.index == 0
            ? TransactionType.expense
            : TransactionType.fund;
        _updateCategories();
      });
    });
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final orgId = authService.currentOrgId;
    if (orgId == null) {
      setState(() {});
      _updateCategories();
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('categories')
        .get();
    setState(() {
      _categories = snap.docs
          .map((d) => CategoryModel.fromFirestore(d))
          .toList();
    });
    _updateCategories();
  }

  bool _isLoading = false;

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _addTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_amount.isEmpty ||
        double.tryParse(_amount) == null ||
        double.parse(_amount) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestore = FirebaseFirestore.instance;
      if (authService.currentOrgId == null) {
        throw Exception('No organization selected');
      }
      final orgId = authService.currentOrgId;
      final userId = authService.firebaseUser?.uid;
      if (orgId == null || userId == null || _selectedCategory == null) {
        throw Exception('Missing organization, user, or category');
      }
      final amount = double.parse(_amount);
      final note = _noteController.text.trim();
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
        'type': _selectedType == TransactionType.expense ? 'expense' : 'fund',
        'date': Timestamp.fromDate(_selectedDate),
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
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
        title: const Text(
          'Add Transaction',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: TWColors.slate.shade200,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Expense'),
            Tab(text: 'Fund'),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  _selectedType == TransactionType.expense
                      ? 'Add Expense'
                      : 'Add Fund',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _selectedType == TransactionType.expense
                      ? 'Record a new expense for your organization'
                      : 'Record a new fund for your organization',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Amount Field with Custom Keypad
                Text('Amount', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _amount.isEmpty
                        ? (_expression.isEmpty ? '0.00' : _expression)
                        : _amount,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CalculatorKeypad(
                  value: _expression,
                  onValueChanged: (val) {
                    setState(() {
                      _expression = val;
                      // If result is a valid number, update _amount
                      final parsed = double.tryParse(val);
                      if (parsed != null) {
                        _amount = val;
                      } else {
                        _amount = '';
                      }
                    });
                  },
                  theme: Theme.of(context),
                ),
                const SizedBox(height: 20),

                // Category Field
                DropdownButtonFormField<CategoryModel>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((category) {
                    IconData icon;
                    switch (category.id) {
                      case 'food':
                        icon = Icons.restaurant;
                        break;
                      case 'transportation':
                        icon = Icons.directions_bus;
                        break;
                      case 'supplies':
                        icon = Icons.shopping_bag;
                        break;
                      case 'utilities':
                        icon = Icons.lightbulb;
                        break;
                      case 'miscellaneous':
                        icon = Icons.more_horiz;
                        break;
                      case 'school_funds':
                        icon = Icons.school;
                        break;
                      case 'club_funds':
                        icon = Icons.groups;
                        break;
                      default:
                        icon = Icons.category;
                    }
                    return DropdownMenuItem<CategoryModel>(
                      value: category,
                      child: Row(
                        children: [
                          Icon(icon, color: Colors.teal),
                          const SizedBox(width: 12),
                          Text(category.name),
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

                // Date Picker
                Text('Date', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat.yMMMMd().format(_selectedDate),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Note Field
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(Icons.note),
                    border: OutlineInputBorder(),
                    hintText: 'Description or reason for this transaction',
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty && value.length < 5) {
                      return 'Note must be at least 5 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Save Button
                FilledButton(
                  onPressed: _isLoading ? null : _addTransaction,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _selectedType == TransactionType.expense
                              ? 'Save Expense'
                              : 'Save Fund',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Numeric Keypad Widget
