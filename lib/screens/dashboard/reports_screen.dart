// ignore_for_file: avoid_types_as_parameter_names

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:org_wallet/models/transaction.dart';
// import 'package:org_wallet/models/expense.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'This Month';
  final List<AppTransaction> _transactions = [];
  final bool _isLoading = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period Selector
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range),
                          const SizedBox(width: 12),
                          const Text('Period:'),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _selectedPeriod,
                            items:
                                [
                                      'This Month',
                                      'Last Month',
                                      'This Year',
                                      'All Time',
                                    ]
                                    .map(
                                      (period) => DropdownMenuItem(
                                        value: period,
                                        child: Text(period),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedPeriod = value;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Summary Cards
                  _buildSummaryCards(),
                  const SizedBox(height: 20),

                  // Category Chart
                  _buildCategoryChart(),
                  const SizedBox(height: 20),

                  // Monthly Trend Chart
                  _buildMonthlyTrendChart(),
                  const SizedBox(height: 20),

                  // Top Expenses
                  _buildTopExpenses(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    final filteredTxs = _getFilteredTransactions();
    final totalAmount = filteredTxs.fold<double>(
      0,
      (sum, tx) => sum + tx.amount,
    );
    final avgAmount = filteredTxs.isNotEmpty
        ? totalAmount / filteredTxs.length
        : 0.0;
    final categoryCount = filteredTxs.map((e) => e.categoryId).toSet().length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Expenses',
            '₱${totalAmount.toStringAsFixed(2)}',
            Icons.attach_money,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Average',
            '₱${avgAmount.toStringAsFixed(2)}',
            Icons.analytics,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Categories',
            categoryCount.toString(),
            Icons.category,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    final filteredTxs = _getFilteredTransactions();
    final categoryData = <String, double>{};
    for (final tx in filteredTxs) {
      categoryData[tx.categoryId] =
          (categoryData[tx.categoryId] ?? 0) + tx.amount;
    }

    final pieChartData = categoryData.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value,
        title: '${entry.key}\n₱${entry.value.toStringAsFixed(0)}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        color: _getCategoryColor(entry.key),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expenses by Category',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: pieChartData,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrendChart() {
    final filteredTxs = _getFilteredTransactions();
    final monthlyData = <String, double>{};
    for (final tx in filteredTxs) {
      final month = '${tx.createdAt.month}/${tx.createdAt.year}';
      monthlyData[month] = (monthlyData[month] ?? 0) + tx.amount;
    }

    final sortedMonths = monthlyData.keys.toList()
      ..sort((a, b) {
        final aParts = a.split('/');
        final bParts = b.split('/');
        final aMonth = int.parse(aParts[0]);
        final aYear = int.parse(aParts[1]);
        final bMonth = int.parse(bParts[0]);
        final bYear = int.parse(bParts[1]);

        if (aYear != bYear) return aYear.compareTo(bYear);
        return aMonth.compareTo(bMonth);
      });

    final lineChartData = sortedMonths.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), monthlyData[entry.value]!);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Trend',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < sortedMonths.length) {
                            return Text(
                              sortedMonths[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: lineChartData,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopExpenses() {
    final filteredTxs = _getFilteredTransactions();
    final sortedTxs = List<AppTransaction>.from(filteredTxs)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final topTxs = sortedTxs.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 5 Transactions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (topTxs.isEmpty)
              const Center(child: Text('No transactions found'))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topTxs.length,
                itemBuilder: (context, index) {
                  final tx = topTxs[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(
                        Icons.category,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    title: Text(
                      tx.note.isNotEmpty ? tx.note : 'No description',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(tx.categoryId),
                    trailing: Text(
                      '₱${tx.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  List<AppTransaction> _getFilteredTransactions() {
    final now = DateTime.now();
    List<AppTransaction> filtered = [];
    switch (_selectedPeriod) {
      case 'This Month':
        filtered = _transactions
            .where(
              (e) =>
                  e.createdAt.month == now.month &&
                  e.createdAt.year == now.year,
            )
            .toList();
        break;
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1);
        filtered = _transactions
            .where(
              (e) =>
                  e.createdAt.month == lastMonth.month &&
                  e.createdAt.year == lastMonth.year,
            )
            .toList();
        break;
      case 'This Year':
        filtered = _transactions
            .where((e) => e.createdAt.year == now.year)
            .toList();
        break;
      case 'All Time':
        filtered = _transactions;
        break;
    }
    return filtered;
  }

  Color _getCategoryColor(String categoryName) {
    switch (categoryName) {
      case 'Food':
        return Colors.orange;
      case 'Transportation':
        return Colors.blue;
      case 'Utilities':
        return Colors.green;
      case 'Entertainment':
        return Colors.purple;
      case 'Healthcare':
        return Colors.red;
      case 'Education':
        return Colors.indigo;
      case 'Shopping':
        return Colors.pink;
      case 'Other':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
