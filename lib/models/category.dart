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
}

class CategoryModel {
  final String id;
  final String name;
  final CategoryType type;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CategoryModel(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      type: CategoryType.fromString((data['type'] ?? 'expense').toString()),
    );
  }
}


