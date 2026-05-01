import 'package:ashhab_gym_web/services/qr_checkin_service.dart';
import 'package:flutter/material.dart';

import 'views/home_screen.dart';

class GymApp extends StatefulWidget {
  const GymApp({super.key});

  @override
  State<GymApp> createState() => _GymAppState();
}

class _GymAppState extends State<GymApp> {
  final QRCheckInService _qrCheckInService = QRCheckInService();

  @override
  void initState() {
    super.initState();
    _checkForAutoCheckIn();
  }

  Future<void> _checkForAutoCheckIn() async {
    // Wait a bit for the app to fully load
    await Future.delayed(const Duration(seconds: 1));
    
    if (_qrCheckInService.hasCheckInParameters()) {
      // Process automatic check-in
      final result = await _qrCheckInService.processAutoCheckIn();
      
      if (mounted && result['autoCheckIn'] == true) {
        // Navigate to home screen and trigger automatic check-in
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(autoTriggerCheckIn: true),
          ),
        );
      } else if (mounted) {
        // Show error dialog
        _qrCheckInService.showCheckInResult(context, result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Check-In',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
