import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/membership_validation_service.dart';
import 'package:org_wallet/screens/auth/login_screen.dart';
import 'package:org_wallet/screens/organization/join_organization_screen.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';

/// Widget that wraps organization screens and validates membership in real-time
class MembershipValidationWrapper extends StatefulWidget {
  final Widget child;
  final String? userId;
  final String? orgId;

  const MembershipValidationWrapper({
    super.key,
    required this.child,
    this.userId,
    this.orgId,
  });

  @override
  State<MembershipValidationWrapper> createState() => _MembershipValidationWrapperState();
}

class _MembershipValidationWrapperState extends State<MembershipValidationWrapper> {
  late MembershipValidationService _validationService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _validationService = MembershipValidationService();
    _setupValidationCallbacks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeValidation();
  }

  void _setupValidationCallbacks() {
    // Handle access revoked
    _validationService.addOnAccessRevokedCallback(() {
      if (mounted) {
        _showAccessRevokedDialog();
      }
    });

    // Handle role changes
    _validationService.addOnRoleChangedCallback(() {
      if (mounted) {
        SnackBarHelper.showInfo(
          context,
          message: 'Your role has been updated',
        );
      }
    });

    // Handle organization changes
    _validationService.addOnOrganizationChangedCallback(() {
      if (mounted) {
        // Organization information updated - no notification needed
      }
    });
  }

  Future<void> _initializeValidation() async {
    if (_isInitialized) return;

    final userId = widget.userId;
    final orgId = widget.orgId;

    // Only initialize if we have both userId and orgId
    if (userId != null && orgId != null) {
      await _validationService.initialize(userId, orgId);
      _isInitialized = true;
    }
    // If we don't have the required data, just wait - don't redirect to login
    // The AuthService might still be loading the user data
  }

  void _showAccessRevokedDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.block, color: Colors.red.shade600),
                const SizedBox(width: 8),
                const Text('Access Revoked'),
              ],
            ),
            content: const Text(
              'Your access to this organization has been removed. You will be redirected to join another organization.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _redirectToJoinOrganization();
                },
                child: const Text('Join Organization'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _redirectToLogin();
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

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    });
  }

  void _redirectToJoinOrganization() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const JoinOrganizationScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MembershipValidationService>.value(
      value: _validationService,
      child: Consumer<MembershipValidationService>(
        builder: (context, validationService, child) {
          // If we don't have userId or orgId, just show the child (let AuthService handle it)
          if (widget.userId == null || widget.orgId == null) {
            return widget.child;
          }

          // Show loading while validating
          if (validationService.isValidating) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // Check if user has valid membership
          if (!validationService.canAccessOrganizationScreen()) {
            // Return appropriate screen based on status
            return validationService.getRedirectScreen();
          }

          // User has valid access, show the wrapped content
          return widget.child;
        },
      ),
    );
  }

  @override
  void dispose() {
    _validationService.removeOnAccessRevokedCallback(() {});
    _validationService.removeOnRoleChangedCallback(() {});
    _validationService.removeOnOrganizationChangedCallback(() {});
    super.dispose();
  }
}

/// Mixin for screens that need membership validation
mixin MembershipValidationMixin<T extends StatefulWidget> on State<T> {
  MembershipValidationService? _validationService;

  @override
  void initState() {
    super.initState();
    _validationService = MembershipValidationService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupValidationCallbacks();
  }

  void _setupValidationCallbacks() {
    if (_validationService == null) return;

    // Handle access revoked
    _validationService!.addOnAccessRevokedCallback(() {
      if (mounted) {
        _onAccessRevoked();
      }
    });

    // Handle role changes
    _validationService!.addOnRoleChangedCallback(() {
      if (mounted) {
        _onRoleChanged();
      }
    });

    // Handle organization changes
    _validationService!.addOnOrganizationChangedCallback(() {
      if (mounted) {
        _onOrganizationChanged();
      }
    });
  }

  /// Override this method to handle access revocation
  void _onAccessRevoked() {
    // Default implementation - can be overridden
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JoinOrganizationScreen()),
      (route) => false,
    );
  }

  /// Override this method to handle role changes
  void _onRoleChanged() {
    // Default implementation - can be overridden
    setState(() {});
  }

  /// Override this method to handle organization changes
  void _onOrganizationChanged() {
    // Default implementation - can be overridden
    setState(() {});
  }

  @override
  void dispose() {
    _validationService?.removeOnAccessRevokedCallback(() {});
    _validationService?.removeOnRoleChangedCallback(() {});
    _validationService?.removeOnOrganizationChangedCallback(() {});
    super.dispose();
  }
}
