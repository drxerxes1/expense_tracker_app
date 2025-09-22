import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:org_wallet/models/transaction.dart';
import 'package:org_wallet/models/category.dart';

class TransactionService {
  // Create a transaction with category type validation
  Future<void> createTransaction({
    required String orgId,
    required double amount,
    required String categoryId,
    required String note,
    required String addedBy,
    required CategoryType expectedType,
  }) async {
    // Validate category type
    final catSnap = await _categories(orgId).doc(categoryId).get();
    if (!catSnap.exists) throw Exception('Category not found');
    final category = CategoryModel.fromFirestore(catSnap);
    if (category.type != expectedType) {
      throw Exception('Category type mismatch: expected ${expectedType.toShortString()}, got ${category.type.toShortString()}');
    }
    final txDoc = _org(orgId).doc();
    await txDoc.set({
      'id': txDoc.id,
      'orgId': orgId,
      'amount': amount,
      'categoryId': categoryId,
      'note': note,
      'addedBy': addedBy,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    // TODO: Add audit trail logic here
  }
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
    CategoryType? type,
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
    if (type != null) {
      // Join with categories to filter by type
      // This requires client-side filtering since Firestore doesn't support joins
      return query.snapshots().asyncMap((snap) async {
        final txs = snap.docs.map((d) => AppTransaction.fromFirestore(d)).toList();
        final filtered = <AppTransaction>[];
        for (final tx in txs) {
          final catSnap = await _categories(orgId).doc(tx.categoryId).get();
          if (!catSnap.exists) continue;
          final category = CategoryModel.fromFirestore(catSnap);
          if (category.type == type) filtered.add(tx);
        }
        return filtered;
      });
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

  // Get total for a specific type (expense or fund)
  Future<double> getTotalByType(String orgId, CategoryType type, {DateTimeRange? range}) async {
    final querySnap = await _rangeQuery(orgId, range).get();
    double total = 0;
    for (final doc in querySnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final categoryId = (data['categoryId'] ?? '').toString();
      if (categoryId.isEmpty) continue;
      final catSnap = await _categories(orgId).doc(categoryId).get();
      if (!catSnap.exists) continue;
      final category = CategoryModel.fromFirestore(catSnap);
      if (category.type == type) {
        total += (data['amount'] ?? 0).toDouble();
      }
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
