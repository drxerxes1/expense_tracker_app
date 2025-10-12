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
import 'package:org_wallet/screens/dashboard/manage_categories_screen.dart';

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
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              tooltip: 'Reset to this month',
              onPressed: () {
                final now = DateTime.now();
                final start = DateTime(now.year, now.month, 1);
                final end = now; // up-to-today
                setState(() {
                  _selectedDateRange = DateTimeRange(start: start, end: end);
                });
              },
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
                        if (authService.isPresident()) ...[
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('Edit Organization'),
                            onTap: () =>
                                _handleMenuSelection('edit_org', context),
                          ),
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
                          ListTile(
                            leading: const Icon(Icons.people),
                            title: const Text('Manage Members'),
                            onTap: () =>
                                _handleMenuSelection('manage_members', context),
                          ),
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No organization selected'),
                                  ),
                                );
                              }
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.download),
                            title: const Text('Export Reports'),
                            onTap: () =>
                                _handleMenuSelection('export_reports', context),
                          ),
                        ],
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
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TransactionScreen()),
              ),
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
        // Navigate to edit organization screen
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
        // Navigate to profile screen
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

  Future<void> _selectDateRange() async {
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
