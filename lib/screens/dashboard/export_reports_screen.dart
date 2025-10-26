// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/services/transaction_service.dart';
import 'package:org_wallet/models/transaction.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class ExportPeriodOption {
  final String label;
  final DateTimeRange? dateRange;
  final bool isCustom;

  ExportPeriodOption({
    required this.label,
    this.dateRange,
    required this.isCustom,
  });
}

class ExportReportsScreen extends StatefulWidget {
  const ExportReportsScreen({super.key});

  @override
  State<ExportReportsScreen> createState() => _ExportReportsScreenState();
}

class _ExportReportsScreenState extends State<ExportReportsScreen> {
  String _selectedPeriod = 'all';
  DateTimeRange? _customDateRange;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _customDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
  }

  DateTimeRange? _getSelectedDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'all':
        return null;
      case 'last_7_days':
        return DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
      case 'last_30_days':
        return DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
      case 'custom':
        return _customDateRange;
      default:
        return null;
    }
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange,
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
      });
    }
  }

  Future<void> _exportToCSV() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final transactionService = TransactionService();
      final orgId = authService.currentOrgId;

      if (orgId == null) {
        SnackBarHelper.showError(context, message: 'No organization selected');
        return;
      }

      // Get the selected date range
      final dateRange = _getSelectedDateRange();

      // Fetch transactions
      final transactions = await transactionService.getAllTransactions(
        orgId,
        range: dateRange,
      );

      if (transactions.isEmpty) {
        SnackBarHelper.showError(
          context,
          message: 'No transactions found in the selected period',
        );
        return;
      }

      // Generate CSV content
      final csvContent = _generateCSV(transactions, dateRange);

      // Get directory for saving file
      final directory = await _getDownloadDirectory();
      if (directory == null) {
        SnackBarHelper.showError(
          context,
          message: 'Could not access downloads directory',
        );
        return;
      }

      // Create file name with timestamp
      final timestamp = DateFormat(
        'yyyy-MM-dd_HH-mm-ss',
      ).format(DateTime.now());
      final fileName = 'transactions_export_$timestamp.csv';
      final file = File('$directory/$fileName');

      // Write file
      await file.writeAsString(csvContent);

      // Share the file
      final XFile shareFile = XFile(file.path);
      
      if (mounted) {
        // Show share dialog so user can share, move, or open the file
        await Share.shareXFiles([shareFile], text: 'Exported transaction report');
        
        // Show success dialog with option to view file
        await _showSuccessDialog(context, file.path, fileName);
        
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          message: 'Error exporting report: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  String _generateCSV(
    List<AppTransaction> transactions,
    DateTimeRange? dateRange,
  ) {
    final buffer = StringBuffer();

    // Add date range header
    if (dateRange != null) {
      buffer.writeln(
        'Date Range,${DateFormat('yyyy-MM-dd').format(dateRange.start)} to ${DateFormat('yyyy-MM-dd').format(dateRange.end)}',
      );
      buffer.writeln('');
    }
    buffer.writeln('Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('');

    // Sort transactions chronologically
    final sortedTransactions = List<AppTransaction>.from(transactions)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Separate expenses and funds
    final expenses = sortedTransactions.where((tx) => tx.type == 'expense').toList();
    final funds = sortedTransactions.where((tx) => tx.type == 'fund').toList();

    // === TIMELINE DATASET ===
    buffer.writeln('=== TIMELINE DATASET (All Transactions) ===');
    buffer.writeln(
      'Date,Type,Category,Amount,Note,Created At,Updated At',
    );

    for (final transaction in sortedTransactions) {
      final date = DateFormat('yyyy-MM-dd').format(transaction.createdAt);
      final type = transaction.type;
      final category = transaction.categoryName;
      final amount = transaction.amount.toStringAsFixed(2);
      final note = transaction.note.replaceAll(',', ';').replaceAll('\n', ' ');
      final createdAt = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(transaction.createdAt);
      final updatedAt = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(transaction.updatedAt);

      buffer.writeln(
        '$date,$type,$category,$amount,$note,$createdAt,$updatedAt',
      );
    }
    buffer.writeln('');

    // === EXPENSES SECTION ===
    buffer.writeln('=== EXPENSES ===');
    buffer.writeln(
      'Date,Category,Amount,Note,Created At,Updated At',
    );

    double expenseTotal = 0;
    for (final transaction in expenses) {
      final date = DateFormat('yyyy-MM-dd').format(transaction.createdAt);
      final category = transaction.categoryName;
      final amount = transaction.amount.toStringAsFixed(2);
      final note = transaction.note.replaceAll(',', ';').replaceAll('\n', ' ');
      final createdAt = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(transaction.createdAt);
      final updatedAt = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(transaction.updatedAt);

      buffer.writeln(
        '$date,$category,$amount,$note,$createdAt,$updatedAt',
      );
      expenseTotal += transaction.amount;
    }

    // Expense summary
    buffer.writeln('');
    buffer.writeln('Expense Summary:');
    buffer.writeln('Total Transactions,${expenses.length}');
    buffer.writeln('Total Amount,P${expenseTotal.toStringAsFixed(2)}');
    if (expenses.isNotEmpty) {
      buffer.writeln('Average Amount,P${(expenseTotal / expenses.length).toStringAsFixed(2)}');
    }
    buffer.writeln('');

    // === FUNDS SECTION ===
    buffer.writeln('=== FUNDS ===');
    buffer.writeln(
      'Date,Category,Amount,Note,Created At,Updated At',
    );

    double fundsTotal = 0;
    for (final transaction in funds) {
      final date = DateFormat('yyyy-MM-dd').format(transaction.createdAt);
      final category = transaction.categoryName;
      final amount = transaction.amount.toStringAsFixed(2);
      final note = transaction.note.replaceAll(',', ';').replaceAll('\n', ' ');
      final createdAt = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(transaction.createdAt);
      final updatedAt = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(transaction.updatedAt);

      buffer.writeln(
        '$date,$category,$amount,$note,$createdAt,$updatedAt',
      );
      fundsTotal += transaction.amount;
    }

    // Funds summary
    buffer.writeln('');
    buffer.writeln('Funds Summary:');
    buffer.writeln('Total Transactions,${funds.length}');
    buffer.writeln('Total Amount,P${fundsTotal.toStringAsFixed(2)}');
    if (funds.isNotEmpty) {
      buffer.writeln('Average Amount,P${(fundsTotal / funds.length).toStringAsFixed(2)}');
    }
    buffer.writeln('');

    // === OVERALL SUMMARY ===
    buffer.writeln('=== OVERALL SUMMARY ===');
    buffer.writeln('Total Transactions,${transactions.length}');
    buffer.writeln('Total Expenses,P${expenseTotal.toStringAsFixed(2)}');
    buffer.writeln('Total Funds,P${fundsTotal.toStringAsFixed(2)}');
    buffer.writeln('Net Balance,P${(fundsTotal - expenseTotal).toStringAsFixed(2)}');
    buffer.writeln('');
    
    // Category breakdown for expenses
    if (expenses.isNotEmpty) {
      buffer.writeln('=== EXPENSES BY CATEGORY ===');
      final categoryData = <String, double>{};
      for (final tx in expenses) {
        categoryData[tx.categoryName] = (categoryData[tx.categoryName] ?? 0) + tx.amount;
      }
      
      final sortedCategories = categoryData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      
      buffer.writeln('Category,Amount,Percentage');
      for (final entry in sortedCategories) {
        final percentage = (entry.value / expenseTotal * 100).toStringAsFixed(2);
        buffer.writeln('${entry.key},P${entry.value.toStringAsFixed(2)},$percentage%');
      }
      buffer.writeln('');
    }

    // Category breakdown for funds
    if (funds.isNotEmpty) {
      buffer.writeln('=== FUNDS BY CATEGORY ===');
      final categoryData = <String, double>{};
      for (final tx in funds) {
        categoryData[tx.categoryName] = (categoryData[tx.categoryName] ?? 0) + tx.amount;
      }
      
      final sortedCategories = categoryData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      
      buffer.writeln('Category,Amount,Percentage');
      for (final entry in sortedCategories) {
        final percentage = (entry.value / fundsTotal * 100).toStringAsFixed(2);
        buffer.writeln('${entry.key},P${entry.value.toStringAsFixed(2)},$percentage%');
      }
    }

    return buffer.toString();
  }

  Future<void> _showSuccessDialog(BuildContext context, String filePath, String fileName) async {
    if (!mounted) return;
    
    // Show where file is saved
    final locationInfo = 'Click "Save to Files" to choose where to save the file.';
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Export Successful',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: TWColors.slate.shade900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your transaction report has been exported.',
              style: TextStyle(
                color: TWColors.slate.shade700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: TWColors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TWColors.blue.shade200, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: TWColors.blue.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      locationInfo,
                      style: TextStyle(
                        fontSize: 11,
                        color: TWColors.blue.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TWColors.slate.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file, size: 20, color: TWColors.slate.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 12,
                        color: TWColors.slate.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Share the file again if user wants to share it
              final XFile shareFile = XFile(filePath);
              await Share.shareXFiles([shareFile], text: 'Exported transaction report');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.share, size: 18, color: TWColors.slate.shade700),
                const SizedBox(width: 6),
                Text('Share Again', style: TextStyle(color: TWColors.slate.shade700)),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Save file using file picker
              try {
                final file = File(filePath);
                final fileData = await file.readAsBytes();
                
                final savedPath = await FilePicker.platform.saveFile(
                  dialogTitle: 'Save CSV File',
                  fileName: fileName,
                  type: FileType.custom,
                  allowedExtensions: ['csv'],
                  bytes: fileData,
                );
                
                if (savedPath != null && mounted) {
                  SnackBarHelper.showSuccess(
                    context,
                    message: 'File saved successfully!',
                  );
                }
              } catch (e) {
                if (mounted) {
                  SnackBarHelper.showError(
                    context,
                    message: 'Could not save file: $e',
                  );
                }
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save, size: 18, color: TWColors.slate.shade700),
                const SizedBox(width: 6),
                Text('Save to Files', style: TextStyle(color: TWColors.slate.shade700)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: TWColors.slate.shade900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<String?> _getDownloadDirectory() async {
    try {
      // For Android, use external storage accessible directory
      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Return the external directory path
          return directory.path;
        }
      }
      
      // For iOS and other platforms
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      debugPrint('Error getting download directory: $e');
      // Fallback to Documents directory
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  String _formatDateRange(DateTimeRange range) {
    return '${DateFormat('MMM dd, yyyy').format(range.start)} - ${DateFormat('MMM dd, yyyy').format(range.end)}';
  }

  String _getPeriodLabel(String period) {
    switch (period) {
      case 'all':
        return 'All records';
      case 'last_7_days':
        return 'Last 7 days';
      case 'last_30_days':
        return 'Last 30 days';
      case 'custom':
        return _customDateRange != null
            ? _formatDateRange(_customDateRange!)
            : 'Customize';
      default:
        return period;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'Export Reports',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: TWColors.slate.shade200,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TWColors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TWColors.blue.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: TWColors.blue.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select the period of data you want to export and choose CSV format',
                        style: TextStyle(
                          color: TWColors.blue.shade900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Period Selection Section
              Text(
                'Select Period',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: TWColors.slate.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose what data to include in your export',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: TWColors.slate.shade600),
              ),
              const SizedBox(height: 20),

              // Radio buttons for period selection
              ...['all', 'last_7_days', 'last_30_days', 'custom'].map((period) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedPeriod == period
                          ? TWColors.slate.shade900
                          : TWColors.slate.shade200,
                      width: _selectedPeriod == period ? 2 : 1,
                    ),
                  ),
                  child: RadioListTile<String>(
                    value: period,
                    groupValue: _selectedPeriod,
                    onChanged: (String? value) {
                      setState(() {
                        _selectedPeriod = value ?? 'all';
                      });
                    },
                    title: Text(
                      _getPeriodLabel(period),
                      style: TextStyle(
                        fontWeight: _selectedPeriod == period
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: _selectedPeriod == period
                            ? TWColors.slate.shade900
                            : TWColors.slate.shade700,
                      ),
                    ),
                    activeColor: TWColors.slate.shade900,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                );
              }),

              // Custom date range picker (show when custom is selected)
              if (_selectedPeriod == 'custom') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TWColors.slate.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: TWColors.slate.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: TWColors.slate.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Custom Date Range',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: TWColors.slate.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _selectCustomDateRange,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: TWColors.slate.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _customDateRange != null
                                    ? _formatDateRange(_customDateRange!)
                                    : 'Select date range',
                                style: TextStyle(
                                  color: _customDateRange != null
                                      ? TWColors.slate.shade900
                                      : TWColors.slate.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Icon(
                                Icons.date_range,
                                color: TWColors.slate.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Export Format Section
              Text(
                'Export Format',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: TWColors.slate.shade800,
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TWColors.slate.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TWColors.slate.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: TWColors.slate.shade900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CSV Format',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: TWColors.slate.shade900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Comma-separated values file',
                            style: TextStyle(
                              color: TWColors.slate.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Export Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isExporting ? null : _exportToCSV,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TWColors.slate.shade900,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isExporting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download, size: 24),
                            const SizedBox(width: 12),
                            Text(
                              'Export to CSV',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
