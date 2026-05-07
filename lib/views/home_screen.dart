import 'package:flutter/material.dart';

import 'qr_scan_screen.dart';
import '../controllers/checkin_controller.dart';

class HomeScreen extends StatefulWidget {
  final bool autoTriggerScan;
  final bool autoTriggerCheckIn;

  const HomeScreen({super.key, this.autoTriggerScan = false, this.autoTriggerCheckIn = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CheckInController _checkInController = CheckInController();
  CheckInResult? _checkInResult;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoTriggerScan) {
      // Auto-trigger scan after a short delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerAutoScan();
      });
    } else if (widget.autoTriggerCheckIn) {
      // Auto-trigger check-in directly
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerAutoCheckIn();
      });
    }
  }

  void _triggerAutoScan() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const QrScanScreen(),
      ),
    );
  }

  void _triggerAutoCheckIn() async {
    setState(() {
      _isProcessing = true;
      _checkInResult = null;
    });

    // Directly trigger check-in logic with the expected QR value
    final result = await _checkInController.handleQrScan('GYM_CHECKIN');
    
    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _checkInResult = result;
    });
  }

  String _dialogTitleForStatus(CheckInStatus status) {
    switch (status) {
      case CheckInStatus.success:
        return 'Check-in Successful';
      case CheckInStatus.invalidQr:
        return 'Invalid QR Code';
      case CheckInStatus.profileNotFound:
        return 'Profile Not Found';
      case CheckInStatus.membershipIssue:
        return 'Membership Issue';
      case CheckInStatus.membershipExpired:
        return 'Membership Expired';
      case CheckInStatus.membershipPending:
        return 'Membership Pending';
      case CheckInStatus.newDeviceRegistered:
        return 'Device Registered';
      case CheckInStatus.alreadyCheckedIn:
        return 'Already Checked In';
      case CheckInStatus.unknownError:
        return 'Error';
    }
  }

  Color _getResultColor() {
    if (_checkInResult == null) return Colors.grey;
    switch (_checkInResult!.status) {
      case CheckInStatus.success:
        return Colors.green.withOpacity(0.1);
      case CheckInStatus.alreadyCheckedIn:
        return Colors.orange.withOpacity(0.1);
      case CheckInStatus.newDeviceRegistered:
        return Colors.blue.withOpacity(0.1);
      default:
        return Colors.red.withOpacity(0.1);
    }
  }

  Color _getResultBorderColor() {
    if (_checkInResult == null) return Colors.grey;
    switch (_checkInResult!.status) {
      case CheckInStatus.success:
        return Colors.green;
      case CheckInStatus.alreadyCheckedIn:
        return Colors.orange;
      case CheckInStatus.newDeviceRegistered:
        return Colors.blue;
      default:
        return Colors.red;
    }
  }

  Color _getResultTextColor() {
    if (_checkInResult == null) return Colors.grey;
    switch (_checkInResult!.status) {
      case CheckInStatus.success:
        return Colors.green;
      case CheckInStatus.alreadyCheckedIn:
        return Colors.orange;
      case CheckInStatus.newDeviceRegistered:
        return Colors.blue;
      default:
        return Colors.red;
    }
  }

  Color _getResultIconColor() {
    if (_checkInResult == null) return Colors.grey;
    switch (_checkInResult!.status) {
      case CheckInStatus.success:
        return Colors.green;
      case CheckInStatus.alreadyCheckedIn:
        return Colors.orange;
      case CheckInStatus.newDeviceRegistered:
        return Colors.blue;
      default:
        return Colors.red;
    }
  }

  IconData _getResultIcon() {
    if (_checkInResult == null) return Icons.info;
    switch (_checkInResult!.status) {
      case CheckInStatus.success:
        return Icons.check_circle;
      case CheckInStatus.alreadyCheckedIn:
        return Icons.info;
      case CheckInStatus.newDeviceRegistered:
        return Icons.app_registration;
      case CheckInStatus.profileNotFound:
        return Icons.person_off;
      case CheckInStatus.membershipExpired:
        return Icons.timer_off;
      case CheckInStatus.membershipPending:
        return Icons.pending;
      case CheckInStatus.membershipIssue:
        return Icons.warning;
      default:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ashhab Gym'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Welcome to Ashhab Gym',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Scan the entrance QR code to check in.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_isProcessing)
                const SizedBox(
                  width: 220,
                  height: 56,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Checking in...'),
                    ],
                  ),
                )
              else if (_checkInResult != null)
                Container(
                  width: 300,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getResultColor(),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getResultBorderColor(),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getResultIcon(),
                        color: _getResultIconColor(),
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _dialogTitleForStatus(_checkInResult!.status),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _getResultTextColor(),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _checkInResult!.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: _getResultTextColor().withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: 220,
                  height: 56,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text(
                      'SCAN QR CODE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const QrScanScreen(),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
