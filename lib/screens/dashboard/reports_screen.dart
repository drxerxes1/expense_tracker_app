// ignore_for_file: avoid_types_as_parameter_names

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:org_wallet/models/transaction.dart';
import 'package:org_wallet/services/transaction_service.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';
// import 'package:org_wallet/models/expense.dart';

class ReportsScreen extends StatefulWidget {
  final DateTime selectedMonth;
  final bool isLoading;
  final VoidCallback onLoadingComplete;
  
  const ReportsScreen({
    super.key,
    required this.selectedMonth,
    required this.isLoading,
    required this.onLoadingComplete,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with TickerProviderStateMixin {
  List<AppTransaction> _transactions = [];
  bool _isLoading = true;
  bool _isDisposed = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTransactions();
  }

  @override
  void didUpdateWidget(ReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth) {
      // Add a small delay to show loading state for better UX
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_isDisposed) {
          _loadTransactions();
        }
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    // Check if widget is disposed before starting
    if (_isDisposed) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final orgId = authService.currentOrgId;

    if (orgId == null) {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // Get date range based on selected period
      DateTimeRange? dateRange = _getDateRangeForPeriod();

      final transactions = await TransactionService().getAllTransactions(
        orgId,
        range: dateRange,
      );
      
      // Check if widget is still mounted and not disposed before updating state
      if (mounted && !_isDisposed) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
        // Notify parent that loading is complete
        widget.onLoadingComplete();
      }
    } catch (e) {
      // Check if widget is still mounted and not disposed before updating state
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
        });
        // Notify parent that loading is complete (even on error)
        widget.onLoadingComplete();
        SnackBarHelper.showError(
          context,
          message: 'Error loading transactions: $e',
        );
      }
    }
  }

  DateTimeRange? _getDateRangeForPeriod() {
    // Use the selected month for filtering
    final start = DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1);
    final end = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0);
    return DateTimeRange(start: start, end: end);
  }

  String _getMonthYearText(DateTime selectedMonth) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[selectedMonth.month - 1]} ${selectedMonth.year}';
  }


  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Tab Bar
                  Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Expenses'),
                        Tab(text: 'Funds'),
                      ],
                      labelColor: TWColors.slate.shade900,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: TWColors.slate.shade900,
                    ),
                  ),
                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Expense Tab
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCategoryChart('expense'),
                              const SizedBox(height: 20),
                              _buildExpenseRanking('expense'),
                              const SizedBox(height: 20),
                              _buildExpenseForecast('expense'),
                            ],
                          ),
                        ),
                        // Fund Tab
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCategoryChart('fund'),
                              const SizedBox(height: 20),
                              _buildExpenseRanking('fund'),
                              const SizedBox(height: 20),
                              _buildExpenseForecast('fund'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        // Loading overlay when parent is loading
        if (widget.isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryChart(String transactionType) {
    final filteredTxs = _getFilteredTransactions();
    // Filter to only include transactions of the specified type
    final filteredTxsByType = filteredTxs.where((tx) => tx.type == transactionType).toList();
    
    final categoryData = <String, double>{};
    for (final tx in filteredTxsByType) {
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
              '${transactionType == 'expense' ? 'Expenses' : 'Funds'} by Category',
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
                                TWColors.slate.shade900,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              totalAmount.toStringAsFixed(2),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: TWColors.slate.shade900,
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

  Widget _buildExpenseRanking(String transactionType) {
    final filteredTxs = _getFilteredTransactions();
    // Filter to only include transactions of the specified type
    final filteredTxsByType = filteredTxs.where((tx) => tx.type == transactionType).toList();
    
    final categoryData = <String, double>{};
    for (final tx in filteredTxsByType) {
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
              '${transactionType == 'expense' ? 'Expense' : 'Fund'} Ranking',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (sortedCategories.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('No $transactionType data available'),
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

  Widget _buildExpenseForecast(String transactionType) {
    final filteredTxs = _getFilteredTransactions();
    // Filter to only include transactions of the specified type
    final filteredTxsByType = filteredTxs.where((tx) => tx.type == transactionType).toList();
    
    // Use the selected month instead of current month
    final selectedMonth = widget.selectedMonth;
    final selectedYear = selectedMonth.year;
    final selectedMonthNum = selectedMonth.month;
    
    // Get the number of days in the selected month
    final daysInMonth = DateTime(selectedYear, selectedMonthNum + 1, 0).day;
    
    // Check if the selected month is in the past, current, or future
    final now = DateTime.now();
    final isCurrentMonth = selectedYear == now.year && selectedMonthNum == now.month;
    final isPastMonth = selectedYear < now.year || 
                       (selectedYear == now.year && selectedMonthNum < now.month);
    final currentDay = isCurrentMonth ? now.day : (isPastMonth ? daysInMonth : 1);
    
    // Group transactions by day for the selected month
    final dailyData = <int, double>{};
    for (final tx in filteredTxsByType) {
      if (tx.createdAt.year == selectedYear && tx.createdAt.month == selectedMonthNum) {
        final day = tx.createdAt.day;
        dailyData[day] = (dailyData[day] ?? 0) + tx.amount;
      }
    }
    
    if (dailyData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${transactionType == 'expense' ? 'Expense' : 'Fund'} Forecast',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('No $transactionType data available for forecasting'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate statistics for actual data
    final actualDaysWithData = dailyData.entries.where((entry) => entry.value > 0).toList();
    final totalActualAmount = actualDaysWithData.fold<double>(0, (sum, entry) => sum + entry.value);
    final avgDailyAmount = actualDaysWithData.isNotEmpty ? totalActualAmount / actualDaysWithData.length : 0.0;
    final maxDailyAmount = actualDaysWithData.isNotEmpty ? actualDaysWithData.map((e) => e.value).reduce((a, b) => a > b ? a : b) : 0.0;
    final highestDay = actualDaysWithData.isNotEmpty ? actualDaysWithData.firstWhere((e) => e.value == maxDailyAmount).key : 0;
    
    // Generate forecast data for remaining days of the month
    // Only show forecast for current month's future days
    final forecastData = <int, double>{};
    final actualData = <int, double>{};
    
    for (int day = 1; day <= daysInMonth; day++) {
      if (day <= currentDay) {
        actualData[day] = dailyData[day] ?? 0;
      } else if (isCurrentMonth) {
        // Only forecast for future days in the current month
        forecastData[day] = avgDailyAmount;
      }
    }

    // Create chart data - only show actual data points for days with transactions
    final actualSpots = <FlSpot>[];
    final forecastSpots = <FlSpot>[];
    final trendSpots = <FlSpot>[];
    
    // Only add spots for days with actual transactions
    for (final entry in actualDaysWithData) {
      actualSpots.add(FlSpot(entry.key.toDouble(), entry.value));
    }
    
    // Calculate trendline if we have enough data points
    final trendline = actualDaysWithData.length >= 3 
        ? _calculateTrendline(actualDaysWithData) 
        : null;
    
    // Add trendline spots for all actual days
    if (trendline != null) {
      for (int day = 1; day <= currentDay; day++) {
        final trendValue = trendline.slope * day + trendline.intercept;
        if (trendValue >= 0) {
          trendSpots.add(FlSpot(day.toDouble(), trendValue));
        }
      }
    }
    
    // Add forecast spots for future days (only for current month and if we have actual data)
    if (isCurrentMonth && actualDaysWithData.isNotEmpty) {
      for (int day = currentDay + 1; day <= daysInMonth; day++) {
        forecastSpots.add(FlSpot(day.toDouble(), avgDailyAmount));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${transactionType == 'expense' ? 'Expense' : 'Fund'} Forecast',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Statistics Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TWColors.slate.shade900.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: TWColors.slate.shade900.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total ${transactionType == 'expense' ? 'Spent' : 'Earned'}',
                          'P${totalActualAmount.toStringAsFixed(2)}',
                          Icons.account_balance_wallet,
                          TWColors.slate.shade900,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Days Active',
                          '${actualDaysWithData.length}',
                          Icons.calendar_today,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Daily Average',
                          'P${avgDailyAmount.toStringAsFixed(2)}',
                          Icons.trending_up,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Highest Day',
                          'P${maxDailyAmount.toStringAsFixed(2)}',
                          Icons.keyboard_arrow_up,
                          Colors.orange,
                          '${_getMonthYearText(widget.selectedMonth).split(' ')[0]} $highestDay',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Legend
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 3,
                      decoration: BoxDecoration(
                        color: TWColors.slate.shade900,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Actual Data',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (trendline != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 2,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Trendline',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(1),
                        border: Border.all(color: Colors.grey[400]!, width: 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Forecast',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _calculateYAxisInterval(totalActualAmount, maxDailyAmount),
                    verticalInterval: 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[200]!,
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: _calculateYAxisInterval(totalActualAmount, maxDailyAmount),
                        getTitlesWidget: (value, meta) {
                          return Text(
                            'P${value.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          final day = value.toInt();
                          if (day >= 1 && day <= daysInMonth && day % 5 == 0) {
                            return Text(
                              '${_getMonthYearText(widget.selectedMonth).split(' ')[0]} $day',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
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
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.black87,
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          // Skip trendline (index 0 if trendline exists) - return empty tooltip
                          if (trendline != null && barSpot.barIndex == 0) {
                            return LineTooltipItem(
                              '',
                              const TextStyle(color: Colors.transparent, fontSize: 0),
                            );
                          }
                          
                          final day = barSpot.x.toInt();
                          final amount = barSpot.y;
                          // Adjust index based on whether trendline exists
                          final isActual = trendline != null 
                              ? barSpot.barIndex == 1 
                              : barSpot.barIndex == 0;
                          
                          return LineTooltipItem(
                            '${isActual ? 'Actual' : 'Forecast'}\n${_getMonthYearText(widget.selectedMonth).split(' ')[0]} $day\nP${amount.toStringAsFixed(2)}',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }).toList();
                      },
                    ),
                    getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                      // Skip indicators for trendline - it's visual only
                      if (barData.dashArray != null && barData.dashArray!.isNotEmpty) {
                        // This is likely the trendline or forecast
                        if (barData.color == Colors.orange) {
                          // Trendline - return empty indicator
                          return spotIndexes.map((index) {
                            return TouchedSpotIndicatorData(
                              FlLine(color: Colors.transparent, strokeWidth: 0),
                              FlDotData(show: false),
                            );
                          }).toList();
                        }
                      }
                      
                      return spotIndexes.map((index) {
                        return TouchedSpotIndicatorData(
                          FlLine(
                            color: barData.color ?? TWColors.slate.shade900,
                            strokeWidth: 2,
                            dashArray: [5, 5],
                          ),
                          FlDotData(
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 6,
                                color: barData.color ?? TWColors.slate.shade900,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                        );
                      }).toList();
                    },
                  ),
                  lineBarsData: [
                    // Trendline - show first so it appears behind actual data
                    if (trendSpots.isNotEmpty)
                      LineChartBarData(
                        spots: trendSpots,
                        isCurved: false,
                        color: Colors.orange,
                        barWidth: 2,
                        dashArray: [8, 4],
                        preventCurveOverShooting: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    // Actual data line - only show dots for actual transaction days
                    LineChartBarData(
                      spots: actualSpots,
                      isCurved: false,
                      color: TWColors.slate.shade900,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: TWColors.slate.shade900,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: TWColors.slate.shade900.withOpacity(0.1),
                      ),
                    ),
                    // Forecast data line - only show if we have actual data
                    if (actualDaysWithData.isNotEmpty)
                      LineChartBarData(
                        spots: forecastSpots,
                        isCurved: false,
                        color: Colors.grey[400]!.withOpacity(0.6),
                        barWidth: 2,
                        dashArray: [5, 5],
                        dotData: const FlDotData(
                          show: false, // Hide forecast dots to reduce clutter
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color, [String? subtitle]) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          // Show date as text instead of icon for highest day
          if (subtitle != null && title == 'Highest Day')
            Text(
              subtitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            )
          else
            Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null && title != 'Highest Day') ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
    );
  }

  double _calculateYAxisInterval(double totalAmount, double maxAmount) {
    if (maxAmount == 0) return 100;
    
    // Calculate appropriate interval based on the maximum value
    if (maxAmount <= 100) return 20;
    if (maxAmount <= 500) return 50;
    if (maxAmount <= 1000) return 100;
    if (maxAmount <= 5000) return 500;
    if (maxAmount <= 10000) return 1000;
    return 2000;
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

  /// Calculate linear regression trendline for the given data points
  /// Returns TrendlineResult with slope and intercept for y = mx + b
  _TrendlineResult? _calculateTrendline(List<MapEntry<int, double>> dataPoints) {
    if (dataPoints.isEmpty || dataPoints.length < 2) return null;

    final n = dataPoints.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (final point in dataPoints) {
      final x = point.key.toDouble();
      final y = point.value;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    // Calculate slope (m) and intercept (b) for y = mx + b
    final denominator = n * sumX2 - sumX * sumX;
    if (denominator == 0) return null;

    final slope = (n * sumXY - sumX * sumY) / denominator;
    final intercept = (sumY - slope * sumX) / n;

    return _TrendlineResult(slope: slope, intercept: intercept);
  }
}

/// Simple data class to hold trendline calculation results
class _TrendlineResult {
  final double slope;
  final double intercept;

  _TrendlineResult({
    required this.slope,
    required this.intercept,
  });
}

