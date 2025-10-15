import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/models/officer.dart';
import 'package:org_wallet/models/organization.dart';
import 'package:org_wallet/screens/auth/pending_membership_screen.dart';
import 'package:org_wallet/screens/organization/join_organization_screen.dart';

/// Service for real-time membership validation across organization screens
class MembershipValidationService extends ChangeNotifier {
  static final MembershipValidationService _instance = MembershipValidationService._internal();
  factory MembershipValidationService() => _instance;
  MembershipValidationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Stream subscriptions for real-time monitoring
  StreamSubscription<DocumentSnapshot>? _organizationSubscription;
  StreamSubscription<QuerySnapshot>? _officerSubscription;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  
  // Current state
  String? _currentUserId;
  String? _currentOrgId;
  Officer? _currentOfficer;
  Organization? _currentOrganization;
  bool _isValidating = false;
  
  // Validation callbacks
  final List<VoidCallback> _onAccessRevokedCallbacks = [];
  final List<VoidCallback> _onRoleChangedCallbacks = [];
  final List<VoidCallback> _onOrganizationChangedCallbacks = [];

  // Getters
  String? get currentUserId => _currentUserId;
  String? get currentOrgId => _currentOrgId;
  Officer? get currentOfficer => _currentOfficer;
  Organization? get currentOrganization => _currentOrganization;
  bool get isValidating => _isValidating;
  bool get hasValidMembership => _currentOfficer != null && _currentOfficer!.status == OfficerStatus.approved;
  bool get isPendingMembership => _currentOfficer?.status == OfficerStatus.pending;
  bool get isDeniedMembership => _currentOfficer?.status == OfficerStatus.denied;

  /// Initialize the service with current user and organization
  Future<void> initialize(String userId, String orgId) async {
    if (_currentUserId == userId && _currentOrgId == orgId) {
      return; // Already initialized with same data
    }

    // Cancel existing subscriptions
    await _cancelSubscriptions();
    
    _currentUserId = userId;
    _currentOrgId = orgId;
    _isValidating = true;
    notifyListeners();

    try {
      // Load initial data
      await _loadInitialData();
      
      // Set up real-time listeners
      await _setupRealtimeListeners();
      
      _isValidating = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing membership validation: $e');
      _isValidating = false;
      notifyListeners();
    }
  }

