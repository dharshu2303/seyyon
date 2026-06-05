import 'dart:math';
import 'package:flutter/material.dart';
import '../services/checkin_timer_service.dart';

/// Check-in Timer Screen
/// User sets a duration and optional note. Timer runs with countdown.
/// On expire, escalation sequence triggers through the service.
class CheckinTimerScreen extends StatefulWidget {
  final Function()? onSosTriggered;

  const CheckinTimerScreen({super.key, this.onSosTriggered});

  @override
  State<CheckinTimerScreen> createState() => _CheckinTimerScreenState();
}

class _CheckinTimerScreenState extends State<CheckinTimerScreen>
    with SingleTickerProviderStateMixin {
  static const Color _green = Color(0xFF10B981);
  static const Color _greenDark = Color(0xFF065F46);
  static const Color _red = Color(0xFFEF4444);
  static const Color _amber = Color(0xFFF59E0B);

  final TextEditingController _noteController = TextEditingController();
  int _selectedMinutes = 20;
  CheckinState _currentState = CheckinState.idle;
  int _displaySeconds = 0;
  OverlayEntry? _alertOverlay;

  // Preset durations
  final List<int> _presets = [10, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _initializeTimer();
  }

  void _initializeTimer() {
    CheckinTimerService.initialize(
      onStateChanged: (state) {
        if (mounted) {
          setState(() => _currentState = state);
        }
      },
      onTick: (remaining) {
        if (mounted) {
          setState(() => _displaySeconds = remaining);
        }
      },
      onShowAlert: _showEmergencyOverlay,
      onDismissAlert: _dismissEmergencyOverlay,
    );

    _currentState = CheckinTimerService.state;
    _displaySeconds = CheckinTimerService.remainingSeconds;
  }

  void _startTimer() {
    CheckinTimerService.startTimer(
      durationSeconds: _selectedMinutes * 60,
      note: _noteController.text.trim(),
    );
  }

  void _showEmergencyOverlay() {
    _dismissEmergencyOverlay();
    _alertOverlay = OverlayEntry(
      builder: (context) => _EmergencyAlertOverlay(
        state: _currentState,
        secondsRemaining: _displaySeconds,
        onSafe: () {
          CheckinTimerService.markSafe();
          _dismissEmergencyOverlay();
        },
      ),
    );
    Overlay.of(context).insert(_alertOverlay!);
  }

  void _dismissEmergencyOverlay() {
    _alertOverlay?.remove();
    _alertOverlay = null;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _dismissEmergencyOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _currentState == CheckinState.idle
          ? _buildSetupView()
          : _buildActiveTimerView(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SETUP VIEW — Timer not running
  // ═══════════════════════════════════════════════════════════
  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Header
          const Icon(Icons.timer_outlined, size: 48, color: _green),
          const SizedBox(height: 12),
          const Text(
            'Check-in Timer',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Set a timer. If you don\'t check in when it expires,\nyour emergency contacts will be alerted.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),

          // Duration presets
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Duration',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presets.map((mins) {
              bool selected = _selectedMinutes == mins;
              return GestureDetector(
                onTap: () => setState(() => _selectedMinutes = mins),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? _green : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? _green : Colors.grey.shade200,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 8)]
                        : [],
                  ),
                  child: Text(
                    mins >= 60 ? '${mins ~/ 60}hr' : '${mins}min',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF4B5563),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Custom slider
          Row(
            children: [
              const Icon(Icons.tune, size: 18, color: _green),
              const SizedBox(width: 8),
              Text('Custom: $_selectedMinutes min',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            ],
          ),
          Slider(
            value: _selectedMinutes.toDouble(),
            min: 5,
            max: 120,
            divisions: 23,
            activeColor: _green,
            label: '$_selectedMinutes min',
            onChanged: (v) => setState(() => _selectedMinutes = v.round()),
          ),
          const SizedBox(height: 16),

          // Note field
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: 'Add a note (e.g. "Walking home")',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: const Icon(Icons.note_alt_outlined, color: _green, size: 20),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _green, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Start button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _startTimer,
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: Text(
                'Start $_selectedMinutes min Timer',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // How it works
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How it works',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _greenDark)),
                const SizedBox(height: 8),
                _howStep('1', 'Timer runs as a countdown notification'),
                _howStep('2', 'When it expires, you\'ll get an "Are you safe?" alert'),
                _howStep('3', 'Tap "I\'m Safe" to cancel — no alerts sent'),
                _howStep('4', 'No response in 35 seconds → SOS auto-fires to your contacts'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _howStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(num,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _greenDark)),
            ),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIVE TIMER VIEW — Timer running
  // ═══════════════════════════════════════════════════════════
  Widget _buildActiveTimerView() {
    double progress = CheckinTimerService.totalSeconds > 0
        ? _displaySeconds / CheckinTimerService.totalSeconds
        : 0;

    Color ringColor = _green;
    String statusText = 'Timer running';
    if (_currentState == CheckinState.alert1 || _currentState == CheckinState.alert2) {
      ringColor = _red;
      statusText = 'Are you safe?';
      progress = _currentState == CheckinState.alert1
          ? _displaySeconds / 30
          : _displaySeconds / 5;
    } else if (_currentState == CheckinState.autoSos) {
      ringColor = _red;
      statusText = '🆘 SOS Sent!';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Countdown ring
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: _CountdownRingPainter(
                progress: progress,
                color: ringColor,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentState == CheckinState.running
                          ? CheckinTimerService.formatRemaining()
                          : '${_displaySeconds}s',
                      style: TextStyle(
                        fontSize: _currentState == CheckinState.running ? 40 : 48,
                        fontWeight: FontWeight.bold,
                        color: ringColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Note
          if (CheckinTimerService.note.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.note, size: 16, color: Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Text(
                    CheckinTimerService.note,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),

          // Action buttons
          if (_currentState == CheckinState.running) ...[
            // I'm Safe button (prominent)
            SizedBox(
              width: 200,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  CheckinTimerService.markSafe();
                },
                icon: const Icon(Icons.check_circle, size: 24),
                label: const Text("I'm Safe",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                CheckinTimerService.cancelTimer();
              },
              child: const Text('Cancel Timer',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            ),
          ],

          if (_currentState == CheckinState.alert1 ||
              _currentState == CheckinState.alert2) ...[
            // Large I'm Safe button during alerts
            SizedBox(
              width: 240,
              height: 64,
              child: ElevatedButton.icon(
                onPressed: () {
                  CheckinTimerService.markSafe();
                },
                icon: const Icon(Icons.check_circle, size: 32),
                label: const Text("I'M SAFE",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  elevation: 8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _currentState == CheckinState.alert1
                  ? 'SOS will auto-fire in ${_displaySeconds}s'
                  : '⚠️ FINAL WARNING — ${_displaySeconds}s',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _currentState == CheckinState.alert2 ? _red : _amber,
              ),
            ),
          ],

          if (_currentState == CheckinState.autoSos) ...[
            const Icon(Icons.emergency, size: 48, color: _red),
            const SizedBox(height: 8),
            const Text(
              'Emergency SOS has been sent\nto all your contacts',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _red),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// FULL-SCREEN EMERGENCY ALERT OVERLAY
// ═══════════════════════════════════════════════════════════
class _EmergencyAlertOverlay extends StatelessWidget {
  final CheckinState state;
  final int secondsRemaining;
  final VoidCallback onSafe;

  const _EmergencyAlertOverlay({
    required this.state,
    required this.secondsRemaining,
    required this.onSafe,
  });

  @override
  Widget build(BuildContext context) {
    bool isSecondAlert = state == CheckinState.alert2;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isSecondAlert
                ? [const Color(0xFFDC2626), const Color(0xFF991B1B)]
                : [const Color(0xFFEF4444), const Color(0xFFB91C1C)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSecondAlert ? Icons.warning_amber_rounded : Icons.access_time,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              Text(
                isSecondAlert ? '⚠️ FINAL WARNING' : 'Are You Safe?',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isSecondAlert
                    ? 'SOS fires in $secondsRemaining seconds!'
                    : 'Your timer has expired.\nTap below if you\'re okay.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 40),

              // Large I'M SAFE button
              GestureDetector(
                onTap: onSafe,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 56),
                      SizedBox(height: 8),
                      Text(
                        "I'M SAFE",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Countdown text
              Text(
                'Auto-SOS in $secondsRemaining seconds',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// COUNTDOWN RING PAINTER
// ═══════════════════════════════════════════════════════════
class _CountdownRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CountdownRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress.clamp(0, 1),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
