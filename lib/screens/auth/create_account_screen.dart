import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/widgets/custom_text_field.dart';
import 'package:org_wallet/widgets/custom_button.dart';
import 'package:org_wallet/screens/main_dashboard.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';

class CreateAccountScreen extends StatefulWidget {
  final String role;
  final String orgId;

  const CreateAccountScreen({
    super.key,
    required this.role,
    required this.orgId,
  });

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Business logic (signup & join) remains separated; this method is a
  // thin wrapper that will be implemented elsewhere. For now we keep an
  // async placeholder to be wired to your AuthService implementation.
  Future<void> _onJoinPressed() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final success = await authService.createAccountAndJoin(
        name: name,
        email: email,
        password: password,
        orgId: widget.orgId,
        role: widget.role,
      );

      if (!success) {
        final err =
            authService.lastErrorMessage ?? 'Failed to create account and join';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Role parsing and join logic are handled inside AuthService.createAccountAndJoin

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Please enter your email';
    final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}");
    if (!emailRegex.hasMatch(v)) return 'Please enter a valid email';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header text (in body, not AppBar)
                      const SizedBox(height: 8),
                      Text(
                        'Fill Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: TWColors.slate.shade900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Join your organization by creating an account',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: TWColors.slate.shade400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Role (read-only)
                            CustomTextField(
                              controller: TextEditingController(
                                text: widget.role,
                              ),
                              hintText: 'Role',
                              enabled: false,
                            ),
                            const SizedBox(height: 12),

                            // Name
                            CustomTextField(
                              controller: _nameController,
                              hintText: 'Full name',
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Please enter your name'
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            // Email
                            CustomTextField(
                              controller: _emailController,
                              hintText: 'Email',
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 12),

                            // Password
                            CustomTextField(
                              controller: _passwordController,
                              hintText: 'Password',
                              obscureText: true,
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Password must be at least 6 characters'
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            // Confirm Password
                            CustomTextField(
                              controller: _confirmController,
                              hintText: 'Confirm Password',
                              obscureText: true,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (v != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Spacer to push the button to bottom when there's space
                          ],
                        ),
                      ),

                      // Primary Join button
                      CustomButton(
                        text: 'Join',
                        onPressed: _onJoinPressed,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
