import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:expense_tracker_app/services/auth_service.dart';
import 'package:expense_tracker_app/models/expense.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'This Month';
  List<Expense> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentOrgId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('orgId', isEqualTo: authService.currentOrgId)
          .get();

      final expenses = snapshot.docs.map((doc) => Expense.fromMap({
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      })).toList();

      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expenses: $e')),
        );
      }
    }
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
                            items: ['This Month', 'Last Month', 'This Year', 'All Time']
                                .map((period) => DropdownMenuItem(
                                      value: period,
                                      child: Text(period),
                                    ))
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
    final filteredExpenses = _getFilteredExpenses();
    final totalAmount = filteredExpenses.fold<double>(
        0, (sum, expense) => sum + expense.amount);
    final avgAmount = filteredExpenses.isNotEmpty
        ? totalAmount / filteredExpenses.length
        : 0.0;
    final categoryCount = filteredExpenses
        .map((e) => e.category)
        .toSet()
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Expenses',
            '\$${totalAmount.toStringAsFixed(2)}',
            Icons.attach_money,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Average',
            '\$${avgAmount.toStringAsFixed(2)}',
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

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    final filteredExpenses = _getFilteredExpenses();
    final categoryData = <String, double>{};
    
    for (final expense in filteredExpenses) {
      categoryData[expense.categoryDisplayName] = 
          (categoryData[expense.categoryDisplayName] ?? 0) + expense.amount;
    }

    final pieChartData = categoryData.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value,
        title: '${entry.key}\n\$${entry.value.toStringAsFixed(0)}',
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
    final filteredExpenses = _getFilteredExpenses();
    final monthlyData = <String, double>{};
    
    for (final expense in filteredExpenses) {
      final month = '${expense.createdAt.month}/${expense.createdAt.year}';
      monthlyData[month] = (monthlyData[month] ?? 0) + expense.amount;
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
    final filteredExpenses = _getFilteredExpenses();
    final sortedExpenses = List<Expense>.from(filteredExpenses)
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final topExpenses = sortedExpenses.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 5 Expenses',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (topExpenses.isEmpty)
              const Center(
                child: Text('No expenses found'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topExpenses.length,
                itemBuilder: (context, index) {
                  final expense = topExpenses[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getCategoryColor(expense.categoryDisplayName),
                      child: Icon(
                        _getCategoryIcon(expense.categoryDisplayName),
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    title: Text(
                      expense.note.isNotEmpty ? expense.note : 'No description',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(expense.categoryDisplayName),
                    trailing: Text(
                      '\$${expense.amount.toStringAsFixed(2)}',
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

  List<Expense> _getFilteredExpenses() {
    final now = DateTime.now();
    List<Expense> filtered = [];

    switch (_selectedPeriod) {
      case 'This Month':
        filtered = _expenses.where((e) =>
            e.createdAt.month == now.month && e.createdAt.year == now.year).toList();
        break;
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1);
        filtered = _expenses.where((e) =>
            e.createdAt.month == lastMonth.month && e.createdAt.year == lastMonth.year).toList();
        break;
      case 'This Year':
        filtered = _expenses.where((e) => e.createdAt.year == now.year).toList();
        break;
      case 'All Time':
        filtered = _expenses;
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

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName) {
      case 'Food':
        return Icons.restaurant;
      case 'Transportation':
        return Icons.directions_car;
      case 'Utilities':
        return Icons.power;
      case 'Entertainment':
        return Icons.movie;
      case 'Healthcare':
        return Icons.local_hospital;
      case 'Education':
        return Icons.school;
      case 'Shopping':
        return Icons.shopping_cart;
      case 'Other':
        return Icons.more_horiz;
      default:
        return Icons.more_horiz;
    }
  }
}
