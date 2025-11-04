// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/services/tutorial_service.dart';
import 'package:org_wallet/models/officer.dart';
import 'package:org_wallet/screens/dashboard/transactions_screen.dart';
import 'package:org_wallet/screens/dashboard/reports_screen.dart';
import 'package:org_wallet/screens/dashboard/logs_screen.dart';
import 'package:org_wallet/screens/dashboard/org_info_screen.dart';
import 'package:org_wallet/screens/dashboard/export_reports_screen.dart';
import 'package:org_wallet/screens/transaction/manage_transaction_screen.dart';
import 'package:org_wallet/screens/auth/login_screen.dart';
import 'package:org_wallet/screens/organization/qr_generator_screen.dart';
import 'package:org_wallet/screens/organization/scan_qr_screen.dart';
import 'package:org_wallet/screens/dues/manage_dues_screen.dart';
import 'package:org_wallet/screens/organization/manage_members_screen.dart';
import 'package:org_wallet/screens/organization/edit_organization_screen.dart';
import 'package:org_wallet/screens/organization/manage_categories_screen.dart';
import 'package:org_wallet/screens/profile/profile_screen.dart';
import 'package:org_wallet/widgets/organization_switcher_modal.dart';
import 'package:org_wallet/screens/auth/pending_membership_screen.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';
import 'package:org_wallet/widgets/membership_validation_wrapper.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:org_wallet/theme/app_theme.dart';

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
  DateTime _selectedMonth = DateTime.now();
  bool _isReportsLoading = false;
  bool _tutorialStarted = false;
  bool _tutorialCompleted = true; // Default to true to prevent Showcase widgets initially
  bool _isQuarterlyView = false; // New state variable for quarterly view

  // GlobalKeys for tutorial targets
  final GlobalKey _transactionsNavKey = GlobalKey();
  final GlobalKey _reportsNavKey = GlobalKey();
  final GlobalKey _logsNavKey = GlobalKey();
  final GlobalKey _orgInfoNavKey = GlobalKey();
  final GlobalKey _manageDuesKey = GlobalKey();
  final GlobalKey _manageCategoriesKey = GlobalKey();
  final GlobalKey _exportReportsKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Default to current month
    _refreshDateRange();
    // Check tutorial status immediately to set state before first build
    _checkTutorialStatus();
    // Check if tutorial should be shown
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndShowTutorial());
  }

  Future<void> _checkTutorialStatus() async {
    final isCompleted = await TutorialService.isTutorialCompleted();
    if (mounted) {
      setState(() {
        _tutorialCompleted = isCompleted;
      });
    }
  }

  Future<void> _checkAndShowTutorial() async {
    // Prevent multiple tutorial starts
    if (_tutorialStarted) return;
    
    final isCompleted = await TutorialService.isTutorialCompleted();
    if (mounted) {
      setState(() {
        _tutorialCompleted = isCompleted;
      });
    }
    
    if (!isCompleted && mounted && !_tutorialStarted) {
      _tutorialStarted = true;
      // Small delay to ensure UI is ready
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        ShowCaseWidget.of(context).startShowCase([
          _transactionsNavKey,
          _reportsNavKey,
          _logsNavKey,
          _orgInfoNavKey,
        ]);
      }
    }
  }

  List<Widget> get _screens => [
    TransactionsScreen(key: ValueKey(_transactionScreenKey), dateRange: _selectedDateRange),
    ReportsScreen(
      selectedMonth: _selectedMonth,
      isQuarterlyView: _isQuarterlyView,
      isLoading: _isReportsLoading,
      onLoadingComplete: () {
        setState(() {
          _isReportsLoading = false;
        });
      },
    ),
    const LogsScreen(),
    const OrgInfoScreen(),
  ];

  @override
  void dispose() {
    super.dispose();
  }

  void _onTabTapped(int index) {
    final authService = Provider.of<AuthService>(context, listen: false);
    // Prevent members from accessing logs screen (index 2)
    if (authService.isMember() && index == 2) {
      // Redirect members to transactions screen
      setState(() {
        _currentIndex = 0;
      });
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // If user is not logged in (e.g., was automatically signed out), redirect to login
    if (!authService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      });
      // Return a loading screen while redirecting
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Check if user has pending membership
    if (authService.isPendingMembership()) {
      return const PendingMembershipScreen();
    }

    // Wrap the dashboard with membership validation
    return MembershipValidationWrapper(
      userId: authService.firebaseUser?.uid,
      orgId: authService.currentOrgId,
      child: _buildDashboard(authService),
    );
  }

  Widget _buildDashboard(AuthService authService) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
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
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_currentIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.date_range, color: Colors.black),
              tooltip: 'Filter by date',
              onPressed: _selectDateRange,
            ),
          ],
          if (_currentIndex == 1) ...[
            GestureDetector(
              onTap: _showMonthYearPicker,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getMonthYearText(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.black,
                      size: 20,
                    ),
                  ],
                ),
              ),
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
                      
                      // Organization + Role in one row
                      if (authService.organization != null || authService.currentOfficer != null)
                        Row(
                          children: [
                            // Organization name first
                            if (authService.organization != null)
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
                                    Text(
                                      authService.organization?.name ?? '',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            if (authService.organization != null && authService.currentOfficer != null)
                              const SizedBox(width: 8),
                            // Role second
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
                              // subtitle: 'Manage organization settings',
                              onTap: () => _handleMenuSelection('edit_org', context),
                            ),
                          
                          // Manage Members - Only President/Moderator
                          if (authService.canAccessDrawerItem('manage_members'))
                            _buildMenuItem(
                              icon: Icons.people,
                              title: 'Manage Members',
                              // subtitle: 'Add, remove, and manage members',
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
                            _tutorialCompleted
                                ? _buildMenuItem(
                                    icon: Icons.payments,
                                    title: 'Manage Dues',
                                    // subtitle: 'Track and manage member dues',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const ManageDuesScreen(),
                                        ),
                                      );
                                    },
                                  )
                                : Showcase(
                                    key: _manageDuesKey,
                                    description: 'Track and manage member dues easily',
                                    overlayOpacity: 0.7,
                                    title: 'Manage Dues',
                                    titleTextStyle: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    descTextStyle: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    tooltipBackgroundColor: AppTheme.primaryColor,
                                    textColor: Colors.white,
                                    child: _buildMenuItem(
                                      icon: Icons.payments,
                                      title: 'Manage Dues',
                                      // subtitle: 'Track and manage member dues',
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const ManageDuesScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                          
                          // Manage Categories - Treasurer/Secretary/Auditor/President/Moderator
                          if (authService.canAccessDrawerItem('manage_categories'))
                            _tutorialCompleted
                                ? _buildMenuItem(
                                    icon: Icons.category,
                                    title: 'Manage Categories',
                                    // subtitle: 'Organize transaction categories',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const ManageCategoriesScreen(),
                                        ),
                                      );
                                    },
                                  )
                                : Showcase(
                                    key: _manageCategoriesKey,
                                    description: 'Organize transaction categories',
                                    overlayOpacity: 0.7,
                                    title: 'Manage Categories',
                                    titleTextStyle: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    descTextStyle: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    tooltipBackgroundColor: AppTheme.primaryColor,
                                    textColor: Colors.white,
                                    child: _buildMenuItem(
                                      icon: Icons.category,
                                      title: 'Manage Categories',
                                      // subtitle: 'Organize transaction categories',
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const ManageCategoriesScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                          
                          // Invite QR - Only President/Moderator
                          if (authService.canAccessDrawerItem('invite_qr'))
                            _buildMenuItem(
                              icon: Icons.qr_code,
                              title: 'Invite QR',
                              // subtitle: 'Generate QR codes for invitations',
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
                            _tutorialCompleted
                                ? _buildMenuItem(
                                    icon: Icons.download,
                                    title: 'Export Reports',
                                    // subtitle: 'Download financial reports',
                                    onTap: () => _handleMenuSelection('export_reports', context),
                                  )
                                : Showcase(
                                    key: _exportReportsKey,
                                    description: 'Download financial reports',
                                    overlayOpacity: 0.7,
                                    title: 'Export Reports',
                                    titleTextStyle: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    descTextStyle: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    tooltipBackgroundColor: AppTheme.primaryColor,
                                    textColor: Colors.white,
                                    child: _buildMenuItem(
                                      icon: Icons.download,
                                      title: 'Export Reports',
                                      // subtitle: 'Download financial reports',
                                      onTap: () => _handleMenuSelection('export_reports', context),
                                    ),
                                  ),
                          
                          const SizedBox(height: 16),
                        ],
                        
                        // Account Section
                        _buildSectionHeader('Account'),
                        const SizedBox(height: 8),
                        
                        // Profile - All roles
                        _tutorialCompleted
                            ? _buildMenuItem(
                                icon: Icons.person,
                                title: 'Profile',
                                // subtitle: 'View and edit your profile',
                                onTap: () => _handleMenuSelection('profile', context),
                              )
                            : Showcase(
                                key: _profileKey,
                                description: 'View and edit your profile',
                                overlayOpacity: 0.7,
                                title: 'Profile',
                                titleTextStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                descTextStyle: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                                tooltipBackgroundColor: AppTheme.primaryColor,
                                textColor: Colors.white,
                                child: _buildMenuItem(
                                  icon: Icons.person,
                                  title: 'Profile',
                                  // subtitle: 'View and edit your profile',
                                  onTap: () => _handleMenuSelection('profile', context),
                                ),
                              ),
                        
                        // Join QR - All roles
                        _buildMenuItem(
                          icon: Icons.qr_code_scanner,
                          title: 'Join QR',
                          // subtitle: 'Scan QR code to join organization',
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
                          // subtitle: 'Change your current organization',
                          onTap: () => _showOrganizationSwitcher(context),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Logout - All roles
                        _buildMenuItem(
                          icon: Icons.logout,
                          title: 'Logout',
                          //  subtitle: 'Sign out of your account',
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
                Expanded(
                  child: _tutorialCompleted
                      ? _buildNavItemContent(
                          icon: Icons.receipt_long,
                          label: 'Transactions',
                          index: 0,
                        )
                      : Showcase(
                          key: _transactionsNavKey,
                          description: 'View and add transactions here',
                          overlayOpacity: 0.7,
                          title: 'Transactions',
                          titleTextStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          descTextStyle: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          tooltipBackgroundColor: AppTheme.primaryColor,
                          textColor: Colors.white,
                          disposeOnTap: false,
                          onTargetClick: () async {
                            setState(() {
                              _currentIndex = 0;
                            });
                            await Future.delayed(const Duration(milliseconds: 300));
                            ShowCaseWidget.of(context).next();
                          },
                          onBarrierClick: () async {
                            await TutorialService.setTutorialCompleted();
                            if (mounted) {
                              setState(() {
                                _tutorialCompleted = true;
                              });
                            }
                            ShowCaseWidget.of(context).dismiss();
                          },
                          child: _buildNavItemContent(
                            icon: Icons.receipt_long,
                            label: 'Transactions',
                            index: 0,
                          ),
                        ),
                ),
                Expanded(
                  child: _tutorialCompleted
                      ? _buildNavItemContent(
                          icon: Icons.analytics,
                          label: 'Reports',
                          index: 1,
                        )
                      : Showcase(
                          key: _reportsNavKey,
                          description: 'Check your financial reports here',
                          overlayOpacity: 0.7,
                          title: 'Reports',
                          titleTextStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          descTextStyle: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          tooltipBackgroundColor: AppTheme.primaryColor,
                          textColor: Colors.white,
                          disposeOnTap: false,
                          onTargetClick: () async {
                            setState(() {
                              _currentIndex = 1;
                            });
                            await Future.delayed(const Duration(milliseconds: 300));
                            ShowCaseWidget.of(context).next();
                          },
                          onBarrierClick: () async {
                            await TutorialService.setTutorialCompleted();
                            if (mounted) {
                              setState(() {
                                _tutorialCompleted = true;
                              });
                            }
                            ShowCaseWidget.of(context).dismiss();
                          },
                          child: _buildNavItemContent(
                            icon: Icons.analytics,
                            label: 'Reports',
                            index: 1,
                          ),
                        ),
                ),
                // Only show logs tab for non-member roles
                if (!authService.isMember())
                  Expanded(
                    child: _tutorialCompleted
                        ? _buildNavItemContent(
                            icon: Icons.history,
                            label: 'Logs',
                            index: 2,
                          )
                        : Showcase(
                            key: _logsNavKey,
                            description: 'Review all activity logs here',
                            overlayOpacity: 0.7,
                            title: 'Logs',
                            titleTextStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            descTextStyle: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            tooltipBackgroundColor: AppTheme.primaryColor,
                            textColor: Colors.white,
                            disposeOnTap: false,
                            onTargetClick: () async {
                              setState(() {
                                _currentIndex = 2;
                              });
                              await Future.delayed(const Duration(milliseconds: 300));
                              ShowCaseWidget.of(context).next();
                            },
                            onBarrierClick: () async {
                              await TutorialService.setTutorialCompleted();
                              if (mounted) {
                                setState(() {
                                  _tutorialCompleted = true;
                                });
                              }
                              ShowCaseWidget.of(context).dismiss();
                            },
                            child: _buildNavItemContent(
                              icon: Icons.history,
                              label: 'Logs',
                              index: 2,
                            ),
                          ),
                  ),
                Expanded(
                  child: _tutorialCompleted
                      ? _buildNavItemContent(
                          icon: Icons.business,
                          label: 'Org Info',
                          index: 3,
                        )
                      : Showcase(
                          key: _orgInfoNavKey,
                          description: 'View your organization details here',
                          overlayOpacity: 0.7,
                          title: 'Org Info',
                          titleTextStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          descTextStyle: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          tooltipBackgroundColor: AppTheme.primaryColor,
                          textColor: Colors.white,
                          disposeOnTap: false,
                          onTargetClick: () async {
                            setState(() {
                              _currentIndex = 3;
                            });
                            await Future.delayed(const Duration(milliseconds: 300));
                            ShowCaseWidget.of(context).dismiss();
                            await TutorialService.setTutorialCompleted();
                            if (mounted) {
                              setState(() {
                                _tutorialCompleted = true;
                              });
                            }
                          },
                          onBarrierClick: () async {
                            await TutorialService.setTutorialCompleted();
                            if (mounted) {
                              setState(() {
                                _tutorialCompleted = true;
                              });
                            }
                            ShowCaseWidget.of(context).dismiss();
                          },
                          child: _buildNavItemContent(
                            icon: Icons.business,
                            label: 'Org Info',
                            index: 3,
                          ),
                        ),
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

  String _getMonthYearText() {
    if (_isQuarterlyView) {
      // Determine which quarter based on the selected month
      final month = _selectedMonth.month;
      int quarter;
      if (month >= 1 && month <= 3) {
        quarter = 1;
      } else if (month >= 4 && month <= 6) {
        quarter = 2;
      } else if (month >= 7 && month <= 9) {
        quarter = 3;
      } else {
        quarter = 4;
      }
      return 'Q$quarter ${_selectedMonth.year}';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
    }
  }

  void _showMonthYearPicker() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _MonthYearPickerDialog(
          selectedMonth: _selectedMonth,
          isQuarterlyView: _isQuarterlyView,
          onMonthSelected: (DateTime newMonth, bool isQuarterly) {
            setState(() {
              _selectedMonth = newMonth;
              _isQuarterlyView = isQuarterly;
              _isReportsLoading = true;
            });
          },
        );
      },
    );
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ExportReportsScreen(),
          ),
        );
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
    // String? subtitle,
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
                      // Text(
                      //   subtitle ?? '',
                      //   style: TextStyle(
                      //     fontSize: 13,
                      //     color: TWColors.slate.shade500,
                      //   ),
                      // ),
                    ],
                  ),
                ),
                // Icon(
                //   Icons.chevron_right,
                //   color: TWColors.slate.shade400,
                //   size: 20,
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build navigation items content (without Expanded wrapper)
  Widget _buildNavItemContent({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 360 ? 20.0 : 22.0;
    final fontSize = screenWidth < 360 ? 12.0 : 13.0;
    
    return GestureDetector(
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
    );
  }
}

