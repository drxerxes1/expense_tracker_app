// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/organization.dart';
import 'package:org_wallet/models/officer.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class OrgInfoScreen extends StatefulWidget {
  const OrgInfoScreen({super.key});

  @override
  State<OrgInfoScreen> createState() => _OrgInfoScreenState();
}

class _OrgInfoScreenState extends State<OrgInfoScreen> {
  Organization? _organization;
  List<Officer> _officers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrganizationData();
  }

  Future<void> _loadOrganizationData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentOrgId == null) {
        setState(() {
          _errorMessage = 'No organization selected';
          _isLoading = false;
        });
        return;
      }

      // Load organization details
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(authService.currentOrgId)
          .get();

      if (!mounted) return;
      if (orgDoc.exists) {
        _organization = Organization.fromMap({
          'id': orgDoc.id,
          ...orgDoc.data() as Map<String, dynamic>,
        });
      } else {
        setState(() {
          _errorMessage = 'Organization not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error loading organization data: $e';
        _isLoading = false;
      });
    }
  }
  
  List<Officer> _parseOfficers(QuerySnapshot snapshot) {
    final officers = snapshot.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return null;
          
          final dataMap = Map<String, dynamic>.from(data);
          // Fix the status parsing issue - handle both string and int formats
          if (dataMap['status'] is int) {
            dataMap['status'] = OfficerStatus.values[dataMap['status'] as int].toString().split('.').last;
          }
          // Fix the role parsing issue - handle both string and int formats  
          if (dataMap['role'] is int) {
            dataMap['role'] = OfficerRole.values[dataMap['role'] as int].toString().split('.').last;
          }
          // Fix date parsing issues
          if (dataMap['joinedAt'] is String) {
            dataMap['joinedAt'] = Timestamp.fromDate(DateTime.parse(dataMap['joinedAt'] as String));
          }
          if (dataMap['createdAt'] is String) {
            dataMap['createdAt'] = Timestamp.fromDate(DateTime.parse(dataMap['createdAt'] as String));
          }
          if (dataMap['updatedAt'] is String) {
            dataMap['updatedAt'] = Timestamp.fromDate(DateTime.parse(dataMap['updatedAt'] as String));
          }
          return Officer.fromMap({'id': doc.id, ...dataMap});
        })
        .whereType<Officer>()
        .toList();
    
    return officers;
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      backgroundColor: TWColors.slate.shade50,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorState()
                : authService.currentOrgId == null
                    ? Center(
                        child: Text(
                          'No organization selected',
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadOrganizationData,
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('officers')
                              .where('orgId', isEqualTo: authService.currentOrgId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error loading members: ${snapshot.error}',
                                  style: GoogleFonts.poppins(fontSize: 16),
                                ),
                              );
                            }
                            
                            _officers = snapshot.hasData ? _parseOfficers(snapshot.data!) : [];
                            
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Organization Header
                                  _buildOrganizationHeader(),
                                  const SizedBox(height: 20),

                                  // Organization Details
                                  _buildOrganizationDetails(),
                                  const SizedBox(height: 20),

                                  // Members Section
                                  _buildMembersSection(),
                                  const SizedBox(height: 20),
                                  
                                  // Pending Members Section (if any)
                                  _buildPendingMembersSection(),
                                  const SizedBox(height: 100), // Bottom padding for FAB
                                ],
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: TWColors.slate.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: TWColors.slate.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOrganizationData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: TWColors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationHeader() {
    if (_organization == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              TWColors.blue.shade50,
              TWColors.indigo.shade50,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: TWColors.blue.shade600,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: TWColors.blue.shade200,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.business,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _organization!.name,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: TWColors.slate.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _organization!.description,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: TWColors.slate.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrganizationDetails() {
    if (_organization == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: TWColors.blue.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Organization Details',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: TWColors.slate.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Created', _formatDate(_organization!.createdAt)),
            _buildInfoRow('Last Updated', _formatDate(_organization!.updatedAt)),
            _buildInfoRow('Members', _officers.where((officer) => officer.status == OfficerStatus.approved).length.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection() {
    // Filter out pending members - only show approved members, sorted by role priority
    final approvedMembers = _officers
        .where((officer) => officer.status == OfficerStatus.approved)
        .toList()
      ..sort((a, b) => _getRolePriority(a.role).compareTo(_getRolePriority(b.role)));
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people,
                  color: TWColors.green.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Members',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: TWColors.slate.shade800,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: TWColors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: TWColors.green.shade200),
                      ),
                      child: Text(
                        '${approvedMembers.length}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: TWColors.green.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (approvedMembers.isEmpty)
              _buildEmptyMembersState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: approvedMembers.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final officer = approvedMembers[index];
                  return _buildMemberTile(officer);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingMembersSection() {
    // Get pending members, sorted by role priority
    final pendingMembers = _officers
        .where((officer) => officer.status == OfficerStatus.pending)
        .toList()
      ..sort((a, b) => _getRolePriority(a.role).compareTo(_getRolePriority(b.role)));
    
    // Only show this section if there are pending members
    if (pendingMembers.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pending_actions,
                  color: TWColors.orange.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pending Approvals',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: TWColors.slate.shade800,
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: TWColors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: TWColors.orange.shade200),
                      ),
                      child: Text(
                        '${pendingMembers.length}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: TWColors.orange.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingMembers.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final officer = pendingMembers[index];
                return _buildPendingMemberTile(officer);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMembersState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Members Yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: TWColors.slate.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Members will appear here once they join your organization',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: TWColors.slate.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingMemberTile(Officer officer) {
    return GestureDetector(
      onTap: () => _showMemberDetails(officer),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: TWColors.orange.shade100,
            child: Icon(
              Icons.pending,
              color: TWColors.orange.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  officer.name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: TWColors.slate.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'Requested: ${_formatDate(officer.joinedAt)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: TWColors.slate.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildRoleBadge(officer.role, isPending: true),
        ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(Officer officer) {
    return GestureDetector(
      onTap: () => _showMemberDetails(officer),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _getRoleColor(officer.role),
            child: Icon(
              _getRoleIcon(officer.role),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  officer.name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: TWColors.slate.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'Joined: ${_formatDate(officer.joinedAt)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: TWColors.slate.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildRoleBadge(officer.role),
        ],
        ),
      ),
    );
  }

  void _showMemberDetails(Officer officer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: officer.status == OfficerStatus.pending
                          ? TWColors.orange.shade100
                          : _getRoleColor(officer.role),
                      child: Icon(
                        officer.status == OfficerStatus.pending
                            ? Icons.pending
                            : _getRoleIcon(officer.role),
                        color: officer.status == OfficerStatus.pending
                            ? TWColors.orange.shade600
                            : Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            officer.name,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: TWColors.slate.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            officer.email,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: TWColors.slate.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Details
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildDetailItem(
                      'Email',
                      officer.email,
                      Icons.email_outlined,
                      allowCopy: true,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailItem(
                      'Role',
                      officer.role.toString().split('.').last.toUpperCase(),
                      Icons.badge_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailItem(
                      'Status',
                      officer.status.toString().split('.').last.toUpperCase(),
                      Icons.info_outline,
                      statusColor: _getStatusColor(officer.status),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailItem(
                      'Joined',
                      _formatDate(officer.joinedAt),
                      Icons.calendar_today_outlined,
                    ),
                    const SizedBox(height: 16),
                    // _buildDetailItem(
                    //   'Created',
                    //   _formatDate(officer.createdAt),
                    //   Icons.access_time_outlined,
                    // ),
                    // const SizedBox(height: 16),
                    // _buildDetailItem(
                    //   'Last Updated',
                    //   _formatDate(officer.updatedAt),
                    //   Icons.update_outlined,
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon, {Color? statusColor, bool allowCopy = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TWColors.slate.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TWColors.slate.shade200,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: statusColor ?? TWColors.blue.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: TWColors.slate.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (allowCopy)
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: value));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$label copied to clipboard'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: TWColors.green.shade600,
                            ),
                          );
                        },
                        child: Icon(
                          Icons.copy_outlined,
                          size: 16,
                          color: TWColors.blue.shade600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: statusColor ?? TWColors.slate.shade800,
                    fontWeight: statusColor != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Responsive label width for better spacing on small screens
    final double labelWidth = screenWidth * 0.32;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth.clamp(100, 160),
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: TWColors.slate.shade600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              softWrap: true,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: TWColors.slate.shade800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Color _getRoleColor(OfficerRole role) {
    switch (role) {
      case OfficerRole.president:
        return TWColors.red.shade600;
      case OfficerRole.treasurer:
        return TWColors.green.shade600;
      case OfficerRole.secretary:
        return TWColors.blue.shade600;
      case OfficerRole.auditor:
        return TWColors.purple.shade600;
      case OfficerRole.moderator:
        return TWColors.orange.shade600;
      case OfficerRole.member:
        return TWColors.slate.shade600;
    }
  }

  IconData _getRoleIcon(OfficerRole role) {
    switch (role) {
      case OfficerRole.president:
        return Icons.star;
      case OfficerRole.treasurer:
        return Icons.account_balance_wallet;
      case OfficerRole.secretary:
        return Icons.description;
      case OfficerRole.auditor:
        return Icons.verified_user;
      case OfficerRole.moderator:
        return Icons.admin_panel_settings;
      case OfficerRole.member:
        return Icons.person;
    }
  }

  Color _getStatusColor(OfficerStatus status) {
    switch (status) {
      case OfficerStatus.pending:
        return TWColors.orange.shade600;
      case OfficerStatus.approved:
        return TWColors.green.shade600;
      case OfficerStatus.denied:
        return TWColors.red.shade600;
    }
  }

  /// Get role priority for sorting (lower number = higher priority)
  int _getRolePriority(OfficerRole role) {
    switch (role) {
      case OfficerRole.moderator:
        return 1; // Highest priority
      case OfficerRole.president:
        return 2;
      case OfficerRole.treasurer:
        return 3;
      case OfficerRole.secretary:
        return 4;
      case OfficerRole.auditor:
        return 5;
      case OfficerRole.member:
        return 6;
    }
  }

  Widget _buildRoleBadge(OfficerRole role, {bool isPending = false}) {
    final roleColor = _getRoleColor(role);
    final roleName = role.toString().split('.').last.toUpperCase();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: roleColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: roleColor.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: roleColor.withOpacity(0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getRoleIcon(role),
            size: 12,
            color: roleColor,
          ),
          const SizedBox(width: 4),
          Text(
            roleName,
            style: GoogleFonts.poppins(
              color: roleColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          if (isPending) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: TWColors.orange.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'PENDING',
                style: GoogleFonts.poppins(
                  color: TWColors.orange.shade700,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
