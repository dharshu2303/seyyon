import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'backend_service.dart';

enum ZoneType { safe, danger }

class SafeZone {
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final ZoneType type;
  final String icon;
  final String description;

  SafeZone({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.type,
    required this.icon,
    required this.description,
  });

  double distanceTo(double lat, double lng) {
    return Geolocator.distanceBetween(latitude, longitude, lat, lng);
  }
}

class SafeZoneService {
  static List<SafeZone> _zones = [];
  static Position? _lastKnownPosition;

  /// Load zones: safe zones are preset landmarks, danger zones come from Firestore
  static Future<List<SafeZone>> getZonesAroundLocation(Position position) async {
    _lastKnownPosition = position;
    _zones = [];

    // ── Safe zones: preset known-safe landmark types ──
    _zones.addAll(_generateSafeZones(position.latitude, position.longitude));

    // ── Danger zones: REAL data from server ──
    try {
      List<DangerCluster> clusters = await BackendService.getDangerClusters();

      for (int i = 0; i < clusters.length; i++) {
        final c = clusters[i];
        String severityLabel = c.severity == 'high'
            ? '🔴 High Risk'
            : (c.severity == 'medium' ? '🟠 Medium Risk' : '🟡 Risk');
        _zones.add(SafeZone(
          name: 'Danger Zone ${i + 1}',
          latitude: c.latitude,
          longitude: c.longitude,
          radiusMeters: c.radiusMeters.clamp(80, 500),
          type: ZoneType.danger,
          icon: '⚠️',
          description: '$severityLabel — ${c.alertCount} SOS alert(s) reported here',
        ));
      }
    } catch (e) {
      print('Could not fetch danger zones from Firebase: $e');
    }

    return _zones;
  }

  /// Find the nearest safe zone from a given point
  static SafeZone? getNearestSafeZone(double lat, double lng) {
    List<SafeZone> safeZones =
        _zones.where((z) => z.type == ZoneType.safe).toList();
    if (safeZones.isEmpty) return null;
    safeZones.sort(
        (a, b) => a.distanceTo(lat, lng).compareTo(b.distanceTo(lat, lng)));
    return safeZones.first;
  }

  /// Get a safe route from current location to the nearest safe zone
  static List<List<double>> getSafeRoute(double fromLat, double fromLng) {
    SafeZone? nearest = getNearestSafeZone(fromLat, fromLng);
    if (nearest == null) return [];
    return _calculateSafeRoute(
        fromLat, fromLng, nearest.latitude, nearest.longitude);
  }

  /// Get a safe route to a specific destination
  static List<List<double>> getSafeRouteTo(
      double fromLat, double fromLng, double toLat, double toLng) {
    return _calculateSafeRoute(fromLat, fromLng, toLat, toLng);
  }

  /// Calculate route waypoints that avoid danger zones
  static List<List<double>> _calculateSafeRoute(
      double fromLat, double fromLng, double toLat, double toLng) {
    List<List<double>> route = [];
    route.add([fromLat, fromLng]);

    int steps = 10;
    for (int i = 1; i < steps; i++) {
      double t = i / steps;
      double lat = fromLat + (toLat - fromLat) * t;
      double lng = fromLng + (toLng - fromLng) * t;

      // Deviate around danger zones
      for (var zone in _zones.where((z) => z.type == ZoneType.danger)) {
        double dist = Geolocator.distanceBetween(
            lat, lng, zone.latitude, zone.longitude);
        if (dist < zone.radiusMeters * 1.5) {
          double perpLat = -(toLng - fromLng) * 0.002;
          double perpLng = (toLat - fromLat) * 0.002;
          lat += perpLat;
          lng += perpLng;
        }
      }

      route.add([lat, lng]);
    }

    route.add([toLat, toLng]);
    return route;
  }

  /// Generate preset safe zones (common safe landmarks near user)
  static List<SafeZone> _generateSafeZones(
      double centerLat, double centerLng) {
    final random = Random(42);
    List<SafeZone> zones = [];

    List<Map<String, dynamic>> safeSpots = [
      {
        'name': 'City Police Station',
        'icon': '🏛️',
        'desc': 'Main police headquarters – 24/7 patrol',
        'dist': 0.008,
        'angle': 0.3
      },
      {
        'name': 'General Hospital',
        'icon': '🏥',
        'desc': '24/7 emergency care & ambulance',
        'dist': 0.012,
        'angle': 1.2
      },
      {
        'name': 'Fire Station No. 1',
        'icon': '🚒',
        'desc': 'Emergency fire & rescue services',
        'dist': 0.006,
        'angle': 2.5
      },
      {
        'name': 'Women Safety Center',
        'icon': '🛡️',
        'desc': 'Women helpline & safe shelter',
        'dist': 0.010,
        'angle': 3.8
      },
      {
        'name': 'Metro Station',
        'icon': '🚇',
        'desc': 'Crowded safe transit hub with CCTV',
        'dist': 0.005,
        'angle': 4.5
      },
      {
        'name': 'Community Center',
        'icon': '🏢',
        'desc': 'Public community space with security',
        'dist': 0.014,
        'angle': 5.5
      },
      {
        'name': 'Traffic Police Post',
        'icon': '👮',
        'desc': 'Traffic police booth – always staffed',
        'dist': 0.009,
        'angle': 0.9
      },
      {
        'name': 'Primary Health Center',
        'icon': '⚕️',
        'desc': 'Government health clinic',
        'dist': 0.011,
        'angle': 4.0
      },
    ];

    for (var spot in safeSpots) {
      double angle = spot['angle'] as double;
      double dist = spot['dist'] as double;
      zones.add(SafeZone(
        name: spot['name'],
        latitude: centerLat + dist * cos(angle),
        longitude: centerLng + dist * sin(angle),
        radiusMeters: 80 + random.nextDouble() * 120,
        type: ZoneType.safe,
        icon: spot['icon'],
        description: spot['desc'],
      ));
    }

    return zones;
  }

  static List<SafeZone> get zones => _zones;
  static Position? get lastKnownPosition => _lastKnownPosition;
}
