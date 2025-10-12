import '../models/category.dart';

List<CategoryModel> defaultExpenseCategories = [
  CategoryModel(id: 'food', name: 'Food', type: CategoryType.expense),
  CategoryModel(id: 'transportation', name: 'Transportation', type: CategoryType.expense),
  CategoryModel(id: 'supplies', name: 'Supplies', type: CategoryType.expense),
  CategoryModel(id: 'utilities', name: 'Utilities', type: CategoryType.expense),
  CategoryModel(id: 'miscellaneous', name: 'Miscellaneous', type: CategoryType.expense),
];

// Separate defaults: fund accounts (buckets) vs fund categories
List<CategoryModel> defaultFundAccounts = [
  CategoryModel(id: 'school_funds', name: 'School Funds', type: CategoryType.fund),
  CategoryModel(id: 'club_funds', name: 'Club Funds', type: CategoryType.fund),
];

// Default fund categories shown in the Fund tab's Category dropdown
List<CategoryModel> defaultFundCategories = [
  CategoryModel(id: 'donation', name: 'Donation', type: CategoryType.fund),
  CategoryModel(id: 'event_income', name: 'Event Income', type: CategoryType.fund),
  CategoryModel(id: 'membership_fee', name: 'Membership Fee', type: CategoryType.fund),
  CategoryModel(id: 'grant', name: 'Grant', type: CategoryType.fund),
  CategoryModel(id: 'misc_income', name: 'Miscellaneous Income', type: CategoryType.fund),
];
