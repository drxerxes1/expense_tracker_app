import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/models/category.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  CollectionReference _categoriesRef(String orgId) =>
      _db.collection('organizations').doc(orgId).collection('categories');

  Future<void> _showEditDialog(BuildContext context, String orgId, {CategoryModel? category}) async {
    final nameCtrl = TextEditingController(text: category?.name ?? '');
    CategoryType selectedType = category?.type ?? CategoryType.expense;

    final formKey = GlobalKey<FormState>();

    final res = await showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CategoryType>(
                value: selectedType,
                items: CategoryType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.toShortString().capitalize())))
                    .toList(),
                onChanged: (v) {
                  if (v != null) selectedType = v;
                },
                decoration: const InputDecoration(labelText: 'Type'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              final name = nameCtrl.text.trim();
              try {
                if (category == null) {
                  final doc = _categoriesRef(orgId).doc();
                  await doc.set({'name': name, 'type': selectedType.toShortString(), 'createdAt': Timestamp.fromDate(DateTime.now())});
                } else {
                  await _categoriesRef(orgId).doc(category.id).update({'name': name, 'type': selectedType.toShortString()});
                }
                Navigator.of(ctx).pop(true);
              } catch (e) {
                // use the dialog-local context to show snack bars while dialog is open
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Save failed: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    if (!mounted) return;
    if (res == true) setState(() {});
  }

  Future<void> _confirmDelete(BuildContext context, String orgId, CategoryModel category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category'),
        content: Text('Are you sure you want to delete "${category.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _categoriesRef(orgId).doc(category.id).delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category deleted')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final orgId = auth.currentOrgId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        backgroundColor: TWColors.slate.shade200,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Expense'), Tab(text: 'Fund')],
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
      floatingActionButton: orgId == null
          ? null
          : FloatingActionButton(
              onPressed: () => _showEditDialog(context, orgId),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildCategoryList(String orgId, CategoryType type) {
    return StreamBuilder<QuerySnapshot>(
      stream: _categoriesRef(orgId).orderBy('name').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data?.docs ?? [];
        final cats = docs.map((d) => CategoryModel.fromFirestore(d)).where((c) => c.type == type).toList();

        if (cats.isEmpty) return Center(child: Text('No ${type.toShortString()} categories'));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: cats.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final c = cats[index];
            return Card(
              child: ListTile(
                title: Text(c.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text(c.type.toShortString()),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditDialog(context, orgId, category: c)),
                  IconButton(icon: const Icon(Icons.delete), onPressed: () => _confirmDelete(context, orgId, c)),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

extension _StringCap on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
