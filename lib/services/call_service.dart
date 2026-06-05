import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  static const platform = MethodChannel('com.sosapp/call');

  // Request phone call permission
  static Future<bool> requestCallPermission() async {
    var status = await Permission.phone.status;
    
    if (status.isDenied) {
      status = await Permission.phone.request();
    }
    
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    
    return status.isGranted;
  }

  // Make emergency call automatically (no user interaction)
  static Future<bool> makeEmergencyCall(String phoneNumber) async {
    try {
      // Clean phone number (remove spaces and special chars except +)
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Request permission first
      bool hasPermission = await requestCallPermission();
      if (!hasPermission) {
        print('Call permission not granted');
        return false;
      }
      
      // Call native Android method to place call automatically
      final String result = await platform.invokeMethod('makeCall', {
        'phone': cleanNumber,
      });
      
      print('Native call result: $result');
      return true;
    } on PlatformException catch (e) {
      print('Failed to make call: ${e.message}');
      return false;
    } catch (e) {
      print('Error making call: $e');
      return false;
    }
  }
}
