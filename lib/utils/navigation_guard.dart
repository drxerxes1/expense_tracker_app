import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/membership_validation_service.dart';
import 'package:org_wallet/screens/organization/join_organization_screen.dart';
import 'package:org_wallet/screens/auth/login_screen.dart';
import 'package:org_wallet/widgets/membership_validation_wrapper.dart';

/// Utility class for navigation guards and membership validation
class NavigationGuard {
  /// Check if user can navigate to organization screens
  static bool canNavigateToOrganizationScreen(BuildContext context) {
    final membershipService = Provider.of<MembershipValidationService>(context, listen: false);
    return membershipService.canAccessOrganizationScreen();
  }

  /// Navigate to appropriate screen based on membership status
  static void navigateBasedOnMembershipStatus(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        final membershipService = Provider.of<MembershipValidationService>(context, listen: false);
        
        if (!membershipService.canAccessOrganizationScreen()) {
          final redirectScreen = membershipService.getRedirectScreen();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => redirectScreen),
            (route) => false,
          );
        }
      }
    });
  }

  /// Guard navigation to organization screens
  static Widget guardOrganizationNavigation(
    BuildContext context,
    Widget child, {
    String? userId,
    String? orgId,
  }) {
    return MembershipValidationWrapper(
      userId: userId,
      orgId: orgId,
      child: child,
    );
  }

  /// Show access denied dialog
  static void showAccessDeniedDialog(BuildContext context, {String? reason}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.block, color: Colors.red.shade600),
                const SizedBox(width: 8),
                const Text('Access Denied'),
              ],
            ),
            content: Text(
              reason ?? 'You do not have permission to access this feature.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const JoinOrganizationScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Join Organization'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: Text(
                  'Logout',
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ),
            ],
          ),
        );
      }
    });
  }

  /// Check membership before performing organization actions
  static Future<bool> checkMembershipBeforeAction(
    BuildContext context, {
    required String action,
    bool showDialog = true,
  }) async {
    final membershipService = Provider.of<MembershipValidationService>(context, listen: false);
    
    if (!membershipService.canAccessOrganizationScreen()) {
      if (showDialog) {
        showAccessDeniedDialog(
          context,
          reason: 'You cannot $action. Your access to this organization has been revoked.',
        );
      }
      return false;
    }
    
    return true;
  }

  /// Validate membership on screen entry
  static void validateMembershipOnEntry(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        final membershipService = Provider.of<MembershipValidationService>(context, listen: false);
        
        if (!membershipService.canAccessOrganizationScreen()) {
          navigateBasedOnMembershipStatus(context);
        }
      }
    });
  }
}

/// Mixin for screens that need membership validation
mixin MembershipValidationMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    // Validate membership when screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationGuard.validateMembershipOnEntry(context);
    });
  }

  /// Override this method to handle access revocation
  void onAccessRevoked() {
    NavigationGuard.navigateBasedOnMembershipStatus(context);
  }

  /// Override this method to handle role changes
  void onRoleChanged() {
    setState(() {});
  }

  /// Override this method to handle organization changes
  void onOrganizationChanged() {
    setState(() {});
  }
}
