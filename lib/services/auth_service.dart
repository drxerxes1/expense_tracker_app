import 'dart:async';
import 'package:hive/hive.dart';
import 'package:org_wallet/models/user_login.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/models/user.dart' as app_user;
import 'package:org_wallet/models/organization.dart';
import 'package:org_wallet/models/officer.dart';
import 'package:org_wallet/constants/role_permissions.dart';

class AuthService extends ChangeNotifier {
  Organization? _organization;

  Organization? get organization => _organization;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _firebaseUser;
  app_user.User? _user;
  Officer? _currentOfficer;
  String? _currentOrgId;
  String? _lastErrorMessage;
  StreamSubscription<QuerySnapshot>? _officerSubscription;

  User? get firebaseUser => _firebaseUser;
  app_user.User? get user => _user;
  Officer? get currentOfficer => _currentOfficer;
  String? get currentOrgId => _currentOrgId;
  bool get isLoggedIn => _firebaseUser != null;
  String? get lastErrorMessage => _lastErrorMessage;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
    _loadLoginFromHive();
  }

  void _onAuthStateChanged(User? user) {
    _firebaseUser = user;
    final loginBox = Hive.box<UserLogin>('userLogin');
    if (user != null) {
      _loadUserData();
      // Save login info to Hive
      final login = UserLogin(
        userId: user.uid,
        email: user.email ?? '',
        name: user.displayName,
      );
      loginBox.put('current', login);
    } else {
      _user = null;
      _currentOfficer = null;
      _currentOrgId = null;
      // Cancel officer subscription
      _officerSubscription?.cancel();
      _officerSubscription = null;
      // Remove login info from Hive
      loginBox.delete('current');
    }
    notifyListeners();
  }
  void _loadLoginFromHive() {
    final loginBox = Hive.box<UserLogin>('userLogin');
    final login = loginBox.get('current');
    if (login != null) {
      // Optionally, you can auto-login or restore state here
      // For now, just print for debug
      debugPrint('Loaded login from Hive: ${login.email}');
    }
  }

  Future<void> _loadUserData() async {
    if (_firebaseUser == null) return;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_firebaseUser!.uid)
          .get();

      if (userDoc.exists) {
        _user = app_user.User.fromMap({'id': userDoc.id, ...userDoc.data()!});

        // Try to load saved organization from Hive first
        try {
          final metaBox = await Hive.openBox('userMeta');
          final savedMeta = metaBox.get(_firebaseUser!.uid);
          if (savedMeta != null && savedMeta['orgId'] != null) {
            final savedOrgId = savedMeta['orgId'] as String;
            // Verify the saved org is still in user's organizations
            if (_user!.organizations.contains(savedOrgId)) {
              _currentOrgId = savedOrgId;
              await _loadCurrentOfficerData();
              await _loadOrganization();
              return;
            }
          }
        } catch (e) {
          debugPrint('Error loading saved organization from Hive: $e');
        }

        // Fallback to first organization if no saved org or saved org is invalid
        if (_user!.organizations.isNotEmpty) {
          _currentOrgId = _user!.organizations.first;
          await _loadCurrentOfficerData();
          await _loadOrganization();
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadOrganization() async {
    if (_currentOrgId == null) {
      _organization = null;
      return;
    }
    try {
      final orgDoc = await _firestore.collection('organizations').doc(_currentOrgId).get();
      if (orgDoc.exists) {
        _organization = Organization.fromMap({'id': orgDoc.id, ...orgDoc.data()!});
      } else {
        _organization = null;
      }
    } catch (e) {
      debugPrint('Error loading organization: $e');
      _organization = null;
    }
    notifyListeners();
  }

  Future<void> _loadCurrentOfficerData() async {
    if (_currentOrgId == null || _firebaseUser == null) return;

    // Cancel existing subscription
    await _officerSubscription?.cancel();

    try {
      // Set up real-time listener for officer data changes
      _officerSubscription = _firestore
          .collection('officers')
          .where('orgId', isEqualTo: _currentOrgId)
          .where('userId', isEqualTo: _firebaseUser!.uid)
          .snapshots()
          .listen((snapshot) {
        try {
          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            _currentOfficer = Officer.fromMap({
              'id': doc.id,
              ...doc.data(),
            });
            notifyListeners();
          } else {
            _currentOfficer = null;
            notifyListeners();
          }
        } catch (e) {
          debugPrint('Error parsing officer data in stream: $e');
          // Don't crash the app, just log the error
        }
      }, onError: (e) {
        debugPrint('Error in officer data stream: $e');
      });

      // Also do an initial load
      final officerDoc = await _firestore
          .collection('officers')
          .where('orgId', isEqualTo: _currentOrgId)
          .where('userId', isEqualTo: _firebaseUser!.uid)
          .get();

      if (officerDoc.docs.isNotEmpty) {
        try {
          _currentOfficer = Officer.fromMap({
            'id': officerDoc.docs.first.id,
            ...officerDoc.docs.first.data(),
          });
        } catch (e) {
          debugPrint('Error parsing officer data in initial load: $e');
          _currentOfficer = null;
        }
      }
    } catch (e) {
      debugPrint('Error loading officer data: $e');
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      _lastErrorMessage = null;
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final user = app_user.User(
          id: userCredential.user!.uid,
          name: name,
          email: email,
          organizations: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(user.toMap());

        _user = user;
        notifyListeners();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _lastErrorMessage = e.message ?? 'Authentication error';
      debugPrint('Error during sign up: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      _lastErrorMessage = 'Unexpected error occurred';
      debugPrint('Error during sign up: $e');
      return false;
    }
  }

  /// Create an account (sign up) and join the provided organization with the
  /// given role. Returns true on success.
  Future<bool> createAccountAndJoin({
    required String name,
    required String email,
    required String password,
    required String orgId,
    required String role,
  }) async {
    final created = await signUp(name: name, email: email, password: password);
    if (!created) return false;

    try {
      final userId = _firebaseUser!.uid;
      // Create officer record
      await _firestore.collection('officers').add({
        'orgId': orgId,
        'userId': userId,
        'name': name,
        'email': email,
        'role': role,
        'status': OfficerStatus.pending.index,
        'joinedAt': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Update user's organizations list
      await _firestore.collection('users').doc(userId).update({
        'organizations': FieldValue.arrayUnion([orgId]),
      });

      // Save to Hive meta
      try {
        final metaBox = await Hive.openBox('userMeta');
        await metaBox.put(userId, {'orgId': orgId, 'role': role});
      } catch (e) {
        debugPrint('Error saving user meta to Hive: $e');
      }

      // Reload user data
      await _loadUserData();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error in createAccountAndJoin: $e');
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    try {
      _lastErrorMessage = null;
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      // Save login info to Hive
      final user = userCredential.user;
      final loginBox = Hive.box<UserLogin>('userLogin');
      if (user != null) {
        final login = UserLogin(
          userId: user.uid,
          email: user.email ?? '',
          name: user.displayName,
        );
        loginBox.put('current', login);
        await _loadUserData();
        notifyListeners();
      }
      return true;
    } on FirebaseAuthException catch (e) {
      // Provide more specific error messages
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email address.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled. Please contact support.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid email or password. Please check your credentials.';
          break;
        default:
          errorMessage = e.message ?? 'Authentication failed. Please try again.';
      }
      _lastErrorMessage = errorMessage;
      debugPrint('Error during sign in: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      String errorMessage = 'Unexpected error occurred';
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please try again.';
      }
      _lastErrorMessage = errorMessage;
      debugPrint('Error during sign in: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      // Remove login info from Hive
      final loginBox = Hive.box<UserLogin>('userLogin');
      loginBox.delete('current');
    } catch (e) {
      debugPrint('Error during sign out: $e');
    }
  }

  Future<void> switchOrganization(String orgId) async {
    // Cancel existing subscription before switching
    await _officerSubscription?.cancel();
    
    _currentOrgId = orgId;
    await _loadCurrentOfficerData();
    await _loadOrganization();
    
    // Save to Hive for persistence
    try {
      final metaBox = await Hive.openBox('userMeta');
      await metaBox.put(_firebaseUser!.uid, {
        'orgId': orgId,
        'role': _currentOfficer?.role.toString().split('.').last ?? 'member',
      });
    } catch (e) {
      debugPrint('Error saving organization switch to Hive: $e');
    }
    
    notifyListeners();
  }

  bool hasRole(OfficerRole role) {
    return _currentOfficer?.role == role;
  }

  bool isPresident() {
    return hasRole(OfficerRole.president);
  }

  bool isModerator() {
    return hasRole(OfficerRole.moderator);
  }

  bool canApproveRequests() {
    return isPresident() || isModerator();
  }

  bool canEditExpenses() {
    return _currentOfficer?.status == OfficerStatus.approved;
  }

  bool isPendingMembership() {
    return _currentOfficer?.status == OfficerStatus.pending;
  }

  bool isApprovedMember() {
    return _currentOfficer?.status == OfficerStatus.approved;
  }

  // Role-based permission checking methods
  bool isTreasurer() {
    return hasRole(OfficerRole.treasurer);
  }

  bool isSecretary() {
    return hasRole(OfficerRole.secretary);
  }

  bool isAuditor() {
    return hasRole(OfficerRole.auditor);
  }

  bool isMember() {
    return hasRole(OfficerRole.member);
  }

  bool hasManagementAccess() {
    return isPresident() || isModerator() || isTreasurer() || isSecretary() || isAuditor();
  }

  bool hasCollectionAccess() {
    // Only officers (Treasurer, Secretary, Auditor, President, Moderator) can manage collections
    return hasManagementAccess();
  }

  bool hasFullPrivileges() {
    return isPresident() || isModerator();
  }

  bool canAccessDrawerItem(String menuItem) {
    if (_currentOfficer == null) return false;
    return RolePermissions.canAccessDrawerItem(_currentOfficer!.role, menuItem);
  }

  bool canPerformAction(String action) {
    if (_currentOfficer == null) return false;
    return RolePermissions.canPerformAction(_currentOfficer!.role, action);
  }

  /// Public method to reload user data
  Future<void> reloadUserData() async {
    await _loadUserData();
  }

  /// Public method to reload organization data
  Future<void> reloadOrganizationData() async {
    await _loadOrganization();
  }

  /// Public method to reload current officer data
  Future<void> reloadCurrentOfficerData() async {
    await _loadCurrentOfficerData();
    notifyListeners();
  }

  @override
  void dispose() {
    _officerSubscription?.cancel();
    super.dispose();
  }
}
