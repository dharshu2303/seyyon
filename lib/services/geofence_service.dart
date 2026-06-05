import 'dart:async';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Geofence Entry Awareness Service
/// Monitors location changes and alerts user when entering amber/red zones.
/// Uses significant-change location monitoring (50m filter) to save battery.
/// Caches zone boundaries locally for offline checks.
class GeofenceService {
  static StreamSubscription<Position>? _positionSubscription;
  static bool _isMonitoring = false;
  static List<Map<String, dynamic>> _cachedZones = [];
  static String? _lastAlertedZoneKey;
  static DateTime? _lastAlertTime;
  static const Duration _alertCooldown = Duration(hours: 1);
  static const String _cachedZonesKey = 'cached_zone_boundaries';

  // Callback for zone entry notification
  static Function(Map<String, dynamic> zone)? _onZoneEntry;

  /// Start monitoring with significant-change location (50m filter)
  static Future<void> startMonitoring({
    required Function(Map<String, dynamic> zone) onZoneEntry,
  }) async {
    if (_isMonitoring) return;

    _onZoneEntry = onZoneEntry;
    _isMonitoring = true;

    // Load cached zones from local storage
    await _loadCachedZones();

    // Subscribe to position changes with 50m distance filter
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 50, // Only fire on 50m+ movement
      ),
    ).listen((Position position) {
      _checkZoneEntry(position);
    });

    print('🔔 Geofence monitoring started (50m filter)');
  }

  /// Stop monitoring
  static void stopMonitoring() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isMonitoring = false;
    print('🔕 Geofence monitoring stopped');
  }

  static bool get isMonitoring => _isMonitoring;

  /// Update cached zone boundaries (call when zones are fetched from backend)
  static Future<void> updateCachedZones(List<Map<String, dynamic>> zones) async {
    _cachedZones = zones.where((z) {
      final level = z['zone_level'] ?? 'green';
      return level == 'amber' || level == 'red';
    }).toList();

    // Persist to SharedPreferences for offline access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedZonesKey, jsonEncode(_cachedZones));
    print('💾 Cached ${_cachedZones.length} zone boundaries locally');
  }

  /// Load zones from local cache
  static Future<void> _loadCachedZones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? cached = prefs.getString(_cachedZonesKey);
      if (cached != null) {
        _cachedZones = List<Map<String, dynamic>>.from(
          (jsonDecode(cached) as List).map((z) => Map<String, dynamic>.from(z)),
        );
        print('💾 Loaded ${_cachedZones.length} cached zone boundaries');
      }
    } catch (e) {
      print('Failed to load cached zones: $e');
    }
  }

  /// Check if position is inside any amber/red zone
  static void _checkZoneEntry(Position position) {
    for (var zone in _cachedZones) {
      double zoneLat = (zone['grid_lat'] as num).toDouble();
      double zoneLng = (zone['grid_lng'] as num).toDouble();
      double radiusM = (zone['radius_meters'] as num?)?.toDouble() ?? 200.0;
      String level = zone['zone_level'] ?? 'green';

      if (level != 'amber' && level != 'red') continue;

      double distance = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        zoneLat, zoneLng,
      );

      if (distance <= radiusM) {
        String zoneKey = '$zoneLat|$zoneLng';

        // Debounce: don't re-alert for same zone within cooldown
        if (_lastAlertedZoneKey == zoneKey &&
            _lastAlertTime != null &&
            DateTime.now().difference(_lastAlertTime!) < _alertCooldown) {
          return;
        }

        _lastAlertedZoneKey = zoneKey;
        _lastAlertTime = DateTime.now();

        // Trigger silent awareness notification
        _triggerAwarenessAlert(zone);
        return;
      }
    }
  }

  /// Trigger silent vibration + notification
  static void _triggerAwarenessAlert(Map<String, dynamic> zone) {
    String level = zone['zone_level'] ?? 'amber';
    int score = (zone['safety_score'] as num?)?.toInt() ?? 50;

    print('⚠️ Entered ${level.toUpperCase()} zone (safety: $score/100)');

    // Silent vibration pattern (not alarming)
    HapticFeedback.mediumImpact();

    // Notify via callback — the screen will show a heads-up notification
    _onZoneEntry?.call(zone);
  }

  /// Get cached zones count
  static int get cachedZoneCount => _cachedZones.length;

  /// Dispose
  static void dispose() {
    stopMonitoring();
    _onZoneEntry = null;
  }
}
