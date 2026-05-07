import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/member.dart';
import '../services/device_id_service.dart';

enum CheckInStatus {
  success,
  invalidQr,
  profileNotFound,
  membershipIssue,
  membershipExpired,
  membershipPending,
  newDeviceRegistered,
  alreadyCheckedIn,
  unknownError,
}

class CheckInResult {
  final CheckInStatus status;
  final String message;

  const CheckInResult({
    required this.status,
    required this.message,
  });
}

class CheckInController {
  CheckInController({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static String? _cachedDeviceType;

  static const String expectedQrValue = 'GYM_CHECKIN';
  static const String membersCollection = 'members';
  static const String pendingRegistrationsCollection =
      'pending_device_registrations';

  Future<CheckInResult> handleQrScan(String qrValue) async {
    try {
      if (qrValue.trim() != expectedQrValue) {
        return const CheckInResult(
          status: CheckInStatus.invalidQr,
          message:
              'Invalid QR Code. Please scan the official gym check-in code.',
        );
      }

      final rawDeviceId = await DeviceIdService.getRawDeviceId();
      final memberDocId = DeviceIdService.sanitizeForFirestoreDocId(rawDeviceId);
      final memberRef =
          _firestore.collection(membersCollection).doc(memberDocId);
      final memberSnap = await memberRef.get();

      if (!memberSnap.exists) {
        final now = DateTime.now();
        final dateFormatter = DateFormat('yyyy-MM-dd');
        final timeFormatter = DateFormat('HH:mm');

        await memberRef.set({
          'device_id': rawDeviceId,
          'phone_number': '',
          'membership_status': Member.statusPending,
          'first_scan_date': dateFormatter.format(now),
          'first_scan_time': timeFormatter.format(now),
          'created_at': FieldValue.serverTimestamp(),
        });

        // Initialize device type info
      await _deviceType();
      
      await _firestore.collection(pendingRegistrationsCollection).add({
          'device_id': rawDeviceId,
          'member_doc_id': memberDocId,
          'platform': _deviceTypeSync(),
          'created_at': FieldValue.serverTimestamp(),
          'acknowledged': false,
        });

        return CheckInResult(
          status: CheckInStatus.newDeviceRegistered,
          message:
              'This device has been registered.\n'
              'Device ID: $rawDeviceId\n\n'
              'Please see reception to complete your membership. '
              'Staff will see this as a new device in the admin app.',
        );
      }

      final member = Member.fromDocument(memberSnap);

      if (member.isPending) {
        return const CheckInResult(
          status: CheckInStatus.membershipPending,
          message:
              'Your membership is not active yet.\n'
              'Please see reception to activate your account.',
        );
      }

      final expiryTimestamp = member.subscriptionExpiryDate;
      if (expiryTimestamp == null) {
        return const CheckInResult(
          status: CheckInStatus.membershipIssue,
          message:
              'Your membership expiry date is not set. Please contact the gym reception.',
        );
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expiry = expiryTimestamp.toDate();
      final expiryDateOnly = DateTime(expiry.year, expiry.month, expiry.day);

      final dateFormatter = DateFormat('yyyy-MM-dd');
      final timeFormatter = DateFormat('HH:mm');

      if (today.isAfter(expiryDateOnly)) {
        await _firestore.collection('expired_checkin_attempts').add({
          'device_id': rawDeviceId,
          'member_doc_id': memberDocId,
          'phone_number': member.phoneNumber,
          'attempt_date': dateFormatter.format(now),
          'attempt_time': timeFormatter.format(now),
          'subscription_expiry_date': expiryTimestamp,
          'timestamp': FieldValue.serverTimestamp(),
        });

        return const CheckInResult(
          status: CheckInStatus.membershipExpired,
          message:
              'Your gym membership has expired.\nPlease renew your subscription.',
        );
      }

      final todayString = dateFormatter.format(now);

      // One document per member per calendar day — avoids a composite index on
      // (device_id, checkin_date).
      final dailyCheckinId = '${memberDocId}_$todayString';
      final dailyCheckinRef =
          _firestore.collection('checkins').doc(dailyCheckinId);
      final existingDaily = await dailyCheckinRef.get();

      if (existingDaily.exists) {
        return const CheckInResult(
          status: CheckInStatus.alreadyCheckedIn,
          message: 'You have already checked in today.',
        );
      }

      // Initialize device type info if not already done
      if (_cachedDeviceType == null) await _deviceType();
      
      await dailyCheckinRef.set({
        'device_id': rawDeviceId,
        'member_doc_id': memberDocId,
        'phone_number': member.phoneNumber,
        'checkin_date': todayString,
        'checkin_time': timeFormatter.format(now),
        'timestamp': FieldValue.serverTimestamp(),
        'device_type': _deviceTypeSync(),
      });

      return CheckInResult(
        status: CheckInStatus.success,
        message:
            'You have successfully checked in on $todayString at ${timeFormatter.format(now)}.',
      );
    } on FirebaseException catch (e, st) {
      if (kDebugMode) {
        debugPrint('Check-in FirebaseException: ${e.code} ${e.message}\n$st');
      }
      return CheckInResult(
        status: CheckInStatus.unknownError,
        message: _messageForFirebaseException(e),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Check-in error: $e\n$st');
      }
      return CheckInResult(
        status: CheckInStatus.unknownError,
        message: kDebugMode
            ? 'Something went wrong: $e'
            : 'Something went wrong while processing your check-in.',
      );
    }
  }

  String _messageForFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Access denied (Firestore rules). In Firebase Console → '
            'Firestore → Rules, allow read/write for collections: members, '
            'pending_device_registrations, checkins, expired_checkin_attempts '
            'for your app (e.g. while testing: allow read, write: if true — '
            'then tighten before production).';
      case 'unavailable':
        return 'Firestore is temporarily unavailable. Check your internet '
            'connection and try again.';
      case 'failed-precondition':
        final msg = e.message ?? '';
        if (msg.contains('index') || msg.contains('Index')) {
          return 'Database index required. If a URL appears in the logs, open '
              'it to create the index, or try again after updating the app.';
        }
        return 'Request could not be completed (${e.code}). ${e.message ?? ''}';
      default:
        return 'Could not reach the database (${e.code}). '
            '${e.message ?? "Please try again."}';
    }
  }

  Future<String> _deviceType() async {
    print('DEBUG: _deviceType() called');
    if (_cachedDeviceType != null) {
      print('DEBUG: Returning cached device type: $_cachedDeviceType');
      return _cachedDeviceType!;
    }
    
    if (kIsWeb) {
      _cachedDeviceType = 'web';
      print('DEBUG: Set device type to web');
      return _cachedDeviceType!;
    }
    
    print('DEBUG: Platform: ${defaultTargetPlatform}');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        _cachedDeviceType = await _getAndroidDeviceInfo();
        print('DEBUG: Set device type to Android result: $_cachedDeviceType');
        return _cachedDeviceType!;
      case TargetPlatform.iOS:
        _cachedDeviceType = await _getIOSDeviceInfo();
        print('DEBUG: Set device type to iOS result: $_cachedDeviceType');
        return _cachedDeviceType!;
      case TargetPlatform.macOS:
        _cachedDeviceType = 'macos';
        print('DEBUG: Set device type to macOS');
        return _cachedDeviceType!;
      case TargetPlatform.windows:
        _cachedDeviceType = 'windows';
        print('DEBUG: Set device type to Windows');
        return _cachedDeviceType!;
      case TargetPlatform.linux:
        _cachedDeviceType = 'linux';
        print('DEBUG: Set device type to Linux');
        return _cachedDeviceType!;
      case TargetPlatform.fuchsia:
        _cachedDeviceType = 'fuchsia';
        print('DEBUG: Set device type to Fuchsia');
        return _cachedDeviceType!;
    }
  }

