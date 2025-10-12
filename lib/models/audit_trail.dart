import 'package:cloud_firestore/cloud_firestore.dart';

enum AuditAction { 
  created, 
  edited, 
  deleted, 
  approved, 
  denied;

  String get actionDisplayName {
    switch (this) {
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

class AuditTrail {
  final String id;
  final String transactionId; // Changed from expenseId to be more generic
  final AuditAction action;
  final String reason;
  final String by;
  final DateTime createdAt;
  final DateTime updatedAt;

  AuditTrail({
    required this.id,
    required this.transactionId,
    required this.action,
    required this.reason,
    required this.by,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AuditTrail.fromMap(Map<String, dynamic> map) {
    return AuditTrail(
      id: map['id'] ?? '',
      transactionId: map['transactionId'] ?? map['expenseId'] ?? '', // Support both field names for backward compatibility
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
      'transactionId': transactionId,
      'action': action.toString().split('.').last,
      'reason': reason,
      'by': by,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  AuditTrail copyWith({
    String? id,
    String? transactionId,
    AuditAction? action,
    String? reason,
    String? by,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AuditTrail(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      action: action ?? this.action,
      reason: reason ?? this.reason,
      by: by ?? this.by,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

}
