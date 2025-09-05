// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker_app/services/auth_service.dart';
import 'package:expense_tracker_app/models/officer.dart';
import 'package:expense_tracker_app/screens/main_dashboard.dart';

class ScanQRScreen extends StatefulWidget {
  const ScanQRScreen({super.key});

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isScanning = true;
  bool _isProcessing = false;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null && !_isProcessing) {
        _processQRCode(scanData.code!);
      }
    });
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
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
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
        content: Text('You have successfully requested to join $orgName. Please wait for approval from the organization president.'),
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
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // QR Scanner
          Expanded(
            child: _isScanning
                ? Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: QRView(
                        key: qrKey,
                        onQRViewCreated: _onQRViewCreated,
                        overlay: QrScannerOverlayShape(
                          borderColor: Theme.of(context).colorScheme.primary,
                          borderRadius: 10,
                          borderLength: 30,
                          borderWidth: 10,
                          cutOutSize: 250,
                        ),
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
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
                            'Point your camera at the QR code. The app will automatically scan and process it.',
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
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
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
