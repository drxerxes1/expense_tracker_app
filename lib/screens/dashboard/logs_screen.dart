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
  final Map<String, String> _userNames =
      {}; // Cache for user ID to name mapping
  final Map<String, String> _userRoles =
      {}; // Cache for user ID to role mapping
  final Map<String, String> _transactionTypes =
      {}; // Cache for transaction ID to type mapping

  // Pagination variables
  int _currentPage = 1;
  static const int _itemsPerPage = 10;

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
        final userName =
            userData?['name'] ?? userData?['email'] ?? 'Unknown User';
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

    // Skip lookup for member management logs
    if (transactionId.startsWith('member_')) {
      _transactionTypes[transactionId] = 'expense';
      return 'expense';
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
    final transactionType =
        auditLog.transactionType ??
        _transactionTypes[auditLog.transactionId] ??
        'expense';

    if (action == 'Created') {
      return transactionType == 'fund' ? 'Created Fund' : 'Created Expense';
    } else if (action == 'Edited') {
      return transactionType == 'fund' ? 'Edited Fund' : 'Edited Expense';
    } else if (action == 'Deleted') {
      return transactionType == 'fund' ? 'Deleted Fund' : 'Deleted Expense';
    }

    return action; // Return original action for other types
  }

  String _formatAmountWithFallback(double? amount) {
    if (amount == null) return '';
    final formattedAmount = amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );

    return '${_getPesoSign()}$formattedAmount';
  }

  String _getPesoSign() {
    // Try different peso sign representations
    // You can test these one by one:
    // return '₱'; // Standard peso sign (U+20B1)
    return 'P'; // Simple P
    // return 'PHP'; // Currency code
    // return 'PESO'; // Full word
    // return 'Php'; // Mixed case
  }

  String _getTransactionDetails(AuditTrail auditLog) {
    // Handle member management actions
    if (auditLog.logType == 'member_action') {
      switch (auditLog.action) {
        case AuditAction.memberApproved:
          return 'Approved member ${auditLog.memberName ?? 'Unknown'} (${auditLog.memberEmail ?? ''}).';
        case AuditAction.memberDenied:
          return 'Denied member ${auditLog.memberName ?? 'Unknown'} (${auditLog.memberEmail ?? ''}).';
        case AuditAction.memberRemoved:
          return 'Removed member ${auditLog.memberName ?? 'Unknown'} (${auditLog.memberEmail ?? ''}) from organization.';
        case AuditAction.memberRoleChanged:
          if (auditLog.oldRole != null && auditLog.newRole != null) {
            return 'Changed role of ${auditLog.memberName ?? 'Unknown'} from ${auditLog.oldRole} to ${auditLog.newRole}.';
          }
          return 'Changed role of ${auditLog.memberName ?? 'Unknown'}.';
        default:
          return 'Member management action performed.';
      }
    }

    // Handle transaction actions
    final action = auditLog.action.actionDisplayName;
    final amount = auditLog.amount;
    final oldAmount = auditLog.oldAmount;
    final newAmount = auditLog.newAmount;
    final transactionType = auditLog.transactionType ?? 'expense';
    final oldTransactionType = auditLog.oldTransactionType;
    final newTransactionType = auditLog.newTransactionType;
    final categoryName = auditLog.categoryName ?? '';
    final oldCategoryName = auditLog.oldCategoryName;
    final newCategoryName = auditLog.newCategoryName;

    switch (action) {
      case 'Created':
        final typeText = transactionType == 'fund' ? 'Fund' : 'Expense';
        return 'Added ${_formatAmountWithFallback(amount)} to $categoryName $typeText.';

      case 'Edited':
        String details = '';

        // Check if transaction type changed
        if (oldTransactionType != null &&
            newTransactionType != null &&
            oldTransactionType != newTransactionType) {
          final oldTypeText = oldTransactionType == 'fund' ? 'Fund' : 'Expense';
          final newTypeText = newTransactionType == 'fund' ? 'Fund' : 'Expense';
          details =
              'Changed transaction type from $oldTypeText to $newTypeText';

          // Add amount change if available
          if (oldAmount != null &&
              newAmount != null &&
              oldAmount != newAmount) {
            details +=
                ' (${_formatAmountWithFallback(oldAmount)} → ${_formatAmountWithFallback(newAmount)})';
          } else if (amount != null) {
            details += ' (${_formatAmountWithFallback(amount)})';
          }

          // Add category change if available
          if (oldCategoryName != null &&
              newCategoryName != null &&
              oldCategoryName != newCategoryName) {
            details += ' - $oldCategoryName → $newCategoryName';
          } else if (categoryName.isNotEmpty) {
            details += ' - $categoryName';
          }

          details += '.';
        } else {
          // Regular edit with amount change
          if (oldAmount != null &&
              newAmount != null &&
              oldAmount != newAmount) {
            details =
                'Edited transaction: ${_formatAmountWithFallback(oldAmount)} → ${_formatAmountWithFallback(newAmount)}';

            // Add category change if available
            if (oldCategoryName != null &&
                newCategoryName != null &&
                oldCategoryName != newCategoryName) {
              details += ' ($oldCategoryName → $newCategoryName)';
            } else if (categoryName.isNotEmpty) {
              details += ' ($categoryName)';
            }

            details += '.';
          } else if (amount != null) {
            // Amount didn't change but other details might have
            details =
                'Edited transaction: ${_formatAmountWithFallback(amount)}';
            if (categoryName.isNotEmpty) {
              details += ' ($categoryName)';
            }
            details += '.';
          }
        }

        return details.isNotEmpty ? details : 'Edited transaction.';

      case 'Deleted':
        final typeText = transactionType == 'fund' ? 'Fund' : 'Expense';
        return 'Deleted ${_formatAmountWithFallback(amount)} from $categoryName $typeText.';

      default:
        return '';
    }
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

      // Get audit trail for the organization from both collections
      // Note: We avoid orderBy in query to prevent composite index requirement
      
      // Get transaction logs from global auditTrail collection
      final transactionAuditSnapshot = await FirebaseFirestore.instance
          .collection('auditTrail')
          .where('orgId', isEqualTo: authService.currentOrgId)
          .get();
      
      // Get member management logs from organization's audit_trails subcollection
      final memberAuditSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(authService.currentOrgId)
          .collection('audit_trails')
          .get();
      
      // Combine both collections
      final allAuditDocs = [
        ...transactionAuditSnapshot.docs,
        ...memberAuditSnapshot.docs,
      ];
      
      debugPrint('Loaded ${transactionAuditSnapshot.docs.length} transaction logs and ${memberAuditSnapshot.docs.length} member management logs');

      if (!mounted) return;

      final auditLogs =
          allAuditDocs
              .map((doc) => AuditTrail.fromMap({'id': doc.id, ...doc.data()}))
              .toList()
            ..sort(
              (a, b) => b.createdAt.compareTo(a.createdAt),
            ); // Sort by createdAt descending
      
      // Debug: Print log types
      final memberActionLogs = auditLogs.where((log) => log.logType == 'member_action').toList();
      final transactionLogs = auditLogs.where((log) => log.logType != 'member_action').toList();
      debugPrint('Processed ${transactionLogs.length} transaction logs and ${memberActionLogs.length} member action logs');

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
        // Only look up transaction types for actual transactions, not member management logs
        if (auditLog.logType != 'member_action' && !_transactionTypes.containsKey(auditLog.transactionId)) {
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
    final totalPages = _getTotalPages();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Compact Header with Filter and Pagination
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              children: [
                // Filter Row
                Row(
                  children: [
                    Icon(Icons.filter_list, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Filter:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedAction,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: TextStyle(color: Colors.grey[800]),
                        items: [
                          DropdownMenuItem<String>(
                            value: 'All',
                            child: Text('All Actions'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Created Expense',
                            child: Text('Created Expense'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Created Fund',
                            child: Text('Created Fund'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Edited Expense',
                            child: Text('Edited Expense'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Edited Fund',
                            child: Text('Edited Fund'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Deleted Expense',
                            child: Text('Deleted Expense'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Deleted Fund',
                            child: Text('Deleted Fund'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Approved',
                            child: Text('Approved'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Denied',
                            child: Text('Denied'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Member Approved',
                            child: Text('Member Approved'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Member Denied',
                            child: Text('Member Denied'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Member Removed',
                            child: Text('Member Removed'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Member Role Changed',
                            child: Text('Member Role Changed'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedAction = value;
                              _currentPage = 1;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),

                // Pagination Row (only show if more than 1 page)
                if (totalPages > 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Previous button
                      TextButton.icon(
                        onPressed: _currentPage > 1 ? _goToPreviousPage : null,
                        icon: const Icon(Icons.chevron_left, size: 18),
                        label: const Text('Previous'),
                        style: TextButton.styleFrom(
                          foregroundColor: _currentPage > 1
                              ? Theme.of(context).primaryColor
                              : Colors.grey[400],
                        ),
                      ),

                      // Page indicator
                      Text(
                        'Page $_currentPage of $totalPages',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      // Next button
                      TextButton.icon(
                        onPressed: _currentPage < totalPages
                            ? _goToNextPage
                            : null,
                        icon: const Icon(Icons.chevron_right, size: 18),
                        label: const Text('Next'),
                        style: TextButton.styleFrom(
                          foregroundColor: _currentPage < totalPages
                              ? Theme.of(context).primaryColor
                              : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Audit Logs List
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeInOut,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading audit logs...',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : _buildAuditLogsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsList() {
    final filteredLogs = _getFilteredLogs();
    final paginatedLogs = _getPaginatedLogs();

    if (filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No audit logs found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Audit logs will appear here when expenses are created or modified',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: ListView.builder(
        key: ValueKey('page_$_currentPage'),
        padding: const EdgeInsets.all(16),
        itemCount: paginatedLogs.length,
        itemBuilder: (context, index) {
          final auditLog = paginatedLogs[index];
          return _buildLogCard(auditLog, index);
        },
      ),
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

  List<AuditTrail> _getPaginatedLogs() {
    final filteredLogs = _getFilteredLogs();
    final totalPages = _getTotalPages();

    // Ensure current page is valid
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, filteredLogs.length);

    if (startIndex >= filteredLogs.length) {
      return [];
    }

    return filteredLogs.sublist(startIndex, endIndex);
  }

  int _getTotalPages() {
    final filteredLogs = _getFilteredLogs();
    return (filteredLogs.length / _itemsPerPage).ceil();
  }

  void _goToNextPage() {
    final totalPages = _getTotalPages();
    if (_currentPage < totalPages) {
      setState(() {
        _currentPage++;
      });
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
    }
  }

  Widget _buildLogCard(AuditTrail auditLog, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getActionIcon(auditLog.action),
                color: _getActionColor(auditLog.action),
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getActionTitle(auditLog),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                _formatDate(auditLog.createdAt),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),

          // Transaction details
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Text(
              _getTransactionDetails(auditLog),
              style: TextStyle(
                color: Colors.blue[800],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          if (auditLog.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              auditLog.reason,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],

          const SizedBox(height: 8),
          Text(
            'By ${_userNames[auditLog.by] ?? auditLog.by} (${_userRoles[auditLog.by] ?? 'member'})',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
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
      case AuditAction.memberApproved:
        return Icons.person_add;
      case AuditAction.memberDenied:
        return Icons.person_remove;
      case AuditAction.memberRemoved:
        return Icons.person_off;
      case AuditAction.memberRoleChanged:
        return Icons.swap_horiz;
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
      case AuditAction.memberApproved:
        return Colors.green;
      case AuditAction.memberDenied:
        return Colors.red;
      case AuditAction.memberRemoved:
        return Colors.red;
      case AuditAction.memberRoleChanged:
        return Colors.orange;
    }
  }
}
