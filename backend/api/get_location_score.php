<?php
// API: Get Location Score — Safety score for any coordinate
// GET /api/get_location_score.php?lat=XX&lng=XX
require_once __DIR__ . '/../config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

if (!isset($_GET['lat']) || !isset($_GET['lng'])) {
    http_response_code(400);
    echo json_encode(['error' => 'lat and lng are required']);
    exit;
}

$lat = (float) $_GET['lat'];
$lng = (float) $_GET['lng'];

// Snap to grid cell
$gridSize = 0.0018;
$gridLat = round(floor($lat / $gridSize) * $gridSize + $gridSize / 2, 6);
$gridLng = round(floor($lng / $gridSize) * $gridSize + $gridSize / 2, 6);

$db = getDB();

// Look up the grid cell
$stmt = $db->prepare('
    SELECT zone_score, zone_score_night, zone_level, alert_count, unique_devices, 
           community_reports, last_alert_at, last_computed_at
    FROM zone_grid_cells
    WHERE grid_lat = ? AND grid_lng = ?
');
$stmt->execute([$gridLat, $gridLng]);
$zone = $stmt->fetch();

if ($zone) {
    $rawScore = (float) $zone['zone_score'];
    $rawScoreNight = (float) $zone['zone_score_night'];
    $safetyScore = max(0, min(100, 100 - ($rawScore * 10)));
    $safetyScoreNight = max(0, min(100, 100 - ($rawScoreNight * 10)));

    echo json_encode([
        'success' => true,
        'latitude' => $lat,
        'longitude' => $lng,
        'safety_score' => round($safetyScore),
        'safety_score_night' => round($safetyScoreNight),
        'zone_level' => $zone['zone_level'],
        'alert_count' => (int) $zone['alert_count'],
        'unique_devices' => (int) $zone['unique_devices'],
        'community_reports' => (int) $zone['community_reports'],
        'last_alert_at' => $zone['last_alert_at'],
        'share_url' => "https://seyyon.app/zone?lat=$lat&lng=$lng",
    ]);
} else {
    // No data for this location — default to safe (100)
    echo json_encode([
        'success' => true,
        'latitude' => $lat,
        'longitude' => $lng,
        'safety_score' => 100,
        'safety_score_night' => 100,
        'zone_level' => 'green',
        'alert_count' => 0,
        'unique_devices' => 0,
        'community_reports' => 0,
        'last_alert_at' => null,
        'share_url' => "https://seyyon.app/zone?lat=$lat&lng=$lng",
    ]);
}
