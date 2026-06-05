<?php
// API: Get all SOS alerts (for danger zone mapping)
// GET /api/get_alerts.php
require_once __DIR__ . '/../config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

$db = getDB();

// Get alerts from last 90 days
$stmt = $db->prepare('SELECT id, latitude, longitude, location_url, phone, message, created_at FROM sos_alerts WHERE created_at >= DATE_SUB(NOW(), INTERVAL 90 DAY) ORDER BY created_at DESC');
$stmt->execute();
$alerts = $stmt->fetchAll();

echo json_encode([
    'success' => true,
    'count' => count($alerts),
    'alerts' => $alerts,
]);
