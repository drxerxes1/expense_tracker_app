import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/organization.dart';
import 'package:org_wallet/models/officer.dart';
import 'package:org_wallet/screens/profile/edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _userOrganizations = [];

  @override
  void initState() {
    super.initState();
    _loadUserOrganizations();
  }

  Future<void> _loadUserOrganizations() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.user?.organizations.isNotEmpty == true) {
        final firestore = FirebaseFirestore.instance;

        // Load organization details for each organization the user belongs to
        final List<Map<String, dynamic>> organizations = [];

        for (final orgId in authService.user!.organizations) {
          try {
            // Get organization details
            final orgDoc = await firestore
                .collection('organizations')
                .doc(orgId)
                .get();

            if (orgDoc.exists) {
              final orgData = orgDoc.data()!;
              final organization = Organization.fromMap({
                'id': orgDoc.id,
                ...orgData,
              });

              // Get user's role in this organization
              final officerQuery = await firestore
                  .collection('officers')
                  .where('orgId', isEqualTo: orgId)
                  .where('userId', isEqualTo: authService.user!.id)
                  .get();

              OfficerRole? userRole;
              OfficerStatus? userStatus;

              if (officerQuery.docs.isNotEmpty) {
                final officerData = officerQuery.docs.first.data();
                userRole = OfficerRole.values.firstWhere(
                  (role) =>
                      role.toString().split('.').last == officerData['role'],
                  orElse: () => OfficerRole.member,
                );
                userStatus = OfficerStatus.values.firstWhere(
                  (status) =>
                      status.toString().split('.').last ==
                      officerData['status'],
                  orElse: () => OfficerStatus.pending,
                );
              }

              organizations.add({
                'organization': organization,
                'role': userRole ?? OfficerRole.member,
                'status': userStatus ?? OfficerStatus.pending,
                'joinedAt': officerQuery.docs.isNotEmpty
                    ? (officerQuery.docs.first.data()['joinedAt'] as Timestamp?)
                          ?.toDate()
                    : null,
              });
            }
          } catch (e) {
            debugPrint('Error loading organization $orgId: $e');
          }
        }

        if (mounted) {
          setState(() {
            _userOrganizations = organizations;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading user organizations: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getRoleDisplayName(OfficerRole role) {
    switch (role) {
      case OfficerRole.president:
        return 'President';
      case OfficerRole.treasurer:
        return 'Treasurer';
      case OfficerRole.secretary:
        return 'Secretary';
      case OfficerRole.auditor:
        return 'Auditor';
      case OfficerRole.moderator:
        return 'Moderator';
      case OfficerRole.member:
        return 'Member';
    }
  }

  String _getStatusDisplayName(OfficerStatus status) {
    switch (status) {
      case OfficerStatus.pending:
        return 'Pending';
      case OfficerStatus.approved:
        return 'Approved';
      case OfficerStatus.denied:
        return 'Denied';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Profile', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Consumer<AuthService>(
            builder: (context, authService, child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  // Show loading indicator
                  setState(() => _isLoading = true);
                  
                  // Refresh user data and officer data
                  await authService.reloadUserData();
                  await authService.reloadCurrentOfficerData();
                  
                  // Reload organizations
                  await _loadUserOrganizations();
                  
                  // Hide loading indicator
                  if (mounted) {
                    setState(() => _isLoading = false);
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile data refreshed'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                tooltip: 'Refresh Profile Data',
              );
            },
          ),
          Consumer<AuthService>(
            builder: (context, authService, child) {
              return IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  );
                },
                tooltip: 'Edit Profile',
              );
            },
          ),
        ],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = authService.user;
          if (user == null) {
            return const Center(child: Text('No user data available'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Profile Avatar
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // User Name
                        Text(
                          user.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        // User Email
                        Text(
                          user.email,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Account Info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Account Created:'),
                                  Text(
                                    '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Last Updated:'),
                                  Text(
                                    '${user.updatedAt.day}/${user.updatedAt.month}/${user.updatedAt.year}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Current Organization (if any)
                if (authService.organization != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.business,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Current Organization',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            authService.organization!.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (authService
                              .organization!
                              .description
                              .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              authService.organization!.description,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getRoleDisplayName(
                                    authService.currentOfficer?.role ??
                                        OfficerRole.member,
                                  ),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    authService.currentOfficer?.status ??
                                        OfficerStatus.pending,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getStatusDisplayName(
                                    authService.currentOfficer?.status ??
                                        OfficerStatus.pending,
                                  ),
                                  style: TextStyle(
                                    color: _getStatusColor(
                                      authService.currentOfficer?.status ??
                                          OfficerStatus.pending,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // All Organizations
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.group,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'All Organizations',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_userOrganizations.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'You are not a member of any organization yet.',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ..._userOrganizations.map((orgData) {
                            final organization =
                                orgData['organization'] as Organization;
                            final role = orgData['role'] as OfficerRole;
                            final status = orgData['status'] as OfficerStatus;
                            final joinedAt = orgData['joinedAt'] as DateTime?;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                                color:
                                    authService.currentOrgId == organization.id
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.05)
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          organization.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      if (authService.currentOrgId ==
                                          organization.id)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'CURRENT',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          _getRoleDisplayName(role),
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(
                                            status,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          _getStatusDisplayName(status),
                                          style: TextStyle(
                                            color: _getStatusColor(status),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (joinedAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Joined: ${joinedAt.day}/${joinedAt.month}/${joinedAt.year}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Profile'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.security),
                        label: const Text('Change Password'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
