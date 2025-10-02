import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/models/officer.dart';
import 'package:org_wallet/screens/main_dashboard.dart';
import 'package:org_wallet/screens/auth/create_account_screen.dart';
import 'package:hive/hive.dart';
import 'package:org_wallet/models/user_login.dart';

class ScanQRScreen extends StatefulWidget {
  const ScanQRScreen({super.key});

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  bool _isProcessing = false;
  bool _torchEnabled = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isNotEmpty && !_isProcessing) {
      final String? code = capture.barcodes.first.rawValue;
      if (code != null) {
        _processQRCode(code);
      }
    }
  }

  Future<void> _processQRCode(String qrData) async {
    setState(() {
      _isProcessing = true;
      _isScanning = false;
    });

    try {
      // Parse QR data (assuming it's a string representation of a map)
      // In a real app, you'd want to use proper JSON encoding/decoding
      final data = _parseQRData(qrData);

      if (data == null) {
        _showError('Invalid QR code format');
        return;
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      final firestore = FirebaseFirestore.instance;

      // Check Hive for existing logged-in user
      final loginBox = Hive.box<UserLogin>('userLogin');
      final currentLogin = loginBox.get('current');

      // If no user exists locally, navigate to create-account flow and
      // pass the scanned role and orgId so the new user can be created
      // and immediately join the organization.
      if (currentLogin == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => CreateAccountScreen(
                role: data['role'] ?? 'member',
                orgId: data['orgId'],
              ),
            ),
          );
        }
        return;
      }

      // Check if organization exists
      final orgDoc = await firestore
          .collection('organizations')
          .doc(data['orgId'])
          .get();

      if (!orgDoc.exists) {
        _showError('Organization not found');
        return;
      }

      // Check if user is already a member
      final existingOfficer = await firestore
          .collection('officers')
          .where('orgId', isEqualTo: data['orgId'])
          .where('userId', isEqualTo: authService.firebaseUser!.uid)
          .get();

      if (existingOfficer.docs.isNotEmpty) {
        _showError('You are already a member of this organization');
        return;
      }

      // Create officer record
      final officerDoc = firestore.collection('officers').doc();
      final officer = Officer(
        id: officerDoc.id,
        orgId: data['orgId'],
        userId: authService.firebaseUser!.uid,
        name: authService.user!.name,
        email: authService.user!.email,
        role: _parseRole(data['role']),
        status: OfficerStatus.pending,
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await officerDoc.set(officer.toMap());

      // Update user's organizations list
      await firestore
          .collection('users')
          .doc(authService.firebaseUser!.uid)
          .update({
            'organizations': FieldValue.arrayUnion([data['orgId']]),
          });

      // Save joined org and role to Hive under a simple meta box keyed by userId
      try {
        final metaBox = await Hive.openBox('userMeta');
        await metaBox.put(authService.firebaseUser!.uid, {
          'orgId': data['orgId'],
          'role': data['role'] ?? 'member',
        });
      } catch (e) {
        debugPrint('Error saving user meta to Hive: $e');
      }

      if (mounted) {
        _showSuccess(data['orgName']);
      }
    } catch (e) {
      _showError('Error processing QR code: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Map<String, dynamic>? _parseQRData(String qrData) {
    try {
      // Remove the curly braces and split by comma
      final cleanData = qrData.replaceAll('{', '').replaceAll('}', '');
      final pairs = cleanData.split(',');

      final Map<String, dynamic> data = {};
      for (final pair in pairs) {
        final keyValue = pair.split(':');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          final value = keyValue[1].trim();
          data[key] = value;
        }
      }

      return data;
    } catch (e) {
      return null;
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

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
      setState(() {
        _isScanning = true;
      });
    }
  }

  void _showSuccess(String orgName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success!'),
        content: Text(
          'You have successfully requested to join $orgName. Please wait for approval from the organization president.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainDashboard()),
              );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await cameraController.toggleTorch();
              setState(() {
                _torchEnabled = !_torchEnabled;
              });
            },
            tooltip: 'Toggle torch',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () async {
              await cameraController.switchCamera();
            },
            tooltip: 'Switch camera',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Join Organization',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Scan the QR code provided by the organization president to join',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // QR Scanner
          Expanded(
            child: _isScanning
                ? Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          MobileScanner(
                            controller: cameraController,
                            onDetect: _onDetect,
                            fit: BoxFit.cover,
                          ),

                          // Center scanning area overlay
                          Center(
                            child: Container(
                              width: 260,
                              height: 260,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 3,
                                ),
                                color: Colors.black.withOpacity(0.2),
                              ),
                            ),
                          ),

                          // Top instruction overlay
                          Positioned(
                            top: 24,
                            left: 24,
                            right: 24,
                            child: Text(
                              'Align the QR code inside the frame',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    shadows: [
                                      const Shadow(
                                        blurRadius: 4,
                                        color: Colors.black45,
                                      ),
                                    ],
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildProcessingView(),
          ),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_isScanning) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Point your camera at the QR code. It will scan automatically.',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _showManualEntryDialog,
                          child: const Text('Enter code'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isScanning = true;
                          });
                        },
                        child: const Text('Scan Again'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Invite Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Paste invite string',
              ),
              minLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim();
              Navigator.of(context).pop();
              if (code.isNotEmpty) _processQRCode(code);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingView() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Processing QR Code...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'Please wait while we verify the organization details',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
