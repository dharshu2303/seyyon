import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class FirebaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _alertsCollection = 'sos_alerts';

  /// Save an SOS alert to Firestore with location data
  static Future<bool> saveSosAlert({
    required double latitude,
    required double longitude,
    String? locationUrl,
    String? phoneNumber,
  }) async {
    try {
      await _db.collection(_alertsCollection).add({
        'latitude': latitude,
        'longitude': longitude,
        'location_url': locationUrl ?? '',
        'phone': phoneNumber ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'created_at': DateTime.now().toIso8601String(),
      });
      print('✅ SOS alert saved to Firestore');
      return true;
    } catch (e) {
      print('❌ Failed to save SOS alert: $e');
      return false;
    }
  }

  /// Fetch all SOS alerts from Firestore (within the last 90 days)
  static Future<List<SosAlertData>> fetchSosAlerts() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 90));
      final cutoffIso = cutoff.toIso8601String();

      QuerySnapshot snapshot;
      try {
        // Try ordered query first (requires Firestore index)
        snapshot = await _db
            .collection(_alertsCollection)
            .orderBy('timestamp', descending: true)
            .get();
      } catch (_) {
        // Fallback: fetch without ordering if index is missing
        print('⚠️ Firestore index not available, fetching without order');
        snapshot = await _db.collection(_alertsCollection).get();
      }

      List<SosAlertData> alerts = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['latitude'] != null && data['longitude'] != null) {
          // Filter by cutoff date using created_at field
          final createdAt = data['created_at'] as String? ?? '';
          if (createdAt.isNotEmpty && createdAt.compareTo(cutoffIso) < 0) {
            continue; // Skip alerts older than 90 days
          }
          alerts.add(SosAlertData(
            latitude: (data['latitude'] as num).toDouble(),
            longitude: (data['longitude'] as num).toDouble(),
            timestamp: createdAt,
          ));
        }
      }
      print('📊 Fetched ${alerts.length} SOS alerts from Firestore');
      return alerts;
    } catch (e) {
      print('❌ Failed to fetch SOS alerts: $e');
      return [];
    }
  }

  /// Get danger zones by clustering nearby SOS alerts
  /// Areas with 2+ SOS alerts within 500m radius = danger zone
  static Future<List<DangerCluster>> getDangerClusters({
    double clusterRadiusMeters = 500,
    int minAlertsForDanger = 1,
  }) async {
    List<SosAlertData> alerts = await fetchSosAlerts();
    if (alerts.isEmpty) return [];

    List<DangerCluster> clusters = [];
    List<bool> visited = List.filled(alerts.length, false);

    for (int i = 0; i < alerts.length; i++) {
      if (visited[i]) continue;
      visited[i] = true;

      List<SosAlertData> cluster = [alerts[i]];

      // Find all alerts within radius of this one
      for (int j = i + 1; j < alerts.length; j++) {
        if (visited[j]) continue;
        double dist = Geolocator.distanceBetween(
          alerts[i].latitude, alerts[i].longitude,
          alerts[j].latitude, alerts[j].longitude,
        );
        if (dist <= clusterRadiusMeters) {
          visited[j] = true;
          cluster.add(alerts[j]);
        }
      }

      if (cluster.length >= minAlertsForDanger) {
        // Calculate centroid of the cluster
        double avgLat = cluster.map((a) => a.latitude).reduce((a, b) => a + b) / cluster.length;
        double avgLng = cluster.map((a) => a.longitude).reduce((a, b) => a + b) / cluster.length;

        // Radius based on spread of alerts (min 100m)
        double maxDist = 100;
        for (var alert in cluster) {
          double d = Geolocator.distanceBetween(avgLat, avgLng, alert.latitude, alert.longitude);
          if (d > maxDist) maxDist = d;
        }

        clusters.add(DangerCluster(
          latitude: avgLat,
          longitude: avgLng,
          radiusMeters: maxDist + 50, // add buffer
          alertCount: cluster.length,
          severity: cluster.length >= 5 ? 'high' : (cluster.length >= 3 ? 'medium' : 'low'),
        ));
      }
    }

    print('🔴 Found ${clusters.length} danger clusters');
    return clusters;
  }
}

/// Data model for a single SOS alert
class SosAlertData {
  final double latitude;
  final double longitude;
  final String timestamp;

  SosAlertData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}

/// Data model for a cluster of nearby SOS alerts (= danger zone)
class DangerCluster {
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final int alertCount;
  final String severity; // 'low', 'medium', 'high'

  DangerCluster({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.alertCount,
    required this.severity,
  });
}
