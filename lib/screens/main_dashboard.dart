import 'package:flutter/material.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
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

  @override
  void initState() {
    super.initState();
    // Default to current month
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
    // Force end to today
    final end = now;
    _selectedDateRange = DateTimeRange(start: start, end: end);
  }

  List<Widget> get _screens => [
    TransactionsScreen(dateRange: _selectedDateRange),
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
          color: TWColors
              .slate
              .shade900, // 👈 gives SafeArea the same dark background
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== Drawer Header =====
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: TWColors.slate.shade900, // 👈 matches SafeArea color
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

                // ===== Drawer Body (with ripple effect) =====
                Expanded(
                  child: Material(
                    color: Colors.white, // 👈 Material surface for ripple
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // Edit Organization - Only President/Moderator
                        if (authService.canAccessDrawerItem('edit_organization')) ...[
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('Edit Organization'),
                            onTap: () =>
                                _handleMenuSelection('edit_org', context),
                          ),
                        ],
                        
                        // Manage Dues - Only President/Moderator
                        if (authService.canAccessDrawerItem('manage_dues')) ...[
                          ListTile(
                            leading: const Icon(Icons.playlist_add),
                            title: const Text('Manage Dues'),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ManageDuesScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                        
                        // Manage Members - Only President/Moderator
                        if (authService.canAccessDrawerItem('manage_members')) ...[
                          ListTile(
                            leading: const Icon(Icons.people),
                            title: const Text('Manage Members'),
                            onTap: () =>
                                _handleMenuSelection('manage_members', context),
                          ),
                        ],
                        
                        // Manage Categories - Treasurer/Secretary/Auditor/President/Moderator
                        if (authService.canAccessDrawerItem('manage_categories')) ...[
                          ListTile(
                            leading: const Icon(Icons.category),
                            title: const Text('Manage Categories'),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ManageCategoriesScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                        
                        // Invite QR - Only President/Moderator
                        if (authService.canAccessDrawerItem('invite_qr')) ...[
                          ListTile(
                            leading: const Icon(Icons.qr_code),
                            title: const Text('Invite QR'),
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
                        ],
                        
                        // Export Reports - All roles (view-only access)
                        if (authService.canAccessDrawerItem('export_reports')) ...[
                          ListTile(
                            leading: const Icon(Icons.download),
                            title: const Text('Export Reports'),
                            onTap: () =>
                                _handleMenuSelection('export_reports', context),
                          ),
                        ],
                        
                        const Divider(),
                        
                        // Profile - All roles
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text('Profile'),
                          onTap: () => _handleMenuSelection('profile', context),
                        ),
                        
                        // Join QR - All roles
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
                        
                        // Switch Organization - All roles
                        ListTile(
                          leading: const Icon(Icons.swap_horiz),
                          title: const Text('Switch Organization'),
                          onTap: () => _showOrganizationSwitcher(context),
                        ),
                        
                        // Logout - All roles
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
      ),

      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: TWColors.slate.shade900,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Reports',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Logs'),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Org Info',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 && authService.canPerformAction('add_transaction')
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TransactionScreen()),
              ),
              backgroundColor: TWColors.slate.shade900,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
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
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = now; // up-to-today
    setState(() {
      _selectedDateRange = DateTimeRange(start: start, end: end);
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
}
