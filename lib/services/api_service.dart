import 'dart:convert';
import 'package:http/http.dart' as http;
import 'location_service.dart';
import 'storage_service.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 15);

  /// Send SOS alert to the configured API endpoint
  static Future<bool> sendSosAlert({
    required String phoneNumber,
    required String locationUrl,
  }) async {
    try {
      String? apiUrl = await StorageService.getApiUrl();
      if (apiUrl == null || apiUrl.isEmpty) {
        print('API URL not configured');
        return false;
      }

      // Get detailed location
      final position = await LocationService.getCurrentLocation();

      final body = {
        'type': 'SOS_ALERT',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'emergencyContact': phoneNumber,
        'location': {
          'url': locationUrl,
          'latitude': position?.latitude,
          'longitude': position?.longitude,
        },
        'message': 'Emergency SOS alert triggered!',
      };

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-SOS-App': 'true',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('API alert sent successfully: ${response.statusCode}');
        return true;
      } else {
        print('API alert failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('API alert error: $e');
      return false;
    }
  }

  /// Test the API connection
  static Future<ApiTestResult> testConnection(String apiUrl) async {
    try {
      final body = {
        'type': 'TEST',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'message': 'SOS App connection test',
      };

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-SOS-App': 'true',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiTestResult(success: true, message: 'Connected (${response.statusCode})');
      } else {
        return ApiTestResult(success: false, message: 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      return ApiTestResult(success: false, message: 'Failed: $e');
    }
  }
}

class ApiTestResult {
  final bool success;
  final String message;

  ApiTestResult({required this.success, required this.message});
}
