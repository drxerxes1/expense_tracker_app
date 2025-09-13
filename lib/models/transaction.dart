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

  AppTransaction({
    required this.id,
    required this.orgId,
    required this.amount,
    required this.categoryId,
    required this.note,
    required this.addedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppTransaction(
      id: doc.id,
      orgId: (data['orgId'] ?? '').toString(),
      amount: (data['amount'] ?? 0).toDouble(),
      categoryId: (data['categoryId'] ?? '').toString(),
      note: (data['note'] ?? '').toString(),
      addedBy: (data['addedBy'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
    };
  }
}
