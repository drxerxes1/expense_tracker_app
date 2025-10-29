// DuesService: CRUD helpers for dues and due_payments
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/models/due.dart';
import 'package:org_wallet/models/due_payment.dart';
import 'package:org_wallet/models/officer.dart';

class DuesService {
  final FirebaseFirestore _db;

  DuesService([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  // Path helpers
  CollectionReference _orgDues(String orgId) => _db.collection('organizations').doc(orgId).collection('dues');
  DocumentReference _dueDoc(String orgId, String dueId) => _orgDues(orgId).doc(dueId);
  CollectionReference _duePayments(String orgId, String dueId) => _dueDoc(orgId, dueId).collection('due_payments');

  // Create a due and return the new document id
  /// Accepts a partial DueModel (id can be empty, timestamps null)
  Future<DueModel> createDue({required DueModel due}) async {
    final docRef = _orgDues(due.orgId).doc();
    // Use toMap, but don't include id (Firestore will assign doc id)
    await docRef.set({
      'orgId': due.orgId,
      'name': due.name,
      'amount': due.amount,
      'frequency': due.frequency,
      'dueDate': Timestamp.fromDate(due.dueDate),
      'createdBy': due.createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final snap = await docRef.get();
    return DueModel.fromFirestore(snap);
  }

  Future<DueModel> updateDue({required DueModel due}) async {
    final updates = <String, dynamic>{
      'name': due.name,
      'amount': due.amount,
      'frequency': due.frequency,
      'dueDate': Timestamp.fromDate(due.dueDate),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _dueDoc(due.orgId, due.id).update(updates);
    final snap = await _dueDoc(due.orgId, due.id).get();
    return DueModel.fromFirestore(snap);
  }

  Future<void> deleteDue({required String orgId, required String dueId}) async {
    // Delete the due and its subcollection documents (client-side cascading)
    final payments = await _duePayments(orgId, dueId).get();
    final batch = _db.batch();
    for (final p in payments.docs) {
      batch.delete(p.reference);
    }
    batch.delete(_dueDoc(orgId, dueId));
    await batch.commit();
  }

  // Enhanced payment creation with transaction linking
  Future<DuePaymentModel> createDuePaymentWithTransaction({
    required String orgId,
    required DuePaymentModel payment,
    String? transactionId,
  }) async {
    final docRef = _duePayments(orgId, payment.dueId).doc(payment.id);
    
    // Update payment with transaction ID if provided
    final paymentData = payment.toMap();
    if (transactionId != null && transactionId.isNotEmpty) {
      paymentData['transactionId'] = transactionId;
    }
    
    // Use a transaction to ensure we don't create duplicate payments for the same user+due
    return await _db.runTransaction<DuePaymentModel>((tx) async {
      final existing = await tx.get(docRef);
      if (existing.exists) {
        // Update existing payment with transaction ID if provided
        if (transactionId != null && transactionId.isNotEmpty) {
          tx.update(docRef, {'transactionId': transactionId, 'updatedAt': FieldValue.serverTimestamp()});
        }
        return DuePaymentModel.fromFirestore(existing);
      }
      tx.set(docRef, paymentData);
      final created = await tx.get(docRef);
      return DuePaymentModel.fromFirestore(created);
    });
  }

  // Create payment with auto-generated ID (fallback method)
  Future<DuePaymentModel> createDuePaymentWithAutoId({
    required String orgId,
    required String dueId,
    required String userId,
    required double amount,
    String? transactionId,
  }) async {
    final paymentsColl = _duePayments(orgId, dueId);
    final now = DateTime.now();
    
    final paymentData = {
      'dueId': dueId,
      'userId': userId,
      'transactionId': transactionId ?? '',
      'amount': amount,
      'paidAt': Timestamp.fromDate(now),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };
    
    final docRef = await paymentsColl.add(paymentData);
    final created = await docRef.get();
    return DuePaymentModel.fromFirestore(created);
  }

  Future<DuePaymentModel> updateDuePayment({
    required String orgId,
    required DuePaymentModel payment,
  }) async {
    final updates = <String, dynamic>{
      'transactionId': payment.transactionId,
      'amount': payment.amount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (payment.paidAt != null) updates['paidAt'] = Timestamp.fromDate(payment.paidAt!);
    await _duePayments(orgId, payment.dueId).doc(payment.id).update(updates);
    final snap = await _duePayments(orgId, payment.dueId).doc(payment.id).get();
    return DuePaymentModel.fromFirestore(snap);
  }

  Future<void> deleteDuePayment({required String orgId, required String dueId, required String paymentId}) async {
    await _duePayments(orgId, dueId).doc(paymentId).delete();
  }

  // Utility: get all due payments for a due
  Future<List<DuePaymentModel>> listDuePayments(String orgId, String dueId) async {
    final snap = await _duePayments(orgId, dueId).get();
    return snap.docs.map((d) => DuePaymentModel.fromFirestore(d)).toList();
  }

  // Stream methods for real-time updates
  Stream<List<DueModel>> watchDues(String orgId) {
    return _orgDues(orgId).orderBy('dueDate').snapshots().map((snap) {
      return snap.docs.map((d) => DueModel.fromFirestore(d)).toList();
    });
  }

  Future<List<DueModel>> getAllDues(String orgId) async {
    final snap = await _orgDues(orgId).orderBy('dueDate').get();
    return snap.docs.map((d) => DueModel.fromFirestore(d)).toList();
  }

  // Enhanced create method that handles ID assignment properly
  Future<DueModel> createDueWithId({required DueModel due}) async {
    final docRef = _orgDues(due.orgId).doc();
    final data = Map<String, dynamic>.from(due.toMap());
    data['id'] = docRef.id;
    await docRef.set(data);
    final snap = await docRef.get();
    return DueModel.fromFirestore(snap);
  }

  // Enhanced update method
  Future<DueModel> updateDueWithMap({required String orgId, required String dueId, required Map<String, dynamic> updates}) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _dueDoc(orgId, dueId).update(updates);
    final snap = await _dueDoc(orgId, dueId).get();
    return DueModel.fromFirestore(snap);
  }

  // Create payment placeholders for all organization members (excluding moderators)
  Future<void> createPaymentPlaceholders(String orgId, String dueId, double amount) async {
    // Get organization members from officers collection
    final officersSnap = await _db
        .collection('officers')
        .where('orgId', isEqualTo: orgId)
        .get();
    final batch = _db.batch();
    
    for (final officerDoc in officersSnap.docs) {
      final officerData = officerDoc.data();
      final status = officerData['status'];
      final role = officerData['role'];
      
      // Check if member is approved
      final isApproved = (status is String && status == 'approved') ||
          (status is int && status == OfficerStatus.approved.index);
      
      // Exclude moderators
      final roleString = role is String ? role.toLowerCase() : (role is int 
          ? OfficerRole.values[role].toString().split('.').last 
          : '');
      final isModerator = roleString == 'moderator';
      
      if (!isApproved || isModerator) continue;
      
      final uid = officerData['userId']?.toString() ?? '';
      if (uid.isEmpty) continue;
      
      final paymentRef = _duePayments(orgId, dueId).doc(uid);
      
      // Check if payment already exists
      final existing = await paymentRef.get();
      if (!existing.exists) {
        batch.set(paymentRef, {
          'id': uid,
          'dueId': dueId,
          'userId': uid,
          'transactionId': '',
          'amount': amount,
          'paidAt': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    
    await batch.commit();
  }

  // Get payment summary for a due (calculated client-side, excluding moderators)
  Future<Map<String, dynamic>> getDueSummary(String orgId, String dueId) async {
    // Fetch the due to determine current period window
    final dueSnap = await _dueDoc(orgId, dueId).get();
    final due = DueModel.fromFirestore(dueSnap);

    // Count approved members for the organization (excluding moderators)
    final officersSnap = await _db
        .collection('officers')
        .where('orgId', isEqualTo: orgId)
        .get();
    int totalMembers = 0;
    final approvedUserIds = <String>{};
    for (final o in officersSnap.docs) {
      final m = o.data();
      final status = m['status'];
      final role = m['role'];
      
      final isApproved = (status is String && status == 'approved') ||
          (status is int && status == 1); // OfficerStatus.approved.index == 1
      
      // Exclude moderators
      final roleString = role is String ? role.toLowerCase() : (role is int 
          ? OfficerRole.values[role].toString().split('.').last 
          : '');
      final isModerator = roleString == 'moderator';
      
      if (isApproved && !isModerator) {
        totalMembers += 1;
        final uid = (m['userId'] ?? '').toString();
        if (uid.isNotEmpty) approvedUserIds.add(uid);
      }
    }

    // Read payments for this due and compute current-period paid users
    final paymentsSnap = await _duePayments(orgId, dueId).get();
    final paidUserIds = <String>{};
    double totalCollected = 0.0;
    for (final p in paymentsSnap.docs) {
      final payment = DuePaymentModel.fromFirestore(p);
      final paidAt = payment.paidAt ?? payment.createdAt;
      if (paidAt == null) continue;
      if (_isPaymentInCurrentPeriod(paidAt, due)) {
        paidUserIds.add(payment.userId);
        totalCollected += payment.amount;
      }
    }

    // Only count approved members in paid/unpaid
    final approvedPaid = paidUserIds.where((id) => approvedUserIds.contains(id)).toSet();
    final paidCount = approvedPaid.length;
    final unpaidCount = (totalMembers - paidCount).clamp(0, totalMembers);

    return {
      'totalCollected': totalCollected,
      'paidCount': paidCount,
      'unpaidCount': unpaidCount,
      'totalMembers': totalMembers,
      'lastUpdated': DateTime.now(),
    };
  }
  
  bool _isPaymentInCurrentPeriod(DateTime paidAt, DueModel due) {
    final freq = due.frequency.toLowerCase();
    final now = DateTime.now();
    if (freq == 'weekly') {
      final start = _startOfWeek(now);
      final end = start.add(const Duration(days: 7));
      return !paidAt.isBefore(start) && paidAt.isBefore(end);
    }
    if (freq == 'monthly') {
      return paidAt.year == now.year && paidAt.month == now.month;
    }
    if (freq == 'quarterly') {
      final qNow = _getQuarter(now);
      final qPaid = _getQuarter(paidAt);
      return paidAt.year == now.year && qNow == qPaid;
    }
    if (freq == 'yearly') {
      return paidAt.year == now.year;
    }
    return paidAt.year == now.year && paidAt.month == now.month;
  }
  
  int _getQuarter(DateTime d) => ((d.month - 1) / 3).floor() + 1;
  DateTime _startOfWeek(DateTime d) {
    final weekday = d.weekday; // Monday=1
    final start = DateTime(d.year, d.month, d.day).subtract(Duration(days: weekday - 1));
    return DateTime(start.year, start.month, start.day);
  }
}
