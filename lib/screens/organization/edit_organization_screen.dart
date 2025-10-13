// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/organization.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';

class EditOrganizationScreen extends StatefulWidget {
  const EditOrganizationScreen({super.key});

  @override
  State<EditOrganizationScreen> createState() => _EditOrganizationScreenState();
}

class _EditOrganizationScreenState extends State<EditOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _isInitialLoading = true;
  Organization? _currentOrganization;

  @override
  void initState() {
    super.initState();
    _loadCurrentOrganization();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentOrganization() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      if (authService.currentOrgId == null) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            message: 'No organization selected',
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Use cached organization data from AuthService first
      _currentOrganization = authService.organization;

      if (_currentOrganization != null) {
        // Populate form fields immediately with cached data
        if (mounted) {
          _nameController.text = _currentOrganization!.name;
          _descriptionController.text = _currentOrganization!.description;
          setState(() => _isInitialLoading = false);
        }

        // Optionally refresh data in background (non-blocking)
        _refreshOrganizationData();
      } else {
        // Fallback: load from Firestore if not in cache
        final orgDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(authService.currentOrgId)
            .get();

        if (orgDoc.exists) {
          _currentOrganization = Organization.fromMap({
            'id': orgDoc.id,
            ...orgDoc.data() as Map<String, dynamic>,
          });

          if (mounted) {
            _nameController.text = _currentOrganization!.name;
            _descriptionController.text = _currentOrganization!.description;
            setState(() => _isInitialLoading = false);
          }
        } else {
          if (mounted) {
            SnackBarHelper.showError(
              context,
              message: 'Organization not found',
            );
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          message: 'Error loading organization: $e',
        );
        Navigator.of(context).pop();
      }
    }
  }

  /// Refresh organization data in background without blocking UI
  Future<void> _refreshOrganizationData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.reloadOrganizationData();

      // Update local data if it changed
      if (mounted && authService.organization != null) {
        _currentOrganization = authService.organization;
        // Only update form fields if they're empty (user hasn't started editing)
        if (_nameController.text.isEmpty) {
          _nameController.text = _currentOrganization!.name;
        }
        if (_descriptionController.text.isEmpty) {
          _descriptionController.text = _currentOrganization!.description;
        }
      }
    } catch (e) {
      debugPrint('Error refreshing organization data: $e');
    }
  }

  Future<void> _updateOrganization() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestore = FirebaseFirestore.instance;

      if (authService.currentOrgId == null) {
        throw Exception('No organization selected');
      }

      // Check if user has permission to edit organization
      if (!authService.canAccessDrawerItem('edit_organization')) {
        throw Exception('You do not have permission to edit this organization');
      }

      // Update organization document
      await firestore
          .collection('organizations')
          .doc(authService.currentOrgId)
          .update({
            'name': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });

      // Update local organization data
      if (_currentOrganization != null) {
        _currentOrganization = _currentOrganization!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          updatedAt: DateTime.now(),
        );
      }

      // Reload organization data in auth service
      await authService.reloadOrganizationData();

      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          message: 'Organization updated successfully!',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          message: 'Error updating organization: $e',
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
          'Edit Organization',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_currentOrganization != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _updateOrganization,
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
                        Icons.business,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Edit Organization',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Update your organization information',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // Organization Name
                      TextFormField(
                        controller: _nameController,
                        maxLength: 30,
                        decoration: const InputDecoration(
                          labelText: 'Organization Name',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(),
                          hintText: 'e.g., ABC Company',
                          counterText: '', // Hide the character counter
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter organization name';
                          }
                          if (value.length < 3) {
                            return 'Name must be at least 3 characters';
                          }
                          if (value.length > 30) {
                            return 'Name must not exceed 30 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                          hintText: 'Brief description of your organization',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter description';
                          }
                          if (value.length < 10) {
                            return 'Description must be at least 10 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),

                      // Update Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _updateOrganization,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Update Organization'),
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
                                'Only organization presidents and moderators can edit organization information.',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
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
