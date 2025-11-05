// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:org_wallet/models/due.dart';
import 'package:org_wallet/models/officer.dart';
import 'package:org_wallet/services/dues_service.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';
import 'package:org_wallet/services/transaction_service.dart';
import 'package:org_wallet/models/category.dart';
import 'package:org_wallet/widgets/edit_reason_dialog.dart';
import 'package:intl/intl.dart';

class DueTransactionScreen extends StatefulWidget {
  final String? initialTransactionId;
  final String? initialDueId;
  final DateTime? initialTransactionDate;
  const DueTransactionScreen({super.key, this.initialTransactionId, this.initialDueId, this.initialTransactionDate});

  @override
  State<DueTransactionScreen> createState() => _DueTransactionScreenState();
}

class _DueTransactionScreenState extends State<DueTransactionScreen> {
  final DuesService _duesService = DuesService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  DueModel? _selectedDue;
  final Map<String, int> _memberPaymentCounts = {}; // userId -> paid count
  final Map<String, bool> _selectedMembers = {}; // userId -> selected for this transaction
  bool _isLoading = false;
  bool _isSaving = false;
  DateTime _selectedDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    // Initialize date from widget parameter or use today
    _selectedDate = widget.initialTransactionDate ?? DateTime.now();
    // If opened for editing an existing collection transaction, initialize fields
    if (widget.initialTransactionId != null) {
      // Delay until build has a context and providers
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeEditMode();
      });
    }
  }

  Future<void> _initializeEditMode() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final orgId = auth.currentOrgId;
      if (orgId == null) return;

      String? dueId = widget.initialDueId;
      // If dueId not provided, locate it by scanning dues for payments with this transactionId
      if (dueId == null) {
        final duesSnap = await _firestore
            .collection('organizations')
            .doc(orgId)
            .collection('dues')
            .get();
        for (final d in duesSnap.docs) {
          final q = await d.reference
              .collection('due_payments')
              .where('transactionId', isEqualTo: widget.initialTransactionId)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            dueId = d.id;
            break;
          }
        }
      }

      if (dueId == null) return;

      // Load selected due model
      final dueDoc = await _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('dues')
          .doc(dueId)
          .get();
      if (!dueDoc.exists) return;
      
      // Load transaction to get its date
      DateTime? transactionDate;
      if (widget.initialTransactionId != null) {
        final txDoc = await _firestore
            .collection('organizations')
            .doc(orgId)
            .collection('transactions')
            .doc(widget.initialTransactionId)
            .get();
        if (txDoc.exists) {
          final txData = txDoc.data();
          if (txData != null) {
            final dateField = txData['date'];
            if (dateField != null) {
              if (dateField is Timestamp) {
                transactionDate = dateField.toDate();
              } else if (dateField is DateTime) {
                transactionDate = dateField;
              }
            }
          }
        }
      }
      
      setState(() {
        _selectedDue = DueModel.fromFirestore(dueDoc);
        if (transactionDate != null) {
          _selectedDate = transactionDate;
        }
      });

      // Load existing payments for this transaction to preselect members
      final paymentsSnap = await _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('dues')
          .doc(dueId)
          .collection('due_payments')
          .where('transactionId', isEqualTo: widget.initialTransactionId)
          .get();

      final selected = <String, bool>{};
      final counts = <String, int>{};
      for (final p in paymentsSnap.docs) {
        final data = p.data();
        final uid = (data['userId'] ?? '').toString();
        if (uid.isEmpty) continue;
        selected[uid] = true;
        // Only count payments that are actually paid
        if (data['paidAt'] != null) {
          counts[uid] = (counts[uid] ?? 0) + 1;
        }
      }

      setState(() {
        _selectedMembers.clear();
        _selectedMembers.addAll(selected);
        _memberPaymentCounts.clear();
        _memberPaymentCounts.addAll(counts);
      });
    } catch (e) {
      debugPrint('Error initializing edit mode: $e');
    }
  }
  
  Future<void> _loadPaymentCounts() async {
    if (_selectedDue == null) return;
    
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final orgId = auth.currentOrgId;
      if (orgId == null) return;
      
      // Get all payments for this due
      final payments = await _duesService.listDuePayments(orgId, _selectedDue!.id);
      
      // Count only actual payments (those with paidAt set)
      final counts = <String, int>{};
      for (final payment in payments) {
        // Only count if payment has been actually made (paidAt is not null)
        if (payment.paidAt != null) {
          counts[payment.userId] = (counts[payment.userId] ?? 0) + 1;
        }
      }
      
      setState(() {
        _memberPaymentCounts.clear();
        _memberPaymentCounts.addAll(counts);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading payment counts: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _saveTransaction() async {
    if (_selectedDue == null) {
      SnackBarHelper.showError(context, message: 'Please select a due');
      return;
    }
    
    if (_selectedMembers.values.where((v) => v).isEmpty) {
      SnackBarHelper.showError(context, message: 'Please select at least one member');
      return;
    }
    
    // Check if this is an edit operation and ask for reason
    String? editReason;
    if (widget.initialTransactionId != null && widget.initialTransactionId!.isNotEmpty) {
      editReason = await showEditReasonDialog(context);
      if (editReason == null) {
        // User cancelled, don't proceed with save
        return;
      }
    }
    
    setState(() => _isSaving = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final orgId = auth.currentOrgId;
      final userId = auth.firebaseUser?.uid;
      if (orgId == null || userId == null) return;
      
      final totalAmount = _calculateTotalAmount();

      // Determine whether we're editing an existing transaction or creating a new one
      String txId;
      if (widget.initialTransactionId != null && widget.initialTransactionId!.isNotEmpty) {
        // Update existing fund transaction
        txId = widget.initialTransactionId!;
        await TransactionService().updateTransaction(
          orgId,
          txId,
          {
            'amount': totalAmount,
            'categoryId': 'collections',
            'note': 'Dues: ${_selectedDue!.name}',
            'type': 'fund',
            'fundId': 'club_funds',
            'updatedBy': userId,
            'reason': editReason ?? '', // Include the edit reason
            'date': _selectedDate, // Update the date
          },
        );
      } else {
        // Create a new fund transaction under Club Funds with Collections category
        txId = await TransactionService().createTransaction(
          orgId: orgId,
          amount: totalAmount,
          categoryId: 'collections',
          note: 'Dues: ${_selectedDue!.name}',
          addedBy: userId,
          expectedType: CategoryType.fund,
          type: 'fund',
          fundId: 'club_funds',
          date: _selectedDate,
        );
      }

      // 2) Reconcile due payments linked to this transaction
      // Fetch existing payments for this txId under the selected due
      final dueId = _selectedDue!.id;
      final paymentsColl = _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('dues')
          .doc(dueId)
          .collection('due_payments');

      final existingSnap = await paymentsColl
          .where('transactionId', isEqualTo: txId)
          .get();

      final existingByUser = <String, DocumentReference>{};
      for (final d in existingSnap.docs) {
        final data = d.data() as Map<String, dynamic>? ?? const {};
        final uid = (data['userId'] ?? '').toString();
        if (uid.isEmpty) continue;
        existingByUser[uid] = d.reference;
      }

      // Create or keep payments for selected members
      for (final entry in _selectedMembers.entries) {
        final uid = entry.key;
        final selected = entry.value;
        if (!selected) continue;
        if (existingByUser.containsKey(uid)) {
          // Already exists; ensure linkage is correct (no-op otherwise)
          continue;
        }
        await _duesService.createDuePaymentWithAutoId(
          orgId: orgId,
          dueId: dueId,
          userId: uid,
          amount: _selectedDue!.amount,
          transactionId: txId,
        );
      }

      // Delete payments for users that are no longer selected
      for (final entry in existingByUser.entries) {
        final uid = entry.key;
        if (!(_selectedMembers[uid] ?? false)) {
          try {
            await entry.value.delete();
          } catch (_) {}
        }
      }
      
      SnackBarHelper.showSuccess(context, message: 'Payments recorded successfully');
      Navigator.of(context).pop(true);
    } catch (e) {
      SnackBarHelper.showError(context, message: 'Error saving: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }
  
  double _calculateTotalAmount() {
    if (_selectedDue == null) return 0.0;
    final selectedCount = _selectedMembers.values.where((v) => v).length;
    return _selectedDue!.amount * selectedCount;
  }
  
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final orgId = auth.currentOrgId;
    
    if (orgId == null) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: const Text('Due Transaction'),
          backgroundColor: TWColors.slate.shade200,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: const Center(child: Text('No organization selected')),
      );
    }
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'Due Transaction',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: TWColors.slate.shade200,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Combined Due Selector and Date Picker
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StreamBuilder<List<DueModel>>(
                    stream: _duesService.watchDues(orgId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final dues = snapshot.data ?? [];
                      // Sort dues alphabetically by name
                      final sortedDues = List<DueModel>.from(dues)
                        ..sort((a, b) => (a.name.toLowerCase()).compareTo(b.name.toLowerCase()));
                      if (dues.isEmpty) {
                        return const Text('No dues available');
                      }
                      
                      final isEditMode = widget.initialTransactionId != null && widget.initialTransactionId!.isNotEmpty;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedDue?.id,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: isEditMode ? TWColors.slate.shade100 : TWColors.slate.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            hint: const Text('Select due'),
                            items: sortedDues.map((due) {
                              return DropdownMenuItem(
                                value: due.id,
                                child: Text('${due.name} - PHP ${due.amount.toStringAsFixed(2)}'),
                              );
                            }).toList(),
                            onChanged: isEditMode ? null : (value) {
                              final due = sortedDues.firstWhere((d) => d.id == value);
                              setState(() {
                                _selectedDue = due;
                                _selectedMembers.clear();
                              });
                              _loadPaymentCounts();
                            },
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
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
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: TWColors.slate.shade300),
                                borderRadius: BorderRadius.circular(8),
                                color: TWColors.slate.shade50,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('MMM d, yyyy').format(_selectedDate),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: TWColors.slate.shade800,
                                    ),
                                  ),
                                  Icon(
                                    Icons.calendar_today,
                                    color: TWColors.slate.shade600,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Compact Due Info
            if (_selectedDue != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: TWColors.blue.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: TWColors.blue.shade800,
                      ),
                    ),
                    Text(
                      'PHP ${_calculateTotalAmount().toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: TWColors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Members List
            if (_selectedDue != null)
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('officers')
                            .where('orgId', isEqualTo: orgId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          final docs = snapshot.data?.docs ?? [];
                          final approvedDocs = docs.where((doc) {
                            final m = doc.data() as Map<String, dynamic>;
                            final status = m['status'];
                            
                            // Check if approved
                            bool isApproved = false;
                            if (status is String) {
                              isApproved = status == 'approved';
                            } else if (status is int) {
                              isApproved = status == OfficerStatus.approved.index;
                            }
                            if (!isApproved) return false;
                            
                            // Exclude moderators
                            final role = (m['role'] ?? '').toString().toLowerCase();
                            final roleString = role.contains('.') ? role.split('.').last : role;
                            final isModerator = roleString == 'moderator';
                            
                            return !isModerator;
                          }).toList();
                          
                          // Sort alphabetically by member display name (name -> email -> userId)
                          approvedDocs.sort((a, b) {
                            final ma = a.data() as Map<String, dynamic>;
                            final mb = b.data() as Map<String, dynamic>;
                            final ua = (ma['userId'] ?? '').toString();
                            final ub = (mb['userId'] ?? '').toString();
                            final na = (ma['name'] ?? ma['email'] ?? ua).toString().toLowerCase();
                            final nb = (mb['name'] ?? mb['email'] ?? ub).toString().toLowerCase();
                            return na.compareTo(nb);
                          });
                          
                          if (approvedDocs.isEmpty) {
                            return const Center(child: Text('No members available'));
                          }
                          // Determine eligible (not fully paid) userIds for bulk selection
                          final eligibleUserIds = approvedDocs.map((doc){
                            final data = doc.data() as Map<String, dynamic>;
                            final uid = (data['userId'] ?? '').toString();
                            final paidCount = _memberPaymentCounts[uid] ?? 0;
                            final totalCount = _selectedDue!.totalDuesCount;
                            final isFullyPaid = paidCount >= totalCount;
                            return isFullyPaid ? '' : uid;
                          }).where((id) => id.isNotEmpty).toList();
                          final allEligibleSelected = eligibleUserIds.isNotEmpty && eligibleUserIds.every((uid) => _selectedMembers[uid] == true);
                          
                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16, 
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: TWColors.slate.shade200,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Select All',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: TWColors.slate.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: 0.75,
                                      child: Switch(
                                        value: allEligibleSelected,
                                        onChanged: (value) {
                                          setState(() {
                                            for (final uid in eligibleUserIds) {
                                              _selectedMembers[uid] = value;
                                            }
                                          });
                                        },
                                        activeColor: TWColors.green.shade500,
                                        activeTrackColor: TWColors.green.shade200,
                                        inactiveThumbColor: TWColors.slate.shade400,
                                        inactiveTrackColor: TWColors.slate.shade200,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: approvedDocs.length,
                                  itemBuilder: (context, index) {
                                    final doc = approvedDocs[index];
                                    final data = doc.data() as Map<String, dynamic>;
                                    final userId = (data['userId'] ?? '').toString();
                                    final name = (data['name'] ?? data['email'] ?? userId).toString();
                                    final paidCount = _memberPaymentCounts[userId] ?? 0;
                                    final totalCount = _selectedDue!.totalDuesCount;
                                    final isFullyPaid = paidCount >= totalCount;
                                    final isSelected = _selectedMembers[userId] ?? false;
                                    
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: isSelected 
                                              ? TWColors.green.shade400 
                                              : isFullyPaid
                                                  ? TWColors.green.shade200
                                                  : TWColors.slate.shade200,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        dense: true,
                                        enabled: !isFullyPaid,
                                        leading: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: isFullyPaid
                                              ? TWColors.green.shade100
                                              : isSelected
                                                  ? TWColors.green.shade400
                                                  : TWColors.slate.shade200,
                                          child: Icon(
                                            isFullyPaid ? Icons.check_circle : Icons.person,
                                            size: 18,
                                            color: isFullyPaid
                                                ? TWColors.green.shade700
                                                : isSelected
                                                    ? Colors.white
                                                    : TWColors.slate.shade600,
                                          ),
                                        ),
                                        title: Text(
                                          name,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            color: isFullyPaid 
                                                ? TWColors.slate.shade500 
                                                : Colors.black,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                              '$paidCount / $totalCount paid',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: isFullyPaid 
                                                    ? TWColors.green.shade600 
                                                    : TWColors.slate.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            LinearProgressIndicator(
                                              value: totalCount > 0 ? paidCount / totalCount : 0,
                                              minHeight: 3,
                                              backgroundColor: TWColors.slate.shade200,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                isFullyPaid 
                                                    ? TWColors.green.shade500 
                                                    : TWColors.blue.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: isFullyPaid
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: TWColors.green.shade100,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'Paid',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: TWColors.green.shade700,
                                                  ),
                                                ),
                                              )
                                            : Transform.scale(
                                                scale: 0.9,
                                                child: Checkbox(
                                                  value: isSelected,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _selectedMembers[userId] = value ?? false;
                                                    });
                                                  },
                                                ),
                                              ),
                                        onTap: isFullyPaid
                                            ? null
                                            : () {
                                                setState(() {
                                                  _selectedMembers[userId] = !isSelected;
                                                });
                                              },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select a due to continue',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _selectedDue != null
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveTransaction,
                    style: FilledButton.styleFrom(
                      backgroundColor: TWColors.slate.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Save Transaction',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

