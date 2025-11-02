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
        'amount': amount,
        'transactionType': type,
        'categoryName': category.name,
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
    // Build query properly: when using orderBy with where on same field,
    // the where clauses should come first.
    Query query = _org(orgId);
    
    if (range != null) {
      // For "This Month" ranges (where start is the 1st of current month),
      // always use current time as end date to include new transactions.
      // For custom ranges with past end dates, use the specified end date.
      final now = DateTime.now();
      final isThisMonthRange = range.start.year == now.year &&
          range.start.month == now.month &&
          range.start.day == 1;
      
      final endDate = (isThisMonthRange && range.end.isBefore(now)) 
          ? now 
          : range.end;
      
      // Apply date range filters first, then orderBy
      query = query
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate),
          )
          .orderBy('createdAt', descending: true);
    } else {
      // If no range, just order by createdAt
      query = query.orderBy('createdAt', descending: true);
    }
    
    final categoriesRef = _categories(orgId);
    
    // Use snapshots() with includeMetadataChanges: false to get real-time updates
    // for actual document changes. This ensures new transactions appear immediately.
    return query.snapshots(includeMetadataChanges: false).asyncMap((snap) async {
      debugPrint('TransactionService.watchTransactions: Received snapshot with ${snap.docs.length} docs (from ${snap.metadata.isFromCache ? "cache" : "server"})');
      
      // Process all snapshots regardless of source to get real-time updates
      final txs = <AppTransaction>[];
      for (final d in snap.docs) {
        try {
          final tx = await AppTransaction.fromFirestoreAsync(d, categoriesRef);
          
          if (type != null) {
            final catSnap = await categoriesRef.doc(tx.categoryId).get();
            if (!catSnap.exists) continue;
            final category = CategoryModel.fromFirestore(catSnap);
            if (category.type != type) continue;
          }
          txs.add(tx);
        } catch (e) {
          debugPrint('TransactionService.watchTransactions: Error parsing transaction ${d.id}: $e');
          // Continue processing other transactions even if one fails
        }
      }
      debugPrint('TransactionService.watchTransactions: Parsed ${txs.length} transactions');
      return txs;
    });
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
    
    // Get current transaction data for comparison
    final currentDoc = await docRef.get();
    final currentData = currentDoc.data() as Map<String, dynamic>? ?? {};
    
    final data = Map<String, dynamic>.from(updates);
    data['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await docRef.update(data);

    // Write audit trail entry for edit with old/new values
    try {
      final auditRef = _db.collection('auditTrail').doc();
      
      // Get old and new category names
      String? oldCategoryName;
      String? newCategoryName;
      if (data['categoryId'] != null && data['categoryId'] != currentData['categoryId']) {
        // Get old category name
        if (currentData['categoryId'] != null) {
          final oldCat = await _categories(orgId).doc(currentData['categoryId']).get();
          final oldCatData = oldCat.data() as Map<String, dynamic>?;
          oldCategoryName = oldCatData?['name'] ?? currentData['categoryId'];
        }
        // Get new category name
        final newCat = await _categories(orgId).doc(data['categoryId']).get();
        final newCatData = newCat.data() as Map<String, dynamic>?;
        newCategoryName = newCatData?['name'] ?? data['categoryId'];
      } else if (currentData['categoryId'] != null) {
        // Category didn't change, use current category name
        final cat = await _categories(orgId).doc(currentData['categoryId']).get();
        final catData = cat.data() as Map<String, dynamic>?;
        oldCategoryName = newCategoryName = catData?['name'] ?? currentData['categoryId'];
      }
      
      await auditRef.set({
        'id': auditRef.id,
        'transactionId': txId,
        'orgId': orgId,
        'action': 'edited',
        'reason': data['reason'] ?? '',
        'by': data['updatedBy'] ?? '',
        'oldAmount': currentData['amount']?.toDouble(),
        'newAmount': data['amount']?.toDouble(),
        'oldTransactionType': currentData['type'],
        'newTransactionType': data['type'],
        'oldCategoryName': oldCategoryName,
        'newCategoryName': newCategoryName,
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
    
    // Get transaction data before deletion for audit trail
    final currentDoc = await docRef.get();
    final currentData = currentDoc.data() as Map<String, dynamic>? ?? {};
    
    // Get category name for audit trail
    String? categoryName;
    if (currentData['categoryId'] != null) {
      final cat = await _categories(orgId).doc(currentData['categoryId']).get();
      final catData = cat.data() as Map<String, dynamic>?;
      categoryName = catData?['name'] ?? currentData['categoryId'];
    }
    
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
        'amount': currentData['amount']?.toDouble(),
        'transactionType': currentData['type'],
        'categoryName': categoryName,
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
