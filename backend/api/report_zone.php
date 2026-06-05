<?php
// API: Report Zone — Community safety reports
// POST /api/report_zone.php
require_once __DIR__ . '/../config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);

if (!$input || !isset($input['latitude']) || !isset($input['longitude']) || !isset($input['device_id'])) {
    http_response_code(400);
    echo json_encode(['error' => 'latitude, longitude, and device_id are required']);
    exit;
}

// Snap to grid cell
$gridSize = 0.0018; // ~200m
$gridLat = round(floor($input['latitude'] / $gridSize) * $gridSize + $gridSize / 2, 6);
$gridLng = round(floor($input['longitude'] / $gridSize) * $gridSize + $gridSize / 2, 6);

$db = getDB();

// Rate limit: max 3 reports per device per day
$rateCheck = $db->prepare('
    SELECT COUNT(*) as cnt FROM community_reports
    WHERE device_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY)
');
$rateCheck->execute([$input['device_id']]);
$rate = $rateCheck->fetch();

if ((int) $rate['cnt'] >= 3) {
    http_response_code(429);
    echo json_encode(['error' => 'Rate limit: max 3 reports per day']);
    exit;
}

// Check for duplicate report from same device for same cell within 24h
$dupCheck = $db->prepare('
    SELECT COUNT(*) as cnt FROM community_reports
    WHERE device_id = ? AND grid_lat = ? AND grid_lng = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY)
');
$dupCheck->execute([$input['device_id'], $gridLat, $gridLng]);
$dup = $dupCheck->fetch();

if ((int) $dup['cnt'] > 0) {
    http_response_code(409);
    echo json_encode(['error' => 'You already reported this area today']);
    exit;
}

$stmt = $db->prepare('
    INSERT INTO community_reports (grid_lat, grid_lng, device_id, report_type, note)
    VALUES (?, ?, ?, ?, ?)
');
$stmt->execute([
    $gridLat,
    $gridLng,
    $input['device_id'],
    $input['report_type'] ?? 'unsafe_area',
    $input['note'] ?? '',
]);

echo json_encode([
    'success' => true,
    'id' => $db->lastInsertId(),
    'message' => 'Report submitted. Thank you for helping keep the community safe.',
]);
