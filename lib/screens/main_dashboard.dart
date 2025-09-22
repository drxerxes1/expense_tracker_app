import 'package:flutter/material.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/screens/dashboard/transactions_screen.dart';
import 'package:org_wallet/screens/dashboard/reports_screen.dart';
import 'package:org_wallet/screens/dashboard/logs_screen.dart';
import 'package:org_wallet/screens/dashboard/org_info_screen.dart';
import 'package:org_wallet/screens/expenses/add_expense_screen.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  DateTimeRange? _selectedDateRange;

  List<Widget> get _screens => [
    TransactionsScreen(dateRange: _selectedDateRange),
    const ReportsScreen(),
    const LogsScreen(),
    const OrgInfoScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: TWColors.slate.shade200,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.date_range, color: Colors.black),
              tooltip: 'Filter by date',
              onPressed: _selectDateRange,
            ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(authService.user?.name ?? ''),
                accountEmail: Text(authService.user?.email ?? ''),
                currentAccountPicture: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
              ),
              if (authService.isPresident()) ...[
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Organization'),
                  onTap: () => _handleMenuSelection('edit_org', context),
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Manage Members (Approve/Decline)'),
                  onTap: () => _handleMenuSelection('manage_members', context),
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Export Reports'),
                  onTap: () => _handleMenuSelection('export_reports', context),
                ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                onTap: () => _handleMenuSelection('profile', context),
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
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
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
              onPressed: _showFabActions,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Transactions';
      case 1:
        return 'Reports';
      case 2:
        return 'Audit Logs';
      case 3:
        return 'Organization';
      default:
        return 'Dashboard';
    }
  }

  void _handleMenuSelection(String value, BuildContext context) {
    switch (value) {
      case 'edit_org':
        // Navigate to edit organization screen
        break;
      case 'manage_members':
        // Navigate to manage members screen
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
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _showFabActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Add Expense'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Expense'),
                onTap: () {
                  Navigator.pop(context);
                  // Could navigate to an expenses search/list to pick one for editing
                  // For now, open transactions tab where edit is available per item
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
