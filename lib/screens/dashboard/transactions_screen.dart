// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/transaction.dart' as model;
import 'package:org_wallet/services/transaction_service.dart';
import 'package:org_wallet/screens/transaction/manage_transaction_screen.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

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
  // Track optimistic deletions (tombstones) to hide items immediately
  final Set<String> _tombstonedIds = {};
  Future<void> _showServerDebugInfo(BuildContext context, String? orgId) async {
    if (orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No organization selected')),
      );
      return;
    }
    try {
      final txs = await TransactionService().getAllTransactions(orgId, range: widget.dateRange);
      final totalCount = txs.length;
      double fundsAdded = 0, expenses = 0;
      double schoolFundsAdded = 0, schoolFundsExpense = 0;
      double clubFundsAdded = 0, clubFundsExpense = 0;
      for (final tx in txs) {
        final amt = tx.amount;
        if (tx.type == 'fund') {
          fundsAdded += amt;
          if (tx.categoryId == 'school_funds') schoolFundsAdded += amt;
          if (tx.categoryId == 'club_funds') clubFundsAdded += amt;
        } else if (tx.type == 'expense') {
          expenses += amt;
          if (tx.categoryId == 'school_funds') schoolFundsExpense += amt;
          if (tx.categoryId == 'club_funds') clubFundsExpense += amt;
        }
      }
      final totalBalance = fundsAdded - expenses;
      final schoolRemaining = schoolFundsAdded - schoolFundsExpense;
      final clubRemaining = clubFundsAdded - clubFundsExpense;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Server transactions (debug)'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Count: $totalCount'),
                const SizedBox(height: 8),
                Text('Total balance: ${totalBalance.toStringAsFixed(2)}'),
                Text('School funds remaining: ${schoolRemaining.toStringAsFixed(2)}'),
                Text('Club funds remaining: ${clubRemaining.toStringAsFixed(2)}'),
                const SizedBox(height: 12),
                const Text('Sample (first 5):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...txs.take(5).map((t) => Text('- ${t.id}: ${t.type} ${t.amount.toStringAsFixed(2)} (${t.categoryId})'))
              ],
            ),
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching server transactions: $e')),
      );
    }
  }

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

              final txs = (snapshot.data ?? []).where((t) => !_tombstonedIds.contains(t.id)).toList();

              // Calculate balances (sums are kept raw, display uses abs to avoid
              // confusing negatives if stored values are negative). Totals are
              // computed as funds added minus expenses.
              double fundsAdded = 0, expenses = 0;
              double schoolFundsAdded = 0, schoolFundsExpense = 0;
              double clubFundsAdded = 0, clubFundsExpense = 0;
              for (final tx in txs) {
                final amt = tx.amount;
                if (tx.type == 'fund') {
                  fundsAdded += amt;
                  if (tx.categoryId == 'school_funds') {
                    schoolFundsAdded += amt;
                  }
                  if (tx.categoryId == 'club_funds') {
                    clubFundsAdded += amt;
                  }
                } else if (tx.type == 'expense') {
                  expenses += amt;
                  if (tx.categoryId == 'school_funds') {
                    schoolFundsExpense += amt;
                  }
                  if (tx.categoryId == 'club_funds') {
                    clubFundsExpense += amt;
                  }
                }
              }
              final totalBalance = fundsAdded - expenses;
              final schoolFundsRemaining = schoolFundsAdded - schoolFundsExpense;
              final clubFundsRemaining = clubFundsAdded - clubFundsExpense;

              return Column(
                children: [
                  // 🔹 Section 1: Balances block
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
                            if (kDebugMode) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.bug_report, size: 18),
                                tooltip: 'Debug: fetch server transactions',
                                onPressed: () => _showServerDebugInfo(context, Provider.of<AuthService>(context, listen: false).currentOrgId),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 6),
                        CurrencyAmount(
                          value: totalBalance.abs(),
                          iconSize: 18,
                          textStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: TWColors.slate.shade900,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 🔹 School & Club Fund Cards
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(right: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'School Funds',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        color: TWColors.slate.shade900
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    CurrencyAmount(
                                      value: schoolFundsRemaining.abs(),
                                      iconSize: 14,
                                      textStyle: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: TWColors.slate.shade900,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(left: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Club Funds',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        color: TWColors.slate.shade900
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    CurrencyAmount(
                                      value: clubFundsRemaining.abs(),
                                      iconSize: 14,
                                      textStyle: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: TWColors.slate.shade900,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
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
            ? Center(
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
                                  'No transactions found',
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
                          )
                        : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: txs.length,
                              itemBuilder: (context, index) {
                                final tx = txs[index];
                                return TransactionListItem(
                                  transaction: tx,
                                  onRequestDelete: (id) => _handleRequestDelete(id, tx.orgId),
                                );
                              },
                            ),
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
      await TransactionService().deleteTransaction(orgId, id, by: auth.firebaseUser?.uid);
    } catch (e) {
      // revert tombstone
      setState(() {
        _tombstonedIds.remove(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  // Search filter logic removed
}

// Transaction List Item Widget
class TransactionListItem extends StatelessWidget {
  final model.AppTransaction transaction;
  final Future<void> Function(String id)? onRequestDelete;
  const TransactionListItem({super.key, required this.transaction, this.onRequestDelete});

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == 'expense';
    final amountStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: isExpense ? Colors.red : Colors.green,
      fontSize: 18,
    );
    final amountStr = formatAmount(transaction.amount, isExpense);
    final icon = getCategoryIcon(transaction.categoryId);
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push<bool?>(
          MaterialPageRoute(builder: (_) => TransactionScreen(transaction: transaction)),
        );
      },
      onLongPress: () async {
        showModalBottomSheet(
          context: context,
          builder: (ctx) {
            return SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Edit'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransactionScreen(transaction: transaction)));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (dctx) => AlertDialog(
                          title: const Text('Delete transaction'),
                          content: const Text('Are you sure you want to delete this transaction?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Delete')),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: Icon(icon, color: Colors.teal),
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
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
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
    default:
      return Icons.category;
  }
}
