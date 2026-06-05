import 'dart:async';
import 'location_service.dart';
import 'storage_service.dart';
import 'voice_service.dart';
import 'call_service.dart';
import 'shake_service.dart';
import 'backend_service.dart';
import 'platform_dispatch_service.dart';

class SosService {
  static bool _isActive = false;
  static bool _isCooldown = false;
  static const int _cooldownSeconds = 10;
  static Function(String)? _onStatusChanged;
  static Function()? _onSosTriggerCallback;

  // Initialize voice-activated SOS
  static Future<void> initialize(Function(String) onStatusChanged) async {
    _onStatusChanged = onStatusChanged;

    String triggerPhrase = await StorageService.getTriggerPhrase();
    VoiceService.setTriggerPhrase(triggerPhrase);

    await VoiceService.initialize(() {
      _triggerSos(source: 'voice');
    });

    _updateStatus('Ready - Say "${VoiceService.getTriggerPhrase()}" to trigger SOS');
  }

  // Start listening for voice commands
  static Future<void> startListening() async {
    if (_isActive) return;
    _isActive = true;

    await VoiceService.startListening();
    _updateStatus('🎤 Listening for "${VoiceService.getTriggerPhrase()}"...');
  }

  // Stop listening
  static void stopListening() {
    _isActive = false;
    VoiceService.stopListening();
    _updateStatus('Voice detection stopped');
  }

  // Check if listening
  static bool isListening() {
    return _isActive && VoiceService.isListening();
  }

  // Set custom trigger phrase
  static Future<void> setTriggerPhrase(String phrase) async {
    await StorageService.saveTriggerPhrase(phrase);
    VoiceService.setTriggerPhrase(phrase);
    _updateStatus('Trigger phrase set: "$phrase"');
  }

  // Get current trigger phrase
  static String getTriggerPhrase() {
    return VoiceService.getTriggerPhrase();
  }

  // Set callback for when SOS is triggered
  static void setOnSosTriggerCallback(Function() callback) {
    _onSosTriggerCallback = callback;
  }

  // Trigger SOS with source tracking
  static Future<void> _triggerSos({String source = 'manual'}) async {
    if (_isCooldown) {
      _updateStatus('⏳ Cooldown active. Please wait...');
      return;
    }

    _isCooldown = true;
    _updateStatus('🆘 SOS triggered! Getting location...');
    _onSosTriggerCallback?.call();

    try {
      List<String> contacts = await StorageService.getEmergencyContacts();
      if (contacts.isEmpty) {
        _updateStatus('❌ No emergency contacts set!');
        _isCooldown = false;
        return;
      }

      String alertMode = await StorageService.getAlertMode();
      String locationUrl = await LocationService.getLocationUrl();
      String deviceId = await StorageService.getDeviceId();

      _updateStatus('📍 Location obtained. Sending alerts...');

      bool anySmsSuccess = false;
      bool anyCallSuccess = false;

      // Send to ALL contacts using cross-platform dispatch
      for (String contact in contacts) {
        if (alertMode == 'sms' || alertMode == 'both') {
          bool smsSent = await PlatformDispatchService.sendSosMessage(contact, locationUrl);
          if (smsSent) {
            _updateStatus('✅ SMS sent to $contact!');
            anySmsSuccess = true;
          }
        }

        if (alertMode == 'call' || alertMode == 'both') {
          bool callMade = await PlatformDispatchService.makeCall(contact);
          if (callMade) {
            _updateStatus('📞 Call initiated to $contact!');
            anyCallSuccess = true;
          }
        }
      }

      // Save to backend with enriched data
      final pos = LocationService.lastKnownPosition;
      if (pos != null) {
        bool savedToDb = await BackendService.saveSosAlert(
          latitude: pos.latitude,
          longitude: pos.longitude,
          locationUrl: locationUrl,
          phoneNumber: contacts.first,
          deviceId: deviceId,
          source: source,
          smsDelivered: anySmsSuccess,
          callConnected: anyCallSuccess,
        );
        if (savedToDb) {
          _updateStatus('✅ Alert saved to server');
        } else {
          _updateStatus('⚠️ Alert queued (offline) — will retry');
        }
      }

      if (!anySmsSuccess && !anyCallSuccess) {
        _updateStatus('❌ Failed to send alerts');
        // Trigger share fallback
        await PlatformDispatchService.shareViaAnyApp(locationUrl);
      } else {
        _updateStatus('✅ Alerts sent to ${contacts.length} contact(s)');
      }
    } catch (e) {
      _updateStatus('❌ Error: $e');
    }

    // Start cooldown timer
    Timer(Duration(seconds: _cooldownSeconds), () {
      _isCooldown = false;
      if (_isActive) {
        _updateStatus('🎤 Listening for "${VoiceService.getTriggerPhrase()}"...');
      }
    });
  }

  // Manually trigger SOS with optional source tag
  static Future<void> triggerManually({String source = 'manual'}) async {
    await _triggerSos(source: source);
  }

  // Update status callback
  static void _updateStatus(String status) {
    print(status);
    if (_onStatusChanged != null) {
      _onStatusChanged!(status);
    }
  }

  // Start shake detection
  static void startShakeDetection() {
    ShakeService.startListening(() {
      _updateStatus('📳 Shake detected! Triggering SOS...');
      _triggerSos(source: 'shake');
    });
  }

  // Stop shake detection
  static void stopShakeDetection() {
    ShakeService.stopListening();
  }

  // Check if shake detection is active
  static bool isShakeActive() {
    return ShakeService.isActive();
  }

  // Dispose resources
  static void dispose() {
    _isActive = false;
    _onSosTriggerCallback = null;
    VoiceService.dispose();
    ShakeService.dispose();
  }
}
