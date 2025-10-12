
import 'package:cloud_firestore/cloud_firestore.dart';

enum CategoryType {
  expense,
  fund;

  static CategoryType fromString(String value) {
    switch (value) {
      case 'expense':
        return CategoryType.expense;
      case 'fund':
        return CategoryType.fund;
      default:
        return CategoryType.expense;
    }
  }

  String toShortString() {
    return toString().split('.').last;
  }
}

class CategoryModel {
  final String id;
  final String name;
  final CategoryType type;
  final String icon; // Icon identifier (e.g., 'food', 'transport', etc.)
  final String color; // Hex color value (e.g., '#FF5722')
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CategoryModel(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      type: CategoryType.fromString((data['type'] ?? 'expense').toString()),
      icon: (data['icon'] ?? 'category').toString(),
      color: (data['color'] ?? '#6366F1').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toShortString(),
      'icon': icon,
      'color': color,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'name': name,
      'type': type.toShortString(),
      'icon': icon,
      'color': color,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    CategoryType? type,
    String? icon,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


