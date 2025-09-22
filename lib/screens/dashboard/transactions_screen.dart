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
        Text(
          value.toStringAsFixed(2),
          style: textStyle,
        ),
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
  String _searchQuery = '';
  TransactionService? _maybeService;
  double _totalBalance = 0;
  double _clubFunds = 0;
  double _schoolFunds = 0;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    _maybeService ??= TransactionService();

    return Column(
      children: [
        // Header section with balances and search bar
        SingleChildScrollView(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(
                color: TWColors.slate.shade200,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 0,
                      color: TWColors.slate.shade200,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              'Total Balance',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: TWColors.slate.shade900),
                            ),
                            const SizedBox(height: 8),
                                CurrencyAmount(
                                  value: _totalBalance,
                                  iconSize: 18,
                                  textStyle: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: TWColors.slate.shade900,
                                    fontSize: 36,
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Card(
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Club Funds',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: TWColors.slate.shade900,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    CurrencyAmount(
                                      value: _clubFunds,
                                      iconSize: 14,
                                      textStyle: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: TWColors.slate.shade900,
                                        fontSize: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Card(
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'School Funds',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: TWColors.slate.shade900,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    CurrencyAmount(
                                      value: _schoolFunds,
                                      iconSize: 14,
                                      textStyle: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: TWColors.slate.shade900,
                                        fontSize: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: TextField(
                  style: TextStyle(color: TWColors.slate.shade900),
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    hintStyle: TextStyle(color: TWColors.slate.shade900),
                    prefixIcon: Icon(
                      Icons.search,
                      color: TWColors.slate.shade900,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: TWColors.slate.shade200,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ],
          ),
        ),

        // Expenses List
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

              final txs =
                  snapshot.data?.where((tx) => _filterTx(tx)).toList() ?? [];

              if (txs.isEmpty) {
                return Center(
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: txs.length,
                itemBuilder: (context, index) {
                  final tx = txs[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            child: Icon(Icons.swap_horiz),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.note.isNotEmpty ? tx.note : 'No description',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(tx.createdAt),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatAmount(tx.amount),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                              if (authService.canEditExpenses())
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 16),
                                  onPressed: () {
                                    // Navigate to edit transaction/expense screen if applicable
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
    // Load balances side-effect
    _loadBalances(orgId, range);
    return TransactionService().watchTransactions(orgId, range: range);
  }

  bool _filterTx(model.AppTransaction tx) {
    if (_searchQuery.isNotEmpty &&
        !tx.note.toLowerCase().contains(_searchQuery.toLowerCase())) {
      return false;
    }
    return true;
  }

  Future<void> _loadBalances(String orgId, DateTimeRange? range) async {
    final service = _maybeService ?? TransactionService();
    final total = await service.getTotalBalance(orgId, range: range);
    final breakdown = await service.getFundBreakdown(orgId, range: range);
    if (!mounted) return;
    setState(() {
      _totalBalance = total;
      _clubFunds = breakdown['clubFunds'] ?? 0;
      _schoolFunds = breakdown['schoolFunds'] ?? 0;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatAmount(double value) => '₱${value.toStringAsFixed(2)}';
}
