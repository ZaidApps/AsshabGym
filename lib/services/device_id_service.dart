import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Stable per-install / per-device identifier used as the member key in Firestore.
///
/// - Android: [Settings.Secure.ANDROID_ID] via `device_info_plus` (not Wi‑Fi MAC;
///   MAC is not available to normal apps on modern Android).
/// - iOS: `identifierForVendor`.
/// - Web: random UUID persisted in [SharedPreferences] for this browser/profile.
class DeviceIdService {
  DeviceIdService._();

  static const _prefsKey = 'gym_member_device_id';

  static String sanitizeForFirestoreDocId(String raw) {
    if (raw.isEmpty) return 'unknown_device';
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static Future<String> getRawDeviceId() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_prefsKey);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await prefs.setString(_prefsKey, id);
      }
      return id;
    }

    final plugin = DeviceInfoPlugin();

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final info = await plugin.androidInfo;
        return info.id;
      case TargetPlatform.iOS:
        final info = await plugin.iosInfo;
        return info.identifierForVendor ?? 'ios_unknown';
      case TargetPlatform.macOS:
        final info = await plugin.macOsInfo;
        return info.systemGUID ?? 'macos_unknown';
      case TargetPlatform.windows:
        final info = await plugin.windowsInfo;
        return info.deviceId;
      case TargetPlatform.linux:
        final info = await plugin.linuxInfo;
        return info.machineId ?? 'linux_unknown';
      default:
        return 'unsupported_${defaultTargetPlatform.name}';
    }
  }

  static Future<String> getMemberDocumentId() async {
    final raw = await getRawDeviceId();
    return sanitizeForFirestoreDocId(raw);
  }
}
