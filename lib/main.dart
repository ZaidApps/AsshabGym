import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_strategy/url_strategy.dart';
import 'dart:html' as html;

import 'app.dart';

Map<String, String> _urlParameters = {};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture URL parameters before Flutter processes them
  if (kIsWeb) {
    try {
      // Try multiple methods to capture URL parameters
      String? href;
      
      // Method 1: window.location.href
      href = html.window.location.href;
      print('DEBUG: Method 1 - window.location.href: $href');
      
      // Method 2: window.location.href (same as method 1)
      if (href == null || href.isEmpty) {
        href = html.window.location.href;
        print('DEBUG: Method 2 - fallback window.location.href: $href');
      }
      
      // Method 3: window.location.search
      if (href != null && !href.contains('?')) {
        final search = html.window.location.search;
        print('DEBUG: Method 3 - window.location.search: $search');
        if (search != null && search.isNotEmpty) {
          href = '${html.window.location.origin}${html.window.location.pathname}$search';
          print('DEBUG: Method 3 - Reconstructed href: $href');
        }
      }
      
      if (href != null && href.isNotEmpty) {
        final uri = Uri.parse(href);
        _urlParameters = uri.queryParameters;
        print('DEBUG: Final captured URL parameters: $_urlParameters');
      } else {
        print('DEBUG: No valid URL found, using empty parameters');
        _urlParameters = {};
      }
    } catch (e) {
      print('DEBUG: Error capturing URL parameters: $e');
      _urlParameters = {};
    }
    
    // Use hash URL strategy to preserve query parameters
    setHashUrlStrategy();
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
