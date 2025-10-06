import 'package:cloud_firestore/cloud_firestore.dart';

class AppTransaction {
  final String id;
  final String orgId;
  final double amount;
  final String categoryId;
  final String note;
  final String addedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String type;
  final String categoryName;
  final String fundId;

  AppTransaction({
    required this.id,
    required this.orgId,
    required this.amount,
    required this.categoryId,
    required this.note,
    required this.addedBy,
    required this.createdAt,
    required this.updatedAt,
    required this.type,
    required this.categoryName,
    required this.fundId,
  });

  static Future<AppTransaction> fromFirestoreAsync(
    DocumentSnapshot doc,
    CollectionReference categoriesRef,
  ) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    String type = (data['type'] ?? 'expense').toString();
    String categoryId = (data['categoryId'] ?? '').toString();
    String categoryName = '';
    if (categoryId.isNotEmpty) {
      final catSnap = await categoriesRef.doc(categoryId).get();
      if (catSnap.exists) {
        final catData = catSnap.data() as Map<String, dynamic>?;
        categoryName = (catData?['name'] ?? '').toString();
      }
    }
    if (categoryName.isEmpty) {
      // fallback to default names
      if (categoryId == 'food') {
        categoryName = 'Food';
      } else if (categoryId == 'transportation') {
        categoryName = 'Transportation';
      } else if (categoryId == 'supplies') {
        categoryName = 'Supplies';
      } else if (categoryId == 'utilities') {
        categoryName = 'Utilities';
      } else if (categoryId == 'miscellaneous') {
        categoryName = 'Miscellaneous';
      } else if (categoryId == 'school_funds') {
        categoryName = 'School Funds';
      } else if (categoryId == 'club_funds') {
        categoryName = 'Club Funds';
      } else {
        categoryName = 'Unknown';
      }
    }
    final fundId = (data['fundId'] ?? '').toString();
    return AppTransaction(
      id: doc.id,
      orgId: (data['orgId'] ?? '').toString(),
      amount: (data['amount'] ?? 0).toDouble(),
      categoryId: categoryId,
      note: (data['note'] ?? '').toString(),
      addedBy: (data['addedBy'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: type,
      categoryName: categoryName,
      fundId: fundId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'amount': amount,
      'categoryId': categoryId,
      'note': note,
      'addedBy': addedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'type': type,
      'categoryName': categoryName,
      'fundId': fundId,
    };
  }
}
