import 'package:flutter/material.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/services/due_service.dart';
import 'package:org_wallet/models/due.dart';
import 'package:org_wallet/screens/dues/add_edit_due_screen.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';

class ManageDuesScreen extends StatefulWidget {
  const ManageDuesScreen({super.key});

  @override
  State<ManageDuesScreen> createState() => _ManageDuesScreenState();
}

class _ManageDuesScreenState extends State<ManageDuesScreen> {
  late final DueService _dueService;

  @override
  void initState() {
    super.initState();
    _dueService = DueService();
  }

  void _showDueForm({DueModel? existing}) async {
    final orgId = Provider.of<AuthService>(context, listen: false).currentOrgId;
    if (orgId == null) {
      SnackBarHelper.showError(
        context,
        message: 'No organization selected',
      );
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditDueScreen(existing: existing, orgId: orgId),
      ),
    );
    if (result == true) {
      setState(() {}); // refresh list
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final orgId = auth.currentOrgId;
    if (orgId == null) {
      return const Scaffold(
        body: Center(child: Text('No organization selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Dues', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: false,
        backgroundColor: TWColors.slate.shade200,
      ),
      body: StreamBuilder<List<DueModel>>(
        stream: _dueService.watchDues(orgId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final dues = snap.data ?? [];
          if (dues.isEmpty) return const Center(child: Text('No dues yet'));
          return ListView.builder(
            itemCount: dues.length,
            itemBuilder: (context, i) {
              final d = dues[i];
              return ListTile(
                title: Text(d.name),
                subtitle: Text(
                  'Amount: ${d.amount} • Due: ${d.dueDate.toLocal().toString().split(' ')[0]}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showDueForm(existing: d),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        await _dueService.deleteDue(orgId, d.id);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDueForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
