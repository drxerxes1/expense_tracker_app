// ignore_for_file: avoid_types_as_parameter_names

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:org_wallet/models/transaction.dart';
import 'package:org_wallet/services/transaction_service.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:provider/provider.dart';
// import 'package:org_wallet/models/expense.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final String _selectedPeriod = 'This Month';
  List<AppTransaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final orgId = authService.currentOrgId;

    if (orgId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Get date range based on selected period
      DateTimeRange? dateRange = _getDateRangeForPeriod();

      final transactions = await TransactionService().getAllTransactions(
        orgId,
        range: dateRange,
      );
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  DateTimeRange? _getDateRangeForPeriod() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'This Month':
        final start = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: start, end: now);
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1);
        final start = DateTime(lastMonth.year, lastMonth.month, 1);
        final end = DateTime(lastMonth.year, lastMonth.month + 1, 0);
        return DateTimeRange(start: start, end: end);
      case 'This Year':
        final start = DateTime(now.year, 1, 1);
        return DateTimeRange(start: start, end: now);
      case 'All Time':
        return null; // No date range filter
      default:
        return null;
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
                  // Category Chart
                  _buildCategoryChart(),
                  const SizedBox(height: 20),

                  // Expense Ranking
                  _buildExpenseRanking(),
                  const SizedBox(height: 20),

                  // Expense Forecast
                  _buildExpenseForecast(),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryChart() {
    final filteredTxs = _getFilteredTransactions();
    // Filter to only include expense transactions, exclude fund transactions
    final expenseTxs = filteredTxs.where((tx) => tx.type == 'expense').toList();
    
    final categoryData = <String, double>{};
    for (final tx in expenseTxs) {
      // Use categoryName instead of categoryId for better display
      final categoryName = tx.categoryName.isNotEmpty ? tx.categoryName : tx.categoryId;
      categoryData[categoryName] =
          (categoryData[categoryName] ?? 0) + tx.amount;
    }

    // Calculate total for percentage calculation
    final totalAmount = categoryData.values.fold<double>(0, (sum, amount) => sum + amount);
    
    final pieChartData = categoryData.entries.map((entry) {
      final percentage = totalAmount > 0 ? (entry.value / totalAmount * 100) : 0.0;
      return PieChartSectionData(
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 30,
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
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      sections: pieChartData,
                      centerSpaceRadius: 60,
                      sectionsSpace: 2,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Total',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/svg/philippine-peso-icon.svg',
                              width: 16,
                              height: 16,
                              colorFilter: ColorFilter.mode(
                                Theme.of(context).colorScheme.primary,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              totalAmount.toStringAsFixed(2),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseRanking() {
    final filteredTxs = _getFilteredTransactions();
    // Filter to only include expense transactions, exclude fund transactions
    final expenseTxs = filteredTxs.where((tx) => tx.type == 'expense').toList();
    
    final categoryData = <String, double>{};
    for (final tx in expenseTxs) {
      // Use categoryName instead of categoryId for better display
      final categoryName = tx.categoryName.isNotEmpty ? tx.categoryName : tx.categoryId;
      categoryData[categoryName] =
          (categoryData[categoryName] ?? 0) + tx.amount;
    }

    // Calculate total for percentage calculation
    final totalAmount = categoryData.values.fold<double>(0, (sum, amount) => sum + amount);
    
    // Sort categories by amount (highest to lowest)
    final sortedCategories = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense Ranking',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (sortedCategories.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No expense data available'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedCategories.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = sortedCategories[index];
                  final percentage = totalAmount > 0 ? (entry.value / totalAmount * 100) : 0.0;
                  final color = _getCategoryColor(entry.key);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        // Category icon and name
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getCategoryIcon(entry.key),
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // Progress bar
                                    Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        color: Colors.grey[200],
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: percentage / 100,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(2),
                                            color: color,
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
                        const SizedBox(width: 16),
                        // Percentage and amount
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    'assets/svg/philippine-peso-icon.svg',
                                    width: 10,
                                    height: 10,
                                    colorFilter: ColorFilter.mode(
                                      Colors.grey[600]!,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    entry.value.toStringAsFixed(2),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseForecast() {
    final filteredTxs = _getFilteredTransactions();
    // Filter to only include expense transactions, exclude fund transactions
    final expenseTxs = filteredTxs.where((tx) => tx.type == 'expense').toList();
    
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    final currentDay = now.day;
    
    // Group expenses by day for the current month
    final dailyData = <int, double>{};
    for (final tx in expenseTxs) {
      if (tx.createdAt.year == currentYear && tx.createdAt.month == currentMonth) {
        final day = tx.createdAt.day;
        dailyData[day] = (dailyData[day] ?? 0) + tx.amount;
      }
    }

    // Get the number of days in the current month
    final daysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
    
    if (dailyData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expense Forecast',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No expense data available for forecasting'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Generate forecast data for remaining days of the month
    final forecastData = <int, double>{};
    final actualData = <int, double>{};
    
    // Calculate average daily expense for forecasting
    double totalActualAmount = 0;
    int actualDaysCount = 0;
    
    for (int day = 1; day <= daysInMonth; day++) {
      if (day <= currentDay) {
        actualData[day] = dailyData[day] ?? 0;
        totalActualAmount += actualData[day]!;
        if (actualData[day]! > 0) actualDaysCount++;
      } else {
        // Forecast for future days
        final avgDailyExpense = actualDaysCount > 0 ? totalActualAmount / actualDaysCount : 0.0;
        forecastData[day] = avgDailyExpense;
      }
    }

    // Create chart data with smoothing and zero-value handling
    final actualSpots = <FlSpot>[];
    final forecastSpots = <FlSpot>[];
    
    // Only add spots for days with actual data or meaningful forecast
    for (int day = 1; day <= daysInMonth; day++) {
      final actualAmount = actualData[day] ?? 0;
      final forecastAmount = forecastData[day] ?? 0;
      
      if (actualData.containsKey(day)) {
        // Only add actual spots for non-zero values or important days
        if (actualAmount > 0 || day == currentDay || day % 5 == 0) {
          actualSpots.add(FlSpot(day.toDouble(), actualAmount));
        }
      } else if (forecastAmount > 0) {
        // Only add forecast spots for meaningful predictions
        forecastSpots.add(FlSpot(day.toDouble(), forecastAmount));
      }
    }
    
    // Add connecting points for smoother lines
    final smoothedActualSpots = <FlSpot>[];
    final smoothedForecastSpots = <FlSpot>[];
    
    // Smooth actual data by adding intermediate points
    for (int i = 0; i < actualSpots.length - 1; i++) {
      smoothedActualSpots.add(actualSpots[i]);
      final current = actualSpots[i];
      final next = actualSpots[i + 1];
      final midX = (current.x + next.x) / 2;
      final midY = (current.y + next.y) / 2;
      smoothedActualSpots.add(FlSpot(midX, midY));
    }
    if (actualSpots.isNotEmpty) {
      smoothedActualSpots.add(actualSpots.last);
    }
    
    // Smooth forecast data
    for (int i = 0; i < forecastSpots.length - 1; i++) {
      smoothedForecastSpots.add(forecastSpots[i]);
      final current = forecastSpots[i];
      final next = forecastSpots[i + 1];
      final midX = (current.x + next.x) / 2;
      final midY = (current.y + next.y) / 2;
      smoothedForecastSpots.add(FlSpot(midX, midY));
    }
    if (forecastSpots.isNotEmpty) {
      smoothedForecastSpots.add(forecastSpots.last);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense Forecast',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Actual',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        border: Border.all(color: Colors.grey[400]!, width: 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Forecast',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              height: 280,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[200]!,
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 5, // Show every 5th day
                        getTitlesWidget: (value, meta) {
                          final day = value.toInt();
                          if (day >= 1 && day <= daysInMonth && day % 5 == 0) {
                            return Text(
                              day.toString(),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!, width: 0.5),
                  ),
                  lineBarsData: [
                    // Actual data line
                    LineChartBarData(
                      spots: smoothedActualSpots,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 4,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          // Only show dots for days with actual expense data
                          final day = spot.x.toInt();
                          final hasData = actualData.containsKey(day) && (actualData[day] ?? 0) > 0;
                          
                          if (!hasData) {
                            return FlDotCirclePainter(
                              radius: 0,
                              color: Colors.transparent,
                            );
                          }
                          return FlDotCirclePainter(
                            radius: 3,
                            color: Theme.of(context).colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                    // Forecast data line
                    LineChartBarData(
                      spots: smoothedForecastSpots,
                      isCurved: true,
                      color: Colors.grey[400]!.withOpacity(0.7),
                      barWidth: 3,
                      dashArray: [8, 4],
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          // Only show dots for forecast days with meaningful predictions
                          final day = spot.x.toInt();
                          final forecastAmount = forecastData[day] ?? 0;
                          
                          if (forecastAmount <= 0) {
                            return FlDotCirclePainter(
                              radius: 0,
                              color: Colors.transparent,
                            );
                          }
                          return FlDotCirclePainter(
                            radius: 2,
                            color: Colors.grey[400]!.withOpacity(0.7),
                            strokeWidth: 1,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(show: false),
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

  List<AppTransaction> _getFilteredTransactions() {
    // Since we're now filtering at the database level, just return all transactions
    return _transactions;
  }

  Color _getCategoryColor(String categoryName) {
    // Try to get color from database categories first
    // For now, use a fallback system until we can integrate with actual category data
    switch (categoryName.toLowerCase()) {
      case 'food':
        return const Color(0xFFEF4444); // Red
      case 'transportation':
        return const Color(0xFF3B82F6); // Blue
      case 'utilities':
        return const Color(0xFFF97316); // Orange
      case 'supplies':
        return const Color(0xFF10B981); // Green
      case 'miscellaneous':
        return const Color(0xFF8B5CF6); // Purple
      case 'donation':
        return const Color(0xFFEC4899); // Pink
      case 'event_income':
        return const Color(0xFF22C55E); // Green
      case 'membership_fee':
        return const Color(0xFF06B6D4); // Cyan
      case 'grant':
        return const Color(0xFFEAB308); // Yellow
      case 'misc_income':
        return const Color(0xFF8B5CF6); // Purple
      default:
        // Generate a color based on the category name hash
        final colors = [
          const Color(0xFF6366F1), // Indigo
          const Color(0xFF8B5CF6), // Violet
          const Color(0xFFEC4899), // Pink
          const Color(0xFFEF4444), // Red
          const Color(0xFFF97316), // Orange
          const Color(0xFFEAB308), // Yellow
          const Color(0xFF22C55E), // Green
          const Color(0xFF10B981), // Emerald
          const Color(0xFF06B6D4), // Cyan
          const Color(0xFF3B82F6), // Blue
        ];
        final hash = categoryName.hashCode;
        return colors[hash.abs() % colors.length];
    }
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'transportation':
        return Icons.directions_car;
      case 'utilities':
        return Icons.electrical_services;
      case 'supplies':
        return Icons.shopping_bag;
      case 'miscellaneous':
        return Icons.category;
      case 'donation':
        return Icons.favorite;
      case 'event_income':
        return Icons.movie;
      case 'membership_fee':
        return Icons.account_balance_wallet;
      case 'grant':
        return Icons.trending_up;
      case 'misc_income':
        return Icons.category;
      default:
        return Icons.category;
    }
  }
}
