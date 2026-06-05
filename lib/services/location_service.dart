import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'storage_service.dart';

class LocationService {
  static Position? _lastKnownPosition;
  static Timer? _cacheTimer;

  // Request location permission
  static Future<bool> requestLocationPermission() async {
    if (kIsWeb) return true;
    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }
    return status.isGranted;
  }

  // Get current location with timeout and fallback
  static Future<Position?> getCurrentLocation() async {
    try {
      if (!kIsWeb) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          print('Location services are disabled.');
          return _lastKnownPosition;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return _lastKnownPosition;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return _lastKnownPosition;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _lastKnownPosition = position;

      // Cache the position for offline use
      await StorageService.saveCachedLocation(
        position.latitude,
        position.longitude,
      );

      return position;
    } catch (e) {
      print('Error getting location: $e');
      try {
        Position? last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          _lastKnownPosition = last;
          return last;
        }
      } catch (_) {}

      // Fallback to cached location from SharedPreferences
      if (_lastKnownPosition == null) {
        final cached = await StorageService.getCachedLocation();
        if (cached != null) {
          _lastKnownPosition = Position(
            latitude: cached['lat']!,
            longitude: cached['lng']!,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
          print('📍 Using cached location from storage');
        }
      }

      return _lastKnownPosition;
    }
  }

  /// Returns the last known position (cached in memory)
  static Position? get lastKnownPosition => _lastKnownPosition;

  /// Start periodic GPS caching (every 5 minutes) for offline resilience
  static void startPeriodicCache() {
    _cacheTimer?.cancel();
    _cacheTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      try {
        final pos = await getCurrentLocation();
        if (pos != null) {
          await StorageService.saveCachedLocation(pos.latitude, pos.longitude);
          print('💾 GPS cached: ${pos.latitude}, ${pos.longitude}');
        }
      } catch (e) {
        print('GPS cache failed: $e');
      }
    });
  }

  /// Stop periodic GPS caching
  static void stopPeriodicCache() {
    _cacheTimer?.cancel();
    _cacheTimer = null;
  }

  // Format location as Google Maps URL
  static String formatLocationUrl(Position position) {
    return 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
  }

  // Get location as text
  static String formatLocationText(Position position) {
    return 'Lat: ${position.latitude.toStringAsFixed(6)}, Long: ${position.longitude.toStringAsFixed(6)}';
  }

  // Get location URL (convenience method)
  static Future<String> getLocationUrl() async {
    Position? position = await getCurrentLocation();
    if (position != null) {
      return formatLocationUrl(position);
    }

    // Fallback: try cached location
    final cached = await StorageService.getCachedLocation();
    if (cached != null) {
      return 'https://maps.google.com/?q=${cached['lat']},${cached['lng']}';
    }

    return 'Location unavailable';
  }

  // Get location text (convenience method)
  static Future<String> getLocationText() async {
    Position? position = await getCurrentLocation();
    if (position != null) {
      return formatLocationText(position);
    }
    return 'Location unavailable';
  }

  /// Dispose
  static void dispose() {
    stopPeriodicCache();
  }
}
