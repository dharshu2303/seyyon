<?php
// API: Compute Zone Scores — Risk Zone Intelligence Engine
// Called via cron (*/5 * * * *) or on-demand
// Aggregates SOS alerts into 200m grid cells with trust-weighted scoring
require_once __DIR__ . '/../config.php';

$db = getDB();

// ═══════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════
const GRID_SIZE_DEG = 0.0018; // ~200m at equator
const RECENCY_FULL_DAYS = 30;
const RECENCY_HALF_DAYS = 60;
const NIGHT_START_HOUR = 21; // 9pm
const NIGHT_END_HOUR = 5;   // 5am
const NIGHT_WEIGHT = 3.0;
const DAY_WEIGHT = 1.0;
const UNIQUE_DEVICE_THRESHOLD = 5;
const UNIQUE_DEVICE_BONUS = 1.8;
const COMMUNITY_BASE_WEIGHT = 0.4;
const COMMUNITY_VERIFY_COUNT = 3;
const COMMUNITY_VERIFY_DAYS = 7;
const COMMUNITY_VERIFY_BOOST = 1.5;
const SCORE_GREEN_MAX = 2.0;
const SCORE_AMBER_MAX = 7.0;
const AUTO_EXPIRE_DAYS = 60;

// ═══════════════════════════════════════════════════════════
// HELPER: Snap coordinate to grid cell center
// ═══════════════════════════════════════════════════════════
function snapToGrid($coord) {
    return round(floor($coord / GRID_SIZE_DEG) * GRID_SIZE_DEG + GRID_SIZE_DEG / 2, 6);
}

// ═══════════════════════════════════════════════════════════
// HELPER: Compute trust weight for a single alert
// ═══════════════════════════════════════════════════════════
function computeTrustWeight($alert, $allAlerts) {
    // Rule 1: Cancelled within 30 seconds → 0.0
    if ($alert['cancelled_at'] !== null) {
        $created = strtotime($alert['created_at']);
        $cancelled = strtotime($alert['cancelled_at']);
        if (($cancelled - $created) <= 30) {
            return 0.0;
        }
    }

    // Rule 2: Same device 3+ times within 60 min at same grid cell → 0.1
    $deviceId = $alert['device_id'];
    $gridLat = snapToGrid($alert['latitude']);
    $gridLng = snapToGrid($alert['longitude']);
    $alertTime = strtotime($alert['created_at']);

    if (!empty($deviceId)) {
        $sameDeviceSameCell = 0;
        foreach ($allAlerts as $other) {
            if ($other['device_id'] === $deviceId
                && snapToGrid($other['latitude']) === $gridLat
                && snapToGrid($other['longitude']) === $gridLng
                && abs(strtotime($other['created_at']) - $alertTime) <= 3600) {
                $sameDeviceSameCell++;
            }
        }
        if ($sameDeviceSameCell >= 3) {
            return 0.1;
        }
    }

    // Rule 3: No contacts reached → 0.3
    if ($alert['sms_delivered'] === 0 && $alert['call_connected'] === 0) {
        return 0.3;
    }

    // Rule 4: Normal valid SOS → 1.0
    return 1.0;
}

// ═══════════════════════════════════════════════════════════
// HELPER: Compute recency decay
// ═══════════════════════════════════════════════════════════
function computeRecencyDecay($createdAt) {
    $daysSince = (time() - strtotime($createdAt)) / 86400;
    if ($daysSince > RECENCY_HALF_DAYS) return 0.0;
    if ($daysSince > RECENCY_FULL_DAYS) return 0.5;
    return 1.0;
}

// ═══════════════════════════════════════════════════════════
// HELPER: Compute time-of-day weight
// ═══════════════════════════════════════════════════════════
function computeTimeOfDayWeight($createdAt) {
    $hour = (int) date('G', strtotime($createdAt));
    if ($hour >= NIGHT_START_HOUR || $hour < NIGHT_END_HOUR) {
        return NIGHT_WEIGHT;
    }
    return DAY_WEIGHT;
}

