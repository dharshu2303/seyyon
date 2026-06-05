<?php
// API: Device Authentication — Register device and get JWT token
// POST /api/auth.php
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../middleware/jwt_auth.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);

if (!$input || !isset($input['device_id'])) {
    http_response_code(400);
    echo json_encode(['error' => 'device_id is required']);
    exit;
}

$deviceId = trim($input['device_id']);
$platform = $input['platform'] ?? 'android';

if (strlen($deviceId) < 8) {
    http_response_code(400);
    echo json_encode(['error' => 'device_id must be at least 8 characters']);
    exit;
}

$db = getDB();

// Generate JWT
$token = generateJWT($deviceId, $platform);
$tokenHash = hash('sha256', $token);

// Upsert device token
$stmt = $db->prepare('
    INSERT INTO device_tokens (device_id, token_hash, platform, last_seen_at)
    VALUES (?, ?, ?, NOW())
    ON DUPLICATE KEY UPDATE
        token_hash = VALUES(token_hash),
        platform = VALUES(platform),
        last_seen_at = NOW()
');
$stmt->execute([$deviceId, $tokenHash, $platform]);

echo json_encode([
    'success' => true,
    'token' => $token,
    'device_id' => $deviceId,
    'expires_in' => 30 * 24 * 3600, // 30 days in seconds
]);
