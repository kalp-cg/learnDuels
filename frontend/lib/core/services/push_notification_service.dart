import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../constants/api_constants.dart';

class PushNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Initialize Push Notifications
  Future<void> initialize() async {
    try {
      // Request permission
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ User granted permission');

        // Get FCM Token
        String? token = await _firebaseMessaging.getToken();
        if (token != null) {
          debugPrint('🔥 FCM Token: $token');
          String platform = kIsWeb
              ? 'web'
              : (Platform.isAndroid ? 'android' : 'ios');
          await registerDevice(token, platform);
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          String platform = kIsWeb
              ? 'web'
              : (Platform.isAndroid ? 'android' : 'ios');
          registerDevice(newToken, platform);
        });

        // Setup message handlers
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('📩 Got a message whilst in the foreground!');
          debugPrint('Message data: ${message.data}');

          if (message.notification != null) {
            debugPrint(
              'Message also contained a notification: ${message.notification}',
            );
          }
        });
      } else {
        debugPrint('❌ User declined or has not accepted permission');
      }
    } catch (e) {
      debugPrint('⚠️ Push Notification Init Failed: $e');
    }
  }

  /// Register device for push notifications
  Future<void> registerDevice(String deviceToken, String platform) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        debugPrint('⚠️ Cannot register device: Not authenticated');
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/notifications/register-device'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'token': deviceToken, 'platform': platform}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Device registered for push notifications');
      } else {
        debugPrint('❌ Failed to register device: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error registering device: $e');
    }
  }

  /// Remove device token
  Future<void> removeDevice(String deviceToken) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/notifications/remove-device'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'token': deviceToken}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to remove device');
      }
    } catch (e) {
      debugPrint('Error removing device: $e');
      rethrow;
    }
  }

  /// Send test notification
  Future<void> sendTestNotification() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/notifications/test'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send test notification');
      }
    } catch (e) {
      debugPrint('Error sending test notification: $e');
      rethrow;
    }
  }
}
