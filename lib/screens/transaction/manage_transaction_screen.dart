// Unified Transaction screen: add or edit depending on `transaction` being null.
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:org_wallet/screens/transaction/collection_tab.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/models/transaction.dart';
import 'package:org_wallet/models/category.dart';
import 'package:org_wallet/widgets/custom_text_field.dart';
import 'package:org_wallet/services/transaction_service.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:org_wallet/services/dues_service.dart';
import 'package:org_wallet/models/due_payment.dart';
import 'package:org_wallet/models/due.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/services/category_service.dart';
import 'package:org_wallet/widgets/safe_category_dropdown.dart';
import 'package:org_wallet/widgets/edit_reason_dialog.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';

class TransactionScreen extends StatefulWidget {
  final AppTransaction? transaction;
  final String? initialCollectionDueId;
  final bool startWithCollectionTab;

  const TransactionScreen({
    super.key,
    this.transaction,
    this.initialCollectionDueId,
    this.startWithCollectionTab = false,
  });

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final CategoryService _categoryService = CategoryService();

  // UI state
  int _tabIndex = 0;
  bool _isLoading = false;
  TabController? _tabController;

  // Category/fund selections
  String? _selectedCategoryId;
  String? _selectedFundId;

  // Date
  DateTime _selectedDate = DateTime.now();

  // Collection-specific state
  Set<String> _collectionSelectedUserIds = {};
  String? _collectionSelectedDueId;
  bool _isCollectionOnly = false;

  // Data caches
  List<CategoryModel> _expenseCategories = [];
  List<CategoryModel> _fundCategories = [];
  List<CategoryModel> _fundAccounts = [];
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      // Initialize transaction data if editing
      if (widget.transaction != null) {
        await _initializeTransactionData();
      }

      // Initialize TabController with dynamic length based on transaction type
      final tx = widget.transaction;
      final txType = tx?.type;
      final txCatId = (tx?.categoryId ?? '').toLowerCase();
      final txCatName = (tx?.categoryName ?? '').toLowerCase();

      final bool detectedCollection =
          _isCollectionOnly ||
          txType == 'collection' ||
          txCatId == 'collections' ||
          txCatName.contains('collect');

      int tabLength;
      if (tx == null) {
        tabLength = 3; // All tabs for new transactions
        // If starting with collection tab, set the initial tab index
        if (widget.startWithCollectionTab) {
          _tabIndex = 2;
        }
      } else if (detectedCollection) {
        tabLength = 1; // Only collection tab for collection transactions
        _tabIndex = 2; // Collection tab is at index 2 in original array
      } else {
        tabLength = 2; // Only expense and fund tabs
      }

      _tabController = TabController(
        length: tabLength,
        vsync: this,
        initialIndex: _tabIndex.clamp(0, tabLength - 1),
      );
      _tabController!.addListener(_onTabChanged);

      // Load data
      await _loadData();

