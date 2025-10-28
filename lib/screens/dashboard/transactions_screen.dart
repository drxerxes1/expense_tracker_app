// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/transaction.dart' as model;
import 'package:org_wallet/services/transaction_service.dart';
import 'package:org_wallet/screens/transaction/manage_transaction_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:org_wallet/constants/category_constants.dart';
import 'package:intl/intl.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';

// Helper class to group transactions by date
class TransactionDateGroup {
  final DateTime date;
  final List<model.AppTransaction> transactions;
  
  TransactionDateGroup({
    required this.date,
    required this.transactions,
  });
  
  String get formattedDate {
    return DateFormat('MMMM d, yyyy').format(date);
  }
  
  double get dailyTotal {
    double totalFunds = 0.0;
    double totalExpenses = 0.0;
    
    for (final transaction in transactions) {
      if (transaction.type == 'fund') {
        totalFunds += transaction.amount;
      } else if (transaction.type == 'expense') {
        totalExpenses += transaction.amount;
      }
    }
    
    return totalFunds - totalExpenses;
  }
}

// Helper function to group transactions by date
List<TransactionDateGroup> groupTransactionsByDate(List<model.AppTransaction> transactions) {
  // Sort transactions by creation date (most recent first)
  final sortedTransactions = List<model.AppTransaction>.from(transactions)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  
  // Group by date
  final Map<String, List<model.AppTransaction>> groupedMap = {};
  
  for (final transaction in sortedTransactions) {
    final dateKey = DateFormat('yyyy-MM-dd').format(transaction.createdAt);
    groupedMap.putIfAbsent(dateKey, () => []).add(transaction);
  }
  
  // Convert to TransactionDateGroup list and sort by date (most recent first)
  final groups = groupedMap.entries.map((entry) {
    final date = DateTime.parse(entry.key);
    return TransactionDateGroup(
      date: date,
      transactions: entry.value,
    );
  }).toList();
  
  groups.sort((a, b) => b.date.compareTo(a.date));
  
  return groups;
}

// Date Header Widget
class DateHeaderWidget extends StatelessWidget {
  final String dateText;
  final double dailyTotal;
  
