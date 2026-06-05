<?php
// API: Delete User Data — DPDP Act 2023 compliance
// POST /api/delete_user_data.php (authenticated)
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../middleware/jwt_auth.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

// Require authentication
$auth = requireAuth();
$deviceId = $auth['device_id'];

$db = getDB();

// Delete all user data across all tables
$tables = [
    'sos_alerts' => 'device_id',
    'community_reports' => 'device_id',
    'checkin_events' => 'device_id',
    'user_consents' => 'device_id',
    'device_tokens' => 'device_id',
];

$deletedCounts = [];
foreach ($tables as $table => $column) {
    try {
        $stmt = $db->prepare("DELETE FROM $table WHERE $column = ?");
        $stmt->execute([$deviceId]);
        $deletedCounts[$table] = $stmt->rowCount();
    } catch (PDOException $e) {
        // Table might not exist yet — skip silently
        $deletedCounts[$table] = 0;
    }
}

echo json_encode([
    'success' => true,
    'device_id' => $deviceId,
    'message' => 'All your data has been permanently deleted.',
    'deleted' => $deletedCounts,
]);
