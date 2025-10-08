import 'package:cloud_firestore/cloud_firestore.dart';

class DuePaymentModel {
  final String id; // payment doc id (recommended == userId)
  final String dueId;
  final String userId;
  final String transactionId;
  final double amount;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DuePaymentModel({
    required this.id,
    required this.dueId,
    required this.userId,
    required this.transactionId,
    required this.amount,
    this.paidAt,
    this.createdAt,
    this.updatedAt,
  });

  factory DuePaymentModel.fromFirestore(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    return DuePaymentModel(
      id: snap.id,
      dueId: data['dueId'] ?? '',
      userId: data['userId'] ?? '',
      transactionId: data['transactionId'] ?? '',
      amount: (data['amount'] is int) ? (data['amount'] as int).toDouble() : (data['amount'] ?? 0.0),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'dueId': dueId,
        'userId': userId,
        'transactionId': transactionId,
        'amount': amount,
        if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };
}
