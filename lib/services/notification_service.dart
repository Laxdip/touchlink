// ─────────────────────────────────────────────
// lib/services/notification_service.dart
// Handles FCM token retrieval, foreground
// notification display, and background handler.
// ─────────────────────────────────────────────

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'vibration_service.dart';

// ── Must be a top-level function (not a class method) ──
// Called when a notification arrives while app is terminated or in background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Trigger vibration even when app is in background/terminated
  final type = message.data[AppConstants.notifKeyType] ?? AppConstants.touchSingle;
  await VibrationService.triggerFromType(type);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  /// Call once at app startup (in main.dart)
  static Future<void> initialize() async {
    // ── 1. Register background handler ──
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // ── 2. Request notification permission (iOS + Android 13+) ──
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ── 3. Set foreground presentation options ──
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: false, // vibration only — no sound
    );

    // ── 4. Init flutter_local_notifications for foreground display ──
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotif.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );

    // ── 5. Create high-priority Android notification channel ──
    const channel = AndroidNotificationChannel(
      AppConstants.notifChannelId,
      AppConstants.notifChannelName,
      description: AppConstants.notifChannelDesc,
      importance: Importance.high,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // ── 6. Listen for foreground messages ──
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  /// Handle message when app is in foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data[AppConstants.notifKeyType] ?? AppConstants.touchSingle;
    final isAnonymous = data[AppConstants.notifKeyAnonymous] == 'true';

    // Trigger vibration
    await VibrationService.triggerFromType(type);

    // Show local notification only if NOT anonymous mode
    if (!isAnonymous) {
      final title = '💗 Touch received';
      final body = _bodyFromType(type);
      await _showLocalNotification(title, body);
    }
    // In anonymous mode → silent vibration only (no notification shown)
  }

  /// Show a local notification (foreground use)
  static Future<void> _showLocalNotification(
      String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      AppConstants.notifChannelId,
      AppConstants.notifChannelName,
      channelDescription: AppConstants.notifChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: false, // we handle vibration manually
    );
    await _localNotif.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  static String _bodyFromType(String type) {
    switch (type) {
      case AppConstants.touchDouble:
        return '✌️ Double tap from your partner';
      case AppConstants.touchLong:
        return '🤗 Long hug from your partner';
      default:
        return '👆 Single tap from your partner';
    }
  }

  /// Fetch current FCM device token
  static Future<String?> getToken() async {
    return await FirebaseMessaging.instance.getToken();
  }

  // ──────────────────────────────────────────────────────────
  // Send push to partner via Firebase Cloud Messaging HTTP v1
  // ──────────────────────────────────────────────────────────
  // NOTE: In production you should call a Cloud Function or
  // your own backend instead of calling FCM directly from the
  // app (to keep your service account key secret).
  // For this MVP we use the FCM Legacy HTTP API with a server
  // key — replace YOUR_SERVER_KEY below after creating your
  // Firebase project.
  // ──────────────────────────────────────────────────────────
  static Future<void> sendTouchNotification({
    required String targetFcmToken,
    required String touchType,
    required bool anonymous,
    required String senderId,
  }) async {
    // ⚠️  Replace with your actual FCM Server Key from:
    //     Firebase Console → Project Settings → Cloud Messaging → Server Key
    const String serverKey = 'YOUR_FCM_SERVER_KEY';

    final url = Uri.parse('https://fcm.googleapis.com/fcm/send');

    final payload = {
      // Target device
      'to': targetFcmToken,

      // High-priority so it wakes the device
      'priority': 'high',

      // Data payload (always delivered, works in background)
      'data': {
        AppConstants.notifKeyType: touchType,
        AppConstants.notifKeySenderId: senderId,
        AppConstants.notifKeyAnonymous: anonymous.toString(),
      },

      // Notification payload shown in system tray when app is background
      // Hidden in anonymous mode
      if (!anonymous)
        'notification': {
          'title': '💗 Touch received',
          'body': _bodyFromType(touchType),
          'sound': 'default',
        },
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception('FCM error: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
