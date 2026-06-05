-- Seyyon Platform Upgrade — Database Schema Changes
-- Run this SQL AFTER the original database.sql has been applied

USE seyyon_sos;

-- ═══════════════════════════════════════════════════════════
-- 1. Enrich sos_alerts table
-- ═══════════════════════════════════════════════════════════
ALTER TABLE sos_alerts
  ADD COLUMN device_id VARCHAR(64) DEFAULT '' AFTER phone,
  ADD COLUMN source ENUM('manual','shake','voice','checkin_timer') DEFAULT 'manual' AFTER device_id,
  ADD COLUMN cancelled_at DATETIME DEFAULT NULL AFTER source,
  ADD COLUMN sms_delivered TINYINT(1) DEFAULT NULL AFTER cancelled_at,
  ADD COLUMN call_connected TINYINT(1) DEFAULT NULL AFTER sms_delivered,
  ADD INDEX idx_device (device_id),
  ADD INDEX idx_source (source);

-- ═══════════════════════════════════════════════════════════
-- 2. Grid cell zone scores (200m cells)
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS zone_grid_cells (
  id INT AUTO_INCREMENT PRIMARY KEY,
  grid_lat DOUBLE NOT NULL COMMENT 'Snapped latitude for 200m grid cell',
  grid_lng DOUBLE NOT NULL COMMENT 'Snapped longitude for 200m grid cell',
  zone_score DECIMAL(8,2) DEFAULT 0.00,
  zone_score_night DECIMAL(8,2) DEFAULT 0.00 COMMENT 'Projected score at 10pm',
  zone_level ENUM('green','amber','red') DEFAULT 'green',
  alert_count INT DEFAULT 0,
  unique_devices INT DEFAULT 0,
  community_reports INT DEFAULT 0,
  last_alert_at DATETIME DEFAULT NULL,
  last_computed_at DATETIME DEFAULT NULL,
  UNIQUE KEY uk_grid (grid_lat, grid_lng),
  INDEX idx_level (zone_level),
  INDEX idx_score (zone_score)
) ENGINE=InnoDB;

-- ═══════════════════════════════════════════════════════════
-- 3. Community reports
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS community_reports (
  id INT AUTO_INCREMENT PRIMARY KEY,
  grid_lat DOUBLE NOT NULL,
  grid_lng DOUBLE NOT NULL,
  device_id VARCHAR(64) NOT NULL,
  report_type ENUM('unsafe_area','poor_lighting','harassment','theft','other') DEFAULT 'unsafe_area',
  note TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_grid (grid_lat, grid_lng),
  INDEX idx_device (device_id),
  INDEX idx_created (created_at)
) ENGINE=InnoDB;

-- ═══════════════════════════════════════════════════════════
-- 4. Device tokens for JWT auth
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS device_tokens (
  id INT AUTO_INCREMENT PRIMARY KEY,
  device_id VARCHAR(64) NOT NULL UNIQUE,
  token_hash VARCHAR(255) NOT NULL,
  platform ENUM('android','ios','web') DEFAULT 'android',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_seen_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_device (device_id)
) ENGINE=InnoDB;

-- ═══════════════════════════════════════════════════════════
-- 5. Check-in timer events log
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS checkin_events (
  id INT AUTO_INCREMENT PRIMARY KEY,
  device_id VARCHAR(64) NOT NULL,
  event_type ENUM('timer_started','safe_checkin','timer_expired','auto_sos') NOT NULL,
  duration_seconds INT DEFAULT 0,
  note TEXT,
  latitude DOUBLE DEFAULT NULL,
  longitude DOUBLE DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_device (device_id),
  INDEX idx_type (event_type),
  INDEX idx_created (created_at)
) ENGINE=InnoDB;

-- ═══════════════════════════════════════════════════════════
-- 6. User consent records (DPDP Act 2023)
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS user_consents (
  id INT AUTO_INCREMENT PRIMARY KEY,
  device_id VARCHAR(64) NOT NULL,
  consent_location TINYINT(1) DEFAULT 0,
  consent_alerts TINYINT(1) DEFAULT 0,
  consent_community TINYINT(1) DEFAULT 0,
  consented_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  withdrawn_at DATETIME DEFAULT NULL,
  INDEX idx_device (device_id)
) ENGINE=InnoDB;
