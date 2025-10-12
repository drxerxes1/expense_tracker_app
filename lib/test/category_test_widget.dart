import 'package:flutter/material.dart';
import 'package:org_wallet/services/category_service.dart';
import 'package:org_wallet/models/category.dart';

/// Test widget to verify category functionality
class CategoryTestWidget extends StatefulWidget {
  const CategoryTestWidget({super.key});

  @override
  State<CategoryTestWidget> createState() => _CategoryTestWidgetState();
}

class _CategoryTestWidgetState extends State<CategoryTestWidget> {
  final CategoryService _categoryService = CategoryService();
  List<CategoryModel> _categories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      // This would normally use the actual orgId from AuthService
      // For testing, we'll use a test orgId
      const testOrgId = 'test_org_123';
      
      // Ensure default categories exist
      await _categoryService.ensureDefaultCategoriesExist(testOrgId);
      
      // Load all categories
      final categories = await _categoryService.getCategories(orgId: testOrgId);
      setState(() => _categories = categories);
    } catch (e) {
      debugPrint('Error loading categories: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Test'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isDefault = _categoryService.isDefaultCategory(category.id);
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
                    child: Text(
                      category.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(category.name),
                  subtitle: Text('${category.type.toShortString()} ${isDefault ? '(Default)' : ''}'),
                  trailing: Text(category.icon),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadCategories,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
