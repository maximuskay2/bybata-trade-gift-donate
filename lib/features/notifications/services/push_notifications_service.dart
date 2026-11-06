import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../firebase_options.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../api/notifications_api.dart';
import '../utils/notification_navigation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await PushNotificationsService.showBackgroundNotification(message);
  } catch (e) {
    debugPrint('Background FCM handler failed: $e');
  }
}

class PushNotificationsService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// New channel id so existing installs pick up the signature Bybata sound
  /// (Android locks channel sound after first creation).
  static const String androidChannelId = 'bybata_alerts';
  static const String androidChannelName = 'Bybata Alerts';
  static const String androidChannelDescription =
      'Trade, gift, donation, chat, and system alerts from Bybata';
  /// Matches [android/app/src/main/res/raw/bybata_notification.mp3]
  static const String androidSoundName = 'bybata_notification';
  /// Matches [ios/Runner/bybata.caf] in the app bundle
  static const String iosSoundName = 'bybata.caf';

  /// Callback when a foreground FCM message arrives. Set by NotificationInitializer
  /// to add the notification to NotificationProvider.
  static void Function(RemoteMessage message)? onForegroundMessage;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      // Firebase is initialized in main.dart; ensure it's ready before FCM setup
      if (Firebase.apps.isEmpty) {
        if (kIsWeb) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } else {
          await Firebase.initializeApp();
        }
      }
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
      return;
    }

    _initialized = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _initializeLocalNotifications();
    await _registerTokenIfAuthenticated();

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _registerTokenIfAuthenticated(token: token);
    });

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM message: ${message.messageId} ${message.notification?.title}');
      onForegroundMessage?.call(message);
      _showLocalNotification(message);
    });

    // Handle notification tap when app opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });
  }

  /// Call from main.dart after first frame to handle app launch from notification
  static Future<void> handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      _handleNotificationTap(message.data);
    }
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    NotificationNavigation.navigateFromPayload(Map<String, dynamic>.from(data));
  }

  static Future<void> syncTokenWithServer() async {
    await _registerTokenIfAuthenticated(retries: 3);
  }

  /// Call on logout so pushes are not sent to this device for the previous user.
  static Future<void> unregisterTokenFromServer() async {
    try {
      const storage = FlutterSecureStorage();
      final access = await storage.read(key: 'access');
      final fcmToken =
          await storage.read(key: 'push_device_token') ?? await _messaging.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      if (access != null && access.isNotEmpty) {
        final baseUrl = await EnvConfig.getBaseUrl();
        final apiClient = ApiClient(baseUrl, storage);
        final api = NotificationsApi(apiClient);
        await api.removeDeviceToken(token: fcmToken);
      }
      await storage.delete(key: 'push_device_token');
    } catch (e) {
      debugPrint('Failed to unregister device token: $e');
    }
  }

  /// Removes tray notifications shown for the previous signed-in user.
  static Future<void> clearLocalNotifications() async {
    try {
      await _localNotifications.cancelAll();
    } catch (e) {
      debugPrint('Failed to clear local notifications: $e');
    }
  }

  static Future<void> _requestPermission() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.notification.request();
        debugPrint('Android notification permission: $status');
      }
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM permission: ${settings.authorizationStatus}');
      if (!kIsWeb && Platform.isIOS) {
        // FCM on iOS needs APNS token before getToken() is reliable.
        await _waitForApnsToken();
      }
    } catch (e) {
      debugPrint('Push permission request failed: $e');
    }
  }

  static Future<String?> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final apns = await _messaging.getAPNSToken();
        if (apns != null && apns.isNotEmpty) return apns;
      } catch (e) {
        debugPrint('APNS token attempt $attempt failed: $e');
      }
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
    return null;
  }

  static Future<String?> _resolveFcmToken() async {
    if (!kIsWeb && Platform.isIOS) {
      await _waitForApnsToken();
    }
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (e) {
        debugPrint('FCM getToken attempt $attempt failed: $e');
      }
      await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    }
    return null;
  }

  static Future<void> _registerTokenIfAuthenticated({
    String? token,
    int retries = 1,
  }) async {
    for (var attempt = 0; attempt < retries; attempt++) {
      try {
        const storage = FlutterSecureStorage();
        final access = await storage.read(key: 'access');
        if (access == null || access.isEmpty) return;

        final fcmToken = token ?? await _resolveFcmToken();
        if (fcmToken == null || fcmToken.isEmpty) {
          debugPrint('No FCM token yet (attempt ${attempt + 1}/$retries)');
          if (attempt < retries - 1) {
            await Future<void>.delayed(Duration(seconds: attempt + 1));
            continue;
          }
          return;
        }

        final baseUrl = await EnvConfig.getBaseUrl();
        final apiClient = ApiClient(baseUrl, storage);
        final api = NotificationsApi(apiClient);
        // Always upsert — heals DB if token was purged after FCM invalidation.
        await api.registerDeviceToken(
          token: fcmToken,
          deviceType: _deviceType(),
        );
        await storage.write(key: 'push_device_token', value: fcmToken);
        debugPrint('FCM token registered with server');
        return;
      } catch (e) {
        debugPrint('Failed to register device token (attempt ${attempt + 1}): $e');
        if (attempt < retries - 1) {
          await Future<void>.delayed(Duration(seconds: attempt + 1));
        }
      }
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final parts = response.payload!.split('&');
            final data = <String, dynamic>{};
            for (final p in parts) {
              final kv = p.split('=');
              if (kv.length == 2) {
                data[Uri.decodeComponent(kv[0])] = Uri.decodeComponent(kv[1]);
              }
            }
            _handleNotificationTap(data);
          } catch (_) {}
        }
      },
    );

    await _ensureAndroidChannel(_localNotifications);
  }

  static Future<void> _ensureAndroidChannel(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    const channel = AndroidNotificationChannel(
      androidChannelId,
      androidChannelName,
      description: androidChannelDescription,
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(androidSoundName),
    );
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Display a notification when the app is in the background/terminated isolate.
  static Future<void> showBackgroundNotification(RemoteMessage message) async {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    await _ensureAndroidChannel(plugin);
    await _showLocalNotification(message, plugin: plugin);
  }

  static Future<void> _showLocalNotification(
    RemoteMessage message, {
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    final notifications = plugin ?? _localNotifications;
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ??
        data['title'] as String? ??
        'ByBata';
    final body = notification?.body ??
        data['body'] as String? ??
        data['message'] as String? ??
        '';
    if (title.isEmpty && body.isEmpty) return;

    const androidDetails = AndroidNotificationDetails(
      androidChannelId,
      androidChannelName,
      channelDescription: androidChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(androidSoundName),
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      sound: iosSoundName,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Encode data as payload for tap handling (key=value&key2=value2)
    String? payload;
    if (message.data.isNotEmpty) {
      payload = message.data.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
    }

    await notifications.show(
      message.hashCode,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static String _deviceType() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'web';
  }
}
