<?php
// Middleware: JWT Authentication
// Validates device token from Authorization header
// Usage: require_once __DIR__ . '/middleware/jwt_auth.php'; requireAuth($db);
require_once __DIR__ . '/config.php';

// Simple JWT implementation (no external dependencies)
// For production, use firebase/php-jwt via composer

function base64UrlEncode($data) {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

function base64UrlDecode($data) {
    return base64_decode(strtr($data, '-_', '+/') . str_repeat('=', 3 - (3 + strlen($data)) % 4));
}

define('JWT_SECRET', getenv('JWT_SECRET') ?: 'seyyon_jwt_secret_change_in_production_2024');

function generateJWT($deviceId, $platform = 'android') {
    $header = base64UrlEncode(json_encode(['alg' => 'HS256', 'typ' => 'JWT']));
    $payload = base64UrlEncode(json_encode([
        'device_id' => $deviceId,
        'platform' => $platform,
        'iat' => time(),
        'exp' => time() + (30 * 24 * 3600), // 30 days
    ]));
    $signature = base64UrlEncode(hash_hmac('sha256', "$header.$payload", JWT_SECRET, true));
    return "$header.$payload.$signature";
}

function validateJWT($token) {
    $parts = explode('.', $token);
    if (count($parts) !== 3) return null;

    [$header, $payload, $signature] = $parts;

    // Verify signature
    $expectedSig = base64UrlEncode(hash_hmac('sha256', "$header.$payload", JWT_SECRET, true));
    if (!hash_equals($expectedSig, $signature)) return null;

    $data = json_decode(base64UrlDecode($payload), true);
    if (!$data) return null;

    // Check expiry
    if (isset($data['exp']) && $data['exp'] < time()) return null;

    return $data;
}

function requireAuth() {
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';

    if (empty($authHeader) || !str_starts_with($authHeader, 'Bearer ')) {
        http_response_code(401);
        echo json_encode(['error' => 'Authentication required. Send Authorization: Bearer <token>']);
        exit;
    }

    $token = substr($authHeader, 7);
    $payload = validateJWT($token);

    if ($payload === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid or expired token']);
        exit;
    }

    return $payload;
}

// Optional: soft auth — returns payload or null (for read endpoints)
function optionalAuth() {
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';

    if (empty($authHeader) || !str_starts_with($authHeader, 'Bearer ')) {
        return null;
    }

    return validateJWT(substr($authHeader, 7));
}
