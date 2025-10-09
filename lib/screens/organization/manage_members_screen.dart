import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/officer.dart';

class ManageMembersScreen extends StatefulWidget {
  const ManageMembersScreen({super.key});

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _updateStatus(String docId, String status) async {
    await _firestore.collection('officers').doc(docId).update({
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _removeMember(String docId, String userId, String orgId) async {
    // remove officer doc and remove org from user's organizations array
    await _firestore.collection('officers').doc(docId).delete();
    try {
      await _firestore.collection('users').doc(userId).update({
        'organizations': FieldValue.arrayRemove([orgId]),
      });
    } catch (_) {
      // ignore if user doc missing
    }
  }

  void _showDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(data['name'] ?? data['email'] ?? 'Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${data['email'] ?? '-'}'),
            const SizedBox(height: 8),
            Text('Role: ${data['role'] ?? '-'}'),
            const SizedBox(height: 8),
            Text('Status: ${data['status'] ?? '-'}'),
            const SizedBox(height: 8),
            Text('Joined: ${data['joinedAt'] ?? '-'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    if (!auth.isLoggedIn || auth.currentOrgId == null) {
      return const Scaffold(
        body: Center(child: Text('No organization selected')),
      );
    }
    if (!auth.isPresident()) {
      return const Scaffold(
        body: Center(child: Text('Only Presidents can manage members')),
      );
    }
    final orgId = auth.currentOrgId!;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Members')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('officers')
            .where('orgId', isEqualTo: orgId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('No members'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final m = d.data() as Map<String, dynamic>;
              final status = m['status'];
              final statusLabel = status is int
                  ? OfficerStatus.values
                        .elementAt(status)
                        .toString()
                        .split('.')
                        .last
                  : status?.toString() ?? 'unknown';
              final role = m['role'] ?? 'member';
              final name = m['name'] ?? m['email'] ?? '';
              final userId = (m['userId'] ?? '').toString();
              return ListTile(
                title: Text(name),
                subtitle: Text('${m['email'] ?? ''} • $role • $statusLabel'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_red_eye),
                      tooltip: 'View',
                      onPressed: () => _showDetails(m),
                    ),
                    if (statusLabel != 'approved')
                      IconButton(
                        icon: const Icon(Icons.check),
                        tooltip: 'Approve',
                        onPressed: () async {
                          await _updateStatus(d.id, 'approved');
                        },
                      ),
                    if (statusLabel != 'denied')
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Decline',
                        onPressed: () async {
                          await _updateStatus(d.id, 'denied');
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.person_remove),
                      tooltip: 'Remove',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Remove member'),
                            content: const Text(
                              'Are you sure you want to remove this member from the organization?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await _removeMember(d.id, userId, orgId);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
