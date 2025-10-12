// Unified Transaction screen: add or edit depending on `transaction` being null.
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:org_wallet/screens/transaction/collection_tab.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/models/transaction.dart';
import 'package:org_wallet/models/category.dart';
import 'package:org_wallet/constants/default_categories.dart';
import 'package:org_wallet/widgets/custom_text_field.dart';
import 'package:org_wallet/services/transaction_service.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:org_wallet/services/dues_service.dart';
import 'package:org_wallet/models/due_payment.dart';
import 'package:org_wallet/services/auth_service.dart';

class TransactionScreen extends StatefulWidget {
  final AppTransaction? transaction;
  // Optional: when opening an existing collection transaction we can pass the dueId
  // that corresponds to the transaction so the CollectionTab can preselect it.
  final String? initialCollectionDueId;
  const TransactionScreen({
    super.key,
    this.transaction,
    this.initialCollectionDueId,
  });

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  // UI state
  int _tabIndex = 0; // 0: expense, 1: fund, 2: collection
  bool _isLoading = false;
  late TabController _tabController;

  // Category/fund selections
  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategoryModel;
  String? _selectedCategoryId;

  List<CategoryModel> _funds = [];
  String? _selectedFundId;

  // Date
  DateTime _selectedDate = DateTime.now();

  // Collection-specific state
  Set<String> _collectionSelectedUserIds = {};
  String? _collectionSelectedDueId;
  bool _isCollectionOnly = false;

  @override
  void initState() {
    super.initState();
    // If editing an existing transaction, initialize fields
    final tx = widget.transaction;
    if (tx != null) {
      _amountController.text = tx.amount.toStringAsFixed(2);
      _noteController.text = tx.note;
      _selectedDate = tx.createdAt;
      // If the transaction's category indicates it's a Collection, treat this
      // screen as collection-only (hide Expense and Fund tabs).
      final catId = tx.categoryId.toLowerCase();
      final catName = tx.categoryName.toLowerCase();
      if (catId == 'collections' ||
          catName.contains('collect') ||
          tx.type == 'collection') {
        _isCollectionOnly = true;
        _tabIndex = 2;
      } else if (tx.type == 'fund') {
        _tabIndex = 1;
      } else {
        _tabIndex = 0;
      }
      _selectedCategoryId = tx.categoryId;
      _selectedFundId = tx.fundId;
      // If caller supplied an initialCollectionDueId, use it immediately so the
      // CollectionTab can subscribe straight away.
      if (widget.initialCollectionDueId != null) {
        _collectionSelectedDueId = widget.initialCollectionDueId;
      }
      // If this is a collection transaction, try to locate the dueId that
      // matches payments created for this transaction so the UI can preselect
      // the correct due and show paid members.
      if (_isCollectionOnly) {
        // Fire off async lookup (don't await in initState)
        _findDueForTransaction(tx.id, tx.orgId);
      }
    }
    // initialize TabController for three possible tabs
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _tabIndex,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return; // ignore while animating
      if (_tabIndex != _tabController.index) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
  }

