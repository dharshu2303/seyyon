import 'dart:async';
import 'package:flutter/material.dart';
import 'sos_service.dart';
import 'location_service.dart';
import 'backend_service.dart';
import 'storage_service.dart';

/// Check-in Timer Escalation States
enum CheckinState {
  idle,       // No timer running
  running,    // Timer counting down
  expired,    // Timer expired, showing first alert
  alert1,     // First full-screen alert — 30s window
  alert2,     // Second alert — 5s window
  autoSos,    // Auto-SOS triggered
}

/// Check-in Timer Service
/// Manages the countdown timer and escalation state machine:
/// IDLE → RUNNING → EXPIRED → ALERT_1 (30s) → ALERT_2 (5s) → AUTO_SOS
class CheckinTimerService {
  static CheckinState _state = CheckinState.idle;
  static Timer? _countdownTimer;
  static Timer? _escalationTimer;
  static int _remainingSeconds = 0;
  static int _totalSeconds = 0;
  static String _note = '';
  static int _alert1Remaining = 30; // seconds for first alert window
  static int _alert2Remaining = 5;  // seconds for second alert window

  // Callbacks
  static Function(CheckinState state)? _onStateChanged;
  static Function(int remainingSeconds)? _onTick;
  static Function()? _onShowAlert;  // Show full-screen alert
  static Function()? _onDismissAlert;

  static CheckinState get state => _state;
  static int get remainingSeconds => _remainingSeconds;
  static int get totalSeconds => _totalSeconds;
  static String get note => _note;
  static int get alert1Remaining => _alert1Remaining;
  static int get alert2Remaining => _alert2Remaining;

  /// Initialize with callbacks
  static void initialize({
    required Function(CheckinState) onStateChanged,
    required Function(int) onTick,
    required Function() onShowAlert,
    required Function() onDismissAlert,
  }) {
    _onStateChanged = onStateChanged;
    _onTick = onTick;
    _onShowAlert = onShowAlert;
    _onDismissAlert = onDismissAlert;
  }

  /// Start a check-in timer
  static Future<void> startTimer({
    required int durationSeconds,
    String note = '',
  }) async {
    if (_state != CheckinState.idle) {
      cancelTimer();
    }

    _totalSeconds = durationSeconds;
    _remainingSeconds = durationSeconds;
    _note = note;
    _state = CheckinState.running;
    _notifyStateChange();

    // Log timer start to backend
    _logCheckinEvent('timer_started', durationSeconds: durationSeconds, note: note);

    // Start countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds--;
      _onTick?.call(_remainingSeconds);

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _onTimerExpired();
      }
    });
  }

  /// Timer expired — enter escalation sequence
  static void _onTimerExpired() {
    _state = CheckinState.expired;
    _notifyStateChange();

    // Log expiry
    _logCheckinEvent('timer_expired');

    // Immediately show first alert
    _enterAlert1();
  }

  /// First alert: 30-second window
  static void _enterAlert1() {
    _state = CheckinState.alert1;
    _alert1Remaining = 30;
    _notifyStateChange();
    _onShowAlert?.call();

    _escalationTimer?.cancel();
    _escalationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _alert1Remaining--;
      _onTick?.call(_alert1Remaining);

      if (_alert1Remaining <= 0) {
        timer.cancel();
        _enterAlert2();
      }
    });
  }

  /// Second alert: 5-second window with stronger vibration
  static void _enterAlert2() {
    _state = CheckinState.alert2;
    _alert2Remaining = 5;
    _notifyStateChange();
    _onShowAlert?.call(); // Show second alert (louder)

    _escalationTimer?.cancel();
    _escalationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _alert2Remaining--;
      _onTick?.call(_alert2Remaining);

      if (_alert2Remaining <= 0) {
        timer.cancel();
        _triggerAutoSos();
      }
    });
  }

  /// Auto-trigger SOS — user did not respond
  static Future<void> _triggerAutoSos() async {
    _state = CheckinState.autoSos;
    _notifyStateChange();
    _onDismissAlert?.call();

    // Log auto-SOS
    _logCheckinEvent('auto_sos');

    // Fire the full SOS pipeline with source tag
    await SosService.triggerManually(source: 'checkin_timer');

    // Reset state after SOS is sent
    _state = CheckinState.idle;
    _notifyStateChange();
  }

  /// User taps "I'm Safe" — cancel everything
  static void markSafe() {
    _escalationTimer?.cancel();
    _countdownTimer?.cancel();
    _onDismissAlert?.call();

    // Log safe check-in
    _logCheckinEvent('safe_checkin');

    _state = CheckinState.idle;
    _remainingSeconds = 0;
    _notifyStateChange();
  }

  /// User manually cancels timer
  static void cancelTimer() {
    _escalationTimer?.cancel();
    _countdownTimer?.cancel();
    _onDismissAlert?.call();

    _state = CheckinState.idle;
    _remainingSeconds = 0;
    _notifyStateChange();
  }

  /// Check if timer is active
  static bool isActive() => _state != CheckinState.idle;

  /// Format remaining time as mm:ss
  static String formatRemaining() {
    int mins = _remainingSeconds ~/ 60;
    int secs = _remainingSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  static void _notifyStateChange() {
    _onStateChanged?.call(_state);
  }

  /// Log check-in event to backend
  static Future<void> _logCheckinEvent(
    String eventType, {
    int? durationSeconds,
    String? note,
  }) async {
    try {
      final pos = LocationService.lastKnownPosition;
      final deviceId = await StorageService.getDeviceId();
      await BackendService.postJson('save_checkin.php', {
        'device_id': deviceId,
        'event_type': eventType,
        'duration_seconds': durationSeconds ?? _totalSeconds,
        'note': note ?? _note,
        'latitude': pos?.latitude,
        'longitude': pos?.longitude,
      });
    } catch (e) {
      print('Failed to log checkin event: $e');
    }
  }

  /// Dispose all timers
  static void dispose() {
    _countdownTimer?.cancel();
    _escalationTimer?.cancel();
    _onStateChanged = null;
    _onTick = null;
    _onShowAlert = null;
    _onDismissAlert = null;
  }
}
