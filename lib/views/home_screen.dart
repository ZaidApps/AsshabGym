import 'package:flutter/material.dart';

import 'qr_scan_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool autoTriggerScan;
  final bool autoTriggerCheckIn;

  const HomeScreen({super.key, this.autoTriggerScan = false, this.autoTriggerCheckIn = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  void _triggerAutoCheckIn() {
    // This will trigger the existing scanner logic to detect device and check-in automatically
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const QrScanScreen(),
      ),
    );
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
