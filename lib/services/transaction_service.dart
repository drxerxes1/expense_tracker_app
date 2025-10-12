import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:org_wallet/models/transaction.dart';
import 'package:org_wallet/models/category.dart';

class TransactionService {
  // Create a transaction with category type validation
  Future<String> createTransaction({
    required String orgId,
    required double amount,
    required String categoryId,
    required String note,
    required String addedBy,
    required CategoryType expectedType,
    required String type, // 'expense' or 'fund'
    String? fundId,
    DateTime? date,
  }) async {
    // Validate category type
    final catSnap = await _categories(orgId).doc(categoryId).get();
    CategoryModel category;
    if (!catSnap.exists) {
      // Allow creating transactions for categories that exist only locally (defaults).
      // Fall back to the expectedType provided by the caller instead of failing.
      category = CategoryModel(
        id: categoryId, 
        name: categoryId, 
        type: expectedType,
        icon: 'category',
        color: '#6366F1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } else {
      category = CategoryModel.fromFirestore(catSnap);
      if (category.type != expectedType) {
        throw Exception('Category type mismatch: expected ${expectedType.toShortString()}, got ${category.type.toShortString()}');
      }
    }
    final txDoc = _org(orgId).doc();
    await txDoc.set({
      'id': txDoc.id,
      'orgId': orgId,
      'amount': amount,
      'categoryId': categoryId,
      'note': note,
      'addedBy': addedBy,
      'type': type,
      'fundId': fundId ?? '',
      'createdAt': Timestamp.fromDate(date ?? DateTime.now()),
      'updatedAt': Timestamp.fromDate(date ?? DateTime.now()),
    });

    // Write audit trail entry for creation
    try {
      final auditRef = _db.collection('auditTrail').doc();
      await auditRef.set({
        'id': auditRef.id,
        'transactionId': txDoc.id,
        'orgId': orgId, // Add organization ID for efficient querying
        'action': 'created',
        'reason': '',
        'by': addedBy,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Failed to write audit trail for creation: $e');
    }

    return txDoc.id;
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
    final categoriesRef = _categories(orgId);
    // Important: do an initial server-only fetch to avoid showing stale/cache-first
    // data (for example when local auditTrail/transactions were deleted in the
    // backend). Emit the server snapshot first, then continue with realtime
    // snapshots so the UI quickly reflects the authoritative server state.
    final controller = StreamController<List<AppTransaction>>();

    () async {
      try {
        final serverSnap = await query.get(const GetOptions(source: Source.server));
        final serverTxs = <AppTransaction>[];
        for (final d in serverSnap.docs) {
          final tx = await AppTransaction.fromFirestoreAsync(d, categoriesRef);
          if (type != null) {
            final catSnap = await categoriesRef.doc(tx.categoryId).get();
            if (!catSnap.exists) continue;
            final category = CategoryModel.fromFirestore(catSnap);
            if (category.type != type) continue;
          }
          serverTxs.add(tx);
        }
        controller.add(serverTxs);
      } catch (e) {
        // If server fetch fails (offline), ignore — realtime snapshots will still
        // provide cached data.
        debugPrint('TransactionService.watchTransactions server fetch error: $e');
      }
    }();

    final sub = query.snapshots().asyncMap((snap) async {
      final txs = <AppTransaction>[];
      for (final d in snap.docs) {
        final tx = await AppTransaction.fromFirestoreAsync(d, categoriesRef);
        if (type != null) {
          final catSnap = await categoriesRef.doc(tx.categoryId).get();
          if (!catSnap.exists) continue;
          final category = CategoryModel.fromFirestore(catSnap);
          if (category.type != type) continue;
        }
        txs.add(tx);
      }
      return txs;
    }).listen((txs) {
      controller.add(txs);
    }, onError: (e, s) {
      controller.addError(e, s);
    });

    controller.onCancel = () {
      sub.cancel();
    };

    return controller.stream;
  }


  Future<List<AppTransaction>> getAllTransactions(String orgId, {DateTimeRange? range}) async {
    final querySnap = await _rangeQuery(orgId, range).get();
    final categoriesRef = _categories(orgId);
    final txs = <AppTransaction>[];
    for (final doc in querySnap.docs) {
      final tx = await AppTransaction.fromFirestoreAsync(doc, categoriesRef);
      txs.add(tx);
    }
    return txs;
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

  /// Update an existing transaction document.
  Future<void> updateTransaction(String orgId, String txId, Map<String, dynamic> updates) async {
    final docRef = _org(orgId).doc(txId);
    final data = Map<String, dynamic>.from(updates);
    data['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await docRef.update(data);

    // Write audit trail entry for edit
    try {
      final auditRef = _db.collection('auditTrail').doc();
      await auditRef.set({
        'id': auditRef.id,
        'transactionId': txId,
        'orgId': orgId, // Add organization ID for efficient querying
        'action': 'edited',
        'reason': data['reason'] ?? '',
        'by': data['updatedBy'] ?? '',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Failed to write audit trail for update: $e');
    }
  }

  /// Delete a transaction and write an audit trail entry.
  Future<void> deleteTransaction(String orgId, String txId, {String? by}) async {
    final docRef = _org(orgId).doc(txId);
    await docRef.delete();
    try {
      final auditRef = _db.collection('auditTrail').doc();
      await auditRef.set({
        'id': auditRef.id,
        'transactionId': txId,
        'orgId': orgId, // Add organization ID for efficient querying
        'action': 'deleted',
        'reason': '',
        'by': by ?? '',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Failed to write audit trail for delete: $e');
    }
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
