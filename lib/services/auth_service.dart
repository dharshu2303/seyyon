import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'backend_service.dart';

/// Handles device authentication and JWT token management
class AuthService {
  static String? _token;
  static String? _deviceId;

  /// Initialize auth — get or create device token
  static Future<void> initialize() async {
    _deviceId = await StorageService.getDeviceId();
    _token = await StorageService.getAuthToken();

    // If no token or token might be expired, request new one
    if (_token == null || _token!.isEmpty) {
      await _requestToken();
    }
  }

  /// Request a new JWT token from backend
  static Future<bool> _requestToken() async {
    try {
      final baseUrl = BackendService.getServerUrl();
      final deviceId = await StorageService.getDeviceId();

      final response = await http.post(
        Uri.parse('$baseUrl/auth.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': deviceId,
          'platform': 'android', // TODO: detect platform
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['token'] != null) {
          _token = data['token'];
          await StorageService.saveAuthToken(_token!);
          print('✅ Auth token obtained');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('⚠️ Auth token request failed: $e');
      return false;
    }
  }

  /// Get current token (refreshes if needed)
  static Future<String?> getToken() async {
    if (_token == null || _token!.isEmpty) {
      await _requestToken();
    }
    return _token;
  }

  /// Get auth headers for API requests
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get device ID
  static Future<String> getDeviceId() async {
    _deviceId ??= await StorageService.getDeviceId();
    return _deviceId!;
  }

  /// Clear token (on logout or data deletion)
  static Future<void> clearToken() async {
    _token = null;
    await StorageService.saveAuthToken('');
  }
}
