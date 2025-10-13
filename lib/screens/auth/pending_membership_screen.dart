import 'package:flutter/material.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/organization.dart';
import 'package:org_wallet/screens/auth/login_screen.dart';
import 'package:org_wallet/widgets/organization_switcher_modal.dart';
import 'package:org_wallet/screens/organization/scan_qr_screen.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';

class PendingMembershipScreen extends StatelessWidget {
  const PendingMembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            centerTitle: false,
            title: Text(
              authService.organization?.name ?? 'Organization',
              style: const TextStyle(color: Colors.black),
            ),
            backgroundColor: TWColors.slate.shade200,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          drawer: _buildDrawer(context),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Main Illustration
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: TWColors.amber.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hourglass_empty,
                        size: 60,
                        color: TWColors.amber.shade600,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Main Message
                    Text(
                      'Application Sent',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: TWColors.slate.shade900,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Text(
                      'Waiting for the admin to accept your membership request.',
                      style: TextStyle(
                        fontSize: 16,
                        color: TWColors.slate.shade600,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Organization Details Card
                    if (authService.organization != null)
                      _buildOrganizationCard(context, authService.organization!),
                    
                    const SizedBox(height: 32),
                    
                    // Additional Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TWColors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: TWColors.blue.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: TWColors.blue.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You\'ll receive a notification once your membership is approved.',
                              style: TextStyle(
                                fontSize: 14,
                                color: TWColors.blue.shade700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Logout Button
                    TextButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: TextButton.styleFrom(
                        foregroundColor: TWColors.slate.shade600,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrganizationCard(BuildContext context, Organization organization) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Organization Header
            Row(
              children: [
                // Organization Avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: TWColors.slate.shade900,
                  child: Text(
                    organization.name.isNotEmpty 
                        ? organization.name[0].toUpperCase() 
                        : 'O',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Organization Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        organization.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (organization.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          organization.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Request Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TWColors.slate.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: TWColors.slate.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: TWColors.slate.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Requested on ${DateFormat('MMM dd, yyyy').format(organization.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: TWColors.slate.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Provider.of<AuthService>(context, listen: false).signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TWColors.red.shade500,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return Drawer(
          child: Container(
            color: TWColors.slate.shade900,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drawer Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: TWColors.slate.shade900,
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  authService.user?.name ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  authService.user?.email ?? '',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Drawer Body (with ripple effect)
                  Expanded(
                    child: Material(
                      color: Colors.white,
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.person),
                            title: const Text('Profile'),
                            onTap: () => _handleMenuSelection('profile', context),
                          ),
                          ListTile(
                            leading: const Icon(Icons.qr_code_scanner),
                            title: const Text('Join QR'),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ScanQRScreen(),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.swap_horiz),
                            title: const Text('Switch Organization'),
                            onTap: () => _showOrganizationSwitcher(context),
                          ),
                          ListTile(
                            leading: const Icon(Icons.logout),
                            title: const Text('Logout'),
                            onTap: () => _handleMenuSelection('logout', context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleMenuSelection(String value, BuildContext context) {
    switch (value) {
      case 'profile':
        // Navigate to profile screen
        SnackBarHelper.showInfo(
          context,
          message: 'Profile feature coming soon',
        );
        break;
      case 'logout':
        _showLogoutDialog(context);
        break;
    }
  }

  void _showOrganizationSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const OrganizationSwitcherModal(),
    );
  }
}