  const DateHeaderWidget({
    super.key,
    required this.dateText,
    required this.dailyTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dateText,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: TWColors.slate.shade700,
            ),
          ),
          Row(
            children: [
              SvgPicture.asset(
                'assets/svg/philippine-peso-icon.svg',
                width: 12,
                height: 12,
                colorFilter: ColorFilter.mode(
                  dailyTotal > 0 ? Colors.green : dailyTotal < 0 ? Colors.red : Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                dailyTotal.abs().toStringAsFixed(2),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: dailyTotal > 0 ? Colors.green : dailyTotal < 0 ? Colors.red : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CurrencyAmount extends StatelessWidget {
  final double value;
  final double iconSize;
  final TextStyle? textStyle;
  const CurrencyAmount({
    super.key,
    required this.value,
    this.iconSize = 16,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/svg/philippine-peso-icon.svg',
          width: iconSize,
          height: iconSize,
        ),
        const SizedBox(width: 4),
        Text(value.toStringAsFixed(2), style: textStyle),
      ],
    );
  }
}

class TransactionsScreen extends StatefulWidget {
  final DateTimeRange? dateRange;
  const TransactionsScreen({super.key, this.dateRange});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final Set<String> _tombstonedIds = {};

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<model.AppTransaction>>(
            stream: _getTransactionsStream(authService.currentOrgId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final txs = (snapshot.data ?? [])
                  .where((t) => !_tombstonedIds.contains(t.id))
                  .toList();
              
              // Debug: Print transaction details
              debugPrint('TransactionsScreen: Loaded ${txs.length} transactions');
              debugPrint('Date range: ${widget.dateRange?.start} to ${widget.dateRange?.end}');
              for (final tx in txs) {
                debugPrint('Transaction: ${tx.id}, Type: ${tx.type}, Amount: ${tx.amount}, Date: ${tx.createdAt}');
              }
              
              double fundsAdded = 0, expenses = 0;
              double schoolFundsAdded = 0, schoolFundsExpense = 0;
              double clubFundsAdded = 0, clubFundsExpense = 0;
              for (final tx in txs) {
                final amt = tx.amount;
                final targetId = tx.fundId.isNotEmpty
                    ? tx.fundId
                    : tx.categoryId;
                if (tx.type == 'fund') {
                  fundsAdded += amt;
                  if (targetId == 'school_funds') {
                    schoolFundsAdded += amt;
                  }
                  if (targetId == 'club_funds') {
                    clubFundsAdded += amt;
                  }
                } else if (tx.type == 'expense') {
                  expenses += amt;
                  if (targetId == 'school_funds') {
                    schoolFundsExpense += amt;
                  }
                  if (targetId == 'club_funds') {
                    clubFundsExpense += amt;
                  }
                }
              }
              final totalBalance = fundsAdded - expenses;
              final schoolFundsRemaining =
                  schoolFundsAdded - schoolFundsExpense;
              final clubFundsRemaining = clubFundsAdded - clubFundsExpense;

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: TWColors.slate.shade200,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total Balance',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: TWColors.slate.shade900.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/svg/philippine-peso-icon.svg',
                              width: 18,
                              height: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${totalBalance < 0 ? '-' : ''}${totalBalance.abs().toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: totalBalance < 0
                                    ? Colors.red
                                    : TWColors.slate.shade900,
                                fontSize: 28,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 🔹 School & Club Fund Cards (polished)
                        Row(
                          children: [
                            Expanded(
                              child: Card(
                                margin: const EdgeInsets.only(right: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.school,
                                          color: Colors.blue.shade700,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'School Funds',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${schoolFundsRemaining < 0 ? '-' : ''}${schoolFundsRemaining.abs().toStringAsFixed(2)}',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: schoolFundsRemaining < 0
                                                    ? Colors.red
                                                    : TWColors.slate.shade900,
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
                            Expanded(
                              child: Card(
                                margin: const EdgeInsets.only(left: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.groups,
                                          color: Colors.purple.shade700,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Club Funds',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${clubFundsRemaining < 0 ? '-' : ''}${clubFundsRemaining.abs().toStringAsFixed(2)}',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: clubFundsRemaining < 0
                                                    ? Colors.red
                                                    : TWColors.slate.shade900,
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
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 🔹 Section 2: Transaction list
                  const SizedBox(height: 16),
                  Expanded(
                    child: txs.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 100), // Added bottom padding for FAB
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No transactions available',
                                    style: Theme.of(context).textTheme.titleMedium
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add your first transaction to get started',
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildGroupedTransactionList(txs),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Stream<List<model.AppTransaction>> _getTransactionsStream(String? orgId) {
    if (orgId == null) return const Stream.empty();
    final range = widget.dateRange;
    return TransactionService().watchTransactions(orgId, range: range);
  }

  Future<void> _handleRequestDelete(String id, String orgId) async {
    setState(() {
      _tombstonedIds.add(id);
    });
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await TransactionService().deleteTransaction(
        orgId,
        id,
        by: auth.firebaseUser?.uid,
      );
    } catch (e) {
      // revert tombstone
      setState(() {
        _tombstonedIds.remove(id);
      });
      SnackBarHelper.showError(
        context,
        message: 'Delete failed: $e',
      );
    }
  }

  Widget _buildGroupedTransactionList(List<model.AppTransaction> transactions) {
    final groupedTransactions = groupTransactionsByDate(transactions);
    
    return RefreshIndicator(
      onRefresh: () async {
        // Force a complete refresh by recreating the stream
        setState(() {
          // This will trigger a rebuild and recreate the stream
        });
        // Add a small delay to show the refresh indicator
        await Future.delayed(const Duration(milliseconds: 1000));
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Added bottom padding for FAB
        itemCount: _getTotalItemCount(groupedTransactions),
        itemBuilder: (context, index) {
          return _buildListItem(groupedTransactions, index);
        },
      ),
    );
  }

  int _getTotalItemCount(List<TransactionDateGroup> groups) {
    // Each group has 1 date header + number of transactions
    return groups.fold(0, (total, group) => total + 1 + group.transactions.length);
  }

  Widget _buildListItem(List<TransactionDateGroup> groups, int index) {
    int currentIndex = 0;
    
    for (final group in groups) {
      // Check if this index is for the date header
      if (currentIndex == index) {
        return DateHeaderWidget(
          dateText: group.formattedDate,
          dailyTotal: group.dailyTotal,
        );
      }
      currentIndex++;
      
      // Check if this index is for one of the transactions in this group
      for (int i = 0; i < group.transactions.length; i++) {
        if (currentIndex == index) {
          final tx = group.transactions[i];
          return TransactionListItem(
            transaction: tx,
            onRequestDelete: (id) => _handleRequestDelete(id, tx.orgId),
            onEdited: () {
              // trigger rebuild to refresh balances immediately
              setState(() {});
            },
            authService: Provider.of<AuthService>(context, listen: false),
          );
        }
        currentIndex++;
      }
    }
    
    // This should never happen, but return empty container as fallback
    return const SizedBox.shrink();
  }

  // Search filter logic removed
}

// Transaction List Item Widget
class TransactionListItem extends StatelessWidget {
  final model.AppTransaction transaction;
  final Future<void> Function(String id)? onRequestDelete;
  final VoidCallback? onEdited;
  final AuthService authService;
  
  const TransactionListItem({
    super.key,
    required this.transaction,
    this.onRequestDelete,
    this.onEdited,
    required this.authService,
  });

  Future<IconData> _getCategoryIcon(BuildContext context) async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final orgId = auth.currentOrgId;
      
      if (orgId == null || orgId.isEmpty) {
        return Icons.category;
      }

      // Try to get the category from the database
      final categorySnap = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('categories')
          .doc(transaction.categoryId)
          .get();

      if (categorySnap.exists) {
        final categoryData = categorySnap.data();
        if (categoryData != null && categoryData['icon'] != null) {
          return CategoryIcons.getIcon(categoryData['icon']);
        }
      }

      // Fallback to hardcoded icons for known categories
      return getCategoryIcon(transaction.categoryId);
    } catch (e) {
      // Return default icon if there's any error
      return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine collection by category id/name. Collections are stored with
    // categoryId 'collections' and usually have a categoryName containing 'collect'.
    final isCollection =
        (transaction.categoryId == 'collections' ||
        transaction.categoryName.toLowerCase().contains('collect'));
    
    final isExpense = transaction.type == 'expense';
    final amountStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: isCollection 
          ? Colors.orange 
          : isExpense 
          ? Colors.red 
          : Colors.green,
      fontSize: 18,
    );
    final amountStr = formatAmount(transaction.amount, isExpense);

    // Collection transactions are now editable and deletable
    // Determine left indicator color: show for expense, fund, and collection
    final targetId = transaction.fundId.isNotEmpty
        ? transaction.fundId
        : transaction.categoryId;
    Color? leftBorderColor;
    if (transaction.type == 'fund' || transaction.type == 'expense') {
      // Fund transactions: color depends on which fund (school vs club)
      if (targetId == 'school_funds') {
        leftBorderColor = Colors.blue;
      } else if (targetId == 'club_funds') {
        leftBorderColor = Colors.purple;
      } else {
        leftBorderColor = Colors.green;
      }
    } else if (isCollection) {
      // Collection transactions: use bright orange color to distinguish them
      leftBorderColor = Colors.orange;
    }
    return GestureDetector(
      onTap: () async {
              String? dueIdForTx;
              try {
                final duesSnap = await FirebaseFirestore.instance
                    .collection('organizations')
                    .doc(transaction.orgId)
                    .collection('dues')
                    .get();
                for (final d in duesSnap.docs) {
                  final q = await d.reference
                      .collection('due_payments')
                      .where('transactionId', isEqualTo: transaction.id)
                      .limit(1)
                      .get();
                  if (q.docs.isNotEmpty) {
                    dueIdForTx = d.id;
                    break;
                  }
                }
              } catch (_) {}

              final changed = await Navigator.of(context).push<bool?>(
                MaterialPageRoute(
                  builder: (_) => TransactionScreen(
                    transaction: transaction,
                    initialCollectionDueId: dueIdForTx,
                  ),
                ),
              );
              if (changed == true) {
                if (onEdited != null) onEdited!();
              }
            },
      onLongPress: () async {
        showModalBottomSheet(
          context: context,
          builder: (ctx) {
            return SafeArea(
              child: Wrap(
                children: [
                  // Show Edit for all transactions if user has permission
                  if (authService.canPerformAction('edit_transaction'))
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text('Edit'),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        String? dueIdForTx;
                        try {
                          final duesSnap = await FirebaseFirestore.instance
                              .collection('organizations')
                              .doc(transaction.orgId)
                              .collection('dues')
                              .get();
                          for (final d in duesSnap.docs) {
                            final q = await d.reference
                                .collection('due_payments')
                                .where(
                                  'transactionId',
                                  isEqualTo: transaction.id,
                                )
                                .limit(1)
                                .get();
                            if (q.docs.isNotEmpty) {
                              dueIdForTx = d.id;
                              break;
                            }
                          }
                        } catch (_) {}

                        final changed = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TransactionScreen(
                              transaction: transaction,
                              initialCollectionDueId: dueIdForTx,
                            ),
                          ),
                        );
                        if (changed == true) {
                          if (onEdited != null) onEdited!();
                        }
                      },
                    ),
                  // Show Delete only if user has permission
                  if (authService.canPerformAction('delete_transaction'))
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dctx) => AlertDialog(
                            title: const Text('Delete transaction'),
                            content: const Text(
                              'Are you sure you want to delete this transaction?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(dctx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          if (onRequestDelete != null) {
                            await onRequestDelete!(transaction.id);
                          }
                        }
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left indicator that fills the card height when present
              if (leftBorderColor != null)
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: leftBorderColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
              // Content area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<IconData>(
                        future: _getCategoryIcon(context),
                        builder: (context, snapshot) {
                          final icon = snapshot.data ?? Icons.category;
                          return CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            child: Icon(
                              icon,
                              color: transaction.type == 'expense'
                                  ? Colors.red
                                  : transaction.type == 'fund'
                                  ? Colors.green
                                  : Colors.teal,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.categoryName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            if (transaction.note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  transaction.note,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [Text(amountStr, style: amountStyle)],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper: Format amount with sign and color
String formatAmount(double amount, bool isExpense) {
  final sign = isExpense ? '-' : '+';
  return '$sign${amount.abs().toStringAsFixed(2)}';
}

// Helper: Get category icon by id
IconData getCategoryIcon(String? categoryId) {
  switch (categoryId) {
    case 'food':
      return Icons.restaurant;
    case 'transportation':
      return Icons.directions_bus;
    case 'supplies':
      return Icons.shopping_bag;
    case 'utilities':
      return Icons.lightbulb;
    case 'miscellaneous':
      return Icons.more_horiz;
    case 'school_funds':
      return Icons.school;
    case 'club_funds':
      return Icons.groups;
    case 'emergency_fund':
      return Icons.emergency;
    case 'savings':
      return Icons.savings;
    case 'investment':
      return Icons.trending_up;
    case 'collections':
      return Icons.payments;
    default:
      return Icons.category;
  }
}
