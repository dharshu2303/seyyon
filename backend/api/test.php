<?php
// API: Test connection
// POST /api/test.php
require_once __DIR__ . '/../config.php';

$db = getDB();
echo json_encode([
    'success' => true,
    'message' => 'Seyyon SOS API is running',
    'timestamp' => date('c'),
]);
