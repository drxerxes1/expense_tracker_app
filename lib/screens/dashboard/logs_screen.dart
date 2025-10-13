// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/audit_trail.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<AuditTrail> _auditLogs = [];
  bool _isLoading = true;
  String _selectedAction = 'All';
  final Map<String, String> _userNames = {}; // Cache for user ID to name mapping
  final Map<String, String> _userRoles = {}; // Cache for user ID to role mapping
  final Map<String, String> _transactionTypes = {}; // Cache for transaction ID to type mapping

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  Future<String> _getUserName(String userId) async {
    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        final userName = userData?['name'] ?? userData?['email'] ?? 'Unknown User';
        _userNames[userId] = userName;
        return userName;
      }
    } catch (e) {
      debugPrint('Error fetching user name for $userId: $e');
    }
    
    _userNames[userId] = 'Unknown User';
    return 'Unknown User';
  }

  Future<String> _getUserRole(String userId) async {
    if (_userRoles.containsKey(userId)) {
      return _userRoles[userId]!;
    }
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final orgId = authService.currentOrgId;
      
      if (orgId != null) {
        final officerSnapshot = await FirebaseFirestore.instance
            .collection('officers')
            .where('orgId', isEqualTo: orgId)
            .where('userId', isEqualTo: userId)
            .get();
        
        if (officerSnapshot.docs.isNotEmpty) {
          final officerData = officerSnapshot.docs.first.data();
          final role = officerData['role'] ?? 'member';
          _userRoles[userId] = role;
          return role;
        }
      }
    } catch (e) {
      debugPrint('Error fetching user role for $userId: $e');
    }
    
    _userRoles[userId] = 'member';
    return 'member';
  }

  Future<String> _getTransactionType(String transactionId) async {
    if (_transactionTypes.containsKey(transactionId)) {
      return _transactionTypes[transactionId]!;
    }
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final orgId = authService.currentOrgId;
      
      if (orgId != null) {
        final transactionDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgId)
            .collection('transactions')
            .doc(transactionId)
            .get();
        
        if (transactionDoc.exists) {
          final transactionData = transactionDoc.data();
          final type = transactionData?['type'] ?? 'expense';
          _transactionTypes[transactionId] = type;
          return type;
        }
      }
    } catch (e) {
      debugPrint('Error fetching transaction type for $transactionId: $e');
    }
    
    _transactionTypes[transactionId] = 'expense';
    return 'expense';
  }

  String _getActionTitle(AuditTrail auditLog) {
    final action = auditLog.action.actionDisplayName;
    final transactionType = _transactionTypes[auditLog.transactionId] ?? 'expense';
    
    if (action == 'Created') {
      return transactionType == 'fund' ? 'Created Fund' : 'Created Expense';
    } else if (action == 'Edited') {
      return transactionType == 'fund' ? 'Edited Fund' : 'Edited Expense';
    } else if (action == 'Deleted') {
      return transactionType == 'fund' ? 'Deleted Fund' : 'Deleted Expense';
    }
    
    return action; // Return original action for other types
  }

  Future<void> _loadAuditLogs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentOrgId == null) {
        if (!mounted) return;
        setState(() {
          _auditLogs = [];
          _isLoading = false;
        });
        return;
      }

      // Get audit trail for the organization
      // Note: We avoid orderBy in query to prevent composite index requirement
      final auditSnapshot = await FirebaseFirestore.instance
          .collection('auditTrail')
          .where('orgId', isEqualTo: authService.currentOrgId)
          .get();

      if (!mounted) return;

      final auditLogs = auditSnapshot.docs
          .map((doc) => AuditTrail.fromMap({'id': doc.id, ...doc.data()}))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by createdAt descending

      // Resolve user names, roles, and transaction types for all audit logs
      for (final auditLog in auditLogs) {
        if (auditLog.by.isNotEmpty) {
          if (!_userNames.containsKey(auditLog.by)) {
            await _getUserName(auditLog.by);
          }
          if (!_userRoles.containsKey(auditLog.by)) {
            await _getUserRole(auditLog.by);
          }
        }
        if (!_transactionTypes.containsKey(auditLog.transactionId)) {
          await _getTransactionType(auditLog.transactionId);
        }
      }

      if (!mounted) return;
      setState(() {
        _auditLogs = auditLogs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        SnackBarHelper.showError(
          context,
          message: 'Error loading audit logs: $e',
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
                  items: [
                    DropdownMenuItem<String>(value: 'All', child: Text('All')),
                    DropdownMenuItem<String>(value: 'Created Expense', child: Text('Created Expense')),
                    DropdownMenuItem<String>(value: 'Created Fund', child: Text('Created Fund')),
                    DropdownMenuItem<String>(value: 'Edited Expense', child: Text('Edited Expense')),
                    DropdownMenuItem<String>(value: 'Edited Fund', child: Text('Edited Fund')),
                    DropdownMenuItem<String>(value: 'Deleted Expense', child: Text('Deleted Expense')),
                    DropdownMenuItem<String>(value: 'Deleted Fund', child: Text('Deleted Fund')),
                    DropdownMenuItem<String>(value: 'Approved', child: Text('Approved')),
                    DropdownMenuItem<String>(value: 'Denied', child: Text('Denied')),
                  ],
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
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No audit logs found',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Audit logs will appear here when expenses are created or modified',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
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
                            _getActionTitle(auditLog),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getActionColor(
                          auditLog.action,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getActionColor(
                            auditLog.action,
                          ).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        auditLog.action.actionDisplayName,
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
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'By: ${_userNames[auditLog.by] ?? auditLog.by}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Role: ${_userRoles[auditLog.by] ?? 'member'}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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

    return _auditLogs
        .where((log) => _getActionTitle(log) == _selectedAction)
        .toList();
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
      case AuditAction.roleChanged:
        return Icons.admin_panel_settings;
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
      case AuditAction.roleChanged:
        return Colors.purple;
    }
  }
}