  Future<void> _findDueForTransaction(String txId, String orgId) async {
    try {
      final duesSnap = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('dues')
          .get();
      for (final d in duesSnap.docs) {
        final paymentsColl = d.reference.collection('due_payments');
        final q = await paymentsColl
            .where('transactionId', isEqualTo: txId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          if (mounted) setState(() => _collectionSelectedDueId = d.id);
          return;
        }
      }
    } catch (_) {
      // ignore lookup failures
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final userId = auth.firebaseUser?.uid;
      final orgId = widget.transaction?.orgId ?? auth.currentOrgId;
      if (orgId == null) throw 'No organization selected';

      final amount = double.tryParse(_amountController.text) ?? 0.0;

      // determine category/fund to use
      String? categoryIdToUse = _selectedCategoryId;
      String? fundId = _selectedFundId;

      // For collection tab we don't show category/fund pickers in UI, but
      // business rule: collections are stored as fund-type transactions
      if (_tabIndex == 2) {
        // Use a dedicated 'collections' category id if present in org, else fallback to default
        categoryIdToUse = 'collections';
        fundId =
            'club_funds'; // collections are added to club_funds per requirement
      }

      final type = _tabIndex == 0 ? 'expense' : 'fund';

      // selectedCategoryModel may be null; that's okay — TransactionService will validate expectedType
      final expectedType = _tabIndex == 2
          ? CategoryType.fund
          : (_selectedCategoryModel?.type ?? CategoryType.fund);

      if (widget.transaction == null) {
        final txId = await TransactionService().createTransaction(
          orgId: orgId,
          amount: amount,
          categoryId: categoryIdToUse ?? '',
          note: _noteController.text.trim(),
          addedBy: userId ?? '',
          expectedType: expectedType,
          type: type,
          fundId: fundId,
          date: _selectedDate,
        );

        // If Collection tab, create due_payments for selected members (post-transaction)
        if (_tabIndex == 2 &&
            _collectionSelectedUserIds.isNotEmpty &&
            _collectionSelectedDueId != null) {
          final duesService = DuesService();
          final now = DateTime.now();
          for (final memberId in _collectionSelectedUserIds) {
            try {
              final payment = DuePaymentModel(
                id: memberId,
                dueId: _collectionSelectedDueId!,
                userId: memberId,
                transactionId: txId,
                amount: amount,
                paidAt: now,
                createdAt: now,
                updatedAt: now,
              );
              await duesService.createDuePayment(
                orgId: orgId,
                payment: payment,
              );
            } catch (e) {
              // If deterministic-id write disallowed by rules, fallback to auto-id add
              try {
                final paymentsColl = FirebaseFirestore.instance
                    .collection('organizations')
                    .doc(orgId)
                    .collection('dues')
                    .doc(_collectionSelectedDueId!)
                    .collection('due_payments');
                await paymentsColl.add({
                  'dueId': _collectionSelectedDueId!,
                  'userId': memberId,
                  'transactionId': txId,
                  'amount': amount,
                  'paidAt': Timestamp.fromDate(now),
                  'createdAt': Timestamp.fromDate(now),
                  'updatedAt': Timestamp.fromDate(now),
                });
              } catch (_) {
                // ignore fallback failure
              }
            }
          }
        }

        if (mounted) Navigator.of(context).pop(true);
      } else {
        // Edit existing transaction
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
        if (mounted) Navigator.of(context).pop(true);
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
      if (mounted) Navigator.of(context).pop(true);
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
        child: Column(
          children: [
            Builder(
              builder: (context) {
                final tx = widget.transaction;
                final txType = tx?.type;
                final txCatId = (tx?.categoryId ?? '').toLowerCase();
                final txCatName = (tx?.categoryName ?? '').toLowerCase();

                final bool detectedCollection =
                    _isCollectionOnly ||
                    txType == 'collection' ||
                    txCatId == 'collections' ||
                    txCatName.contains('collect');

                List<int> visibleIndices;
                if (tx == null) {
                  visibleIndices = [0, 1, 2];
                } else if (detectedCollection) {
                  visibleIndices = [2];
                } else {
                  visibleIndices = [0, 1];
                }

                // Ensure controller index is valid
                if (!visibleIndices.contains(_tabController.index)) {
                  // jump to first allowed
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _tabController.index = visibleIndices.first;
                  });
                }

                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: TWColors.slate.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    onTap: (index) {
                      // Only allow switching to a visible tab
                      if (!visibleIndices.contains(index)) return;
                      setState(() => _tabIndex = index);
                    },
                    tabs: const [
                      Tab(text: 'Expense'),
                      Tab(text: 'Fund'),
                      Tab(text: 'Collection'),
                    ],
                    // remove internal padding so the text isn't wrapped by extra spacing
                    labelPadding: EdgeInsets.zero,
                    labelColor: Colors.black,
                    indicatorColor: Colors.black,
                    unselectedLabelColor: Colors.grey[700],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CustomTextField(
                          controller: _amountController,
                          hintText: 'Amount',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          enabled:
                              _tabIndex !=
                              2, // disable editing when on Collection tab
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
                        if (_tabIndex == 2)
                          CollectionTab(
                            orgId: orgId ?? '',
                            createPaymentsImmediately: false,
                            initialDueId: _collectionSelectedDueId,
                            currentTransactionId: widget.transaction?.id,
                            onAmountChanged: (val) =>
                                _amountController.text = val.toStringAsFixed(2),
                            onSelectionChanged: (set) =>
                                _collectionSelectedUserIds = set,
                            onSelectedDueChanged: (dueId) =>
                                _collectionSelectedDueId = dueId,
                          ),
                        if (_tabIndex != 2) ...[
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
                                final Map<String, CategoryModel> orgExpense =
                                    {};
                                final Map<String, CategoryModel> orgFund = {};
                                for (final d in docs) {
                                  final cm = CategoryModel.fromFirestore(d);
                                  if (cm.type == CategoryType.expense) {
                                    orgExpense[cm.id] = cm;
                                  }
                                  if (cm.type == CategoryType.fund) {
                                    orgFund[cm.id] = cm;
                                  }
                                }

                                if (_tabIndex == 0) {
                                  final List<CategoryModel> finalList = [
                                    for (final d in defaultExpenseCategories)
                                      CategoryModel(
                                        id: d.id,
                                        name: d.name,
                                        type: d.type,
                                      ),
                                  ];
                                  for (final cm in orgExpense.values) {
                                    if (!finalList.any((c) => c.id == cm.id)) {
                                      finalList.add(cm);
                                    }
                                  }
                                  _categories = finalList;
                                }
                                if (_tabIndex == 1) {
                                  final List<CategoryModel> finalList = [
                                    for (final d in defaultFundCategories)
                                      CategoryModel(
                                        id: d.id,
                                        name: d.name,
                                        type: d.type,
                                      ),
                                  ];
                                  for (final cm in orgFund.values) {
                                    // Exclude fund account buckets from the Fund tab's category list
                                    if (cm.id == 'school_funds' ||
                                        cm.id == 'club_funds') {
                                      continue;
                                    }
                                    if (!finalList.any((c) => c.id == cm.id)) {
                                      finalList.add(cm);
                                    }
                                  }
                                  _categories = finalList;
                                }

                                if (_categories.isNotEmpty) {
                                  final Map<String, CategoryModel> seen = {};
                                  final List<CategoryModel> deduped = [];
                                  for (final c in _categories) {
                                    if (!seen.containsKey(c.id)) {
                                      seen[c.id] = c;
                                      deduped.add(c);
                                    }
                                  }
                                  _categories = deduped;
                                  // Ensure fund account buckets are never presented as Fund tab categories
                                  _categories.removeWhere(
                                    (c) =>
                                        c.id == 'school_funds' ||
                                        c.id == 'club_funds',
                                  );
                                  if (_selectedCategoryId == null ||
                                      !_categories.any(
                                        (c) => c.id == _selectedCategoryId,
                                      )) {
                                    _selectedCategoryId = _categories.first.id;
                                  }
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
                                  onChanged: (v) => setState(() {
                                    _selectedCategoryId = v;
                                    _selectedCategoryModel = _categories
                                        .firstWhere(
                                          (c) => c.id == v,
                                          orElse: () =>
                                              _selectedCategoryModel ??
                                              _categories.first,
                                        );
                                  }),
                                );
                              },
                            ),
                          const SizedBox(height: 12),
                          FutureBuilder<List<DocumentSnapshot>>(
                            future: Future.wait([
                              FirebaseFirestore.instance
                                  .collection('organizations')
                                  .doc(orgId)
                                  .collection('categories')
                                  .doc('school_funds')
                                  .get(),
                              FirebaseFirestore.instance
                                  .collection('organizations')
                                  .doc(orgId)
                                  .collection('categories')
                                  .doc('club_funds')
                                  .get(),
                            ]),
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
                              final docs = snap.data ?? [];
                              final Map<String, CategoryModel> fundMap = {};
                              for (final d in docs) {
                                if (d.exists) {
                                  final fm = CategoryModel.fromFirestore(d);
                                  fundMap[fm.id] = fm;
                                }
                              }
                              _funds = fundMap.values.toList();
                              if (_funds.isEmpty) {
                                // Fallback to the canonical fund accounts (buckets)
                                _funds = defaultFundAccounts
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
                        ],
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
            ),
          ],
        ),
      ),
    );
  }
}
