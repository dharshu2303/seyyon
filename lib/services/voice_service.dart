import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceService {
  static const platform = MethodChannel('com.sosapp/speech');
  static bool _isListening = false;
  static String _triggerPhrase = 'help me';
  static Function()? _onTriggerDetected;

  // Initialize - setup method call handler for callbacks from native
  static Future<void> initialize(Function() onTriggerDetected) async {
    _onTriggerDetected = onTriggerDetected;
    
    // Handle callbacks from native Android
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onListening':
          _isListening = call.arguments as bool;
          print('Listening status: $_isListening');
          break;
        case 'onResult':
          String result = call.arguments as String;
          print('Speech recognized: $result');
          break;
        case 'onTriggerDetected':
          print('🚨 TRIGGER PHRASE DETECTED!');
          if (_onTriggerDetected != null) {
            _onTriggerDetected!();
          }
          break;
        case 'onError':
          String error = call.arguments as String;
          print('Speech error: $error');
          break;
      }
    });
  }

  // Request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    
    return status.isGranted;
  }

  // Set custom trigger phrase
  static void setTriggerPhrase(String phrase) {
    _triggerPhrase = phrase.toLowerCase().trim();
    print('Trigger phrase set to: $_triggerPhrase');
  }

  // Get current trigger phrase
  static String getTriggerPhrase() {
    return _triggerPhrase;
  }

  // Start listening for voice commands
  static Future<bool> startListening() async {
    try {
      // Request permission first
      bool hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        print('Microphone permission not granted');
        return false;
      }
      
      // Start native speech recognition
      await platform.invokeMethod('startListening', {
        'triggerPhrase': _triggerPhrase,
      });
      
      _isListening = true;
      print('Started listening for "$_triggerPhrase"...');
      return true;
    } on PlatformException catch (e) {
      print('Failed to start listening: ${e.message}');
      return false;
    }
  }

  // Stop listening
  static Future<void> stopListening() async {
    try {
      await platform.invokeMethod('stopListening');
      _isListening = false;
      print('Stopped listening');
    } on PlatformException catch (e) {
      print('Failed to stop listening: ${e.message}');
    }
  }

  // Check if currently listening
  static bool isListening() {
    return _isListening;
  }

  // Dispose resources
  static void dispose() {
    stopListening();
  }
}
