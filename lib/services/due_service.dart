import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/models/due.dart';

class DueService {
  final FirebaseFirestore _db;
  DueService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _duesRef(String orgId) =>
      _db.collection('organizations').doc(orgId).collection('dues');

  Stream<List<DueModel>> watchDues(String orgId) {
    return _duesRef(orgId).orderBy('dueDate').snapshots().map((snap) {
      return snap.docs.map((d) => DueModel.fromFirestore(d)).toList();
    });
  }

  Future<List<DueModel>> getAll(String orgId) async {
    final snap = await _duesRef(orgId).orderBy('dueDate').get();
    return snap.docs.map((d) => DueModel.fromFirestore(d)).toList();
  }

  Future<void> createDue(DueModel due) async {
    final docRef = _duesRef(due.orgId).doc();
    final data = Map<String, dynamic>.from(due.toMap());
    // ensure id is stored
    data['id'] = docRef.id;
    await docRef.set(data);
  }

  Future<void> updateDue(String orgId, String dueId, Map<String, dynamic> updates) async {
    final docRef = _duesRef(orgId).doc(dueId);
    updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await docRef.update(updates);
  }

  Future<void> deleteDue(String orgId, String dueId) async {
    await _duesRef(orgId).doc(dueId).delete();
  }
}
