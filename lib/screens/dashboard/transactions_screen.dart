import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// ignore: unused_import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/transaction.dart' as model;
import 'package:org_wallet/services/transaction_service.dart';

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
        // Header balances and search
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Total Balance center
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Total Balance',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatAmount(_totalBalance),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Remaining Club Funds'),
                            const SizedBox(height: 6),
                            Text(
                              _formatAmount(_clubFunds),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Remaining School Funds'),
                            const SizedBox(height: 6),
                            Text(
                              _formatAmount(_schoolFunds),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
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
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.swap_horiz),
                      ),
                      title: Text(
                        tx.note.isNotEmpty ? tx.note : 'No description',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(tx.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
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
                      onTap: () {},
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
