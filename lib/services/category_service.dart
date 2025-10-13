import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:org_wallet/models/category.dart';

class CategoryService {
  final FirebaseFirestore _db;
  
  CategoryService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _categoriesRef(String orgId) =>
      _db.collection('organizations').doc(orgId).collection('categories');

  /// Create a new category
  Future<String> createCategory({
    required String orgId,
    required String name,
    required CategoryType type,
    required String icon,
    required String color,
  }) async {
    final docRef = _categoriesRef(orgId).doc();
    final now = DateTime.now();
    
    final category = CategoryModel(
      id: docRef.id,
      name: name,
      type: type,
      icon: icon,
      color: color,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(category.toFirestoreMap());
    return docRef.id;
  }

  /// Update an existing category
  Future<void> updateCategory({
    required String orgId,
    required String categoryId,
    required String name,
    required CategoryType type,
    required String icon,
    required String color,
  }) async {
    final docRef = _categoriesRef(orgId).doc(categoryId);
    
    await docRef.update({
      'name': name,
      'type': type.toShortString(),
      'icon': icon,
      'color': color,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Delete a category
  Future<void> deleteCategory({
    required String orgId,
    required String categoryId,
  }) async {
    await _categoriesRef(orgId).doc(categoryId).delete();
  }

  /// Get a single category by ID
  Future<CategoryModel?> getCategory({
    required String orgId,
    required String categoryId,
  }) async {
    final doc = await _categoriesRef(orgId).doc(categoryId).get();
    if (!doc.exists) return null;
    return CategoryModel.fromFirestore(doc);
  }

  /// Get all categories for an organization
  Future<List<CategoryModel>> getCategories({
    required String orgId,
    CategoryType? type,
  }) async {
    // Get all categories first, then filter in memory to avoid index requirements
    final snapshot = await _categoriesRef(orgId).get();
    final allCategories = snapshot.docs
        .map((doc) => CategoryModel.fromFirestore(doc))
        .toList();
    
    // Filter by type if specified
    final filteredCategories = type != null 
        ? allCategories.where((c) => c.type == type).toList()
        : allCategories;
    
    // Sort by name
    filteredCategories.sort((a, b) => a.name.compareTo(b.name));
    
    return filteredCategories;
  }

  /// Stream all categories for an organization
  Stream<List<CategoryModel>> watchCategories({
    required String orgId,
    CategoryType? type,
  }) {
    return _categoriesRef(orgId).snapshots().map((snapshot) {
      final allCategories = snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .toList();
      
      // Filter by type if specified
      final filteredCategories = type != null 
          ? allCategories.where((c) => c.type == type).toList()
          : allCategories;
      
      // Sort by name
      filteredCategories.sort((a, b) => a.name.compareTo(b.name));
      
      return filteredCategories;
    });
  }

  /// Stream categories by type (expense or fund)
  Stream<List<CategoryModel>> watchCategoriesByType({
    required String orgId,
    required CategoryType type,
  }) {
    return _categoriesRef(orgId).snapshots().map((snapshot) {
      final categories = snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .where((c) => c.type == type)
          .toList();
      
      // Sort by name
      categories.sort((a, b) => a.name.compareTo(b.name));
      
      return categories;
    });
  }

  /// Get categories by type (expense or fund)
  Future<List<CategoryModel>> getCategoriesByType({
    required String orgId,
    required CategoryType type,
  }) async {
    final snapshot = await _categoriesRef(orgId).get();
    final categories = snapshot.docs
        .map((doc) => CategoryModel.fromFirestore(doc))
        .where((c) => c.type == type)
        .toList();
    
    // Sort by name
    categories.sort((a, b) => a.name.compareTo(b.name));
    
    return categories;
  }

  /// Check if a category name already exists for the organization
  Future<bool> categoryNameExists({
    required String orgId,
    required String name,
    CategoryType? type,
    String? excludeCategoryId,
  }) async {
    // Get all categories and filter in memory to avoid index requirements
    final snapshot = await _categoriesRef(orgId).get();
    final categories = snapshot.docs
        .map((doc) => CategoryModel.fromFirestore(doc))
        .where((c) => c.name.toLowerCase() == name.toLowerCase())
        .toList();
    
    // Filter by type if specified
    final filteredCategories = type != null 
        ? categories.where((c) => c.type == type).toList()
        : categories;
    
    // If we're updating an existing category, exclude it from the check
    if (excludeCategoryId != null) {
      return filteredCategories.any((c) => c.id != excludeCategoryId);
    }
    
    return filteredCategories.isNotEmpty;
  }

  /// Initialize default categories for a new organization
  Future<void> initializeDefaultCategories(String orgId) async {
    final defaultCategories = [
      // Default expense categories
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
        id: 'transport',
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
      // Default fund categories
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
    ];

    final batch = _db.batch();
    
    for (final category in defaultCategories) {
      final docRef = _categoriesRef(orgId).doc(category.id);
      batch.set(docRef, category.toFirestoreMap());
    }
    
    await batch.commit();
  }

  /// Check if a category is a default category
  bool isDefaultCategory(String categoryId) {
    const defaultCategoryIds = {
      'food', 'transport', 'supplies', 'utilities', 'miscellaneous',
      'donation', 'event_income', 'membership_fee', 'grant'
    };
    return defaultCategoryIds.contains(categoryId);
  }

  /// Get all default category IDs
  Set<String> getDefaultCategoryIds() {
    return {
      'food', 'transport', 'supplies', 'utilities', 'miscellaneous',
      'donation', 'event_income', 'membership_fee', 'grant'
    };
  }

  /// Ensure default categories exist for an organization
  /// This method checks if default categories exist and creates them if they don't
  Future<void> ensureDefaultCategoriesExist(String orgId) async {
    // Check if any categories exist for this organization
    final existingCategories = await getCategories(orgId: orgId);
    
    // If no categories exist, initialize defaults
    if (existingCategories.isEmpty) {
      await initializeDefaultCategories(orgId);
    } else {
      // Check if we need to add any missing default categories
      final existingIds = existingCategories.map((c) => c.id).toSet();
      final defaultCategoryIds = {
        'food', 'transport', 'supplies', 'utilities', 'miscellaneous',
        'donation', 'event_income', 'membership_fee', 'grant'
      };
      
      final missingIds = defaultCategoryIds.difference(existingIds);
      
      if (missingIds.isNotEmpty) {
        // Add only the missing default categories
        final batch = _db.batch();
        
        for (final categoryId in missingIds) {
          CategoryModel? defaultCategory;
          
          switch (categoryId) {
            case 'food':
              defaultCategory = CategoryModel(
                id: 'food',
                name: 'Food',
                type: CategoryType.expense,
                icon: 'food',
                color: '#EF4444',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              break;
            case 'transport':
              defaultCategory = CategoryModel(
                id: 'transport',
                name: 'Transportation',
                type: CategoryType.expense,
                icon: 'transport',
                color: '#3B82F6',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              break;
            case 'supplies':
              defaultCategory = CategoryModel(
                id: 'supplies',
                name: 'Supplies',
                type: CategoryType.expense,
                icon: 'shopping',
                color: '#10B981',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              break;
            case 'utilities':
              defaultCategory = CategoryModel(
                id: 'utilities',
                name: 'Utilities',
                type: CategoryType.expense,
                icon: 'utilities',
                color: '#F97316',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              break;
            case 'miscellaneous':
              defaultCategory = CategoryModel(
                id: 'miscellaneous',
                name: 'Miscellaneous',
                type: CategoryType.expense,
                icon: 'miscellaneous',
                color: '#8B5CF6',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              break;
            case 'donation':
              defaultCategory = CategoryModel(
                id: 'donation',
                name: 'Donation',
                type: CategoryType.fund,
                icon: 'donation',
                color: '#EC4899',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              break;
            case 'event_income':
              defaultCategory = CategoryModel(
                id: 'event_income',
                name: 'Event Income',
                type: CategoryType.fund,
                icon: 'entertainment',
                color: '#22C55E',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              break;
            case 'membership_fee':
              defaultCategory = CategoryModel(
                id: 'membership_fee',
                name: 'Membership Fee',
                type: CategoryType.fund,
                icon: 'salary',
                color: '#06B6D4',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              break;
            case 'grant':
              defaultCategory = CategoryModel(
                id: 'grant',
                name: 'Grant',
                type: CategoryType.fund,
                icon: 'investment',
                color: '#EAB308',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              break;
          }
          
          if (defaultCategory != null) {
            final docRef = _categoriesRef(orgId).doc(defaultCategory.id);
            batch.set(docRef, defaultCategory.toFirestoreMap());
          }
        }
        
        await batch.commit();
      }
    }
  }

  /// Initialize fund accounts (system-level funds) for an organization
  /// These are separate from categories and represent actual fund buckets
  Future<void> initializeFundAccounts(String orgId) async {
    final fundAccounts = [
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

    final batch = _db.batch();
    
    for (final fundAccount in fundAccounts) {
      final docRef = _categoriesRef(orgId).doc(fundAccount.id);
      batch.set(docRef, fundAccount.toFirestoreMap());
    }
    
    await batch.commit();
  }

  /// Ensure fund accounts exist for an organization
  Future<void> ensureFundAccountsExist(String orgId) async {
    final existingFundAccounts = await getCategoriesByType(
      orgId: orgId,
      type: CategoryType.fund,
    );
    
    final existingIds = existingFundAccounts.map((c) => c.id).toSet();
    final fundAccountIds = {'school_funds', 'club_funds'};
    
    final missingIds = fundAccountIds.difference(existingIds);
    
    if (missingIds.isNotEmpty) {
      final batch = _db.batch();
      
      for (final fundAccountId in missingIds) {
        CategoryModel? fundAccount;
        
        switch (fundAccountId) {
          case 'school_funds':
            fundAccount = CategoryModel(
              id: 'school_funds',
              name: 'School Funds',
              type: CategoryType.fund,
              icon: 'education',
              color: '#06B6D4',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            break;
          case 'club_funds':
            fundAccount = CategoryModel(
              id: 'club_funds',
              name: 'Club Funds',
              type: CategoryType.fund,
              icon: 'groups',
              color: '#8B5CF6',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            break;
        }
        
        if (fundAccount != null) {
          final docRef = _categoriesRef(orgId).doc(fundAccount.id);
          batch.set(docRef, fundAccount.toFirestoreMap());
        }
      }
      
      await batch.commit();
    }
    
    // Update existing Club Funds to use the new icon and color
    await updateClubFundsIconAndColor(orgId);
  }

  /// Force update Club Funds icon and color - call this to manually update
  Future<void> forceUpdateClubFundsIconAndColor(String orgId) async {
    try {
      final clubFundsRef = _categoriesRef(orgId).doc('club_funds');
      await clubFundsRef.update({
        'icon': 'groups',
        'color': '#8B5CF6',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      debugPrint('Successfully updated Club Funds icon and color');
    } catch (e) {
      debugPrint('Error force updating Club Funds: $e');
      // If update fails, try to create the document
      try {
        final clubFundsRef = _categoriesRef(orgId).doc('club_funds');
        await clubFundsRef.set({
          'id': 'club_funds',
          'name': 'Club Funds',
          'type': 'fund',
          'icon': 'groups',
          'color': '#8B5CF6',
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
        debugPrint('Successfully created Club Funds with new icon and color');
      } catch (e2) {
        debugPrint('Error creating Club Funds: $e2');
      }
    }
  }

  /// Update existing Club Funds to use the new icon and color
  Future<void> updateClubFundsIconAndColor(String orgId) async {
    try {
      final clubFundsRef = _categoriesRef(orgId).doc('club_funds');
      final clubFundsDoc = await clubFundsRef.get();
      
      if (clubFundsDoc.exists) {
        await clubFundsRef.update({
          'icon': 'groups',
          'color': '#8B5CF6',
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      // Ignore errors - this is a non-critical update
      debugPrint('Error updating Club Funds icon and color: $e');
    }
  }

  /// Check if a category is a fund account (system-level fund)
  bool isFundAccount(String categoryId) {
    const fundAccountIds = {'school_funds', 'club_funds'};
    return fundAccountIds.contains(categoryId);
  }

  /// Get fund accounts (system-level funds)
  Future<List<CategoryModel>> getFundAccounts(String orgId) async {
    final allFunds = await getCategoriesByType(orgId: orgId, type: CategoryType.fund);
    return allFunds.where((c) => isFundAccount(c.id)).toList();
  }

  /// Stream fund accounts (system-level funds)
  Stream<List<CategoryModel>> watchFundAccounts(String orgId) {
    return watchCategoriesByType(orgId: orgId, type: CategoryType.fund)
        .map((funds) => funds.where((c) => isFundAccount(c.id)).toList());
  }
}
