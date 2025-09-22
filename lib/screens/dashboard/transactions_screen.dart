import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/transaction.dart' as model;
import 'package:org_wallet/services/transaction_service.dart';
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

              final txs = snapshot.data ?? [];

              // Calculate balances
              double fundsAdded = 0, expenses = 0;
              double schoolFundsAdded = 0, schoolFundsExpense = 0;
              double clubFundsAdded = 0, clubFundsExpense = 0;
              for (final tx in txs) {
                if (tx.type == 'fund') {
                  fundsAdded += tx.amount;
                  if (tx.categoryId == 'school_funds') {
                    schoolFundsAdded += tx.amount;
                  }
                  if (tx.categoryId == 'club_funds') {
                    clubFundsAdded += tx.amount;
                  }
                } else if (tx.type == 'expense') {
                  expenses += tx.amount;
                  if (tx.categoryId == 'school_funds') {
                    schoolFundsExpense += tx.amount;
                  }
                  if (tx.categoryId == 'club_funds') {
                    clubFundsExpense += tx.amount;
                  }
                }
              }
              final totalBalance = fundsAdded - expenses;
              final schoolFundsRemaining =
                  schoolFundsAdded - schoolFundsExpense;
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
                        Text(
                          'Total Balance',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: TWColors.slate.shade900.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 6),
                        CurrencyAmount(
                          value: totalBalance,
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
                                      value: schoolFundsRemaining,
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
                                      value: clubFundsRemaining,
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
                              return TransactionListItem(transaction: tx);
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

  // Search filter logic removed
}

// Transaction List Item Widget
class TransactionListItem extends StatelessWidget {
  final model.AppTransaction transaction;
  const TransactionListItem({super.key, required this.transaction});

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
    return Card(
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
                  if ((transaction.note).isNotEmpty)
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
    );
  }
}

// Helper: Format amount with sign and color
String formatAmount(double amount, bool isExpense) {
  final sign = isExpense ? '-' : '+';
  return '$sign ${amount.toStringAsFixed(2)}';
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
