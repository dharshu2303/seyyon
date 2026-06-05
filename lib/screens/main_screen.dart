import 'dart:async';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/sos_service.dart';
import '../services/location_service.dart';
import '../services/geofence_service.dart';
import '../services/backend_service.dart';
import '../services/auth_service.dart';
import '../services/offline_queue_service.dart';
import 'setup_screen.dart';
import '../services/shake_service.dart';
import 'safe_map_screen.dart';
import 'checkin_timer_screen.dart';
import '../widgets/vel_icon.dart';

// ─── App Colors ───────────────────────────────────────────
class AppColors {
  static const Color primary = Color(0xFF10B981);
  static const Color primaryDark = Color(0xFF065F46);
  static const Color accent = Color(0xFFFF6584);
  static const Color bg = Colors.white;
  static const Color card = Color(0xFFF8F9FA);
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String _emergencyContact = '';
  List<String> _emergencyContacts = [];
  String _sosStatus = 'Ready';
  String _currentLocation = 'Getting location...';
  List<String> _triggerPhrases = ['help me'];
  String _alertMode = 'both';
  bool _isListening = false;
  bool _shakeEnabled = false;
  int _currentTabIndex = 0;
  bool _panicMode = false;
  bool _sosPressed = false;
  bool _isDeletingData = false;
  final GlobalKey<SafeMapScreenState> _safeMapKey = GlobalKey<SafeMapScreenState>();
  final TextEditingController _phraseController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();
  String _serverConnectionStatus = '';
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    String? contact = await StorageService.getEmergencyContact();
    List<String> contacts = await StorageService.getEmergencyContacts();
    List<String> phrases = await StorageService.getTriggerPhrases();
    String mode = await StorageService.getAlertMode();
    bool shakeEnabled = await StorageService.getShakeEnabled();

    setState(() {
      _emergencyContact = contact ?? '';
      _emergencyContacts = contacts;
      _triggerPhrases = phrases;
      _alertMode = mode;
      _shakeEnabled = shakeEnabled;
    });

    _serverUrlController.text = BackendService.getServerUrl();

    if (shakeEnabled) {
      SosService.startShakeDetection();
    }

    await SosService.initialize((status) {
      setState(() {
        _sosStatus = status;
        _isListening = SosService.isListening();
      });
    });

    SosService.setOnSosTriggerCallback(() {
      setState(() {
        _currentTabIndex = 1;
        _panicMode = true;
        _sosPressed = false;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        _safeMapKey.currentState?.activatePanicRoute();
      });
    });

    // Start periodic GPS caching for offline resilience
    LocationService.startPeriodicCache();

    // Start geofence monitoring
    GeofenceService.startMonitoring(
      onZoneEntry: (zone) {
        if (mounted) {
          _showGeofenceNotification(zone);
        }
      },
    );

    // Initialize auth
    try {
      await AuthService.initialize();
    } catch (e) {
      print('Auth init skipped: $e');
    }

    // Flush any queued offline alerts
    OfflineQueueService.flushQueue();

