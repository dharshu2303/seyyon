import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/location_service.dart';
import '../services/safe_zone_service.dart';
import '../services/backend_service.dart';
import '../services/geofence_service.dart';
import '../services/storage_service.dart';

class SafeMapScreen extends StatefulWidget {
  final bool panicMode;

  const SafeMapScreen({super.key, this.panicMode = false});

  @override
  State<SafeMapScreen> createState() => SafeMapScreenState();
}

class SafeMapScreenState extends State<SafeMapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  List<SafeZone> _zones = [];
  List<Map<String, dynamic>> _scoredZones = []; // from backend scoring engine
  List<LatLng> _safeRoute = [];
  SafeZone? _nearestSafe;
  bool _isLoading = true;
  bool _showRoute = false;
  String? _locationError;

  // Search
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _searchResult;
  bool _isSearching = false;
  LatLng? _searchMarker;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  @override
  void didUpdateWidget(SafeMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.panicMode && !oldWidget.panicMode) {
      _findSafeRoute();
    }
  }

  Future<void> _loadMapData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _locationError = null;
    });

    Position? position;
    try {
      position = await LocationService.getCurrentLocation();
    } catch (e) {
      print('Safe map location error: $e');
    }

    if (!mounted) return;

    // Use a default fallback if location is unavailable (New Delhi, India)
    if (position == null) {
      setState(() {
        _locationError = 'Could not get GPS location. Showing default area.\nPlease enable Location/GPS and tap Refresh.';
      });
      // Create a fake position so the map still renders
      position = Position(
        latitude: 28.6139,
        longitude: 77.2090,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    List<SafeZone> zones =
        await SafeZoneService.getZonesAroundLocation(position);

    // Fetch scored zones from backend
    List<Map<String, dynamic>> scored = await BackendService.getZoneScores(
      lat: position.latitude,
      lng: position.longitude,
      radiusKm: 10,
    );

    // Update geofence cache with scored zones
    GeofenceService.updateCachedZones(scored);

    if (!mounted) return;
    setState(() {
      _currentPosition = position;
      _zones = zones;
      _scoredZones = scored;
      _isLoading = false;
    });

    if (widget.panicMode) {
      _findSafeRoute();
    }
  }

  void _findSafeRoute() {
    if (_currentPosition == null) return;

    SafeZone? nearest = SafeZoneService.getNearestSafeZone(
        _currentPosition!.latitude, _currentPosition!.longitude);

    if (nearest != null) {
      List<List<double>> routePoints = SafeZoneService.getSafeRoute(
          _currentPosition!.latitude, _currentPosition!.longitude);

      setState(() {
        _nearestSafe = nearest;
        _safeRoute = routePoints.map((p) => LatLng(p[0], p[1])).toList();
        _showRoute = true;
      });

      _showSafeRouteInfo(nearest);
    }
  }

  void _showSafeRouteInfo(SafeZone zone) {
    if (!mounted) return;
    double dist = zone.distanceTo(
        _currentPosition!.latitude, _currentPosition!.longitude);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '🛡️ Nearest safe zone: ${zone.name} (${dist.toInt()}m away)'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Called externally (from MainScreen) when SOS is triggered
  void activatePanicRoute() {
    _findSafeRoute();
  }

  /// Called when user taps the Safe Map tab to ensure map data is loaded
  void reloadMap() {
    if (_currentPosition == null || _zones.isEmpty) {
      _loadMapData();
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.tealAccent),
              SizedBox(height: 16),
              Text('Loading Safe Map...',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    if (_currentPosition == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              const Text('Unable to get location',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              const Text('Please enable location services',
                  style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadMapData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final LatLng center =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    return Stack(
      children: [
        // ── Map ───────────────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15.0,
          ),
          children: [
            // OpenStreetMap tiles (free, no API key)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sos.app',
            ),

            // Scored zone circles from backend intelligence engine
            CircleLayer(
              circles: _scoredZones.map((z) {
                String level = z['zone_level'] ?? 'green';
                Color color;
                if (level == 'red') {
                  color = Colors.red;
                } else if (level == 'amber') {
                  color = Colors.orange;
                } else {
                  color = Colors.green;
                }
                return CircleMarker(
                  point: LatLng(
                    (z['grid_lat'] as num).toDouble(),
                    (z['grid_lng'] as num).toDouble(),
                  ),
                  radius: (z['radius_meters'] as num?)?.toDouble() ?? 200,
                  color: color.withOpacity(0.2),
                  borderColor: color.withOpacity(0.7),
                  borderStrokeWidth: 2,
                  useRadiusInMeter: true,
                );
              }).toList(),
            ),

            // Safe zone heatmap circles (local presets)
            CircleLayer(
              circles: _zones
                  .where((z) => z.type == ZoneType.safe)
                  .map((zone) => CircleMarker(
                        point: LatLng(zone.latitude, zone.longitude),
                        radius: zone.radiusMeters,
                        color: Colors.green.withOpacity(0.25),
                        borderColor: Colors.green.withOpacity(0.6),
                        borderStrokeWidth: 2,
                        useRadiusInMeter: true,
                      ))
                  .toList(),
            ),

            // Danger zone circles (local presets)
            CircleLayer(
              circles: _zones
                  .where((z) => z.type == ZoneType.danger)
                  .map((zone) => CircleMarker(
                        point: LatLng(zone.latitude, zone.longitude),
                        radius: zone.radiusMeters,
                        color: Colors.red.withOpacity(0.25),
                        borderColor: Colors.red.withOpacity(0.6),
                        borderStrokeWidth: 2,
                        useRadiusInMeter: true,
                      ))
                  .toList(),
            ),

            // Safe route polyline
            if (_showRoute && _safeRoute.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _safeRoute,
                    color: Colors.blue,
                    strokeWidth: 5.0,
                  ),
                ],
              ),

            // Zone markers + scored zone badges + current location
            MarkerLayer(
              markers: [
                // Scored zone score badges
                ..._scoredZones.map((z) {
                  String level = z['zone_level'] ?? 'green';
                  int safetyScore = (z['safety_score'] as num?)?.toInt() ?? 100;
                  Color badgeColor = level == 'red'
                      ? Colors.red.shade700
                      : level == 'amber'
                          ? Colors.orange.shade700
                          : Colors.green.shade700;
                  return Marker(
                    point: LatLng(
                      (z['grid_lat'] as num).toDouble(),
                      (z['grid_lng'] as num).toDouble(),
                    ),
                    width: 36,
                    height: 36,
                    child: GestureDetector(
                      onTap: () => _showScoredZoneDetails(z),
                      child: Container(
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(color: badgeColor.withOpacity(0.5), blurRadius: 6),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$safetyScore',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Local zone icon markers
                ..._zones.map((zone) => Marker(
                      point: LatLng(zone.latitude, zone.longitude),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showZoneDetails(zone),
                        child: Container(
                          decoration: BoxDecoration(
                            color: zone.type == ZoneType.safe
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: (zone.type == ZoneType.safe
                                        ? Colors.green
                                        : Colors.red)
                                    .withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(zone.icon,
                                style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                      ),
                    )),

                // Search marker
                if (_searchMarker != null)
                  Marker(
                    point: _searchMarker!,
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.purple.shade700,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(color: Colors.purple.withOpacity(0.6), blurRadius: 12),
                        ],
                      ),
                      child: const Icon(Icons.search, color: Colors.white, size: 22),
                    ),
                  ),

                // Highlight the nearest safe zone
                if (_nearestSafe != null)
                  Marker(
                    point: LatLng(
                        _nearestSafe!.latitude, _nearestSafe!.longitude),
                    width: 56,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.blue, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.6),
                            blurRadius: 12,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🛡️', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                  ),

                // Current-location pin
                Marker(
                  point: center,
                  width: 50,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.my_location,
                        color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ],
        ),

        // ── Location error banner ─────────────────────────
        if (_locationError != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_locationError!,
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                      onPressed: _loadMapData,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Search bar ─────────────────────────────────────
        Positioned(
          top: _locationError != null ? 80 : 16,
          left: 16,
          right: 16,
          child: SafeArea(
            child: Card(
              elevation: 8,
              color: Colors.white.withOpacity(0.95),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search location safety score...',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 13),
                        onSubmitted: (_) => _searchLocation(),
                      ),
                    ),
                    if (_isSearching)
                      const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.search, color: Color(0xFF10B981), size: 22),
                        onPressed: _searchLocation,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Search result card ────────────────────────────
        if (_searchResult != null)
          Positioned(
            top: _locationError != null ? 140 : 76,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getScoreColor((_searchResult!['safety_score'] as num).toInt()).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_searchResult!['safety_score']}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _getScoreColor((_searchResult!['safety_score'] as num).toInt()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Safety: ${_searchResult!['safety_score']}/100',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(
                                  'Tonight: ${_searchResult!['safety_score_night']}/100',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() {
                              _searchResult = null;
                              _searchMarker = null;
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── Legend panel ──────────────────────────────────
        Positioned(
          bottom: 110,
          left: 16,
          child: Card(
            elevation: 6,
            color: Colors.white.withOpacity(0.93),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🗺️ Safety Map',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  _legendItem(Colors.green, '🟢 Safe'),
                  _legendItem(Colors.orange, '🟡 Caution'),
                  _legendItem(Colors.red, '🔴 Danger'),
                  _legendItem(Colors.blue, '📍 You'),
                  if (_showRoute) _legendItem(Colors.blue, '🛤️ Route'),
                ],
              ),
            ),
          ),
        ),

        // ── Refresh button ───────────────────────────────
        Positioned(
          top: 16,
          right: 16,
          child: SafeArea(
            child: FloatingActionButton.small(
              heroTag: 'refresh_map',
              onPressed: _loadMapData,
              backgroundColor: Colors.white,
              child: const Icon(Icons.refresh, color: Colors.black87),
            ),
          ),
        ),

        // ── Bottom panel ─────────────────────────────────
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Column(
            children: [
              // Route info card
              if (_showRoute && _nearestSafe != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.green.withOpacity(0.4), blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text('🛡️', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Head to: ${_nearestSafe!.name}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_nearestSafe!.description} • ${_nearestSafe!.distanceTo(_currentPosition!.latitude, _currentPosition!.longitude).toInt()}m away',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Find / Update safe route button
              ElevatedButton.icon(
                onPressed: _findSafeRoute,
                icon: const Icon(Icons.shield, size: 28),
                label: Text(
                  _showRoute
                      ? 'Update Safe Route'
                      : '🆘 Find Nearest Safe Zone',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _showRoute ? Colors.blue.shade700 : Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────

  Color _getScoreColor(int score) {
    if (score >= 70) return Colors.green.shade700;
    if (score >= 40) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  Widget _legendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withOpacity(0.5),
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  /// Search location by name (Nominatim/OSM free geocoder)
  Future<void> _searchLocation() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      // Geocode using OSM Nominatim (free, no API key)
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1'),
        headers: {'User-Agent': 'Seyyon-Safety-App'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List;
        if (results.isNotEmpty) {
          double lat = double.parse(results[0]['lat']);
          double lng = double.parse(results[0]['lon']);

          // Get safety score from backend
          final score = await BackendService.getLocationScore(lat, lng);

          setState(() {
            _searchMarker = LatLng(lat, lng);
            _searchResult = score;
          });

          // Move map to searched location
          _mapController.move(LatLng(lat, lng), 15);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location not found')),
            );
          }
        }
      }
    } catch (e) {
      print('Search failed: $e');
    }

    setState(() => _isSearching = false);
  }

  /// Show scored zone detail bottom sheet
  void _showScoredZoneDetails(Map<String, dynamic> zone) {
    int safetyScore = (zone['safety_score'] as num?)?.toInt() ?? 100;
    int nightScore = (zone['safety_score_night'] as num?)?.toInt() ?? 100;
    String level = zone['zone_level'] ?? 'green';
    int alerts = (zone['alert_count'] as num?)?.toInt() ?? 0;
    int devices = (zone['unique_devices'] as num?)?.toInt() ?? 0;
    int reports = (zone['community_reports'] as num?)?.toInt() ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _getScoreColor(safetyScore).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '$safetyScore',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(safetyScore),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety Score: $safetyScore/100',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Zone: ${level.toUpperCase()}',
                        style: TextStyle(
                          color: _getScoreColor(safetyScore),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _statChip('🌙 Tonight', '$nightScore/100'),
                const SizedBox(width: 10),
                _statChip('🚨 Alerts', '$alerts'),
                const SizedBox(width: 10),
                _statChip('📱 Devices', '$devices'),
              ],
            ),
            if (reports > 0) ...[const SizedBox(height: 8), _statChip('📝 Reports', '$reports')],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  String deviceId = await StorageService.getDeviceId();
                  double lat = (zone['grid_lat'] as num).toDouble();
                  double lng = (zone['grid_lng'] as num).toDouble();
                  bool ok = await BackendService.reportZone(
                    latitude: lat, longitude: lng, deviceId: deviceId,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? '✅ Report submitted' : '❌ Report failed'),
                    ));
                  }
                },
                icon: const Icon(Icons.report, size: 18),
                label: const Text('Report This Area'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showZoneDetails(SafeZone zone) {
    double dist = _currentPosition != null
        ? zone.distanceTo(
            _currentPosition!.latitude, _currentPosition!.longitude)
        : 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: zone.type == ZoneType.safe
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                      child: Text(zone.icon,
                          style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(zone.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        zone.type == ZoneType.safe
                            ? '✅ Safe Zone'
                            : '⚠️ Danger Zone',
                        style: TextStyle(
                          color: zone.type == ZoneType.safe
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(zone.description,
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 8),
            Text('📏 Distance: ${dist.toInt()} meters',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            if (zone.type == ZoneType.safe)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    List<List<double>> routePoints =
                        SafeZoneService.getSafeRouteTo(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      zone.latitude,
                      zone.longitude,
                    );
                    setState(() {
                      _nearestSafe = zone;
                      _safeRoute = routePoints
                          .map((p) => LatLng(p[0], p[1]))
                          .toList();
                      _showRoute = true;
                    });
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Navigate to Safe Zone'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
