import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseCategory {
  food,
  transportation,
  utilities,
  entertainment,
  healthcare,
  education,
  shopping,
  other;

  String get categoryDisplayName {
    switch (this) {
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.transportation:
        return 'Transportation';
      case ExpenseCategory.utilities:
        return 'Utilities';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
      case ExpenseCategory.healthcare:
        return 'Healthcare';
      case ExpenseCategory.education:
        return 'Education';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.other:
        return 'Other';
    }
  }
}

class Expense {
  final String id;
  final String orgId;
  final double amount;
  final ExpenseCategory category;
  final String note;
  final String addedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.orgId,
    required this.amount,
    required this.category,
    required this.note,
    required this.addedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? '',
      orgId: map['orgId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: ExpenseCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category'],
        orElse: () => ExpenseCategory.other,
      ),
      note: map['note'] ?? '',
      addedBy: map['addedBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orgId': orgId,
      'amount': amount,
      'category': category.toString().split('.').last,
      'note': note,
      'addedBy': addedBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Expense copyWith({
    String? id,
    String? orgId,
    double? amount,
    ExpenseCategory? category,
    String? note,
    String? addedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

}
