import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker_app/services/auth_service.dart';
import 'package:expense_tracker_app/models/audit_trail.dart';
import 'package:expense_tracker_app/models/expense.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<AuditTrail> _auditLogs = [];
  bool _isLoading = true;
  String _selectedAction = 'All';

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentOrgId == null) return;

      // Get all expenses for the organization
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('orgId', isEqualTo: authService.currentOrgId)
          .get();

      final expenseIds = expensesSnapshot.docs.map((doc) => doc.id).toList();

      if (expenseIds.isEmpty) {
        setState(() {
          _auditLogs = [];
          _isLoading = false;
        });
        return;
      }

      // Get audit trail for all expenses
      final auditSnapshot = await FirebaseFirestore.instance
          .collection('auditTrail')
          .where('expenseId', whereIn: expenseIds)
          .orderBy('createdAt', descending: true)
          .get();

      final auditLogs = auditSnapshot.docs.map((doc) => AuditTrail.fromMap({
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      })).toList();

      setState(() {
        _auditLogs = auditLogs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audit logs: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Filter Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.filter_list),
                const SizedBox(width: 12),
                const Text('Filter by Action:'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedAction,
                  items: ['All', ...AuditAction.values.map((e) => e.actionDisplayName)],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedAction = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          // Audit Logs List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildAuditLogsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsList() {
    final filteredLogs = _getFilteredLogs();

    if (filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No audit logs found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Audit logs will appear here when expenses are created or modified',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredLogs.length,
      itemBuilder: (context, index) {
        final auditLog = filteredLogs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getActionIcon(auditLog.action),
                      color: _getActionColor(auditLog.action),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auditLog.actionDisplayName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatDate(auditLog.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getActionColor(auditLog.action).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getActionColor(auditLog.action).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        auditLog.actionDisplayName,
                        style: TextStyle(
                          color: _getActionColor(auditLog.action),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                
                if (auditLog.reason.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reason:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(auditLog.reason),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'By: ${auditLog.by}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Expense ID: ${auditLog.expenseId.substring(0, 8)}...',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<AuditTrail> _getFilteredLogs() {
    if (_selectedAction == 'All') {
      return _auditLogs;
    }
    
    return _auditLogs.where((log) => 
        log.actionDisplayName == _selectedAction).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  IconData _getActionIcon(AuditAction action) {
    switch (action) {
      case AuditAction.created:
        return Icons.add_circle;
      case AuditAction.edited:
        return Icons.edit;
      case AuditAction.deleted:
        return Icons.delete;
      case AuditAction.approved:
        return Icons.check_circle;
      case AuditAction.denied:
        return Icons.cancel;
    }
  }

  Color _getActionColor(AuditAction action) {
    switch (action) {
      case AuditAction.created:
        return Colors.green;
      case AuditAction.edited:
        return Colors.blue;
      case AuditAction.deleted:
        return Colors.red;
      case AuditAction.approved:
        return Colors.green;
      case AuditAction.denied:
        return Colors.red;
    }
  }
}
