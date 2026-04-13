import 'package:cloud_firestore/cloud_firestore.dart';
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

        await _firestore.collection(pendingRegistrationsCollection).add({
          'device_id': rawDeviceId,
          'member_doc_id': memberDocId,
          'platform': _deviceType(),
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

      await dailyCheckinRef.set({
        'device_id': rawDeviceId,
        'member_doc_id': memberDocId,
        'phone_number': member.phoneNumber,
        'checkin_date': todayString,
        'checkin_time': timeFormatter.format(now),
        'timestamp': FieldValue.serverTimestamp(),
        'device_type': _deviceType(),
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

  String _deviceType() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