    _refreshLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshLocation();
    });
  }

  void _showGeofenceNotification(Map<String, dynamic> zone) {
    String level = zone['zone_level'] ?? 'amber';
    int score = (zone['safety_score'] as num?)?.toInt() ?? 50;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              level == 'red' ? Icons.warning : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'You are entering a flagged area (safety: $score/100).\nSOS contacts are ready.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: level == 'red' ? Colors.red.shade700 : Colors.orange.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _refreshLocation() async {
    String location = await LocationService.getLocationText();
    if (mounted) {
      setState(() {
        _currentLocation = location;
      });
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      SosService.stopListening();
    } else {
      await SosService.startListening();
    }
    setState(() {
      _isListening = SosService.isListening();
    });
  }

  Future<void> _addTriggerPhrase() async {
    String newPhrase = _phraseController.text.trim();
    if (newPhrase.isEmpty) return;
    if (_triggerPhrases.contains(newPhrase.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phrase already exists')),
      );
      return;
    }
    List<String> updated = [..._triggerPhrases, newPhrase.toLowerCase()];
    await StorageService.saveTriggerPhrases(updated);
    await SosService.setTriggerPhrase(updated.first);
    setState(() {
      _triggerPhrases = updated;
      _phraseController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added: "$newPhrase"')),
    );
  }

  Future<void> _removeTriggerPhrase(int index) async {
    if (_triggerPhrases.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one phrase is required')),
      );
      return;
    }
    List<String> updated = [..._triggerPhrases];
    updated.removeAt(index);
    await StorageService.saveTriggerPhrases(updated);
    await SosService.setTriggerPhrase(updated.first);
    setState(() => _triggerPhrases = updated);
  }

  void _testSos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test SOS Alert'),
        content: const Text('This will send an actual SMS to your emergency contact. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              SosService.triggerManually();
            },
            child: const Text('Send Test SOS'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMyData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All My Data'),
        content: const Text(
          'This will permanently delete ALL your data from our servers:\n\n'
          '• SOS alert history\n'
          '• Community reports\n'
          '• Check-in logs\n'
          '• Device registration\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isDeletingData = true);
      try {
        final token = await StorageService.getAuthToken();
        if (token != null && token.isNotEmpty) {
          await BackendService.deleteUserData(token);
        }
        await AuthService.clearToken();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ All your data has been deleted from our servers.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
      setState(() => _isDeletingData = false);
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    SosService.dispose();
    ShakeService.dispose();
    LocationService.dispose();
    GeofenceService.dispose();
    _phraseController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          // ═══════════════════════════════════════════════════
          // TAB 0 — HOME
          // ═══════════════════════════════════════════════════
          SafeArea(
            child: Column(
              children: [
                // ── App Header ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VelIcon(size: 36, color: AppColors.primary),
                          SizedBox(width: 10),
                          Text(
                            'Seyyon',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        'The Saviour',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Main content ──
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _sosStatus,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // ── Big SOS Button ──
                      GestureDetector(
                        onTapDown: (_) => setState(() => _sosPressed = true),
                        onTapUp: (_) => setState(() => _sosPressed = false),
                        onTapCancel: () => setState(() => _sosPressed = false),
                        onTap: () {
                          _testSos();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: _sosPressed ? 160 : 170,
                          height: _sosPressed ? 160 : 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withOpacity(_sosPressed ? 0.3 : 0.5),
                                blurRadius: _sosPressed ? 20 : 40,
                                spreadRadius: _sosPressed ? 2 : 8,
                              ),
                            ],
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.emergency, color: Colors.white, size: 48),
                              SizedBox(height: 8),
                              Text(
                                'SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap to send emergency alert',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // ── Bottom info cards ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    children: [
                      _infoTile(
                        icon: Icons.person,
                        iconBg: AppColors.primary,
                        title: 'Emergency Contacts',
                        subtitle: _emergencyContacts.isEmpty
                            ? 'Not set'
                            : _emergencyContacts.join(', '),
                        trailing: Icons.edit,
                        onTrailing: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const SetupScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _infoTile(
                        icon: Icons.location_on,
                        iconBg: AppColors.success,
                        title: 'Current Location',
                        subtitle: _currentLocation,
                        trailing: Icons.refresh,
                        onTrailing: _refreshLocation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ═══════════════════════════════════════════════════
          // TAB 1 — SAFE MAP
          // ═══════════════════════════════════════════════════
          SafeMapScreen(key: _safeMapKey, panicMode: _panicMode),

          // ═══════════════════════════════════════════════════
          // TAB 2 — CHECK-IN TIMER
          // ═══════════════════════════════════════════════════
          CheckinTimerScreen(
            onSosTriggered: () {
              setState(() {
                _currentTabIndex = 1;
                _panicMode = true;
              });
            },
          ),

          // ═══════════════════════════════════════════════════
          // TAB 3 — SETTINGS
          // ═══════════════════════════════════════════════════
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  const Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            VelIcon(size: 36, color: AppColors.primary),
                            SizedBox(width: 10),
                            Text('Seyyon',
                                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.5)),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text('The Saviour',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, letterSpacing: 3)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ═══ Trigger Phrases ═══
                  _sectionTitle('Voice Trigger Phrases'),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: AppColors.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(_triggerPhrases.length, (i) {
                              return Chip(
                                label: Text(
                                  '"${_triggerPhrases[i]}"',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () => _removeTriggerPhrase(i),
                                backgroundColor: AppColors.primary.withOpacity(0.08),
                                side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              );
                            }),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _phraseController,
                                  decoration: InputDecoration(
                                    hintText: 'Add new phrase...',
                                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                    ),
                                  ),
                                  onSubmitted: (_) => _addTriggerPhrase(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _addTriggerPhrase,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 18),
                                  ),
                                  child: const Icon(Icons.add, size: 22),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ═══ Alert Mode ═══
                  _sectionTitle('Alert Mode'),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: AppColors.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _alertOption('sms', Icons.message_rounded, 'SMS Only', 'Send SMS with location'),
                          Divider(color: Colors.grey.shade200, height: 1),
                          _alertOption('call', Icons.call_rounded, 'Call Only', 'Make emergency call'),
                          Divider(color: Colors.grey.shade200, height: 1),
                          _alertOption('both', Icons.notification_important_rounded, 'SMS + Call', 'Send SMS and make a call'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ═══ Shake to SOS ═══
                  _sectionTitle('Shake Detection'),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: AppColors.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: const Text('Shake to SOS', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      subtitle: Text(
                        _shakeEnabled ? 'Shake phone 3 times to trigger' : 'Disabled',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.vibration, color: AppColors.primary, size: 22),
                      ),
                      value: _shakeEnabled,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      onChanged: (value) async {
                        await StorageService.saveShakeEnabled(value);
                        setState(() => _shakeEnabled = value);
                        if (value) {
                          SosService.startShakeDetection();
                        } else {
                          SosService.stopShakeDetection();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ═══ Server URL ═══
                  _sectionTitle('Server (Database)'),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: AppColors.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SOS alerts are saved to your PHP/MySQL server for danger-zone mapping.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _serverUrlController,
                            decoration: InputDecoration(
                              hintText: 'http://your-server-ip/seyyon/api',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                              prefixIcon: const Icon(Icons.dns_rounded, color: AppColors.primary, size: 20),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    String url = _serverUrlController.text.trim();
                                    if (url.isEmpty) {
                                      setState(() => _serverConnectionStatus = '❌ Enter a URL first');
                                      return;
                                    }
                                    setState(() => _serverConnectionStatus = '⏳ Testing...');
                                    await BackendService.setServerUrl(url);
                                    bool ok = await BackendService.testConnection(url);
                                    setState(() {
                                      _serverConnectionStatus = ok
                                          ? '✅ Connected & saved!'
                                          : '❌ Cannot reach server';
                                    });
                                  },
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: const Text('Save & Test', style: TextStyle(fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_serverConnectionStatus.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              _serverConnectionStatus,
                              style: TextStyle(
                                fontSize: 12,
                                color: _serverConnectionStatus.contains('✅')
                                    ? AppColors.success
                                    : _serverConnectionStatus.contains('⏳')
                                        ? AppColors.textSecondary
                                        : AppColors.danger,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ═══ Privacy & Data ═══
                  _sectionTitle('Privacy & Data'),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: AppColors.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your data is auto-deleted after 90 days per DPDP Act 2023.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isDeletingData ? null : _deleteMyData,
                              icon: _isDeletingData
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.delete_forever, size: 20),
                              label: Text(
                                _isDeletingData ? 'Deleting...' : 'Delete All My Data',
                                style: const TextStyle(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ═══ How to Use ═══
                  _sectionTitle('How to Use'),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: AppColors.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _howToStep('1', 'Press the SOS button on the Home tab to trigger an emergency alert.'),
                          _howToStep('2', 'Add voice trigger phrases — saying any of them will auto-trigger SOS.'),
                          _howToStep('3', 'Enable Shake Detection to trigger SOS by shaking your phone.'),
                          _howToStep('4', 'Set a Check-in Timer when walking alone — auto-SOS if you don\'t check in.'),
                          _howToStep('5', 'Use Safe Map to see risk zones and search safety scores for any location.'),
                          _howToStep('6', 'Your location is automatically shared with your emergency contacts.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),

      // ═══════════════════════════════════════════════════
      // BOTTOM NAV — 4 tabs
      // ═══════════════════════════════════════════════════
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() => _currentTabIndex = index);
            if (index == 1) {
              _safeMapKey.currentState?.reloadMap();
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey.shade400,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Safe Map'),
            BottomNavigationBarItem(icon: Icon(Icons.timer_rounded), label: 'Timer'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  // ─── HELPER WIDGETS ──────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required IconData trailing,
    required VoidCallback onTrailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconBg, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTrailing,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(trailing, size: 18, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertOption(String value, IconData icon, String title, String subtitle) {
    bool selected = _alertMode == value;
    return InkWell(
      onTap: () async {
        await StorageService.saveAlertMode(value);
        setState(() => _alertMode = value);
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withOpacity(0.12) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: selected ? AppColors.primary : Colors.grey, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: selected ? AppColors.primary : AppColors.textPrimary)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : Colors.grey.shade300,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _howToStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(number, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
