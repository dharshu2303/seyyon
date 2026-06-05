<?php
// API: Save SOS Alert (enriched)
// POST /api/save_alert.php
require_once __DIR__ . '/../config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);

if (!$input || !isset($input['latitude']) || !isset($input['longitude'])) {
    http_response_code(400);
    echo json_encode(['error' => 'latitude and longitude are required']);
    exit;
}

$db = getDB();
$stmt = $db->prepare('
    INSERT INTO sos_alerts (latitude, longitude, location_url, phone, device_id, source, sms_delivered, call_connected, message) 
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
');
$stmt->execute([
    $input['latitude'],
    $input['longitude'],
    $input['location_url'] ?? '',
    $input['phone'] ?? '',
    $input['device_id'] ?? '',
    $input['source'] ?? 'manual',
    isset($input['sms_delivered']) ? (int) $input['sms_delivered'] : null,
    isset($input['call_connected']) ? (int) $input['call_connected'] : null,
    $input['message'] ?? 'SOS Alert triggered',
]);

$alertId = $db->lastInsertId();

echo json_encode([
    'success' => true,
    'id' => $alertId,
    'message' => 'SOS alert saved',
]);