  String _deviceTypeSync() {
    return _cachedDeviceType ?? 'unknown';
  }

  Future<String> _getAndroidDeviceInfo() async {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final brand = androidInfo.brand ?? 'Unknown';
      final model = androidInfo.model ?? 'Unknown';
      final product = androidInfo.product ?? 'Unknown';
      
      print('DEBUG: Android Device Info - Brand: $brand, Model: $model, Product: $product');
      
      // Format: Samsung Galaxy Note 20 (SM-N975F)
      if (brand.toLowerCase() == 'samsung') {
        final deviceInfo = '$brand $model ($product)';
        print('DEBUG: Formatted Samsung device: $deviceInfo');
        return deviceInfo;
      }
      
      // Format: Google Pixel 7 (redfin)
      if (brand.toLowerCase() == 'google') {
        final deviceInfo = '$brand $model ($product)';
        print('DEBUG: Formatted Google device: $deviceInfo');
        return deviceInfo;
      }
      
      // Format: OnePlus 9 (LE2123)
      if (brand.toLowerCase() == 'oneplus') {
        final deviceInfo = '$brand $model ($product)';
        print('DEBUG: Formatted OnePlus device: $deviceInfo');
        return deviceInfo;
      }
      
      // Format: Xiaomi Redmi Note 10 (sweet)
      if (brand.toLowerCase() == 'xiaomi') {
        final deviceInfo = '$brand $model ($product)';
        print('DEBUG: Formatted Xiaomi device: $deviceInfo');
        return deviceInfo;
      }
      
      // Default format for other Android devices
      final deviceInfo = '$brand $model';
      print('DEBUG: Formatted default Android device: $deviceInfo');
      return deviceInfo;
    } catch (e) {
      print('DEBUG: Error getting Android device info: $e');
      return 'android';
    }
  }

  Future<String> _getIOSDeviceInfo() async {
    try {
      final iosInfo = await DeviceInfoPlugin().iosInfo;
      final name = iosInfo.name ?? 'Unknown';
      final model = iosInfo.model ?? 'Unknown';
      final localizedModel = iosInfo.localizedModel ?? 'Unknown';
      
      print('DEBUG: iOS Device Info - Name: $name, Model: $model, Localized: $localizedModel');
      
      // Format: iPhone 13 (iPhone14,3)
      if (name.contains('iPhone')) {
        final deviceInfo = '$name $model';
        print('DEBUG: Formatted iPhone device: $deviceInfo');
        return deviceInfo;
      }
      
      // Format: iPad Pro 12.9-inch (iPad13,8)
      if (name.contains('iPad')) {
        final deviceInfo = '$name $model';
        print('DEBUG: Formatted iPad device: $deviceInfo');
        return deviceInfo;
      }
      
      // Format for other iOS devices
      final deviceInfo = '$name $localizedModel';
      print('DEBUG: Formatted default iOS device: $deviceInfo');
      return deviceInfo;
    } catch (e) {
      print('DEBUG: Error getting iOS device info: $e');
      return 'ios';
    }
  }
}
