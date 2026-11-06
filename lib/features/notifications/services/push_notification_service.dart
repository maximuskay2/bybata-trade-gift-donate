import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../api/notifications_api.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static StreamSubscription<String>? _tokenSubscription;
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (e) {
      debugPrint('[PushNotificationService] Firebase init failed: $e');
    }
  }

  static Future<void> registerDeviceToken(NotificationsApi api) async {
    await ensureInitialized();
    if (!_initialized) return;

    try {
      await _messaging.requestPermission();
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      final storage = const FlutterSecureStorage();
      final existing = await storage.read(key: 'push_device_token');
      if (existing == token) {
        _listenForTokenRefresh(api);
        return;
      }

      if (existing != null && existing.isNotEmpty) {
        try {
          await api.removeDeviceToken(token: existing);
        } catch (_) {}
      }

      await api.registerDeviceToken(
        token: token,
        deviceType: _deviceType(),
      );
      await storage.write(key: 'push_device_token', value: token);
      _listenForTokenRefresh(api);
    } catch (e) {
      debugPrint('[PushNotificationService] Token registration failed: $e');
    }
  }

  static void _listenForTokenRefresh(NotificationsApi api) {
    _tokenSubscription ??= _messaging.onTokenRefresh.listen((newToken) async {
      try {
        final storage = const FlutterSecureStorage();
        final existing = await storage.read(key: 'push_device_token');
        if (existing != null && existing.isNotEmpty && existing != newToken) {
          try {
            await api.removeDeviceToken(token: existing);
          } catch (_) {}
        }
        await api.registerDeviceToken(
          token: newToken,
          deviceType: _deviceType(),
        );
        await storage.write(key: 'push_device_token', value: newToken);
      } catch (e) {
        debugPrint('[PushNotificationService] Token refresh failed: $e');
      }
    });
  }

  static String _deviceType() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }
}
