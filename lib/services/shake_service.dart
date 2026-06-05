import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeService {
  static StreamSubscription<AccelerometerEvent>? _subscription;
  static Function? _onShakeDetected;
  static bool _isActive = false;

  // Shake detection thresholds
  static const double _shakeThreshold = 15.0; // Force threshold (m/s²)
  static const int _shakeCountNeeded = 3; // Number of shakes needed
  static const int _shakeWindowMs = 1500; // Time window to count shakes (ms)
  static const int _cooldownMs = 3000; // Cooldown after trigger (ms)

  static final List<int> _shakeTimestamps = [];
  static bool _inCooldown = false;

  /// Start listening for shake gestures
  static void startListening(Function onShakeDetected) {
    if (_isActive) return;

    _onShakeDetected = onShakeDetected;
    _isActive = true;
    _shakeTimestamps.clear();

    _subscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((AccelerometerEvent event) {
      _processAccelerometerData(event);
    });
  }

  /// Stop listening for shake gestures
  static void stopListening() {
    _isActive = false;
    _subscription?.cancel();
    _subscription = null;
    _shakeTimestamps.clear();
  }

  /// Check if shake detection is currently active
  static bool isActive() => _isActive;

  /// Process accelerometer data to detect shake
  static void _processAccelerometerData(AccelerometerEvent event) {
    if (_inCooldown) return;

    // Calculate total acceleration force (excluding gravity ~9.8)
    double acceleration = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // Subtract gravity to get actual device movement
    double force = (acceleration - 9.8).abs();

    if (force > _shakeThreshold) {
      int now = DateTime.now().millisecondsSinceEpoch;

      // Remove old timestamps outside the shake window
      _shakeTimestamps.removeWhere(
        (timestamp) => now - timestamp > _shakeWindowMs,
      );

      _shakeTimestamps.add(now);

      // Check if enough shakes detected within the window
      if (_shakeTimestamps.length >= _shakeCountNeeded) {
        _shakeTimestamps.clear();
        _triggerShake();
      }
    }
  }

  /// Handle shake trigger with cooldown
  static void _triggerShake() {
    if (_inCooldown) return;

    _inCooldown = true;
    _onShakeDetected?.call();

    // Reset cooldown after delay
    Timer(const Duration(milliseconds: _cooldownMs), () {
      _inCooldown = false;
    });
  }

  /// Dispose resources
  static void dispose() {
    stopListening();
    _onShakeDetected = null;
  }
}
