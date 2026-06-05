<?php
// API: Save Check-in Event
// POST /api/save_checkin.php
require_once __DIR__ . '/../config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);

if (!$input || !isset($input['device_id']) || !isset($input['event_type'])) {
    http_response_code(400);
    echo json_encode(['error' => 'device_id and event_type are required']);
    exit;
}

$validTypes = ['timer_started', 'safe_checkin', 'timer_expired', 'auto_sos'];
if (!in_array($input['event_type'], $validTypes)) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid event_type. Must be one of: ' . implode(', ', $validTypes)]);
    exit;
}

$db = getDB();
$stmt = $db->prepare('
    INSERT INTO checkin_events (device_id, event_type, duration_seconds, note, latitude, longitude)
    VALUES (?, ?, ?, ?, ?, ?)
');
$stmt->execute([
    $input['device_id'],
    $input['event_type'],
    $input['duration_seconds'] ?? 0,
    $input['note'] ?? '',
    $input['latitude'] ?? null,
    $input['longitude'] ?? null,
]);

echo json_encode([
    'success' => true,
    'id' => $db->lastInsertId(),
    'message' => 'Check-in event logged',
]);
