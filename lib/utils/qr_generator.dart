import 'dart:html' as html;
import 'package:ashhab_gym_web/services/qr_checkin_service.dart';

import '../services/qr_checkin_service.dart';

class QRGenerator {
  // Generate QR code URL for device check-in
  static String generateCheckInQRUrl(String deviceId, {String? baseUrl}) {
    final base = baseUrl ?? _getCurrentBaseUrl();
    return QRCheckInService.generateQRCodeUrl(deviceId, base);
  }

  // Get current base URL
  static String _getCurrentBaseUrl() {
    try {
      final uri = html.window.location;
      final path = uri.pathname ?? '';
      return '${uri.origin}${path.replaceAll(RegExp(r'/+$'), '')}';
    } catch (e) {
      // Fallback for development or error cases
      return 'https://your-gym-app.com';
    }
  }

  // Generate QR code data for multiple devices
  static List<Map<String, String>> generateBatchQRUrls(List<String> deviceIds) {
    return deviceIds.map((deviceId) {
      return {
        'deviceId': deviceId,
        'qrUrl': generateCheckInQRUrl(deviceId),
        'shortUrl': generateShortUrl(deviceId),
      };
    }).toList();
  }

  // Generate short URL (for display purposes)
  static String generateShortUrl(String deviceId) {
    final base = _getCurrentBaseUrl();
    // Show only domain and device ID for better readability
    final domain = base.replaceAll(RegExp(r'https?://'), '').replaceAll(RegExp(r'/.*'), '');
    return '$domain/...$deviceId';
  }

  // Validate QR code URL format
  static bool isValidCheckInUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasQuery &&
             uri.queryParameters.containsKey('action') &&
             uri.queryParameters.containsKey('deviceId') &&
             uri.queryParameters['action'] == 'checkin';
    } catch (e) {
      return false;
    }
  }

  // Extract device ID from QR code URL
  static String? extractDeviceIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['deviceId'];
    } catch (e) {
      return null;
    }
  }

  // Generate QR code for admin dashboard (with different action)
  static String generateAdminQRUrl(String baseUrl) {
    return '$baseUrl?action=admin';
  }

  // Generate QR code for member registration
  static String generateRegistrationQRUrl(String deviceId, {String? baseUrl}) {
    final base = baseUrl ?? _getCurrentBaseUrl();
    return '$base?action=register&deviceId=$deviceId';
  }
}

// Extension for string manipulation
extension StringExtension on String {
  String get lastChars {
    if (length <= 8) return this;
    return substring(length - 8);
  }
}
