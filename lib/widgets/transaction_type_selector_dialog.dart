import 'package:flutter/material.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:google_fonts/google_fonts.dart';

enum TransactionType {
  expenseFund,
  collection,
}

/// Dialog to select transaction type: Expense/Fund or Collection (Dues)
class TransactionTypeSelectorDialog extends StatelessWidget {
  const TransactionTypeSelectorDialog({super.key});

  static Future<TransactionType?> show(BuildContext context) {
    return showDialog<TransactionType>(
      context: context,
      builder: (context) => const TransactionTypeSelectorDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              'Select Transaction Type',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: TWColors.slate.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose what type of transaction you want to add',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: TWColors.slate.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Expense/Fund Option
            _buildOptionCard(
              context,
              title: 'Expense / Fund',
              description: 'Record an expense or add funds to your organization',
              icon: Icons.account_balance_wallet,
              color: TWColors.blue,
              onTap: () => Navigator.of(context).pop(TransactionType.expenseFund),
            ),
            const SizedBox(height: 16),
            
            // Collection Option
            _buildOptionCard(
              context,
              title: 'Collection (Dues)',
              description: 'Record member dues payments and collections',
              icon: Icons.payments,
              color: TWColors.green,
              onTap: () => Navigator.of(context).pop(TransactionType.collection),
            ),
            const SizedBox(height: 16),
            
            // Cancel Button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: TWColors.slate.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.shade200,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: color.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: color.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: color.shade600,
            ),
          ],
        ),
      ),
    );
  }
}