class _MonthYearPickerDialog extends StatefulWidget {
  final DateTime selectedMonth;
  final bool isQuarterlyView;
  final Function(DateTime, bool) onMonthSelected;

  const _MonthYearPickerDialog({
    required this.selectedMonth,
    this.isQuarterlyView = false,
    required this.onMonthSelected,
  });

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late DateTime _currentYear;
  late DateTime _selectedMonth;
  late bool _isQuarterlyView;

  @override
  void initState() {
    super.initState();
    _currentYear = DateTime(widget.selectedMonth.year);
    _selectedMonth = widget.selectedMonth;
    _isQuarterlyView = widget.isQuarterlyView;
  }

  void _previousYear() {
    setState(() {
      _currentYear = DateTime(_currentYear.year - 1);
    });
  }

  void _nextYear() {
    setState(() {
      _currentYear = DateTime(_currentYear.year + 1);
    });
  }

  void _toggleView() {
    setState(() {
      _isQuarterlyView = !_isQuarterlyView;
    });
  }

  void _selectMonth(int month) {
    setState(() {
      _selectedMonth = DateTime(_currentYear.year, month);
    });
    widget.onMonthSelected(_selectedMonth, false);
    Navigator.of(context).pop();
  }

  void _selectQuarter(int quarter) {
    // Calculate the first month of the selected quarter
    // Q1 = Jan (1), Q2 = Apr (4), Q3 = Jul (7), Q4 = Oct (10)
    final quarterStartMonth = (quarter - 1) * 3 + 1;
    setState(() {
      _selectedMonth = DateTime(_currentYear.year, quarterStartMonth);
    });
    widget.onMonthSelected(_selectedMonth, true);
    Navigator.of(context).pop();
  }

