<?php
// API: Get danger zone clusters
// GET /api/get_danger_zones.php
require_once __DIR__ . '/../config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}


$db = getDB();
$stmt = $db->prepare('SELECT latitude, longitude FROM sos_alerts WHERE created_at >= DATE_SUB(NOW(), INTERVAL 90 DAY)');
$stmt->execute();
$alerts = $stmt->fetchAll();

$clusters = [];
foreach ($alerts as $alert) {
    $clusters[] = [
        'latitude' => $alert['latitude'],
        'longitude' => $alert['longitude'],
        'radius_meters' => 80,
        'alert_count' => 1,
        'severity' => 'low',
    ];
}

echo json_encode(['success' => true, 'clusters' => $clusters]);

// Haversine distance in meters
function haversineDistance($lat1, $lon1, $lat2, $lon2) {
    $R = 6371000; // Earth radius in meters
    $dLat = deg2rad($lat2 - $lat1);
    $dLon = deg2rad($lon2 - $lon1);
    $a = sin($dLat/2) * sin($dLat/2) +
         cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
         sin($dLon/2) * sin($dLon/2);
    $c = 2 * atan2(sqrt($a), sqrt(1-$a));
    return $R * $c;
}
