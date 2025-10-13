import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/officer.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ManageMembersScreen extends StatefulWidget {
  const ManageMembersScreen({super.key});

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, pending, approved, denied
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String docId, String status) async {
    setState(() => _isLoading = true);
    try {
    await _firestore.collection('officers').doc(docId).update({
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Member status updated to $status'),
            backgroundColor: TWColors.emerald.shade500,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: TWColors.red.shade500,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(String docId, String userId, String orgId) async {
    setState(() => _isLoading = true);
    try {
    await _firestore.collection('officers').doc(docId).delete();
    try {
      await _firestore.collection('users').doc(userId).update({
        'organizations': FieldValue.arrayRemove([orgId]),
      });
    } catch (_) {
      // ignore if user doc missing
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Member removed successfully'),
            backgroundColor: TWColors.emerald.shade500,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing member: $e'),
            backgroundColor: TWColors.red.shade500,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changeMemberRole(String docId, String newRole, String memberName, String orgId) async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.firebaseUser!;
      
      // Update the officer's role
      await _firestore.collection('officers').doc(docId).update({
        'role': newRole,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Create audit trail entry for role change
      try {
        final auditRef = _firestore.collection('auditTrail').doc();
        await auditRef.set({
          'id': auditRef.id,
          'transactionId': docId, // Using officer doc ID as transaction ID
          'orgId': orgId,
          'action': 'roleChanged',
          'reason': 'Role changed from previous role to $newRole',
          'by': currentUser.uid,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      } catch (e) {
        debugPrint('Failed to write audit trail for role change: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$memberName role changed to ${_getRoleDisplayName(newRole)}'),
            backgroundColor: TWColors.emerald.shade500,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing role: $e'),
            backgroundColor: TWColors.red.shade500,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'president':
        return 'President';
      case 'treasurer':
        return 'Treasurer';
      case 'secretary':
        return 'Secretary';
      case 'auditor':
        return 'Auditor';
      case 'moderator':
        return 'Moderator';
      case 'member':
        return 'Member';
      default:
        return role.toUpperCase();
    }
  }

  void _showRoleChangeDialog(String docId, String currentRole, String memberName, String orgId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change Role for $memberName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current role: ${_getRoleDisplayName(currentRole)}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: TWColors.slate.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select new role:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: TWColors.slate.shade800,
              ),
            ),
            const SizedBox(height: 12),
            ...OfficerRole.values.map((role) {
              final roleString = role.toString().split('.').last;
              final isCurrentRole = roleString == currentRole;
              return ListTile(
                title: Text(
                  _getRoleDisplayName(roleString),
                  style: GoogleFonts.poppins(
                    fontWeight: isCurrentRole ? FontWeight.bold : FontWeight.normal,
                    color: isCurrentRole ? TWColors.slate.shade900 : TWColors.slate.shade700,
                  ),
                ),
                subtitle: Text(
                  _getRoleDescription(roleString),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: TWColors.slate.shade600,
                  ),
                ),
                leading: Radio<String>(
                  value: roleString,
                  groupValue: currentRole,
                  onChanged: isCurrentRole ? null : (value) {
                    Navigator.of(context).pop();
                    if (value != null) {
                      _changeMemberRole(docId, value, memberName, orgId);
                    }
                  },
                ),
                enabled: !isCurrentRole,
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _getRoleDescription(String role) {
    switch (role.toLowerCase()) {
      case 'president':
        return 'Full administrative access and control';
      case 'treasurer':
        return 'Manage finances and transactions';
      case 'secretary':
        return 'Handle documentation and records';
      case 'auditor':
        return 'Review and audit financial records';
      case 'moderator':
        return 'Approve requests and moderate content';
      case 'member':
        return 'Basic member with limited access';
      default:
        return 'Organization member';
    }
  }

  void _showMemberDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: TWColors.slate.shade900,
              child: Text(
                (data['name'] ?? data['email'] ?? 'M')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data['name'] ?? data['email'] ?? 'Member',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Email', data['email'] ?? '-'),
            _buildDetailRow('Role', _formatRole(data['role'] ?? '-')),
            _buildDetailRow('Status', _formatStatus(data['status'])),
            _buildDetailRow('Joined', _formatDate(data['joinedAt'])),
            if (data['createdAt'] != null)
              _buildDetailRow('Applied', _formatDate(data['createdAt'])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: TWColors.slate.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(color: TWColors.slate.shade800),
            ),
          ),
        ],
      ),
    );
  }

  String _formatRole(String role) {
    return role.toString().split('.').last.toUpperCase();
  }

  String _formatStatus(dynamic status) {
    if (status == null) return 'UNKNOWN';
    if (status is int) {
      return OfficerStatus.values.elementAt(status).toString().split('.').last.toUpperCase();
    }
    return status.toString().toUpperCase();
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      if (date is String) {
        return DateFormat('MMM dd, yyyy').format(DateTime.parse(date));
      } else if (date is Timestamp) {
        return DateFormat('MMM dd, yyyy').format(date.toDate());
      }
    } catch (e) {
      return '-';
    }
    return '-';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return TWColors.emerald.shade500;
      case 'pending':
        return TWColors.amber.shade500;
      case 'denied':
        return TWColors.red.shade500;
      default:
        return TWColors.slate.shade500;
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TWColors.slate.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TWColors.slate.shade300),
      ),
      child: Text(
        role.toUpperCase(),
        style: GoogleFonts.poppins(
          color: TWColors.slate.shade700,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterMembers(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      final status = _formatStatus(data['status']).toLowerCase();
      
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());
      
      // Status filter
      final matchesStatus = _statusFilter == 'all' ||
          status == _statusFilter;
      
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    if (!auth.isLoggedIn || auth.currentOrgId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manage Members'),
          backgroundColor: TWColors.slate.shade200,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: const Center(
          child: Text('No organization selected'),
        ),
      );
    }
    if (!auth.isPresident()) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manage Members'),
          backgroundColor: TWColors.slate.shade200,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: const Center(
          child: Text('Only Presidents can manage members'),
        ),
      );
    }
    final orgId = auth.currentOrgId!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Members',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: TWColors.slate.shade200,
        centerTitle: false,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search members...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: TWColors.slate.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: TWColors.slate.shade900),
                    ),
                    filled: true,
                    fillColor: TWColors.slate.shade50,
                  ),
                ),
                const SizedBox(height: 12),
                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending', 'pending'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Approved', 'approved'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Denied', 'denied'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Members List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('officers')
            .where('orgId', isEqualTo: orgId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
                
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: TWColors.red.shade500,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading members: ${snap.error}',
                          style: GoogleFonts.poppins(),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
          final docs = snap.data?.docs ?? [];
                final filteredDocs = _filterMembers(docs);
                
                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          docs.isEmpty ? 'No members found' : 'No members match your search',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final status = _formatStatus(data['status']);
                    final role = _formatRole(data['role'] ?? 'member');
                    final name = data['name'] ?? data['email'] ?? '';
                    final email = data['email'] ?? '';
                    final userId = (data['userId'] ?? '').toString();
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: TWColors.slate.shade900,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'M',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: GoogleFonts.poppins(
                                color: TWColors.slate.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildStatusChip(status),
                                const SizedBox(width: 8),
                                _buildRoleChip(role),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'view':
                                _showMemberDetails(data);
                                break;
                              case 'change_role':
                                _showRoleChangeDialog(doc.id, data['role'] ?? 'member', name, orgId);
                                break;
                              case 'approve':
                                if (status.toLowerCase() != 'approved') {
                                  await _updateStatus(doc.id, 'approved');
                                }
                                break;
                              case 'deny':
                                if (status.toLowerCase() != 'denied') {
                                  await _updateStatus(doc.id, 'denied');
                                }
                                break;
                              case 'remove':
                                final confirmed = await _showRemoveConfirmation(name);
                                if (confirmed) {
                                  await _removeMember(doc.id, userId, orgId);
                                }
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility),
                                  SizedBox(width: 8),
                                  Text('View Details'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'change_role',
                              child: Row(
                                children: [
                                  Icon(Icons.admin_panel_settings, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Change Role'),
                                ],
                              ),
                            ),
                            if (status.toLowerCase() != 'approved')
                              const PopupMenuItem(
                                value: 'approve',
                                child: Row(
                                  children: [
                                    Icon(Icons.check, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text('Approve'),
                                  ],
                                ),
                              ),
                            if (status.toLowerCase() != 'denied')
                              const PopupMenuItem(
                                value: 'deny',
                                child: Row(
                                  children: [
                                    Icon(Icons.close, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Deny'),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.person_remove, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Remove'),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          );
        },
            ),
          ),
          
          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _statusFilter = value);
      },
      selectedColor: TWColors.slate.shade900.withOpacity(0.1),
      checkmarkColor: TWColors.slate.shade900,
      labelStyle: GoogleFonts.poppins(
        color: isSelected ? TWColors.slate.shade900 : TWColors.slate.shade600,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Future<bool> _showRemoveConfirmation(String memberName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove $memberName from the organization? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: TWColors.red.shade500,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    ) ?? false;
  }
}
