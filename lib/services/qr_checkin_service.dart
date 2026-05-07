import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/checkin.dart';

class QRCheckInService {
  static final QRCheckInService _instance = QRCheckInService._internal();
  factory QRCheckInService() => _instance;
  QRCheckInService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isProcessing = false;

  // Check if URL contains scan parameters
  bool hasCheckInParameters() {
    try {
      Map<String, String>? params;
      
      if (kIsWeb) {
        // For web, try multiple methods to get URL parameters
        
        // Method 1: Try window.location.href
        try {
          final currentUrl = html.window.location.href;
          print('DEBUG: Method 1 - Window location href: $currentUrl');
          final uri = Uri.parse(currentUrl);
          params = uri.queryParameters;
          print('DEBUG: Method 1 - Parsed query parameters: $params');
        } catch (e) {
          print('DEBUG: Method 1 - Error using window.location: $e');
        }
        
        // Method 2: Try window.location.search (more reliable for query params)
        if (params == null || params.isEmpty) {
          try {
            final search = html.window.location.search;
            print('DEBUG: Method 2 - Window location search: $search');
            if (search != null && search.isNotEmpty) {
              if (search.startsWith('?')) {
                final queryString = search.substring(1);
                params = Uri.splitQueryString(queryString);
              } else {
                params = Uri.splitQueryString(search);
              }
              print('DEBUG: Method 2 - Parsed search parameters: $params');
            }
          } catch (e) {
            print('DEBUG: Method 2 - Error using window.location.search: $e');
          }
        }
        
        // Method 3: Try to get from URL hash (for hash URL strategy)
        if (params == null || params.isEmpty) {
          try {
            final hash = html.window.location.hash;
            print('DEBUG: Method 3 - Window location hash: $hash');
            if (hash.isNotEmpty && hash.contains('?')) {
              final hashParts = hash.split('?');
              if (hashParts.length > 1) {
                final queryString = hashParts[1];
                params = Uri.splitQueryString(queryString);
                print('DEBUG: Method 3 - Parsed hash parameters: $params');
              }
            }
          } catch (e) {
            print('DEBUG: Method 3 - Error using window.location.hash: $e');
          }
        }
        
        // Method 4: Try to check if the URL contains the action parameter directly
        if (params == null || params.isEmpty) {
          try {
            final currentUrl = html.window.location.href;
            print('DEBUG: Method 4 - Checking URL directly: $currentUrl');
            if (currentUrl.contains('action=scan')) {
              print('DEBUG: Method 4 - Found action=scan in URL');
              params = {'action': 'scan'};
            }
          } catch (e) {
            print('DEBUG: Method 4 - Error checking URL directly: $e');
          }
        }
      } else {
        // For mobile, use Uri.base
        final uri = Uri.base;
        params = uri.queryParameters;
        print('DEBUG: Mobile query parameters: $params');
      }
      
      final hasScan = params?['action'] == 'scan';
      print('DEBUG: Final parameters: $params');
      print('DEBUG: Has scan parameter: $hasScan');
      return hasScan;
    } catch (e) {
      print('DEBUG: Error checking URL parameters: $e');
      return false;
    }
  }

  // Get device ID from URL parameters (not needed for universal QR code)
  String? getDeviceIdFromUrl() {
    try {
      final uri = Uri.base;
      return uri.queryParameters['deviceId'];
    } catch (e) {
      return null;
    }
  }

  // Process automatic check-in directly
  Future<Map<String, dynamic>> processAutoCheckIn() async {
    if (_isProcessing) {
      return {'success': false, 'message': 'Check-in already in progress'};
    }

    _isProcessing = true;
    
    try {
      // For universal QR code, we need to detect device UUID automatically
      // This will be done by the existing scanner logic
      
      // Return success to indicate check-in should proceed
      return {
        'success': true,
        'message': 'QR code detected - starting automatic check-in...',
        'autoCheckIn': true
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Error processing QR code: ${e.toString()}'
      };
    } finally {
      _isProcessing = false;
    }
  }

  // Check if already checked in today
  Future<bool> isAlreadyCheckedInToday(String deviceId) async {
    try {
      final today = DateTime.now();
      final todayString = '${today.day}-${today.month}-${today.year}';
      
      final query = await _firestore
          .collection('checkins')
          .where('device_id', isEqualTo: deviceId)
          .where('checkin_date', isEqualTo: todayString)
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Check in member
  Future<bool> checkInMember({
    required String deviceId,
    required Map<String, dynamic> memberData,
  }) async {
    try {
      // Create check-in record
      final now = DateTime.now();
      final checkIn = CheckIn(
        deviceId: deviceId,
        memberName: memberData['member_name'],
        checkinDate: '${now.day}-${now.month}-${now.year}',
        checkinTime: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        deviceType: detectPlatform(),
        timestamp: Timestamp.now(),
      );

      await _firestore.collection('checkins').add(checkIn.toFirestore());
      print('Check-in successful for device: $deviceId');
      return true;
    } catch (e) {
      print('Error checking in member: $e');
      return false;
    }
  }

  // Detect platform based on user agent
  String detectPlatform() {
    try {
      // For web, we can detect from user agent
      final userAgent = Uri.base.queryParameters['user_agent'] ?? '';
      if (userAgent.toLowerCase().contains('android')) return 'android';
      if (userAgent.toLowerCase().contains('iphone')) return 'ios';
      return 'web';
    } catch (e) {
      return 'web';
    }
  }

  // Generate QR code URL for a device
  static String generateQRCodeUrl(String deviceId, String baseUrl) {
    return '$baseUrl?action=scan&deviceId=$deviceId';
  }

  // Clear URL parameters after processing
  void clearUrlParameters() {
    try {
      // Navigate to clean URL
      final cleanUri = Uri.base.replace(queryParameters: {});
      // Note: In web, this would require using router or navigation
      // For now, we'll just clear the parameters from memory
    } catch (e) {
      // Handle error silently
    }
  }

  // Show check-in result dialog
  void showCheckInResult(BuildContext context, Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result['success'] ? Icons.check_circle : Icons.error,
              color: result['success'] ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(result['success'] ? 'Check-in Successful' : 'Check-in Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result['message']),
            if (result['memberName'] != null) ...[
              const SizedBox(height: 8),
              Text('Member: ${result['memberName']}'),
            ],
            if (result['checkInTime'] != null) ...[
              const SizedBox(height: 8),
              Text('Time: ${formatTime(result['checkInTime'])}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              clearUrlParameters();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
