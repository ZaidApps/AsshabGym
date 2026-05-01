import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_strategy/url_strategy.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set URL strategy for web
  if (kIsWeb) {
    setPathUrlStrategy();
  }

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyBp2n49gFWQGiH4tDxr641HTj8kILU9y0w',
        authDomain: 'ashhabgymweb.firebaseapp.com',
        projectId: 'ashhabgymweb',
        storageBucket: 'ashhabgymweb.firebasestorage.app',
        messagingSenderId: '439303536524',
        appId: '1:439303536524:web:06dd98fa3d0425c77fa0a9',
        measurementId: 'G-JB0Y9P090Y',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const GymApp());
}
