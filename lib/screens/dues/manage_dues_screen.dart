import 'package:flutter/material.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/services/due_service.dart';
import 'package:org_wallet/models/due.dart';

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

  void _showDueForm({DueModel? existing}) {
    final orgId = Provider.of<AuthService>(context, listen: false).currentOrgId;
    if (orgId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No organization selected')));
      return;
    }

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl = TextEditingController(
      text: existing?.amount.toString() ?? '',
    );
    DateTime dueDate = existing?.dueDate ?? DateTime.now();
    String frequency = existing?.frequency ?? 'monthly';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add Due' : 'Edit Due'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Due date: ${dueDate.toLocal().toString().split(' ')[0]}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => dueDate = picked);
                    },
                    child: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: frequency,
                items: const [
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(
                    value: 'quarterly',
                    child: Text('Quarterly'),
                  ),
                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                ],
                onChanged: (v) => frequency = v ?? frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (name.isEmpty || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter name and valid amount')),
                );
                return;
              }
              if (existing == null) {
                final due = DueModel.create(
                  orgId: orgId,
                  name: name,
                  amount: amount,
                  frequency: frequency,
                  dueDate: dueDate,
                  createdBy:
                      Provider.of<AuthService>(
                        context,
                        listen: false,
                      ).user?.id ??
                      '',
                );
                await _dueService.createDue(due);
              } else {
                await _dueService.updateDue(orgId, existing.id, {
                  'name': name,
                  'amount': amount,
                  'frequency': frequency,
                  'dueDate': Timestamp.fromDate(dueDate),
                });
              }
              // ignore: use_build_context_synchronously
              Navigator.of(context).pop();
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
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
