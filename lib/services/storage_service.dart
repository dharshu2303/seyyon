import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _emergencyContactKey = 'emergency_contact';
  static const String _emergencyContactsKey = 'emergency_contacts';
  static const String _setupCompleteKey = 'setup_complete';

  // ═══════════════════════════════════════════════════════════
  // Emergency Contacts
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveEmergencyContact(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emergencyContactKey, phoneNumber);
    await prefs.setBool(_setupCompleteKey, true);
  }

  static Future<void> saveEmergencyContacts(List<String> numbers) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> cleaned = numbers
        .map((n) => n.replaceAll(RegExp(r'[^\d+]'), ''))
        .where((n) => n.length >= 10)
        .toList();
    await prefs.setStringList(_emergencyContactsKey, cleaned);
    if (cleaned.isNotEmpty) {
      await prefs.setString(_emergencyContactKey, cleaned.first);
    }
    await prefs.setBool(_setupCompleteKey, true);
  }

  static Future<List<String>> getEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? contacts = prefs.getStringList(_emergencyContactsKey);
    if (contacts != null && contacts.isNotEmpty) return contacts;
    String? single = prefs.getString(_emergencyContactKey);
    if (single != null && single.isNotEmpty) return [single];
    return [];
  }

  static Future<String?> getEmergencyContact() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emergencyContactKey);
  }

  static Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupCompleteKey) ?? false;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ═══════════════════════════════════════════════════════════
  // Trigger Phrases
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveTriggerPhrase(String phrase) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trigger_phrase', phrase.toLowerCase().trim());
  }

  static Future<String> getTriggerPhrase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('trigger_phrase') ?? 'help me';
  }

  static Future<void> saveTriggerPhrases(List<String> phrases) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> cleaned = phrases
        .map((p) => p.toLowerCase().trim())
        .where((p) => p.isNotEmpty)
        .toList();
    await prefs.setStringList('trigger_phrases', cleaned);
    if (cleaned.isNotEmpty) {
      await prefs.setString('trigger_phrase', cleaned.first);
    }
  }

  static Future<List<String>> getTriggerPhrases() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? phrases = prefs.getStringList('trigger_phrases');
    if (phrases == null || phrases.isEmpty) {
      String single = prefs.getString('trigger_phrase') ?? 'help me';
      return [single];
    }
    return phrases;
  }

  // ═══════════════════════════════════════════════════════════
  // Alert Mode
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveAlertMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alert_mode', mode);
  }

  static Future<String> getAlertMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('alert_mode') ?? 'both';
  }

  // ═══════════════════════════════════════════════════════════
  // Shake Detection
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveShakeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shake_enabled', enabled);
  }

  static Future<bool> getShakeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('shake_enabled') ?? false;
  }

  // ═══════════════════════════════════════════════════════════
  // API / Server URL
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_url', url.trim());
  }

  static Future<String?> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_url');
  }

  static Future<void> saveApiEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('api_enabled', enabled);
  }

  static Future<bool> getApiEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('api_enabled') ?? false;
  }

  static Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url.trim());
  }

  static Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_url');
  }

  // ═══════════════════════════════════════════════════════════
  // Device ID (unique per install)
  // ═══════════════════════════════════════════════════════════

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null || deviceId.isEmpty) {
      // Generate a simple unique ID
      deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }

  // ═══════════════════════════════════════════════════════════
  // Auth Token (JWT)
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // ═══════════════════════════════════════════════════════════
  // DPDP Consent
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveConsentGiven(bool given) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dpdp_consent_given', given);
    if (given) {
      await prefs.setString('dpdp_consent_date', DateTime.now().toIso8601String());
    }
  }

  static Future<bool> isConsentGiven() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('dpdp_consent_given') ?? false;
  }

  // ═══════════════════════════════════════════════════════════
  // Cached GPS Location
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveCachedLocation(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('cached_lat', lat);
    await prefs.setDouble('cached_lng', lng);
    await prefs.setString('cached_location_time', DateTime.now().toIso8601String());
  }

  static Future<Map<String, double>?> getCachedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    double? lat = prefs.getDouble('cached_lat');
    double? lng = prefs.getDouble('cached_lng');
    if (lat != null && lng != null) {
      return {'lat': lat, 'lng': lng};
    }
    return null;
  }
}
