// DuesService: CRUD helpers for dues and due_payments
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/models/due.dart';
import 'package:org_wallet/models/due_payment.dart';

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

  // Payments CRUD
  // NOTE: to enforce uniqueness (dueId, userId) use the payment document ID as the userId.
  Future<DuePaymentModel> createDuePayment({
    required String orgId,
    required DuePaymentModel payment,
  }) async {
    final docRef = _duePayments(orgId, payment.dueId).doc(payment.id);
    await docRef.set(payment.toMap());
    final snap = await docRef.get();
    return DuePaymentModel.fromFirestore(snap);
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
}
