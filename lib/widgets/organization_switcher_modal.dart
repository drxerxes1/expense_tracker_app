import 'package:flutter/material.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/organization.dart';
import 'package:org_wallet/screens/organization/create_organization_screen.dart';
import 'package:org_wallet/screens/auth/pending_membership_screen.dart';
import 'package:org_wallet/screens/main_dashboard.dart';

class OrganizationSwitcherModal extends StatefulWidget {
  const OrganizationSwitcherModal({super.key});

  @override
  State<OrganizationSwitcherModal> createState() => _OrganizationSwitcherModalState();
}

class _OrganizationSwitcherModalState extends State<OrganizationSwitcherModal> {
  List<Organization> _organizations = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedOrgId;

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.user?.organizations.isEmpty ?? true) {
        setState(() {
          _isLoading = false;
          _organizations = [];
        });
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final orgIds = authService.user!.organizations;
      
      // Load organization details for each org ID
      final List<Organization> organizations = [];
      for (final orgId in orgIds) {
        try {
          final orgDoc = await firestore.collection('organizations').doc(orgId).get();
          if (orgDoc.exists) {
            organizations.add(Organization.fromMap({
              'id': orgDoc.id,
              ...orgDoc.data() as Map<String, dynamic>,
            }));
          }
        } catch (e) {
          debugPrint('Error loading organization $orgId: $e');
        }
      }

      setState(() {
        _organizations = organizations;
        _selectedOrgId = authService.currentOrgId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading organizations: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _switchOrganization(String orgId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.switchOrganization(orgId);

      if (mounted) {
        Navigator.of(context).pop();
        
        // Check if user is now in pending status
        if (authService.isPendingMembership()) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PendingMembershipScreen()),
            (route) => false,
          );
        } else {
          // Clear navigation stack and go to main dashboard for approved members
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainDashboard()),
            (route) => false,
          );
          // Show success message for approved members
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Switched to ${_organizations.firstWhere((org) => org.id == orgId).name}'),
              backgroundColor: TWColors.emerald.shade500,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching organization: $e'),
            backgroundColor: TWColors.red.shade500,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: TWColors.slate.shade900,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Organization',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          
          // Body
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
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
              _errorMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOrganizations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_organizations.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _organizations.length,
      itemBuilder: (context, index) {
        final org = _organizations[index];
        final isSelected = _selectedOrgId == org.id;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? TWColors.slate.shade900 : Colors.transparent,
              width: 2,
            ),
          ),
          child: RadioListTile<String>(
            value: org.id,
            groupValue: _selectedOrgId,
            onChanged: (value) {
              if (value != null) {
                _switchOrganization(value);
              }
            },
            title: Text(
              org.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? TWColors.slate.shade900 : Colors.black87,
              ),
            ),
            subtitle: org.description.isNotEmpty
                ? Text(
                    org.description,
                    style: TextStyle(
                      color: isSelected ? TWColors.slate.shade700 : Colors.grey[600],
                    ),
                  )
                : Text(
                    'ID: ${org.id.substring(0, 8)}...',
                    style: TextStyle(
                      color: isSelected ? TWColors.slate.shade700 : Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
            secondary: CircleAvatar(
              backgroundColor: isSelected ? TWColors.slate.shade900 : TWColors.slate.shade300,
              child: Text(
                org.name.isNotEmpty ? org.name[0].toUpperCase() : 'O',
                style: TextStyle(
                  color: isSelected ? Colors.white : TWColors.slate.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            activeColor: TWColors.slate.shade900,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'You are not part of any organization yet.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateOrganizationScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Join or Create Organization'),
              style: ElevatedButton.styleFrom(
                backgroundColor: TWColors.slate.shade900,
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
}
