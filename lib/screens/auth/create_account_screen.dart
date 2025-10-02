import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/widgets/custom_text_field.dart';
import 'package:org_wallet/widgets/custom_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:org_wallet/models/officer.dart';
import 'package:org_wallet/screens/main_dashboard.dart';

class CreateAccountScreen extends StatefulWidget {
  final String role;
  final String orgId;

  const CreateAccountScreen({super.key, required this.role, required this.orgId});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);

    final success = await authService.signUp(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!success) {
      final err = authService.lastErrorMessage ?? 'Failed to create account';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      // After signUp, user is authenticated. Create officer record and attach org
      final firestore = FirebaseFirestore.instance;
      final userId = authService.firebaseUser!.uid;

      // Create officer record with pending status
      final officerDoc = firestore.collection('officers').doc();
      final officer = Officer(
        id: officerDoc.id,
        orgId: widget.orgId,
        userId: userId,
        name: authService.user!.name,
        email: authService.user!.email,
        role: _parseRole(widget.role),
        status: OfficerStatus.pending,
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await officerDoc.set(officer.toMap());

      // Update user's organizations list
      await firestore.collection('users').doc(userId).update({
        'organizations': FieldValue.arrayUnion([widget.orgId]),
      });

      // Save joined org and role to Hive
      final metaBox = await Hive.openBox('userMeta');
      await metaBox.put(userId, {'orgId': widget.orgId, 'role': widget.role});

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining organization: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  OfficerRole _parseRole(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'president':
        return OfficerRole.president;
      case 'treasurer':
        return OfficerRole.treasurer;
      case 'secretary':
        return OfficerRole.secretary;
      case 'auditor':
        return OfficerRole.auditor;
      case 'moderator':
        return OfficerRole.moderator;
      default:
        return OfficerRole.member;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account & Join')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                CustomTextField(
                  controller: _nameController,
                  hintText: 'Full name',
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter name' : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}\$').hasMatch(v)) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Password min 6 chars' : null,
                ),
                const SizedBox(height: 20),
                CustomButton(
                  text: 'Create Account & Join as ${widget.role}',
                  onPressed: _createAccount,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
