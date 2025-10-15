import 'package:flutter/material.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/officer.dart';
import 'package:org_wallet/screens/dashboard/transactions_screen.dart';
import 'package:org_wallet/screens/dashboard/reports_screen.dart';
import 'package:org_wallet/screens/dashboard/logs_screen.dart';
import 'package:org_wallet/screens/dashboard/org_info_screen.dart';
import 'package:org_wallet/screens/transaction/manage_transaction_screen.dart';
import 'package:org_wallet/screens/auth/login_screen.dart';
import 'package:org_wallet/screens/organization/qr_generator_screen.dart';
import 'package:org_wallet/screens/organization/scan_qr_screen.dart';
import 'package:org_wallet/screens/dues/manage_dues_screen.dart';
import 'package:org_wallet/screens/organization/manage_members_screen.dart';
import 'package:org_wallet/screens/organization/edit_organization_screen.dart';
import 'package:org_wallet/screens/dashboard/manage_categories_screen.dart';
import 'package:org_wallet/screens/profile/profile_screen.dart';
import 'package:org_wallet/widgets/organization_switcher_modal.dart';
import 'package:org_wallet/screens/auth/pending_membership_screen.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;
  // Removed PageController, not needed for non-swipable tabs
  DateTimeRange? _selectedDateRange;
  int _transactionScreenKey = 0;

  @override
  void initState() {
    super.initState();
    // Default to current month
    _refreshDateRange();
  }

  List<Widget> get _screens => [
    TransactionsScreen(key: ValueKey(_transactionScreenKey), dateRange: _selectedDateRange),
    const ReportsScreen(),
    const LogsScreen(),
    const OrgInfoScreen(),
  ];

  @override
  void dispose() {
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // Check if user has pending membership
    if (authService.isPendingMembership()) {
      return const PendingMembershipScreen();
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              authService.organization?.name ?? 'Organization',
              style: const TextStyle(color: Colors.black),
            ),
            if (_currentIndex == 0 && _selectedDateRange != null)
              Text(
                _formatRange(_selectedDateRange!),
                style: TextStyle(color: Colors.grey[800], fontSize: 12),
              ),
          ],
        ),
        backgroundColor: TWColors.slate.shade200,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_currentIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.date_range, color: Colors.black),
              tooltip: 'Filter by date',
              onPressed: _selectDateRange,
            ),
          ],
        ],
      ),
      drawer: Drawer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                TWColors.slate.shade900,
                TWColors.slate.shade800,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== Enhanced Drawer Header =====
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        TWColors.slate.shade900,
                        TWColors.slate.shade700,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Avatar
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              TWColors.blue.shade400,
                              TWColors.purple.shade400,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            (authService.user?.name ?? 'U').substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // User Name
                      Text(
                        authService.user?.name ?? 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // User Email
                      Text(
                        authService.user?.email ?? '',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // Organization Info
                      if (authService.organization != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.business,
                                color: Colors.white.withOpacity(0.8),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  authService.organization!.name,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      
                      // Role Badge
                      if (authService.currentOfficer != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                TWColors.blue.shade600,
                                TWColors.purple.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: TWColors.blue.shade600.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _getRoleDisplayName(authService.currentOfficer!.role),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ===== Enhanced Drawer Body =====
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(0),
                        topRight: Radius.circular(0),
                      ),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        // Administrative Section
                        if (authService.canAccessDrawerItem('edit_organization') || 
                            authService.canAccessDrawerItem('manage_members')) ...[
                          _buildSectionHeader('Administration'),
                          const SizedBox(height: 8),
                          
                          // Edit Organization - Only President/Moderator
                          if (authService.canAccessDrawerItem('edit_organization'))
                            _buildMenuItem(
                              icon: Icons.edit,
                              title: 'Edit Organization',
                              subtitle: 'Manage organization settings',
                              onTap: () => _handleMenuSelection('edit_org', context),
                            ),
                          
                          // Manage Members - Only President/Moderator
                          if (authService.canAccessDrawerItem('manage_members'))
                            _buildMenuItem(
                              icon: Icons.people,
                              title: 'Manage Members',
                              subtitle: 'Add, remove, and manage members',
                              onTap: () => _handleMenuSelection('manage_members', context),
                            ),
                          
                          const SizedBox(height: 16),
                        ],
                        
                        // Management Section
                        if (authService.canAccessDrawerItem('manage_collections') || 
                            authService.canAccessDrawerItem('manage_categories') ||
                            authService.canAccessDrawerItem('invite_qr') ||
                            authService.canAccessDrawerItem('export_reports')) ...[
                          _buildSectionHeader('Management'),
                          const SizedBox(height: 8),
                          
                          // Manage Dues - Treasurer/Secretary/Auditor/President/Moderator
                          if (authService.canAccessDrawerItem('manage_collections'))
                            _buildMenuItem(
                              icon: Icons.payments,
                              title: 'Manage Dues',
                              subtitle: 'Track and manage member dues',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ManageDuesScreen(),
                                  ),
                                );
                              },
                            ),
                          
                          // Manage Categories - Treasurer/Secretary/Auditor/President/Moderator
                          if (authService.canAccessDrawerItem('manage_categories'))
                            _buildMenuItem(
                              icon: Icons.category,
                              title: 'Manage Categories',
                              subtitle: 'Organize transaction categories',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ManageCategoriesScreen(),
                                  ),
                                );
                              },
                            ),
                          
                          // Invite QR - Only President/Moderator
                          if (authService.canAccessDrawerItem('invite_qr'))
                            _buildMenuItem(
                              icon: Icons.qr_code,
                              title: 'Invite QR',
                              subtitle: 'Generate QR codes for invitations',
                              onTap: () {
                                if (authService.organization != null) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => QRGeneratorScreen(
                                        organization: authService.organization!,
                                      ),
                                    ),
                                  );
                                } else {
                                  SnackBarHelper.showError(
                                    context,
                                    message: 'No organization selected',
                                  );
                                }
                              },
                            ),
                          
                          // Export Reports - Only officers and presidents
                          if (authService.canAccessDrawerItem('export_reports'))
                            _buildMenuItem(
                              icon: Icons.download,
                              title: 'Export Reports',
                              subtitle: 'Download financial reports',
                              onTap: () => _handleMenuSelection('export_reports', context),
                            ),
                          
                          const SizedBox(height: 16),
                        ],
                        
                        // Account Section
                        _buildSectionHeader('Account'),
                        const SizedBox(height: 8),
                        
                        // Profile - All roles
                        _buildMenuItem(
                          icon: Icons.person,
                          title: 'Profile',
                          subtitle: 'View and edit your profile',
                          onTap: () => _handleMenuSelection('profile', context),
                        ),
                        
                        // Join QR - All roles
                        _buildMenuItem(
                          icon: Icons.qr_code_scanner,
                          title: 'Join QR',
                          subtitle: 'Scan QR code to join organization',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ScanQRScreen(),
                              ),
                            );
                          },
                        ),
                        
                        // Switch Organization - All roles
                        _buildMenuItem(
                          icon: Icons.swap_horiz,
                          title: 'Switch Organization',
                          subtitle: 'Change your current organization',
                          onTap: () => _showOrganizationSwitcher(context),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Logout - All roles
                        _buildMenuItem(
                          icon: Icons.logout,
                          title: 'Logout',
                          subtitle: 'Sign out of your account',
                          onTap: () => _handleMenuSelection('logout', context),
                          isDestructive: true,
                        ),
                        
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.04,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  icon: Icons.receipt_long,
                  label: 'Transactions',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.analytics,
                  label: 'Reports',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.history,
                  label: 'Logs',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.business,
                  label: 'Org Info',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 0 && authService.canPerformAction('add_transaction')
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: TWColors.slate.shade900.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TransactionScreen()),
                  );
                  // If a transaction was added/updated, refresh the transactions screen
                  if (result == true) {
                    setState(() {
                      _transactionScreenKey++;
                      // Update date range to ensure it includes the current moment
                      _refreshDateRange();
                    });
                  }
                },
                backgroundColor: TWColors.slate.shade900,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, size: 24),
              ),
            )
          : null,
    );
  }

  String _formatRange(DateTimeRange range) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final start = range.start;
    final end = range.end;
    final startStr = '${months[start.month - 1]} ${start.day}';
    final endStr = '${months[end.month - 1]} ${end.day}';
    if (start.month == end.month && start.year == end.year) {
      return '${months[start.month - 1]} ${start.day}–${end.day}';
    }
    return '$startStr – $endStr';
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

  void _refreshDateRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    _selectedDateRange = DateTimeRange(start: start, end: now);
  }

  // Removed _getAppBarTitle, will use organization name in app bar

  void _handleMenuSelection(String value, BuildContext context) {
    switch (value) {
      case 'edit_org':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const EditOrganizationScreen(),
          ),
        );
        break;
      case 'manage_members':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ManageMembersScreen()));
        break;
      case 'export_reports':
        // Navigate to export reports screen
        break;
      case 'profile':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ProfileScreen(),
          ),
        );
        break;
      case 'logout':
        _showLogoutDialog(context);
        break;
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
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
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showOrganizationSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const OrganizationSwitcherModal(),
    );
  }

  Future<void> _selectDateRange() async {
    // Show a bottom sheet with predefined options and custom range
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Date Range',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // This Month option
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('This Month'),
              subtitle: Text(_formatThisMonthRange()),
              onTap: () {
                Navigator.pop(context);
                _setThisMonthRange();
              },
            ),
            
            const Divider(),
            
            // Custom Range option
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Custom Range'),
              subtitle: Text(_selectedDateRange != null 
                ? _formatRange(_selectedDateRange!)
                : 'Select custom dates'),
              onTap: () {
                Navigator.pop(context);
                _selectCustomDateRange();
              },
            ),
            
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _setThisMonthRange() {
    setState(() {
      _refreshDateRange();
    });
  }

  String _formatThisMonthRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = now;
    return '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
  }

  Future<void> _selectCustomDateRange() async {
    // Ensure lastDate is at least as late as the current initial range end
    DateTime lastDate = DateTime.now();
    if (_selectedDateRange != null && _selectedDateRange!.end.isAfter(lastDate)) {
      lastDate = _selectedDateRange!.end;
    }

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: lastDate,
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      // Cap end to today to avoid future end dates
      final now = DateTime.now();
      final cappedEnd = picked.end.isAfter(now) ? now : picked.end;
      setState(() {
        _selectedDateRange = DateTimeRange(start: picked.start, end: cappedEnd);
      });
    }
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: TWColors.slate.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Helper method to build menu items
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.transparent,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDestructive 
                        ? Colors.red.shade50
                        : TWColors.slate.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive 
                        ? Colors.red.shade600
                        : TWColors.slate.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDestructive 
                              ? Colors.red.shade700
                              : TWColors.slate.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: TWColors.slate.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: TWColors.slate.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build navigation items
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 360 ? 20.0 : 22.0;
    final fontSize = screenWidth < 360 ? 12.0 : 13.0;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container with background
              Container(
                width: screenWidth < 360 ? 36 : 40,
                height: screenWidth < 360 ? 36 : 40,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? TWColors.slate.shade900
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: TWColors.slate.shade900.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Icon(
                  icon,
                  color: isSelected 
                      ? Colors.white
                      : TWColors.slate.shade600,
                  size: iconSize,
                ),
              ),
              const SizedBox(height: 4),
              // Label with proper spacing
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected 
                      ? TWColors.slate.shade900
                      : TWColors.slate.shade700,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
