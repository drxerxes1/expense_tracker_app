import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/membership_validation_service.dart';
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
  late VoidCallback _accessRevokedCallback;
  late VoidCallback _roleChangedCallback;
  late VoidCallback _organizationChangedCallback;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _validationService = MembershipValidationService();
    
    // Create callbacks with proper references
    _accessRevokedCallback = () {
      if (mounted) {
        _showAccessRevokedDialog();
      }
    };
    
    _roleChangedCallback = () {
      if (mounted) {
        SnackBarHelper.showInfo(
          context,
          message: 'Your role has been updated',
        );
      }
    };
    
    _organizationChangedCallback = () {
      if (mounted) {
        // Organization information updated - no notification needed
      }
    };
    
    _setupValidationCallbacks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeValidation();
  }

  void _setupValidationCallbacks() {
    // Handle access revoked
    _validationService.addOnAccessRevokedCallback(_accessRevokedCallback);

    // Handle role changes
    _validationService.addOnRoleChangedCallback(_roleChangedCallback);

    // Handle organization changes
    _validationService.addOnOrganizationChangedCallback(_organizationChangedCallback);
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
    // Skip showing dialog - let the Consumer handle the redirect directly
    // This prevents conflicts between dialog and Consumer redirect
    debugPrint('Access revoked - redirecting to join organization screen');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _redirectToJoinOrganization();
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
            // If officer doesn't exist (kicked/removed), show join screen immediately
            if (validationService.currentOfficer == null && validationService.currentOrganization == null) {
              return const JoinOrganizationScreen();
            }
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
    _validationService.removeOnAccessRevokedCallback(_accessRevokedCallback);
    _validationService.removeOnRoleChangedCallback(_roleChangedCallback);
    _validationService.removeOnOrganizationChangedCallback(_organizationChangedCallback);
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
