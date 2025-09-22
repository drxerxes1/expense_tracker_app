import 'package:hive/hive.dart';
import 'package:org_wallet/models/user_login.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/models/user.dart' as app_user;
import 'package:org_wallet/models/organization.dart';
import 'package:org_wallet/models/officer.dart';

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

        // Load current officer data if user has organizations
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

    try {
      final officerDoc = await _firestore
          .collection('officers')
          .where('orgId', isEqualTo: _currentOrgId)
          .where('userId', isEqualTo: _firebaseUser!.uid)
          .get();

      if (officerDoc.docs.isNotEmpty) {
        _currentOfficer = Officer.fromMap({
          'id': officerDoc.docs.first.id,
          ...officerDoc.docs.first.data(),
        });
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
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _lastErrorMessage = e.message ?? 'Authentication error';
      debugPrint('Error during sign in: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      _lastErrorMessage = 'Unexpected error occurred';
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
    _currentOrgId = orgId;
    await _loadCurrentOfficerData();
  await _loadOrganization();
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
}
