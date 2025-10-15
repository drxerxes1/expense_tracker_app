import 'package:cloud_firestore/cloud_firestore.dart';

enum AuditAction { 
  created, 
  edited, 
  deleted, 
  approved,
  denied,
  roleChanged,
  memberApproved,
  memberDenied,
  memberRemoved,
  memberRoleChanged;

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
      case AuditAction.roleChanged:
        return 'Role Changed';
      case AuditAction.memberApproved:
        return 'Member Approved';
      case AuditAction.memberDenied:
        return 'Member Denied';
      case AuditAction.memberRemoved:
        return 'Member Removed';
      case AuditAction.memberRoleChanged:
        return 'Member Role Changed';
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
  
  // Amount tracking fields
  final double? amount;
  final double? oldAmount;
  final double? newAmount;
  
  // Transaction type and category tracking
  final String? transactionType; // 'expense' or 'fund'
  final String? oldTransactionType;
  final String? newTransactionType;
  final String? categoryName;
  final String? oldCategoryName;
  final String? newCategoryName;
  
  // Member management tracking
  final String? logType; // 'transaction' or 'member_action'
  final String? memberId;
  final String? memberName;
  final String? memberEmail;
  final String? oldRole;
  final String? newRole;

  AuditTrail({
    required this.id,
    required this.transactionId,
    required this.action,
    required this.reason,
    required this.by,
    required this.createdAt,
    required this.updatedAt,
    this.amount,
    this.oldAmount,
    this.newAmount,
    this.transactionType,
    this.oldTransactionType,
    this.newTransactionType,
    this.categoryName,
    this.oldCategoryName,
    this.newCategoryName,
    this.logType,
    this.memberId,
    this.memberName,
    this.memberEmail,
    this.oldRole,
    this.newRole,
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
      amount: map['amount']?.toDouble(),
      oldAmount: map['oldAmount']?.toDouble(),
      newAmount: map['newAmount']?.toDouble(),
      transactionType: map['transactionType'],
      oldTransactionType: map['oldTransactionType'],
      newTransactionType: map['newTransactionType'],
      categoryName: map['categoryName'],
      oldCategoryName: map['oldCategoryName'],
      newCategoryName: map['newCategoryName'],
      logType: map['logType'],
      memberId: map['memberId'],
      memberName: map['memberName'],
      memberEmail: map['memberEmail'],
      oldRole: map['oldRole'],
      newRole: map['newRole'],
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
      'amount': amount,
      'oldAmount': oldAmount,
      'newAmount': newAmount,
      'transactionType': transactionType,
      'oldTransactionType': oldTransactionType,
      'newTransactionType': newTransactionType,
      'categoryName': categoryName,
      'oldCategoryName': oldCategoryName,
      'newCategoryName': newCategoryName,
      'logType': logType,
      'memberId': memberId,
      'memberName': memberName,
      'memberEmail': memberEmail,
      'oldRole': oldRole,
      'newRole': newRole,
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
    double? amount,
    double? oldAmount,
    double? newAmount,
    String? transactionType,
    String? oldTransactionType,
    String? newTransactionType,
    String? categoryName,
    String? oldCategoryName,
    String? newCategoryName,
    String? logType,
    String? memberId,
    String? memberName,
    String? memberEmail,
    String? oldRole,
    String? newRole,
  }) {
    return AuditTrail(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      action: action ?? this.action,
      reason: reason ?? this.reason,
      by: by ?? this.by,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      amount: amount ?? this.amount,
      oldAmount: oldAmount ?? this.oldAmount,
      newAmount: newAmount ?? this.newAmount,
      transactionType: transactionType ?? this.transactionType,
      oldTransactionType: oldTransactionType ?? this.oldTransactionType,
      newTransactionType: newTransactionType ?? this.newTransactionType,
      categoryName: categoryName ?? this.categoryName,
      oldCategoryName: oldCategoryName ?? this.oldCategoryName,
      newCategoryName: newCategoryName ?? this.newCategoryName,
      logType: logType ?? this.logType,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      memberEmail: memberEmail ?? this.memberEmail,
      oldRole: oldRole ?? this.oldRole,
      newRole: newRole ?? this.newRole,
    );
  }

}
