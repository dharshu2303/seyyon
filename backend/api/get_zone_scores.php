<?php
// API: Get Zone Scores — returns scored zones for the Safe Map
// GET /api/get_zone_scores.php?lat=XX&lng=XX&radius_km=5
require_once __DIR__ . '/../config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

$db = getDB();

$lat = isset($_GET['lat']) ? (float) $_GET['lat'] : null;
$lng = isset($_GET['lng']) ? (float) $_GET['lng'] : null;
$radiusKm = isset($_GET['radius_km']) ? (float) $_GET['radius_km'] : 10;

// Build query — optionally filter by bounding box
if ($lat !== null && $lng !== null) {
    // Approximate bounding box for radius
    $latDelta = $radiusKm / 111.0; // ~111km per degree latitude
    $lngDelta = $radiusKm / (111.0 * cos(deg2rad($lat)));

    $stmt = $db->prepare('
        SELECT grid_lat, grid_lng, zone_score, zone_score_night, zone_level,
               alert_count, unique_devices, community_reports, last_alert_at, last_computed_at
        FROM zone_grid_cells
        WHERE zone_level != "green"
          AND grid_lat BETWEEN ? AND ?
          AND grid_lng BETWEEN ? AND ?
        ORDER BY zone_score DESC
        LIMIT 200
    ');
    $stmt->execute([
        $lat - $latDelta, $lat + $latDelta,
        $lng - $lngDelta, $lng + $lngDelta,
    ]);
} else {
    $stmt = $db->prepare('
        SELECT grid_lat, grid_lng, zone_score, zone_score_night, zone_level,
               alert_count, unique_devices, community_reports, last_alert_at, last_computed_at
        FROM zone_grid_cells
        WHERE zone_level != "green"
        ORDER BY zone_score DESC
        LIMIT 200
    ');
    $stmt->execute();
}

$zones = $stmt->fetchAll();

// Format response
$formatted = [];
foreach ($zones as $z) {
    // Compute safety_score (0-100, inverse of zone_score; 100 = safest)
    $rawScore = (float) $z['zone_score'];
    $rawScoreNight = (float) $z['zone_score_night'];
    $safetyScore = max(0, min(100, 100 - ($rawScore * 10)));
    $safetyScoreNight = max(0, min(100, 100 - ($rawScoreNight * 10)));

    $formatted[] = [
        'grid_lat' => (float) $z['grid_lat'],
        'grid_lng' => (float) $z['grid_lng'],
        'zone_score' => $rawScore,
        'zone_score_night' => $rawScoreNight,
        'safety_score' => round($safetyScore),
        'safety_score_night' => round($safetyScoreNight),
        'zone_level' => $z['zone_level'],
        'alert_count' => (int) $z['alert_count'],
        'unique_devices' => (int) $z['unique_devices'],
        'community_reports' => (int) $z['community_reports'],
        'last_alert_at' => $z['last_alert_at'],
        'last_computed_at' => $z['last_computed_at'],
        'radius_meters' => 200,
    ];
}

echo json_encode([
    'success' => true,
    'zones' => $formatted,
    'count' => count($formatted),
]);