// ═══════════════════════════════════════════════════════════
// MAIN: Fetch all alerts from the last 60 days
// ═══════════════════════════════════════════════════════════
$stmt = $db->prepare('
    SELECT id, latitude, longitude, device_id, source, cancelled_at, 
           sms_delivered, call_connected, created_at
    FROM sos_alerts 
    WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
');
$stmt->execute([RECENCY_HALF_DAYS]);
$allAlerts = $stmt->fetchAll();

// ═══════════════════════════════════════════════════════════
// GROUP alerts into grid cells
// ═══════════════════════════════════════════════════════════
$gridCells = []; // key = "lat|lng" => array of alerts

foreach ($allAlerts as $alert) {
    $gLat = snapToGrid($alert['latitude']);
    $gLng = snapToGrid($alert['longitude']);
    $key = "$gLat|$gLng";
    if (!isset($gridCells[$key])) {
        $gridCells[$key] = ['lat' => $gLat, 'lng' => $gLng, 'alerts' => []];
    }
    $gridCells[$key]['alerts'][] = $alert;
}

// ═══════════════════════════════════════════════════════════
// SCORE each grid cell
// ═══════════════════════════════════════════════════════════
$results = [];

foreach ($gridCells as $key => $cell) {
    $alerts = $cell['alerts'];
    $gLat = $cell['lat'];
    $gLng = $cell['lng'];

    // Compute weighted score
    $totalScore = 0.0;
    $totalScoreNight = 0.0; // projected night score
    $uniqueDevices = [];
    $lastAlertAt = null;

    foreach ($alerts as $alert) {
        $trustWeight = computeTrustWeight($alert, $allAlerts);
        $recencyDecay = computeRecencyDecay($alert['created_at']);
        $todWeight = computeTimeOfDayWeight($alert['created_at']);

        if ($trustWeight == 0.0 || $recencyDecay == 0.0) continue;

        // Current score uses actual time-of-day weight
        $totalScore += $trustWeight * $recencyDecay * $todWeight;

        // Night projection: re-weight all alerts as if triggered at 10pm
        $totalScoreNight += $trustWeight * $recencyDecay * NIGHT_WEIGHT;

        // Track unique devices
        if (!empty($alert['device_id'])) {
            $uniqueDevices[$alert['device_id']] = true;
        }

        // Track latest alert
        if ($lastAlertAt === null || $alert['created_at'] > $lastAlertAt) {
            $lastAlertAt = $alert['created_at'];
        }
    }

    $uniqueCount = count($uniqueDevices);

    // Apply unique device bonus
    if ($uniqueCount >= UNIQUE_DEVICE_THRESHOLD) {
        $totalScore *= UNIQUE_DEVICE_BONUS;
        $totalScoreNight *= UNIQUE_DEVICE_BONUS;
    }

    // ── Community reports contribution ──
    $crStmt = $db->prepare('
        SELECT COUNT(*) as cnt, COUNT(DISTINCT device_id) as unique_reporters
        FROM community_reports
        WHERE grid_lat = ? AND grid_lng = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
    ');
    $crStmt->execute([$gLat, $gLng, COMMUNITY_VERIFY_DAYS]);
    $cr = $crStmt->fetch();
    $communityCount = (int) $cr['cnt'];
    $communityUnique = (int) $cr['unique_reporters'];

    $communityScore = $communityCount * COMMUNITY_BASE_WEIGHT;
    if ($communityUnique >= COMMUNITY_VERIFY_COUNT) {
        $communityScore *= COMMUNITY_VERIFY_BOOST;
    }

    $totalScore += $communityScore;
    $totalScoreNight += $communityScore;

    // Classify zone
    if ($totalScore <= SCORE_GREEN_MAX) {
        $level = 'green';
    } elseif ($totalScore <= SCORE_AMBER_MAX) {
        $level = 'amber';
    } else {
        $level = 'red';
    }

    // Upsert into zone_grid_cells
    $upsert = $db->prepare('
        INSERT INTO zone_grid_cells (grid_lat, grid_lng, zone_score, zone_score_night, zone_level, alert_count, unique_devices, community_reports, last_alert_at, last_computed_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
            zone_score = VALUES(zone_score),
            zone_score_night = VALUES(zone_score_night),
            zone_level = VALUES(zone_level),
            alert_count = VALUES(alert_count),
            unique_devices = VALUES(unique_devices),
            community_reports = VALUES(community_reports),
            last_alert_at = VALUES(last_alert_at),
            last_computed_at = NOW()
    ');
    $upsert->execute([
        $gLat, $gLng,
        round($totalScore, 2),
        round($totalScoreNight, 2),
        $level,
        count($alerts),
        $uniqueCount,
        $communityCount,
        $lastAlertAt
    ]);

    $results[] = [
        'grid_lat' => $gLat,
        'grid_lng' => $gLng,
        'score' => round($totalScore, 2),
        'score_night' => round($totalScoreNight, 2),
        'level' => $level,
        'alerts' => count($alerts),
        'unique_devices' => $uniqueCount,
        'community_reports' => $communityCount,
    ];
}

// ═══════════════════════════════════════════════════════════
// AUTO-EXPIRE: Reset zones with no alerts for 60 days
// ═══════════════════════════════════════════════════════════
$db->exec("
    UPDATE zone_grid_cells 
    SET zone_score = 0, zone_score_night = 0, zone_level = 'green', last_computed_at = NOW()
    WHERE last_alert_at < DATE_SUB(NOW(), INTERVAL " . AUTO_EXPIRE_DAYS . " DAY)
      AND zone_level != 'green'
");

echo json_encode([
    'success' => true,
    'zones_computed' => count($results),
    'zones' => $results,
    'computed_at' => date('Y-m-d H:i:s'),
]);
