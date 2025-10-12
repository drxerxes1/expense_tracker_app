import '../models/category.dart';

// Default expense categories with icons and colors
List<CategoryModel> defaultExpenseCategories = [
  CategoryModel(
    id: 'food',
    name: 'Food',
    type: CategoryType.expense,
    icon: 'food',
    color: '#EF4444',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  CategoryModel(
    id: 'transportation',
    name: 'Transportation',
    type: CategoryType.expense,
    icon: 'transport',
    color: '#3B82F6',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  CategoryModel(
    id: 'supplies',
    name: 'Supplies',
    type: CategoryType.expense,
    icon: 'shopping',
    color: '#10B981',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  CategoryModel(
    id: 'utilities',
    name: 'Utilities',
    type: CategoryType.expense,
    icon: 'utilities',
    color: '#F97316',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  CategoryModel(
    id: 'miscellaneous',
    name: 'Miscellaneous',
    type: CategoryType.expense,
    icon: 'miscellaneous',
    color: '#8B5CF6',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
];

// Default fund account buckets (for fund management)
List<CategoryModel> defaultFundAccounts = [
  CategoryModel(
    id: 'school_funds',
    name: 'School Funds',
    type: CategoryType.fund,
    icon: 'education',
    color: '#06B6D4',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  CategoryModel(
    id: 'club_funds',
    name: 'Club Funds',
    type: CategoryType.fund,
    icon: 'sports',
    color: '#22C55E',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
];

// Default fund categories (for income sources)
List<CategoryModel> defaultFundCategories = [
  CategoryModel(
    id: 'donation',
    name: 'Donation',
    type: CategoryType.fund,
    icon: 'donation',
    color: '#EC4899',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  CategoryModel(
    id: 'event_income',
    name: 'Event Income',
    type: CategoryType.fund,
    icon: 'entertainment',
    color: '#22C55E',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  CategoryModel(
    id: 'membership_fee',
    name: 'Membership Fee',
    type: CategoryType.fund,
    icon: 'salary',
    color: '#06B6D4',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  CategoryModel(
    id: 'grant',
    name: 'Grant',
    type: CategoryType.fund,
    icon: 'investment',
    color: '#EAB308',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  CategoryModel(
    id: 'misc_income',
    name: 'Miscellaneous Income',
    type: CategoryType.fund,
    icon: 'miscellaneous',
    color: '#8B5CF6',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
];
