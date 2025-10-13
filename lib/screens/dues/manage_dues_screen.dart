// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/services/dues_service.dart';
import 'package:org_wallet/models/due.dart';
import 'package:org_wallet/screens/dues/add_edit_due_screen.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';

class ManageDuesScreen extends StatefulWidget {
  const ManageDuesScreen({super.key});

  @override
  State<ManageDuesScreen> createState() => _ManageDuesScreenState();
}

class _ManageDuesScreenState extends State<ManageDuesScreen> {
  late final DuesService _duesService;

  @override
  void initState() {
    super.initState();
    _duesService = DuesService();
  }

  void _showDueForm({DueModel? existing}) async {
    final orgId = Provider.of<AuthService>(context, listen: false).currentOrgId;
    if (orgId == null) {
      SnackBarHelper.showError(
        context,
        message: 'No organization selected',
      );
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditDueScreen(existing: existing, orgId: orgId),
      ),
    );
    if (result == true) {
      setState(() {}); // refresh list
    }
  }

  Future<void> _deleteDue(String orgId, DueModel due) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Due'),
        content: Text(
          'Are you sure you want to delete "${due.name}"? This will also delete all associated payment records and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _duesService.deleteDue(orgId: orgId, dueId: due.id);
        SnackBarHelper.showSuccess(
          context,
          message: 'Due deleted successfully',
        );
      } catch (e) {
        SnackBarHelper.showError(
          context,
          message: 'Error deleting due: $e',
        );
      }
    }
  }

  Future<Map<String, dynamic>> _getDueSummary(String orgId, String dueId) async {
    try {
      return await _duesService.getDueSummary(orgId, dueId);
    } catch (e) {
      return {
        'totalCollected': 0.0,
        'paidCount': 0,
        'unpaidCount': 0,
        'totalMembers': 0,
        'lastUpdated': DateTime.now(),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final orgId = auth.currentOrgId;
    if (orgId == null) {
      return const Scaffold(
        body: Center(child: Text('No organization selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Dues', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: false,
        backgroundColor: TWColors.slate.shade200,
      ),
      body: StreamBuilder<List<DueModel>>(
        stream: _duesService.watchDues(orgId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final dues = snap.data ?? [];
          if (dues.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No dues created yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first due to start collecting payments',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dues.length,
            itemBuilder: (context, i) {
              final due = dues[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  due.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PHP ${due.amount.toStringAsFixed(2)} • ${due.frequency.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Due: ${due.dueDate.toLocal().toString().split(' ')[0]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showDueForm(existing: due);
                              } else if (value == 'delete') {
                                _deleteDue(orgId, due);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 20),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 20, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            child: const Icon(Icons.more_vert),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<Map<String, dynamic>>(
                        future: _getDueSummary(orgId, due.id),
                        builder: (context, summarySnap) {
                          if (summarySnap.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 20,
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          
                          final summary = summarySnap.data ?? {};
                          final paidCount = summary['paidCount'] ?? 0;
                          final unpaidCount = summary['unpaidCount'] ?? 0;
                          final totalMembers = summary['totalMembers'] ?? 0;
                          final totalCollected = summary['totalCollected'] ?? 0.0;
                          
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      'Paid',
                                      '$paidCount/$totalMembers',
                                      Colors.green,
                                      Icons.check_circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildStatCard(
                                      'Unpaid',
                                      '$unpaidCount/$totalMembers',
                                      Colors.orange,
                                      Icons.pending,
                                    ),
                                  ),
                                ],
                              ),
                              if (totalCollected > 0) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.green.shade200,
                                    ),
                                  ),
                                  child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                                      Icon(
                                        Icons.account_balance_wallet,
                                        size: 16,
                                        color: Colors.green.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Collected: ₱${totalCollected.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                      },
                    ),
                  ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDueForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Due'),
        backgroundColor: TWColors.blue.shade600,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildStatCard(String label, String value, MaterialColor color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
