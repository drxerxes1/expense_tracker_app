import 'package:cloud_firestore/cloud_firestore.dart';


class DueModel {
  final String id;
  final String orgId;
  final String name;
  final double amount;
  final String frequency;
  final DateTime dueDate; // Kept for backward compatibility, represents startDate
  final DateTime? startDate; // New field
  final DateTime? endDate; // New field
  final int totalDuesCount; // New field: computed based on frequency and date range
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
    this.startDate,
    this.endDate,
    this.totalDuesCount = 1,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Named constructor for creating a new Due (no id, no timestamps)
  factory DueModel.create({
    required String orgId,
    required String name,
    required double amount,
    required String frequency,
    required DateTime dueDate,
    DateTime? startDate,
    DateTime? endDate,
    int totalDuesCount = 1,
    required String createdBy,
  }) {
    return DueModel(
      id: '',
      orgId: orgId,
      name: name,
      amount: amount,
      frequency: frequency,
      dueDate: dueDate,
      startDate: startDate,
      endDate: endDate,
      totalDuesCount: totalDuesCount,
      createdBy: createdBy,
      createdAt: null,
      updatedAt: null,
    );
  }

  factory DueModel.fromFirestore(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    return DueModel(
      id: snap.id,
      orgId: data['orgId'] ?? '',
      name: data['name'] ?? '',
      amount: (data['amount'] is int) ? (data['amount'] as int).toDouble() : (data['amount'] ?? 0.0),
      frequency: data['frequency'] ?? '',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      totalDuesCount: (data['totalDuesCount'] is int) ? data['totalDuesCount'] : 1,
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
        if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
        if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
        'totalDuesCount': totalDuesCount,
        'createdBy': createdBy,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };
}
