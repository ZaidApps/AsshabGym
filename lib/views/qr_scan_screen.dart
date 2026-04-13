import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../controllers/checkin_controller.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _checkInController = CheckInController();
  bool _isProcessing = false;

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final rawValue = barcode?.rawValue;
    if (rawValue == null) return;

    setState(() {
      _isProcessing = true;
    });

    final result = await _checkInController.handleQrScan(rawValue);

    if (!mounted) return;

    final title = _dialogTitleForStatus(result.status);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(result.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (_shouldPopScanner(result.status)) {
      Navigator.of(context).pop();
    }
  }

  bool _shouldPopScanner(CheckInStatus status) {
    switch (status) {
      case CheckInStatus.success:
      case CheckInStatus.alreadyCheckedIn:
      case CheckInStatus.membershipExpired:
      case CheckInStatus.newDeviceRegistered:
      case CheckInStatus.membershipPending:
        return true;
      case CheckInStatus.invalidQr:
      case CheckInStatus.profileNotFound:
      case CheckInStatus.membershipIssue:
      case CheckInStatus.unknownError:
        return false;
    }
  }

  String _dialogTitleForStatus(CheckInStatus status) {
    switch (status) {
      case CheckInStatus.success:
        return 'Check-in successful';
      case CheckInStatus.invalidQr:
        return 'Invalid QR Code';
      case CheckInStatus.profileNotFound:
        return 'Profile not found';
      case CheckInStatus.membershipIssue:
        return 'Membership issue';
      case CheckInStatus.membershipExpired:
        return 'Membership expired';
      case CheckInStatus.membershipPending:
        return 'Membership pending';
      case CheckInStatus.newDeviceRegistered:
        return 'New device registered';
      case CheckInStatus.alreadyCheckedIn:
        return 'Already checked in';
      case CheckInStatus.unknownError:
        return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Check-In QR'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Point your camera at the gym entrance QR code to check in.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MobileScanner(
                  fit: BoxFit.cover,
                  onDetect: _handleBarcode,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