  /// Load initial organization and officer data
  Future<void> _loadInitialData() async {
    if (_currentUserId == null || _currentOrgId == null) return;

    try {
      // Load organization data
      final orgDoc = await _firestore
          .collection('organizations')
          .doc(_currentOrgId)
          .get();
      
      if (orgDoc.exists) {
        _currentOrganization = Organization.fromMap({
          'id': orgDoc.id,
          ...orgDoc.data()!,
        });
      }

      // Load officer data
      final officerQuery = await _firestore
          .collection('officers')
          .where('userId', isEqualTo: _currentUserId)
          .where('orgId', isEqualTo: _currentOrgId)
          .limit(1)
          .get();

      if (officerQuery.docs.isNotEmpty) {
        _currentOfficer = Officer.fromMap({
          'id': officerQuery.docs.first.id,
          ...officerQuery.docs.first.data(),
        });
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    }
  }

  /// Set up real-time listeners for organization and membership changes
  Future<void> _setupRealtimeListeners() async {
    if (_currentUserId == null || _currentOrgId == null) return;

    // Listen to organization changes
    _organizationSubscription = _firestore
        .collection('organizations')
        .doc(_currentOrgId)
        .snapshots()
        .listen(_onOrganizationChanged, onError: _onListenerError);

    // Listen to officer changes for current user in current organization
    _officerSubscription = _firestore
        .collection('officers')
        .where('userId', isEqualTo: _currentUserId)
        .where('orgId', isEqualTo: _currentOrgId)
        .snapshots()
        .listen(_onOfficerChanged, onError: _onListenerError);

    // Listen to user document changes (for organization list updates)
    _userSubscription = _firestore
        .collection('users')
        .doc(_currentUserId)
        .snapshots()
        .listen(_onUserChanged, onError: _onListenerError);
  }

  /// Handle organization document changes
  void _onOrganizationChanged(DocumentSnapshot snapshot) {
    if (!snapshot.exists) {
      _handleAccessRevoked('Organization no longer exists');
      return;
    }

    try {
      _currentOrganization = Organization.fromMap({
        'id': snapshot.id,
        ...snapshot.data() as Map<String, dynamic>,
      });
      _notifyOrganizationChanged();
    } catch (e) {
      debugPrint('Error parsing organization data: $e');
    }
  }

  /// Handle officer document changes
  void _onOfficerChanged(QuerySnapshot snapshot) {
    if (snapshot.docs.isEmpty) {
      _handleAccessRevoked('You are no longer a member of this organization');
      return;
    }

    try {
      final officerData = snapshot.docs.first.data() as Map<String, dynamic>;
      final newOfficer = Officer.fromMap({
        'id': snapshot.docs.first.id,
        ...officerData,
      });

      final oldOfficer = _currentOfficer;
      _currentOfficer = newOfficer;

      // Check if status changed
      if (oldOfficer?.status != newOfficer.status) {
        _handleStatusChange(oldOfficer?.status, newOfficer.status);
      }

      // Check if role changed
      if (oldOfficer?.role != newOfficer.role) {
        _notifyRoleChanged();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error parsing officer data: $e');
    }
  }

  /// Handle user document changes
  void _onUserChanged(DocumentSnapshot snapshot) {
    if (!snapshot.exists) {
      _handleAccessRevoked('User account no longer exists');
      return;
    }

    try {
      final userData = snapshot.data() as Map<String, dynamic>;
      final organizations = List<String>.from(userData['organizations'] ?? []);
      
      // Check if current organization is still in user's organizations
      if (!organizations.contains(_currentOrgId)) {
        _handleAccessRevoked('You are no longer a member of this organization');
      }
    } catch (e) {
      debugPrint('Error parsing user data: $e');
    }
  }

  /// Handle listener errors
  void _onListenerError(dynamic error) {
    debugPrint('Membership validation listener error: $error');
    // Optionally retry or handle gracefully
  }

  /// Handle access revocation
  void _handleAccessRevoked(String reason) {
    debugPrint('Access revoked: $reason');
    _currentOfficer = null;
    _currentOrganization = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
    _notifyAccessRevoked();
  }

  /// Handle status changes
  void _handleStatusChange(OfficerStatus? oldStatus, OfficerStatus newStatus) {
    switch (newStatus) {
      case OfficerStatus.denied:
        _handleAccessRevoked('Your membership has been denied');
        break;
      case OfficerStatus.pending:
        // User is pending approval
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        break;
      case OfficerStatus.approved:
        // User is approved
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        break;
    }
  }

  /// Validate membership before accessing organization screens
  bool validateMembership() {
    if (_currentOfficer == null) {
      return false;
    }

    if (_currentOfficer!.status == OfficerStatus.denied) {
      return false;
    }

    if (_currentOfficer!.status == OfficerStatus.pending) {
      return false;
    }

    return true;
  }

  /// Check if user can access a specific organization screen
  bool canAccessOrganizationScreen() {
    // If service hasn't been initialized yet, assume access is valid
    // (let the AuthService handle the initial authentication)
    if (_currentUserId == null || _currentOrgId == null) {
      return true;
    }
    
    return validateMembership() && _currentOrganization != null;
  }

  /// Get appropriate screen to redirect to based on current status
  Widget getRedirectScreen() {
    if (_currentOfficer == null) {
      return const JoinOrganizationScreen();
    }

    switch (_currentOfficer!.status) {
      case OfficerStatus.pending:
        return const PendingMembershipScreen();
      case OfficerStatus.denied:
        return const JoinOrganizationScreen();
      case OfficerStatus.approved:
        // This shouldn't happen if we're calling getRedirectScreen
        return const JoinOrganizationScreen();
    }
  }

  /// Add callback for when access is revoked
  void addOnAccessRevokedCallback(VoidCallback callback) {
    _onAccessRevokedCallbacks.add(callback);
  }

  /// Remove callback for when access is revoked
  void removeOnAccessRevokedCallback(VoidCallback callback) {
    _onAccessRevokedCallbacks.remove(callback);
  }

  /// Add callback for when role changes
  void addOnRoleChangedCallback(VoidCallback callback) {
    _onRoleChangedCallbacks.add(callback);
  }

  /// Remove callback for when role changes
  void removeOnRoleChangedCallback(VoidCallback callback) {
    _onRoleChangedCallbacks.remove(callback);
  }

  /// Add callback for when organization changes
  void addOnOrganizationChangedCallback(VoidCallback callback) {
    _onOrganizationChangedCallbacks.add(callback);
  }

  /// Remove callback for when organization changes
  void removeOnOrganizationChangedCallback(VoidCallback callback) {
    _onOrganizationChangedCallbacks.remove(callback);
  }

  /// Notify access revoked callbacks
  void _notifyAccessRevoked() {
    for (final callback in _onAccessRevokedCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Error in access revoked callback: $e');
      }
    }
  }

  /// Notify role changed callbacks
  void _notifyRoleChanged() {
    for (final callback in _onRoleChangedCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Error in role changed callback: $e');
      }
    }
  }

  /// Notify organization changed callbacks
  void _notifyOrganizationChanged() {
    for (final callback in _onOrganizationChangedCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Error in organization changed callback: $e');
      }
    }
  }

  /// Cancel all subscriptions
  Future<void> _cancelSubscriptions() async {
    await _organizationSubscription?.cancel();
    await _officerSubscription?.cancel();
    await _userSubscription?.cancel();
    
    _organizationSubscription = null;
    _officerSubscription = null;
    _userSubscription = null;
  }

  /// Clean up and dispose
  @override
  void dispose() {
    _cancelSubscriptions();
    _onAccessRevokedCallbacks.clear();
    _onRoleChangedCallbacks.clear();
    _onOrganizationChangedCallbacks.clear();
    super.dispose();
  }

  /// Reset the service
  Future<void> reset() async {
    await _cancelSubscriptions();
    _currentUserId = null;
    _currentOrgId = null;
    _currentOfficer = null;
    _currentOrganization = null;
    _isValidating = false;
    notifyListeners();
  }
}
