// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/models/category.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/services/category_service.dart';
import 'package:org_wallet/constants/category_constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CategoryService _categoryService = CategoryService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ensureDefaultCategoriesExist();
  }

  Future<void> _ensureDefaultCategoriesExist() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final orgId = auth.currentOrgId;
    
    if (orgId != null) {
      try {
        // Ensure both categories and fund accounts exist
        await _categoryService.ensureDefaultCategoriesExist(orgId);
        await _categoryService.ensureFundAccountsExist(orgId);
      } catch (e) {
        debugPrint('Error ensuring default categories exist: $e');
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showEditDialog(
    BuildContext context,
    String orgId, {
    CategoryModel? category,
  }) async {
    final nameCtrl = TextEditingController(text: category?.name ?? '');
    CategoryType selectedType = category?.type ?? CategoryType.expense;
    String selectedIcon = category?.icon ?? 'category';
    String selectedColor = category?.color ?? '#6366F1';

    final formKey = GlobalKey<FormState>();

    final res = await showDialog<bool?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(category == null ? 'Add Category' : 'Edit Category'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<CategoryType>(
                    value: selectedType,
                    items: CategoryType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.toShortString().capitalize()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          selectedType = v;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Icon Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Icon', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            childAspectRatio: 1,
                          ),
                          itemCount: CategoryIcons.getIconNames().length,
                          itemBuilder: (context, index) {
                            final iconName = CategoryIcons.getIconNames()[index];
                            final isSelected = iconName == selectedIcon;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedIcon = iconName;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isSelected ? TWColors.indigo.shade100 : null,
                                  borderRadius: BorderRadius.circular(4),
                                  border: isSelected ? Border.all(color: TWColors.indigo.shade500) : null,
                                ),
                                child: Icon(
                                  CategoryIcons.getIcon(iconName),
                                  color: isSelected ? TWColors.indigo.shade700 : Colors.grey.shade600,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Color Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Color', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Container(
                        height: 60,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(8),
                          itemCount: CategoryColors.colors.length,
                          itemBuilder: (context, index) {
                            final color = CategoryColors.colors[index];
                            final colorHex = CategoryColors.colorToHex(color);
                            final isSelected = colorHex == selectedColor;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedColor = colorHex;
                                });
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                  border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() != true) return;
                final name = nameCtrl.text.trim();
                try {
                  if (category == null) {
                    // Check if category name already exists
                    final exists = await _categoryService.categoryNameExists(
                      orgId: orgId,
                      name: name,
                      type: selectedType,
                    );
                    if (exists) {
                      SnackBarHelper.showError(
                        ctx,
                        message: 'A ${selectedType.toShortString()} category with this name already exists',
                      );
                      return;
                    }
                    
                    await _categoryService.createCategory(
                      orgId: orgId,
                      name: name,
                      type: selectedType,
                      icon: selectedIcon,
                      color: selectedColor,
                    );
                  } else {
                    // Check if category name already exists (excluding current category)
                    final exists = await _categoryService.categoryNameExists(
                      orgId: orgId,
                      name: name,
                      type: selectedType,
                      excludeCategoryId: category.id,
                    );
                    if (exists) {
                      SnackBarHelper.showError(
                        ctx,
                        message: 'A ${selectedType.toShortString()} category with this name already exists',
                      );
                      return;
                    }
                    
                    await _categoryService.updateCategory(
                      orgId: orgId,
                      categoryId: category.id,
                      name: name,
                      type: selectedType,
                      icon: selectedIcon,
                      color: selectedColor,
                    );
                  }
                  Navigator.of(ctx).pop(true);
                } catch (e) {
                  SnackBarHelper.showError(
                    ctx,
                    message: 'Save failed: $e',
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    if (!mounted) return;
    if (res == true) setState(() {});
  }

  Future<void> _restoreDefaultCategories(BuildContext context, String orgId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Default Categories'),
        content: const Text(
          'This will add any missing default categories to your organization. '
          'Existing categories will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _categoryService.ensureDefaultCategoriesExist(orgId);
        if (!mounted) return;
        SnackBarHelper.showSuccess(
          context,
          message: 'Default categories restored successfully',
        );
      } catch (e) {
        if (!mounted) return;
        SnackBarHelper.showError(
          context,
          message: 'Failed to restore default categories: $e',
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String orgId,
    CategoryModel category,
  ) async {
    final isDefault = _categoryService.isDefaultCategory(category.id);
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDefault ? 'Delete Default Category' : 'Delete Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDefault 
                ? 'Are you sure you want to delete the default category "${category.name}"?'
                : 'Are you sure you want to delete "${category.name}"?',
            ),
            if (isDefault) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TWColors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TWColors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: TWColors.amber.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a default category. It can be recreated later if needed.',
                        style: TextStyle(
                          color: TWColors.amber.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text('This action cannot be undone.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _categoryService.deleteCategory(
          orgId: orgId,
          categoryId: category.id,
        );
        if (!mounted) return;
        SnackBarHelper.showSuccess(
          context,
          message: isDefault 
              ? 'Default category deleted successfully'
              : 'Category deleted successfully',
        );
      } catch (e) {
        if (!mounted) return;
        SnackBarHelper.showError(
          context,
          message: 'Delete failed: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final orgId = auth.currentOrgId;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'Manage Categories',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: TWColors.slate.shade200,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Expense'),
            Tab(text: 'Fund'),
          ],
          labelColor: Colors.black,
        ),
      ),
      body: orgId == null
          ? const Center(child: Text('No organization selected'))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(orgId, CategoryType.expense),
                _buildCategoryList(orgId, CategoryType.fund),
              ],
            ),
      floatingActionButton: orgId == null || !Provider.of<AuthService>(context, listen: false).canPerformAction('manage_categories')
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "restore_defaults",
                  mini: true,
                  onPressed: () => _restoreDefaultCategories(context, orgId),
                  backgroundColor: TWColors.slate.shade900,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.restore, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "add_category",
                  onPressed: () => _showEditDialog(context, orgId),
                  backgroundColor: TWColors.slate.shade900,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryList(String orgId, CategoryType type) {
    return StreamBuilder<List<CategoryModel>>(
      stream: _categoryService.watchCategories(orgId: orgId, type: type)
          .map((categories) => categories.where((c) => !_categoryService.isFundAccount(c.id)).toList()),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data ?? [];

        if (categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${type.toShortString()} categories',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the + button to add your first category',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final category = categories[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: CategoryColors.hexToColor(category.color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        CategoryIcons.getIcon(category.icon),
                        color: CategoryColors.hexToColor(category.color),
                        size: 24,
                      ),
                    ),
                    // Default category indicator
                    if (_categoryService.isDefaultCategory(category.id))
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: TWColors.blue.shade500,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: const Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  category.name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Text(
                      category.type.toShortString().capitalize(),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    if (_categoryService.isDefaultCategory(category.id)) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: TWColors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Default',
                          style: TextStyle(
                            color: TWColors.blue.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (Provider.of<AuthService>(context, listen: false).canPerformAction('manage_categories')) ...[
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          color: TWColors.indigo.shade600,
                        ),
                        onPressed: () => _showEditDialog(context, orgId, category: category),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade600,
                        ),
                        onPressed: () => _confirmDelete(context, orgId, category),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

extension _StringCap on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
