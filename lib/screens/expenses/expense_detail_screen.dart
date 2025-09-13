import 'package:flutter/material.dart';
import 'package:org_wallet/models/expense.dart';

class ExpenseDetailScreen extends StatelessWidget {
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: _getCategoryColor(expense.category),
                      child: Icon(
                        _getCategoryIcon(expense.category),
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '₱${expense.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      expense.category.categoryDisplayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expense Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      'Amount',
                      '₱${expense.amount.toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Category',
                      expense.category.categoryDisplayName,
                    ),
                    _buildDetailRow(
                      'Note',
                      expense.note.isNotEmpty ? expense.note : 'No description',
                    ),
                    _buildDetailRow('Added By', expense.addedBy),
                    _buildDetailRow('Created', _formatDate(expense.createdAt)),
                    _buildDetailRow(
                      'Last Updated',
                      _formatDate(expense.updatedAt),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Category Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          _getCategoryIcon(expense.category),
                          color: _getCategoryColor(expense.category),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.category.categoryDisplayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _getCategoryDescription(expense.category),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getCategoryColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Colors.orange;
      case ExpenseCategory.transportation:
        return Colors.blue;
      case ExpenseCategory.utilities:
        return Colors.green;
      case ExpenseCategory.entertainment:
        return Colors.purple;
      case ExpenseCategory.healthcare:
        return Colors.red;
      case ExpenseCategory.education:
        return Colors.indigo;
      case ExpenseCategory.shopping:
        return Colors.pink;
      case ExpenseCategory.other:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Icons.restaurant;
      case ExpenseCategory.transportation:
        return Icons.directions_car;
      case ExpenseCategory.utilities:
        return Icons.power;
      case ExpenseCategory.entertainment:
        return Icons.movie;
      case ExpenseCategory.healthcare:
        return Icons.local_hospital;
      case ExpenseCategory.education:
        return Icons.school;
      case ExpenseCategory.shopping:
        return Icons.shopping_cart;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }

  String _getCategoryDescription(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return 'Food and dining expenses';
      case ExpenseCategory.transportation:
        return 'Transportation and travel costs';
      case ExpenseCategory.utilities:
        return 'Utility bills and services';
      case ExpenseCategory.entertainment:
        return 'Entertainment and recreation';
      case ExpenseCategory.healthcare:
        return 'Healthcare and medical expenses';
      case ExpenseCategory.education:
        return 'Education and training costs';
      case ExpenseCategory.shopping:
        return 'Shopping and retail purchases';
      case ExpenseCategory.other:
        return 'Other miscellaneous expenses';
    }
  }
}
