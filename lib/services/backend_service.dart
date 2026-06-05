import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'offline_queue_service.dart';

class BackendService {
  static String _baseUrl = 'http://10.10.9.245/seyyon/api';
  static const Duration _timeout = Duration(seconds: 10);

  /// Initialize with saved server URL
  static Future<void> initialize() async {
    String? savedUrl = await StorageService.getServerUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
    }
  }

  /// Set and save the server URL
  static Future<void> setServerUrl(String url) async {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    await StorageService.saveServerUrl(_baseUrl);
  }

  /// Get current server URL
  static String getServerUrl() => _baseUrl;

  /// Generic POST helper for any API endpoint
  static Future<Map<String, dynamic>?> postJson(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ POST $endpoint failed: $e');
      return null;
    }
  }

  /// Save an SOS alert to the PHP/MySQL backend (with offline queue fallback)
  static Future<bool> saveSosAlert({
    required double latitude,
    required double longitude,
    String? locationUrl,
    String? phoneNumber,
    String? deviceId,
    String source = 'manual',
    bool? smsDelivered,
    bool? callConnected,
  }) async {
    final payload = {
      'latitude': latitude,
      'longitude': longitude,
      'location_url': locationUrl ?? '',
      'phone': phoneNumber ?? '',
      'device_id': deviceId ?? '',
      'source': source,
      'sms_delivered': smsDelivered == true ? 1 : (smsDelivered == false ? 0 : null),
      'call_connected': callConnected == true ? 1 : (callConnected == false ? 0 : null),
      'message': 'SOS Alert triggered',
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/save_alert.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ SOS alert saved to server');
          // Try to flush any queued alerts while we have connectivity
          OfflineQueueService.flushQueue();
          return true;
        }
      }
      print('❌ Server error: ${response.statusCode}');
      // Queue for offline retry
      await OfflineQueueService.enqueue(payload);
      return false;
    } catch (e) {
      print('❌ Failed to save SOS alert (queuing offline): $e');
      await OfflineQueueService.enqueue(payload);
      return false;
    }
  }

  /// Get scored danger zones from backend
  static Future<List<Map<String, dynamic>>> getZoneScores({
    double? lat,
    double? lng,
    double radiusKm = 10,
  }) async {
    try {
      String url = '$_baseUrl/get_zone_scores.php';
      if (lat != null && lng != null) {
        url += '?lat=$lat&lng=$lng&radius_km=$radiusKm';
      }

      final response = await http.get(Uri.parse(url)).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['zones'] != null) {
          return List<Map<String, dynamic>>.from(data['zones']);
        }
      }
      return [];
    } catch (e) {
      print('❌ Failed to fetch zone scores: $e');
      return [];
    }
  }

  /// Get safety score for a specific location
  static Future<Map<String, dynamic>?> getLocationScore(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/get_location_score.php?lat=$lat&lng=$lng'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      print('❌ Failed to get location score: $e');
      return null;
    }
  }

  /// Submit a community safety report
  static Future<bool> reportZone({
    required double latitude,
    required double longitude,
    required String deviceId,
    String reportType = 'unsafe_area',
    String note = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/report_zone.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'device_id': deviceId,
          'report_type': reportType,
          'note': note,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Failed to submit report: $e');
      return false;
    }
  }

  /// Delete all user data (DPDP compliance)
  static Future<bool> deleteUserData(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/delete_user_data.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Failed to delete user data: $e');
      return false;
    }
  }

  /// Get danger zone clusters (backward compatibility)
  static Future<List<DangerCluster>> getDangerClusters() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/get_danger_zones.php'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['clusters'] != null) {
          List<DangerCluster> clusters = [];
          for (var c in data['clusters']) {
            clusters.add(DangerCluster(
              latitude: (c['latitude'] as num).toDouble(),
              longitude: (c['longitude'] as num).toDouble(),
              radiusMeters: (c['radius_meters'] as num).toDouble(),
              alertCount: c['alert_count'] as int,
              severity: c['severity'] as String,
            ));
          }
          return clusters;
        }
      }
      return [];
    } catch (e) {
      print('❌ Failed to fetch danger zones: $e');
      return [];
    }
  }

  /// Test connection to the PHP backend
  static Future<bool> testConnection(String url) async {
    try {
      final testUrl = url.endsWith('/') ? '${url}test.php' : '$url/test.php';
      final response = await http.get(Uri.parse(testUrl)).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// Data model for a cluster of nearby SOS alerts (= danger zone)
class DangerCluster {
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final int alertCount;
  final String severity;

  DangerCluster({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.alertCount,
    required this.severity,
  });
}
