import 'package:cloud_firestore/cloud_firestore.dart';

enum AuditAction { created, edited, deleted, approved, denied }

class AuditTrail {
  final String id;
  final String expenseId;
  final AuditAction action;
  final String reason;
  final String by;
  final DateTime createdAt;
  final DateTime updatedAt;

  AuditTrail({
    required this.id,
    required this.expenseId,
    required this.action,
    required this.reason,
    required this.by,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AuditTrail.fromMap(Map<String, dynamic> map) {
    return AuditTrail(
      id: map['id'] ?? '',
      expenseId: map['expenseId'] ?? '',
      action: AuditAction.values.firstWhere(
        (e) => e.toString().split('.').last == map['action'],
        orElse: () => AuditAction.created,
      ),
      reason: map['reason'] ?? '',
      by: map['by'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expenseId': expenseId,
      'action': action.toString().split('.').last,
      'reason': reason,
      'by': by,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  AuditTrail copyWith({
    String? id,
    String? expenseId,
    AuditAction? action,
    String? reason,
    String? by,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AuditTrail(
      id: id ?? this.id,
      expenseId: expenseId ?? this.expenseId,
      action: action ?? this.action,
      reason: reason ?? this.reason,
      by: by ?? this.by,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get actionDisplayName {
    switch (action) {
      case AuditAction.created:
        return 'Created';
      case AuditAction.edited:
        return 'Edited';
      case AuditAction.deleted:
        return 'Deleted';
      case AuditAction.approved:
        return 'Approved';
      case AuditAction.denied:
        return 'Denied';
    }
  }
}
