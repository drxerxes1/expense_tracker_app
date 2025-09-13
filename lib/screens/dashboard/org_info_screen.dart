// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/organization.dart';
import 'package:org_wallet/models/officer.dart';

class OrgInfoScreen extends StatefulWidget {
  const OrgInfoScreen({super.key});

  @override
  State<OrgInfoScreen> createState() => _OrgInfoScreenState();
}

class _OrgInfoScreenState extends State<OrgInfoScreen> {
  Organization? _organization;
  List<Officer> _officers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrganizationData();
  }

  Future<void> _loadOrganizationData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentOrgId == null) return;

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
      }

      // Load officers
      final officersSnapshot = await FirebaseFirestore.instance
          .collection('officers')
          .where('orgId', isEqualTo: authService.currentOrgId)
          .get();

      if (!mounted) return;
      final officers = officersSnapshot.docs
          .map((doc) => Officer.fromMap({'id': doc.id, ...doc.data()}))
          .toList();

      if (!mounted) return;
      setState(() {
        _officers = officers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading organization data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                ],
              ),
            ),
    );
  }

  Widget _buildOrganizationHeader() {
    if (_organization == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.business,
                size: 50,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _organization!.name,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _organization!.description,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationDetails() {
    if (_organization == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organization Details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Created', _formatDate(_organization!.createdAt)),
            _buildInfoRow(
              'Last Updated',
              _formatDate(_organization!.updatedAt),
            ),
            _buildInfoRow('Available Roles', _organization!.roles.join(', ')),
            _buildInfoRow('Total Members', _officers.length.toString()),
            _buildInfoRow(
              'Active Members',
              _officers
                  .where((o) => o.status == OfficerStatus.approved)
                  .length
                  .toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Members',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_officers.where((o) => o.status == OfficerStatus.approved).length} Active',
                  style: TextStyle(
                    color: Colors.green[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_officers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No members found'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _officers.length,
                itemBuilder: (context, index) {
                  final officer = _officers[index];
                  return _buildMemberTile(officer);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(Officer officer) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getRoleColor(officer.role),
        child: Icon(_getRoleIcon(officer.role), color: Colors.white),
      ),
      title: Text(
        officer.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(officer.email),
          Text(
            'Joined: ${_formatDate(officer.joinedAt)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(officer.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getStatusColor(officer.status).withOpacity(0.3),
              ),
            ),
            child: Text(
              officer.status.toString().split('.').last.toUpperCase(),
              style: TextStyle(
                color: _getStatusColor(officer.status),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            officer.role.toString().split('.').last.toUpperCase(),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getRoleColor(OfficerRole role) {
    switch (role) {
      case OfficerRole.president:
        return Colors.red;
      case OfficerRole.treasurer:
        return Colors.green;
      case OfficerRole.secretary:
        return Colors.blue;
      case OfficerRole.auditor:
        return Colors.purple;
      case OfficerRole.moderator:
        return Colors.orange;
      case OfficerRole.member:
        return Colors.grey;
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
        return Colors.orange;
      case OfficerStatus.approved:
        return Colors.green;
      case OfficerStatus.denied:
        return Colors.red;
    }
  }
}
