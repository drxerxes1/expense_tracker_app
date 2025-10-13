import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tailwind_colors/flutter_tailwind_colors.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/screens/auth/signup_screen.dart';
import 'package:org_wallet/screens/organization/create_organization_screen.dart';
import 'package:org_wallet/screens/organization/scan_qr_screen.dart';
import 'package:org_wallet/screens/main_dashboard.dart';
import 'package:org_wallet/widgets/custom_text_field.dart';
import 'package:org_wallet/widgets/custom_button.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (success && mounted) {
        if (authService.user?.organizations.isNotEmpty == true) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainDashboard()),
          );
        } else {
          _showOrganizationOptions();
        }
      } else if (mounted) {
        final error = _getUserFriendlyErrorMessage(
            authService.lastErrorMessage ?? 'Invalid email or password');
        SnackBarHelper.showError(
          context,
          message: error,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          message: 'An unexpected error occurred. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getUserFriendlyErrorMessage(String errorMessage) {
    // Convert Firebase error messages to user-friendly messages
    if (errorMessage.toLowerCase().contains('user-not-found')) {
      return 'No account found with this email address. Please check your email or create a new account.';
    } else if (errorMessage.toLowerCase().contains('wrong-password')) {
      return 'Incorrect password. Please check your password and try again.';
    } else if (errorMessage.toLowerCase().contains('invalid-email')) {
      return 'Invalid email format. Please enter a valid email address.';
    } else if (errorMessage.toLowerCase().contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    } else if (errorMessage.toLowerCase().contains('too-many-requests')) {
      return 'Too many failed attempts. Please wait a moment before trying again.';
    } else if (errorMessage.toLowerCase().contains('network-request-failed')) {
      return 'Network error. Please check your internet connection and try again.';
    } else if (errorMessage.toLowerCase().contains('authentication error')) {
      return 'Login failed. Please check your email and password, then try again.';
    } else {
      return 'Login failed. Please verify your credentials and try again.';
    }
  }

  void _showOrganizationOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Organization Setup'),
        content: const Text(
          'You need to either join an existing organization or create a new one.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ScanQRScreen()));
            },
            child: const Text('Join Organization'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateOrganizationScreen(),
                ),
              );
            },
            child: const Text('Create Organization'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, screenHeight * 0.15, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Login',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: TWColors.slate.shade900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter your details below to login',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: TWColors.slate.shade400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Email Field
                CustomTextField(
                  controller: _emailController,
                  hintText: 'email@email.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Password Field
                CustomTextField(
                  controller: _passwordController,
                  hintText: 'Enter your password',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: TWColors.slate.shade400,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Sign In Button
                CustomButton(
                  text: 'Login',
                  onPressed: _signIn,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 20),

                // Join with QR code button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ScanQRScreen()),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Join with QR code'),
                ),
                const SizedBox(height: 20),

                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: TWColors.slate.shade400),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          color: TWColors.slate.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
