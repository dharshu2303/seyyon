import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'sms_service.dart';
import 'call_service.dart';

/// Cross-platform SOS dispatch service
/// Android: uses native MethodChannel (silent, automatic)
/// iOS/fallback: uses url_launcher sms:/tel: URIs (requires one tap to confirm)
class PlatformDispatchService {
  /// Send SMS to a phone number with a message
  /// Returns true if dispatched successfully
  static Future<bool> sendSms(String phoneNumber, String message) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Android: use native MethodChannel for silent SMS
    if (Platform.isAndroid) {
      try {
        return await SmsService.sendSms(cleanNumber, message);
      } catch (e) {
        print('Native SMS failed, falling back to url_launcher: $e');
      }
    }

    // iOS / fallback: use sms: URI
    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: cleanNumber,
        queryParameters: {'body': message},
      );
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      }
    } catch (e) {
      print('url_launcher SMS failed: $e');
    }

    return false;
  }

  /// Make an emergency call to a phone number
  /// Returns true if dispatched successfully
  static Future<bool> makeCall(String phoneNumber) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Android: use native MethodChannel for direct call
    if (Platform.isAndroid) {
      try {
        return await CallService.makeEmergencyCall(cleanNumber);
      } catch (e) {
        print('Native call failed, falling back to url_launcher: $e');
      }
    }

    // iOS / fallback: use tel: URI
    try {
      final Uri telUri = Uri(scheme: 'tel', path: cleanNumber);
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
        return true;
      }
    } catch (e) {
      print('url_launcher call failed: $e');
    }

    return false;
  }

  /// Send SOS message with location to a contact
  static Future<bool> sendSosMessage(String phoneNumber, String locationUrl) async {
    String message = 'SOS! Emergency alert!\n\n'
        'I need help! My current location:\n'
        '$locationUrl\n\n'
        'This is an automated emergency message from Seyyon.';
    return await sendSms(phoneNumber, message);
  }

  /// Share SOS message via any installed app (fallback for both platforms)
  static Future<void> shareViaAnyApp(String locationUrl) async {
    try {
      // Use share_plus for universal sharing
      // Import is conditional to avoid issues
      final message = '🆘 SOS Emergency!\n\n'
          'I need immediate help!\n'
          'My location: $locationUrl\n\n'
          'Sent via Seyyon Safety App';

      // Attempt URL-based share as universal fallback
      final Uri shareUri = Uri(
        scheme: 'https',
        host: 'wa.me',
        queryParameters: {'text': message},
      );
      if (await canLaunchUrl(shareUri)) {
        await launchUrl(shareUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Share fallback failed: $e');
    }
  }

  /// Check if platform supports silent (no-tap) SMS
  static bool supportsSilentSms() => Platform.isAndroid;

  /// Check if platform supports silent (no-tap) calling
  static bool supportsSilentCall() => Platform.isAndroid;
}
