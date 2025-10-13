import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:org_wallet/models/organization.dart';
import 'package:org_wallet/models/officer.dart';
import 'package:org_wallet/screens/main_dashboard.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:org_wallet/services/auth_service.dart';
import 'package:org_wallet/utils/snackbar_helper.dart';

class QRGeneratorScreen extends StatefulWidget {
  final Organization organization;

  const QRGeneratorScreen({super.key, required this.organization});

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  OfficerRole _selectedRole = OfficerRole.member;
  String? _qrData;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _generateQRCode();
  }

  void _generateQRCode() {
    final qrData = {
      'orgId': widget.organization.id,
      'orgName': widget.organization.name,
      'role': _selectedRole.toString().split('.').last,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _qrData = qrData.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Make the content scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Text(
                        'Invite Members',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Generate QR codes to invite members to your organization',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),

                      // Role Selection
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Role for Invite',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<OfficerRole>(
                                value: _selectedRole,
                                decoration: const InputDecoration(
                                  labelText: 'Role',
                                  border: OutlineInputBorder(),
                                ),
                                items: OfficerRole.values.map((role) {
                                  return DropdownMenuItem(
                                    value: role,
                                    child: Text(_getRoleDisplayName(role)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedRole = value;
                                      _generateQRCode();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // QR Code Display
                      if (_qrData != null) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                QrImageView(
                                  data: _qrData!,
                                  version: QrVersions.auto,
                                  size: 200.0,
                                  backgroundColor: Colors.white,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Scan this QR code to join as ${_getRoleDisplayName(_selectedRole)}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),

                                // Invite code (text) with copy action
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: _qrData ?? ''),
                                    );
                                    if (mounted) {
                                      SnackBarHelper.showSuccess(
                                        // ignore: use_build_context_synchronously
                                        context,
                                        message: 'Invite code copied',
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copy code'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),

              // Fixed Buttons at the Bottom
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isNavigating ? null : () async {
                        setState(() => _isNavigating = true);
                        
                        // Capture context before async operations
                        final navigator = Navigator.of(context);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final authService = Provider.of<AuthService>(context, listen: false);
                        
                        try {
                          // Switch to the newly created organization
                          await authService.switchOrganization(widget.organization.id);
                          
                          // Navigate to main dashboard
                          if (mounted) {
                            navigator.pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const MainDashboard(),
                              ),
                            );
                          }
                        } catch (e) {
                          // Handle error if organization switch fails
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Error switching to organization: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setState(() => _isNavigating = false);
                          }
                        }
                      },
                      child: _isNavigating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleDisplayName(OfficerRole role) {
    switch (role) {
      case OfficerRole.president:
        return 'President';
      case OfficerRole.treasurer:
        return 'Treasurer';
      case OfficerRole.secretary:
        return 'Secretary';
      case OfficerRole.auditor:
        return 'Auditor';
      case OfficerRole.moderator:
        return 'Moderator';
      case OfficerRole.member:
        return 'Member';
    }
  }
}
