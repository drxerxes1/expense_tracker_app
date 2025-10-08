import 'package:cloud_firestore/cloud_firestore.dart';

class DueModel {
  final String id;
  final String orgId;
  final String name;
  final double amount;
  final String frequency;
  final DateTime dueDate;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DueModel({
    required this.id,
    required this.orgId,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.dueDate,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory DueModel.fromFirestore(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    return DueModel(
      id: snap.id,
      orgId: data['orgId'] ?? '',
      name: data['name'] ?? '',
      amount: (data['amount'] is int) ? (data['amount'] as int).toDouble() : (data['amount'] ?? 0.0),
      frequency: data['frequency'] ?? '',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'orgId': orgId,
        'name': name,
        'amount': amount,
        'frequency': frequency,
        'dueDate': Timestamp.fromDate(dueDate),
        'createdBy': createdBy,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };
}
