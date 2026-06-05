import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'backend_service.dart';

/// Offline resilience: queues failed backend posts and retries on reconnect
/// Uses SharedPreferences as a lightweight persistent queue
class OfflineQueueService {
  static const String _queueKey = 'offline_alert_queue';
  static const int _maxRetries = 3;
  static bool _isFlushing = false;

  /// Add a failed alert payload to the queue
  static Future<void> enqueue(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];

    Map<String, dynamic> item = {
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    };

    queue.add(jsonEncode(item));
    await prefs.setStringList(_queueKey, queue);
    print('📦 Alert queued offline (${queue.length} in queue)');
  }

  /// Flush all queued alerts — call on network reconnect
  static Future<void> flushQueue() async {
    if (_isFlushing) return;
    _isFlushing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> queue = prefs.getStringList(_queueKey) ?? [];

      if (queue.isEmpty) {
        _isFlushing = false;
        return;
      }

      print('📤 Flushing ${queue.length} queued alerts...');
      List<String> remaining = [];

      for (String itemJson in queue) {
        try {
          Map<String, dynamic> item = jsonDecode(itemJson);
          Map<String, dynamic> payload = Map<String, dynamic>.from(item['payload']);
          int retryCount = item['retry_count'] ?? 0;

          bool success = await _postToBackend(payload);

          if (!success && retryCount < _maxRetries) {
            item['retry_count'] = retryCount + 1;
            remaining.add(jsonEncode(item));
            print('⚠️ Retry ${retryCount + 1}/$_maxRetries failed, keeping in queue');
          } else if (success) {
            print('✅ Queued alert posted successfully');
          } else {
            print('❌ Max retries reached, discarding alert');
          }
        } catch (e) {
          print('❌ Error processing queued item: $e');
        }
      }

      await prefs.setStringList(_queueKey, remaining);
      print('📦 Queue: ${remaining.length} items remaining');
    } finally {
      _isFlushing = false;
    }
  }

  /// Attempt to post payload to backend
  static Future<bool> _postToBackend(Map<String, dynamic> payload) async {
    try {
      final baseUrl = BackendService.getServerUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/save_alert.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get current queue size
  static Future<int> getQueueSize() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];
    return queue.length;
  }

  /// Clear queue (for testing)
  static Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }
}
