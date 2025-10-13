import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/user.dart' as app_user;
import 'package:org_wallet/utils/snackbar_helper.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isInitialLoading = true;
  app_user.User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      _currentUser = authService.user;
      
      if (_currentUser != null) {
        // Populate form fields immediately with cached data
        if (mounted) {
          _nameController.text = _currentUser!.name;
          setState(() => _isInitialLoading = false);
        }
      } else {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            message: 'No user data available',
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          message: 'Error loading user data: $e',
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestore = FirebaseFirestore.instance;

      if (authService.user == null) {
        throw Exception('No user data available');
      }

      // Update user document
      await firestore
          .collection('users')
          .doc(authService.user!.id)
          .update({
        'name': _nameController.text.trim(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Update local user data
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          name: _nameController.text.trim(),
          updatedAt: DateTime.now(),
        );
      }

      // Reload user data in auth service
      await authService.reloadUserData();

      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          message: 'Profile updated successfully!',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          message: 'Error updating profile: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_currentUser != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _updateProfile,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Icon(
                        Icons.person,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Edit Profile',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Update your personal information',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // Profile Avatar Display
                      Center(
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Text(
                            _nameController.text.isNotEmpty 
                                ? _nameController.text[0].toUpperCase() 
                                : 'U',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        maxLength: 50,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                          hintText: 'e.g., John Doe',
                          counterText: '', // Hide the character counter
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          if (value.length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          if (value.length > 50) {
                            return 'Name must not exceed 50 characters';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {}); // Update avatar preview
                        },
                      ),
                      const SizedBox(height: 20),

                      // Email Display (Read-only)
                      TextFormField(
                        initialValue: _currentUser?.email ?? '',
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                          helperText: 'Email cannot be changed',
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Update Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _updateProfile,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Update Profile'),
                      ),
                      const SizedBox(height: 20),

                      // Info Text
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your email address cannot be changed. Contact support if you need to update your email.',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Account Information
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Information',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Account Created:'),
                                  Text(
                                    _currentUser != null 
                                        ? '${_currentUser!.createdAt.day}/${_currentUser!.createdAt.month}/${_currentUser!.createdAt.year}'
                                        : 'N/A',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Last Updated:'),
                                  Text(
                                    _currentUser != null 
                                        ? '${_currentUser!.updatedAt.day}/${_currentUser!.updatedAt.month}/${_currentUser!.updatedAt.year}'
                                        : 'N/A',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Organizations:'),
                                  Text(
                                    '${_currentUser?.organizations.length ?? 0}',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
