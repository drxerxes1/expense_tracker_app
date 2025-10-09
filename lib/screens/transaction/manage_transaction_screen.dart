// Unified Transaction screen: add or edit depending on `transaction` being null.
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/models/transaction.dart';
import 'package:org_wallet/models/category.dart';
import 'package:org_wallet/constants/default_categories.dart';
import 'package:org_wallet/widgets/custom_text_field.dart';
import 'package:org_wallet/services/transaction_service.dart';
import 'package:org_wallet/services/auth_service.dart';

class TransactionScreen extends StatefulWidget {
  final AppTransaction? transaction;
  const TransactionScreen({super.key, this.transaction});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  CategoryModel? _selectedCategoryModel;
  String? _selectedFundId;
  List<CategoryModel> _categories = [];
  List<CategoryModel> _funds = [];
  int _tabIndex = 0; // 0 = Expense, 1 = Fund
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _amountController.text = widget.transaction!.amount.toStringAsFixed(2);
      _noteController.text = widget.transaction!.note;
      _selectedCategoryId = widget.transaction!.categoryId;
      _selectedDate = widget.transaction!.createdAt;
      _tabIndex = widget.transaction!.type == 'fund' ? 1 : 0;
      _selectedFundId = widget.transaction!.toMap()['fundId'] ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final userId = auth.firebaseUser?.uid ?? '';
      final orgId = widget.transaction?.orgId ?? auth.currentOrgId;
      if (orgId == null) throw Exception('No organization selected');
      final amount = double.parse(_amountController.text);
      final type = _tabIndex == 0 ? 'expense' : 'fund';
      final fundId = _selectedFundId;
      if (widget.transaction == null) {
        // Add mode
        if (_selectedCategoryModel == null) {
          // try to fetch category model
          final catDoc = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(orgId)
              .collection('categories')
              .doc(_selectedCategoryId)
              .get();
          _selectedCategoryModel = CategoryModel.fromFirestore(catDoc);
        }
        await TransactionService().createTransaction(
          orgId: orgId,
          amount: amount,
          categoryId: _selectedCategoryId ?? '',
          note: _noteController.text.trim(),
          addedBy: userId,
          expectedType: _selectedCategoryModel?.type ?? CategoryType.fund,
          type: type,
          fundId: fundId,
          date: _selectedDate,
        );
        Navigator.of(context).pop(true);
      } else {
        // Edit mode
        final txId = widget.transaction!.id;
        await TransactionService().updateTransaction(orgId, txId, {
          'amount': amount,
          'categoryId': _selectedCategoryId,
          'note': _noteController.text.trim(),
          'updatedBy': userId,
          'type': type,
          'fundId': fundId ?? '',
          'createdAt': Timestamp.fromDate(_selectedDate),
        });
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final orgId = widget.transaction!.orgId;
      await TransactionService().deleteTransaction(
        orgId,
        widget.transaction!.id,
        by: auth.firebaseUser?.uid,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final orgId = widget.transaction?.orgId ?? auth.currentOrgId;
    final isEdit = widget.transaction != null;
    // Build a scrollable, tabbed form
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          isEdit ? 'Transaction' : 'Add Transaction',
          style: const TextStyle(color: Colors.black),
        ),
        centerTitle: false,
        backgroundColor: TWColors.slate.shade200,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ToggleButtons(
                isSelected: [_tabIndex == 0, _tabIndex == 1],
                onPressed: (i) => setState(() => _tabIndex = i),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Expense'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Fund'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CustomTextField(
                          controller: _amountController,
                          hintText: 'Amount',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter amount';
                            final parsed = double.tryParse(v);
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        // Category dropdown
                        if (orgId == null)
                          const Text('No organization selected')
                        else
                          FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('organizations')
                                .doc(orgId)
                                .collection('categories')
                                .get(),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
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
                              // Build a map keyed by id to deduplicate any duplicate category ids
                              final Map<String, CategoryModel> catsMap = {};
                              for (final d in docs) {
                                final cm = CategoryModel.fromFirestore(d);
                                // For expense tab, only include expense categories
                                if (_tabIndex == 0) {
                                  if (cm.type == CategoryType.expense) {
                                    catsMap[cm.id] = cm;
                                  }
                                } else {
                                  // For fund tab include all org categories (we'll merge defaults too)
                                  catsMap[cm.id] = cm;
                                }
                              }
                              // If Fund tab: ensure all default categories (expense + fund) are present
                              if (_tabIndex == 1) {
                                for (final c in [
                                  ...defaultExpenseCategories,
                                  ...defaultFundCategories,
                                ]) {
                                  catsMap.putIfAbsent(
                                    c.id,
                                    () => CategoryModel(
                                      id: c.id,
                                      name: c.name,
                                      type: c.type,
                                    ),
                                  );
                                }
                                // Remove explicit School Fund and Club Fund entries from the selectable category list
                                // These are special fund buckets; users should select specific fund categories instead
                                catsMap.removeWhere(
                                  (key, value) =>
                                      key == 'school_funds' ||
                                      key == 'club_funds',
                                );
                              }
                              _categories = catsMap.values.toList();
                              if (_categories.isEmpty) {
                                // fallback - expense tab uses expense defaults, fund tab uses both
                                _categories =
                                    (_tabIndex == 0
                                            ? defaultExpenseCategories
                                            : [
                                                ...defaultExpenseCategories,
                                                ...defaultFundCategories,
                                              ])
                                        .map(
                                          (c) => CategoryModel(
                                            id: c.id,
                                            name: c.name,
                                            type: c.type,
                                          ),
                                        )
                                        .toList();
                              }
                              // If a selected id exists but isn't in the current list, schedule a background fetch
                              if (_selectedCategoryId != null &&
                                  _categories
                                      .where((c) => c.id == _selectedCategoryId)
                                      .isEmpty) {
                                // insert a temporary placeholder so Dropdown has a matching value immediately
                                _categories.insert(
                                  0,
                                  CategoryModel(
                                    id: _selectedCategoryId!,
                                    name: 'Selected',
                                    type: _tabIndex == 0
                                        ? CategoryType.expense
                                        : CategoryType.fund,
                                  ),
                                );
                                // try to fetch a full category doc in the background and replace placeholder
                                _ensureSelectedCategoryPresent(
                                  orgId,
                                  _selectedCategoryId!,
                                );
                              }
                              // Ensure selected id refers to exactly one item; default only if null
                              if (_selectedCategoryId == null &&
                                  _categories.isNotEmpty) {
                                _selectedCategoryId = _categories.first.id;
                              }
                              _selectedCategoryModel = _categories.isNotEmpty
                                  ? _categories.firstWhere(
                                      (c) => c.id == _selectedCategoryId,
                                      orElse: () => _categories.first,
                                    )
                                  : null;
                              return DropdownButtonFormField<String>(
                                value: _selectedCategoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                ),
                                items: _categories
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _selectedCategoryId = v;
                                    _selectedCategoryModel = _categories
                                        .firstWhere(
                                          (c) => c.id == v,
                                          orElse: () =>
                                              _selectedCategoryModel ??
                                              _categories.first,
                                        );
                                  });
                                },
                              );
                            },
                          ),
                        const SizedBox(height: 12),
                        // Fund selector (choose which fund to add to or deduct from)
                        FutureBuilder<QuerySnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('organizations')
                              .doc(orgId)
                              .collection('categories')
                              .where('type', isEqualTo: 'fund')
                              .get(),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
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
                            final Map<String, CategoryModel> fundMap = {};
                            for (final d in docs) {
                              final fm = CategoryModel.fromFirestore(d);
                              fundMap[fm.id] = fm;
                            }
                            _funds = fundMap.values.toList();
                            if (_funds.isEmpty) {
                              _funds = defaultFundCategories
                                  .map(
                                    (c) => CategoryModel(
                                      id: c.id,
                                      name: c.name,
                                      type: c.type,
                                    ),
                                  )
                                  .toList();
                            }
                            if (_selectedFundId == null ||
                                _funds
                                        .where((f) => f.id == _selectedFundId)
                                        .length !=
                                    1) {
                              _selectedFundId = _funds.isNotEmpty
                                  ? _funds.first.id
                                  : null;
                            }
                            return DropdownButtonFormField<String>(
                              value: _selectedFundId,
                              decoration: InputDecoration(
                                labelText: _tabIndex == 0
                                    ? 'Deduct from fund'
                                    : 'Add to fund',
                              ),
                              items: _funds
                                  .map(
                                    (f) => DropdownMenuItem(
                                      value: f.id,
                                      child: Text(f.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedFundId = v),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        // Date picker
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() => _selectedDate = picked);
                                }
                              },
                              child: const Text('Change'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _noteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!isEdit)
                          FilledButton(
                            onPressed: _isLoading ? null : _save,
                            style: ButtonStyle(
                              padding: MaterialStateProperty.all(
                                const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Add Transaction'),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _isLoading ? null : _save,
                                  style: ButtonStyle(
                                    padding: MaterialStateProperty.all(
                                      const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Save Changes'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : _delete,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Try to fetch the full category doc for a selected id and replace the placeholder
  Future<void> _ensureSelectedCategoryPresent(
    String? orgId,
    String selectedId,
  ) async {
    if (orgId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('categories')
          .doc(selectedId)
          .get();
      if (!mounted) return;
      if (doc.exists) {
        final fetched = CategoryModel.fromFirestore(doc);
        setState(() {
          // remove any placeholder(s) with same id and insert fetched at front
          _categories.removeWhere((c) => c.id == selectedId);
          _categories.insert(0, fetched);
          _selectedCategoryModel = fetched;
        });
      }
    } catch (_) {
      // ignore silently; placeholder remains
    }
  }
}
