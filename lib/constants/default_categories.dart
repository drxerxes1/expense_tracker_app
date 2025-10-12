import '../models/category.dart';

List<CategoryModel> defaultExpenseCategories = [
  CategoryModel(id: 'food', name: 'Food', type: CategoryType.expense),
  CategoryModel(id: 'transportation', name: 'Transportation', type: CategoryType.expense),
  CategoryModel(id: 'supplies', name: 'Supplies', type: CategoryType.expense),
  CategoryModel(id: 'utilities', name: 'Utilities', type: CategoryType.expense),
  CategoryModel(id: 'miscellaneous', name: 'Miscellaneous', type: CategoryType.expense),
];

List<CategoryModel> defaultFundCategories = [
  CategoryModel(id: 'school_funds', name: 'School Funds', type: CategoryType.fund),
  CategoryModel(id: 'club_funds', name: 'Club Funds', type: CategoryType.fund),
  // Additional default fund categories for the Fund tab
  CategoryModel(id: 'donation', name: 'Donation', type: CategoryType.fund),
  CategoryModel(id: 'event_income', name: 'Event Income', type: CategoryType.fund),
  CategoryModel(id: 'membership_fee', name: 'Membership Fee', type: CategoryType.fund),
  CategoryModel(id: 'grant', name: 'Grant', type: CategoryType.fund),
  CategoryModel(id: 'misc_income', name: 'Miscellaneous Income', type: CategoryType.fund),
];
