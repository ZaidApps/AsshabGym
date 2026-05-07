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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Check-In',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: _shouldAutoCheckIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          final autoCheckIn = snapshot.data ?? false;
          return HomeScreen(autoTriggerCheckIn: autoCheckIn);
        },
      ),
    );
  }

  Future<bool> _shouldAutoCheckIn() async {
    // Check if URL contains scan parameters
    return _qrCheckInService.hasCheckInParameters();
  }
}
