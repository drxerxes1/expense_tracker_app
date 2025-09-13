import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker_app/models/transaction.dart';

class TransactionService {
  final FirebaseFirestore _db;
  TransactionService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _org(String orgId) =>
      _db.collection('organizations').doc(orgId).collection('transactions');
  CollectionReference _categories(String orgId) =>
      _db.collection('organizations').doc(orgId).collection('categories');

  Stream<List<AppTransaction>> watchTransactions(
    String orgId, {
    DateTimeRange? range,
  }) {
    Query query = _org(orgId).orderBy('createdAt', descending: true);
    if (range != null) {
      query = query
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(range.end),
          );
    }
    return query.snapshots().map(
      (snap) => snap.docs.map((d) => AppTransaction.fromFirestore(d)).toList(),
    );
  }

  Future<double> getTotalBalance(String orgId, {DateTimeRange? range}) async {
    final querySnap = await _rangeQuery(orgId, range).get();
    double total = 0;
    for (final doc in querySnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['amount'] ?? 0).toDouble();
    }
    return total;
  }

  Future<Map<String, double>> getFundBreakdown(
    String orgId, {
    DateTimeRange? range,
  }) async {
    // Sum amounts by category type (fund vs expense categories interpreted by categories collection)
    final txSnap = await _rangeQuery(orgId, range).get();
    double clubFunds = 0;
    double schoolFunds = 0;
    // Optional: distinguish using category name: 'Club Fund', 'School Fund'
    for (final doc in txSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final categoryId = (data['categoryId'] ?? '').toString();
      if (categoryId.isEmpty) continue;
      final cat = await _categories(orgId).doc(categoryId).get();
      final catData = cat.data() as Map<String, dynamic>?;
      final name = (catData?['name'] ?? '').toString().toLowerCase();
      final amount = (data['amount'] ?? 0).toDouble();
      if (name.contains('club')) {
        clubFunds += amount;
      } else if (name.contains('school')) {
        schoolFunds += amount;
      }
    }
    return {'clubFunds': clubFunds, 'schoolFunds': schoolFunds};
  }

  Query _rangeQuery(String orgId, DateTimeRange? range) {
    Query q = _org(orgId);
    if (range != null) {
      q = q
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(range.end),
          );
    }
    return q;
  }
}
