import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  static const platform = MethodChannel('com.sosapp/sms');

  // Request SMS permission
  static Future<bool> requestSmsPermission() async {
    var status = await Permission.sms.status;
    
    if (status.isDenied) {
      status = await Permission.sms.request();
    }
    
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    
    return status.isGranted;
  }

  // Send SMS automatically using native Android
  static Future<bool> sendSms(String phoneNumber, String message) async {
    try {
      // Clean phone number
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Request permission first
      bool hasPermission = await requestSmsPermission();
      if (!hasPermission) {
        print('SMS permission not granted');
        return false;
      }
      
      // Call native Android method
      final String result = await platform.invokeMethod('sendSMS', {
        'phone': cleanNumber,
        'message': message,
      });
      
      print('Native SMS result: $result');
      return true;
    } on PlatformException catch (e) {
      print('Failed to send SMS: ${e.message}');
      return false;
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }

  // Send SOS message with location
  static Future<bool> sendSosMessage(String phoneNumber, String locationUrl) async {
    String message = 'SOS! Emergency alert!\n\n'
        'I need help! My current location:\n'
        '$locationUrl\n\n'
        'This is an automated emergency message.';
    
    return await sendSms(phoneNumber, message);
  }
}