      // Trigger rebuild after initialization
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error in initialization: $e');
    }
  }

  Future<void> _initializeTransactionData() async {
    final tx = widget.transaction!;
    _amountController.text = tx.amount.toStringAsFixed(2);
    _noteController.text = tx.note;
    _selectedDate = tx.createdAt;

    // Determine transaction type
    final catId = tx.categoryId.toLowerCase();
    final catName = tx.categoryName.toLowerCase();

    if (catId == 'collections' ||
        catName.contains('collect') ||
        tx.type == 'collection') {
      _isCollectionOnly = true;
      _tabIndex = 2; // Collection tab is at index 2 in original array
    } else if (tx.type == 'fund') {
      _tabIndex = 1;
    } else {
      _tabIndex = 0;
    }

    _selectedCategoryId = tx.categoryId;
    _selectedFundId = tx.fundId;

    if (widget.initialCollectionDueId != null) {
      _collectionSelectedDueId = widget.initialCollectionDueId;
    }

    if (_isCollectionOnly) {
      await _findDueForTransaction(tx.id, tx.orgId);
    }
  }

  Future<void> _loadData() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final orgId = auth.currentOrgId;

      if (orgId == null || orgId.isEmpty) {
        debugPrint('No organization ID available');
        return;
      }

      // Ensure default categories exist
      await _categoryService.ensureDefaultCategoriesExist(orgId);
      await _categoryService.ensureFundAccountsExist(orgId);

      // Load categories
      final expenseCategories = await _categoryService.getCategoriesByType(
        orgId: orgId,
        type: CategoryType.expense,
      );

      final fundCategories = await _categoryService.getCategoriesByType(
        orgId: orgId,
        type: CategoryType.fund,
      );

      final fundAccounts = await _categoryService.getFundAccounts(orgId);

      if (mounted) {
        setState(() {
          _expenseCategories = expenseCategories
              .where((c) => !_categoryService.isFundAccount(c.id))
              .toList();
          _fundCategories = fundCategories
              .where(
                (c) =>
                    !_categoryService.isFundAccount(c.id) &&
                    c.id.toLowerCase() != 'collections',
              )
              .toList();
          _fundAccounts = fundAccounts;
          _dataLoaded = true;

          // Set default selections if not already set
          if (_selectedCategoryId == null) {
            if (_tabIndex == 0 && _expenseCategories.isNotEmpty) {
              _selectedCategoryId = _expenseCategories.first.id;
            } else if (_tabIndex == 1 && _fundCategories.isNotEmpty) {
              _selectedCategoryId = _fundCategories.first.id;
            }
          }

          if (_selectedFundId == null && _fundAccounts.isNotEmpty) {
            _selectedFundId = _fundAccounts.first.id;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  void _onTabChanged() {
    if (_tabController?.indexIsChanging ?? true) return;
    if (mounted) {
      // Get the visible indices for the current transaction type
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
        visibleIndices = [2]; // Only collection tab (index 2 in original array)
      } else {
        visibleIndices = [0, 1];
      }

      // Map the TabController index to the actual tab index
      final actualIndex = visibleIndices[_tabController!.index];
      if (_tabIndex != actualIndex) {
        setState(() => _tabIndex = actualIndex);
      }
    }
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
          if (mounted) {
            setState(() {
              _collectionSelectedDueId = d.id;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error finding due for transaction: $e');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if this is an edit operation and ask for reason
    if (widget.transaction != null) {
      final editReason = await showEditReasonDialog(context);
      if (editReason == null) {
        // User cancelled, don't proceed with save
        return;
      }

      // Proceed with save using the provided reason
      await _performSave(editReason);
    } else {
      // Create new transaction - no reason needed
      await _performSave('');
    }
  }

  Future<void> _performSave(String editReason) async {
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final userId = auth.firebaseUser?.uid;
      final orgId = widget.transaction?.orgId ?? auth.currentOrgId;

      if (orgId == null || orgId.isEmpty) {
        throw Exception('No organization selected');
      }

      final amount = double.tryParse(_amountController.text) ?? 0.0;

      // Determine category/fund to use
      String? categoryIdToUse = _selectedCategoryId;
      String? fundId = _selectedFundId;

      // Check if this is a collection transaction (either by tab index or by transaction type)
      final isCollectionTransaction =
          _tabIndex == 2 ||
          (widget.transaction != null &&
              (widget.transaction!.categoryId.toLowerCase() == 'collections' ||
                  widget.transaction!.categoryName.toLowerCase().contains(
                    'collect',
                  ) ||
                  widget.transaction!.type == 'collection'));

      if (isCollectionTransaction) {
        categoryIdToUse = 'collections';
        fundId = 'club_funds';
      } else {
        if (categoryIdToUse == null || categoryIdToUse.isEmpty) {
          throw Exception('Please select a category');
        }
        if (fundId == null || fundId.isEmpty) {
          throw Exception('Please select a fund account');
        }
      }

      final type = _tabIndex == 0 ? 'expense' : 'fund';
      final expectedType = _tabIndex == 0
          ? CategoryType.expense
          : CategoryType.fund;

      if (widget.transaction == null) {
        // Create new transaction
        final txId = await TransactionService().createTransaction(
          orgId: orgId,
          amount: amount,
          categoryId: categoryIdToUse,
          note: _noteController.text.trim(),
          addedBy: userId ?? '',
          expectedType: expectedType,
          type: type,
          fundId: fundId,
          date: _selectedDate,
        );

        // Handle collection payments
        if (isCollectionTransaction &&
            _collectionSelectedUserIds.isNotEmpty &&
            _collectionSelectedDueId != null) {
          await _createCollectionPayments(orgId, txId, amount);
        }

        if (mounted) Navigator.of(context).pop(true);
      } else {
        // Update existing transaction with edit reason
        await TransactionService().updateTransaction(
          orgId,
          widget.transaction!.id,
          {
            'amount': amount,
            'categoryId': categoryIdToUse,
            'note': _noteController.text.trim(),
            'updatedBy': userId,
            'type': type,
            'fundId': fundId,
            'createdAt': Timestamp.fromDate(_selectedDate),
            'reason': editReason, // Include the edit reason
          },
        );

        // Reconcile collection payments when editing a collection transaction
        if (isCollectionTransaction && _collectionSelectedDueId != null) {
          await _reconcileCollectionPayments(
            orgId: orgId,
            txId: widget.transaction!.id,
            txDate: _selectedDate,
          );
        }

        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, message: 'Error saving: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createCollectionPayments(
    String orgId,
    String txId,
    double totalAmount,
  ) async {
    final duesService = DuesService();
    final now = DateTime.now();

    // Get the due amount for individual payments
    double individualAmount = 0.0;
    if (_collectionSelectedDueId != null) {
      try {
        final dueDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgId)
            .collection('dues')
            .doc(_collectionSelectedDueId!)
            .get();
        if (dueDoc.exists) {
          final due = DueModel.fromFirestore(dueDoc);
          individualAmount = due.amount;
        }
      } catch (e) {
        debugPrint('Error getting due amount: $e');
        // Fallback to total amount divided by number of members
        individualAmount = totalAmount / _collectionSelectedUserIds.length;
      }
    }

    for (final memberId in _collectionSelectedUserIds) {
      try {
        final payment = DuePaymentModel(
          id: memberId,
          dueId: _collectionSelectedDueId!,
          userId: memberId,
          transactionId: txId,
          amount: individualAmount,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        );
        await duesService.createDuePaymentWithTransaction(
          orgId: orgId,
          payment: payment,
          transactionId: txId,
        );
      } catch (e) {
        // Fallback to auto-id
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
            'amount': individualAmount,
            'paidAt': Timestamp.fromDate(now),
            'createdAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
          });
        } catch (e2) {
          debugPrint('Failed to create payment for $memberId: $e2');
        }
      }
    }
  }

  Future<void> _reconcileCollectionPayments({
    required String orgId,
    required String txId,
    required DateTime txDate,
  }) async {
    if (_collectionSelectedDueId == null) return;
    final dueId = _collectionSelectedDueId!;
    final duesService = DuesService();

    // Fetch existing payments for this transaction or same-day fallback
    final paymentsColl = FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('dues')
        .doc(dueId)
        .collection('due_payments');

    final existingByUser = <String, DocumentSnapshot>{};
    final snap = await paymentsColl.get();
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>?
          ?? const <String, dynamic>{};
      final uid = (data['userId'] ?? '').toString();
      final tid = (data['transactionId'] ?? '').toString();
      final tsPaid = (data['paidAt'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate();
      final sameDay = tsPaid != null &&
          tsPaid.year == txDate.year &&
          tsPaid.month == txDate.month &&
          tsPaid.day == txDate.day;
      if (tid == txId || sameDay) {
        existingByUser[uid] = d;
      }
    }

    // Compute due amount per member
    double individualAmount = 0.0;
    try {
      final dueDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('dues')
          .doc(dueId)
          .get();
      if (dueDoc.exists) {
        final due = DueModel.fromFirestore(dueDoc);
        individualAmount = due.amount;
      }
    } catch (_) {}

    // Desired selected set from UI
    final desired = Set<String>.from(_collectionSelectedUserIds);

    // Create or update payments for selected users
    for (final uid in desired) {
      final existingDoc = existingByUser[uid];
      if (existingDoc == null) {
        // Create new payment linked to this transaction
        final now = DateTime.now();
        try {
          final payment = DuePaymentModel(
            id: uid,
            dueId: dueId,
            userId: uid,
            transactionId: txId,
            amount: individualAmount,
            paidAt: now,
            createdAt: now,
            updatedAt: now,
          );
          await duesService.createDuePaymentWithTransaction(
            orgId: orgId,
            payment: payment,
            transactionId: txId,
          );
        } catch (_) {
          // Fallback: auto-id
          await paymentsColl.add({
            'dueId': dueId,
            'userId': uid,
            'transactionId': txId,
            'amount': individualAmount,
            'paidAt': Timestamp.fromDate(DateTime.now()),
            'createdAt': Timestamp.fromDate(DateTime.now()),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
      } else {
        // Ensure it has this txId
        if ((existingDoc.data() as Map<String, dynamic>)['transactionId'] !=
            txId) {
          await existingDoc.reference.update({
            'transactionId': txId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    // Delete payments for users that are no longer selected
    for (final entry in existingByUser.entries) {
      final uid = entry.key;
      if (!desired.contains(uid)) {
        try {
          await entry.value.reference.delete();
        } catch (_) {}
      }
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
      await TransactionService().deleteTransaction(
        widget.transaction!.orgId,
        widget.transaction!.id,
        by: auth.firebaseUser?.uid,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, message: 'Error deleting: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTabBar() {
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
      visibleIndices = [2]; // Only collection tab (index 2 in original array)
    } else {
      visibleIndices = [0, 1];
    }

    // Ensure controller index is valid and map to visible indices
    if (_tabController != null) {
      // Find the TabController index that corresponds to the current _tabIndex
      final controllerIndex = visibleIndices.indexOf(_tabIndex);
      if (controllerIndex != -1 && _tabController!.index != controllerIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && controllerIndex < _tabController!.length) {
            _tabController!.index = controllerIndex;
          }
        });
      }
    }

    // Build tabs dynamically based on visible indices
    final List<Widget> tabs = [];
    const List<String> tabLabels = ['Expense', 'Fund', 'Collection'];

    for (int i = 0; i < visibleIndices.length; i++) {
      final tabIndex = visibleIndices[i];
      tabs.add(Tab(child: Text(tabLabels[tabIndex])));
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: TWColors.slate.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          // Map the tapped index to the actual tab index
          final actualIndex = visibleIndices[index];
          setState(() => _tabIndex = actualIndex);
        },
        tabs: tabs,
        labelPadding: EdgeInsets.zero,
        labelColor: Colors.black,
        indicatorColor: Colors.black,
        unselectedLabelColor: Colors.grey[700],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    if (!_dataLoaded) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final categories = _tabIndex == 0 ? _expenseCategories : _fundCategories;

    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No categories available'),
      );
    }

    return SafeCategoryDropdown(
      categories: categories,
      selectedCategoryId: _selectedCategoryId,
      onChanged: (v) {
        if (v != null) {
          setState(() {
            _selectedCategoryId = v;
          });
        }
      },
      labelText: 'Category',
      showIcons: true,
    );
  }

  Widget _buildFundDropdown() {
    if (!_dataLoaded) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_fundAccounts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No fund accounts available'),
      );
    }

    return SafeCategoryDropdown(
      categories: _fundAccounts,
      selectedCategoryId: _selectedFundId,
      onChanged: (v) {
        if (v != null) {
          setState(() => _selectedFundId = v);
        }
      },
      labelText: _tabIndex == 0 ? 'Deduct from fund' : 'Add to fund',
      showIcons: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if TabController is initialized
    if (_tabController == null) {
      return Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.black),
          title: Text(
            widget.transaction != null ? 'Transaction' : 'Add Transaction',
            style: const TextStyle(color: Colors.black),
          ),
          centerTitle: false,
          backgroundColor: TWColors.slate.shade200,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Safely get auth service
    final auth = Provider.of<AuthService>(context, listen: false);
    final orgId = widget.transaction?.orgId ?? auth.currentOrgId;
    final isEdit = widget.transaction != null;

    // Check if this is a collection transaction
    final isCollectionTransaction =
        _tabIndex == 2 ||
        (widget.transaction != null &&
            (widget.transaction!.categoryId.toLowerCase() == 'collections' ||
                widget.transaction!.categoryName.toLowerCase().contains(
                  'collect',
                ) ||
                widget.transaction!.type == 'collection'));

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
            _buildTabBar(),
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
                          enabled: !isCollectionTransaction,
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

                        // Collection Tab
                        if (isCollectionTransaction)
                          orgId != null && orgId.isNotEmpty
                              ? CollectionTab(
                                  orgId: orgId,
                                  createPaymentsImmediately: false,
                                  initialDueId: _collectionSelectedDueId,
                                  currentTransactionId: widget.transaction?.id,
                                  currentTransactionDate: widget.transaction?.createdAt,
                                  onAmountChanged: (val) =>
                                      _amountController.text = val
                                          .toStringAsFixed(2),
                                  onSelectionChanged: (set) =>
                                      _collectionSelectedUserIds = set,
                                  onSelectedDueChanged: (dueId) =>
                                      _collectionSelectedDueId = dueId,
                                )
                              : const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'No organization selected for collection',
                                  ),
                                ),

                        // Expense/Fund Tabs
                        if (!isCollectionTransaction) ...[
                          if (orgId == null || orgId.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No organization selected'),
                            )
                          else ...[
                            _buildCategoryDropdown(),
                            const SizedBox(height: 12),
                            _buildFundDropdown(),
                            const SizedBox(height: 12),
                          ],
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

                        // Note field
                        TextFormField(
                          controller: _noteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action buttons
                        if (!isEdit)
                          FilledButton(
                            onPressed: _isLoading ? null : _save,
                            style: ButtonStyle(
                              foregroundColor: MaterialStateProperty.all(
                                Colors.white,
                              ),
                              backgroundColor: MaterialStateProperty.all(
                                TWColors.slate.shade900,
                              ),
                              shape: MaterialStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),  
                                ),
                              ),
                            ),
                            child: const Text('Add Transaction', style: TextStyle(color: Colors.white),),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _isLoading ? null : _save,
                                  style: ButtonStyle(
                                    foregroundColor: MaterialStateProperty.all(
                                      TWColors.slate.shade900,
                                    ),
                                    backgroundColor: MaterialStateProperty.all(
                                      TWColors.slate.shade900, 
                                    ),
                                    shape: MaterialStateProperty.all(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
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
                                      : const Text(
                                          'Save Changes',
                                          style: TextStyle(color: Colors.white),
                                        ),
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