  String _getMonthYearText() {
    if (_isQuarterlyView) {
      // Determine which quarter based on the selected month
      final month = _selectedMonth.month;
      int quarter;
      if (month >= 1 && month <= 3) {
        quarter = 1;
      } else if (month >= 4 && month <= 6) {
        quarter = 2;
      } else if (month >= 7 && month <= 9) {
        quarter = 3;
      } else {
        quarter = 4;
      }
      return 'Q$quarter ${_selectedMonth.year}';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with current selection
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getMonthYearText(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Toggle between Month and Quarter view
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_isQuarterlyView) _toggleView();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isQuarterlyView 
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Month',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: !_isQuarterlyView 
                              ? Colors.white
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (!_isQuarterlyView) _toggleView();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isQuarterlyView 
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Quarter',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _isQuarterlyView 
                              ? Colors.white
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Year navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousYear,
                  icon: const Icon(Icons.chevron_left),
                  iconSize: 28,
                ),
                Text(
                  _currentYear.year.toString(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _nextYear,
                  icon: const Icon(Icons.chevron_right),
                  iconSize: 28,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Month or Quarter grid
            _isQuarterlyView 
              ? GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    final quarter = index + 1;
                    // Determine if this quarter is selected based on the selected month
                    final selectedMonth = _selectedMonth.month;
                    bool isSelected = false;
                    if (quarter == 1 && selectedMonth >= 1 && selectedMonth <= 3) {
                      isSelected = true;
                    } else if (quarter == 2 && selectedMonth >= 4 && selectedMonth <= 6) {
                      isSelected = true;
                    } else if (quarter == 3 && selectedMonth >= 7 && selectedMonth <= 9) {
                      isSelected = true;
                    } else if (quarter == 4 && selectedMonth >= 10 && selectedMonth <= 12) {
                      isSelected = true;
                    }
                    
                    // Determine if this is the current quarter
                    final now = DateTime.now();
                    final currentMonth = now.month;
                    bool isCurrentQuarter = false;
                    if (quarter == 1 && currentMonth >= 1 && currentMonth <= 3) {
                      isCurrentQuarter = _currentYear.year == now.year;
                    } else if (quarter == 2 && currentMonth >= 4 && currentMonth <= 6) {
                      isCurrentQuarter = _currentYear.year == now.year;
                    } else if (quarter == 3 && currentMonth >= 7 && currentMonth <= 9) {
                      isCurrentQuarter = _currentYear.year == now.year;
                    } else if (quarter == 4 && currentMonth >= 10 && currentMonth <= 12) {
                      isCurrentQuarter = _currentYear.year == now.year;
                    }
                    
                    return GestureDetector(
                      onTap: () => _selectQuarter(quarter),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary
                              : isCurrentQuarter
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                  : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected 
                                ? Theme.of(context).colorScheme.primary
                                : isCurrentQuarter
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                                    : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Q$quarter',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected 
                                  ? Colors.white
                                  : isCurrentQuarter
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final isSelected = _currentYear.year == _selectedMonth.year && 
                                     month == _selectedMonth.month;
                    final isCurrentMonth = _currentYear.year == DateTime.now().year && 
                                         month == DateTime.now().month;
                    
                    return GestureDetector(
                      onTap: () => _selectMonth(month),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary
                              : isCurrentMonth
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                  : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected 
                                ? Theme.of(context).colorScheme.primary
                                : isCurrentMonth
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                                    : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            months[index],
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected 
                                  ? Colors.white
                                  : isCurrentMonth
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            const SizedBox(height: 16),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Close',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
