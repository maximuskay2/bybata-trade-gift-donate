import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/models/app_models.dart';
import '../services/push_notifications_service.dart';
import '../../chat/services/chat_websocket_service.dart';

/// Initializes notifications when user is authenticated:
/// - Calls NotificationProvider.initializeNotifications()
/// - Wires FCM foreground messages to addNotification
/// - Subscribes to Chat WebSocket onNotification
/// - Polling for unread count is started by initializeNotifications
class NotificationInitializer extends StatefulWidget {
  final Widget child;

  const NotificationInitializer({super.key, required this.child});

  @override
  State<NotificationInitializer> createState() => _NotificationInitializerState();
}

class _NotificationInitializerState extends State<NotificationInitializer>
    with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>>? _wsNotificationSubscription;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wsNotificationSubscription?.cancel();
    PushNotificationsService.onForegroundMessage = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final notificationProvider = context.read<NotificationProvider>();
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        notificationProvider.pausePollingForAppBackground();
        break;
      case AppLifecycleState.resumed:
        unawaited(notificationProvider.resumePollingAfterAppForeground());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _setupForAuthenticatedUser(
    NotificationProvider notificationProvider,
    String? userId,
  ) {
    if (_initialized) return;
    _initialized = true;

    notificationProvider.initializeNotifications(userId: userId);

    PushNotificationsService.onForegroundMessage = (RemoteMessage message) {
      _addFcmToProvider(notificationProvider, message);
    };

    _wsNotificationSubscription =
        ChatWebSocketService().onNotification.listen((data) {
      _addWebSocketToProvider(notificationProvider, data);
    });
  }

  void _teardown(NotificationProvider provider) {
    if (_initialized) {
      _initialized = false;
      _wsNotificationSubscription?.cancel();
      _wsNotificationSubscription = null;
      PushNotificationsService.onForegroundMessage = null;
    }
    provider.clearSessionOnSignOut();
  }

  void _addFcmToProvider(NotificationProvider provider, RemoteMessage message) {
    final data = message.data;
    final notif = message.notification;
    final title = notif?.title ?? (data['title'] as String?) ?? 'Notification';
    final body = notif?.body ??
        (data['body'] as String?) ??
        (data['message'] as String?) ??
        '';
    final id = (data['notificationId'] as String?)?.trim().isNotEmpty == true
        ? data['notificationId'] as String
        : (message.messageId ?? 'fcm_${DateTime.now().millisecondsSinceEpoch}');

    final typeStr =
        ((data['notificationType'] ?? data['type']) as String?)?.toUpperCase() ??
            '';
    final sourceType = (data['sourceType'] as String?)?.toLowerCase() ?? '';
    final type = _parseType(typeStr, sourceType);

    provider.addNotificationFromPayload(
      id: id,
      title: title,
      message: body,
      type: type,
      targetId: data['sourceId'] ??
          data['tradeId'] ??
          data['giftId'] ??
          data['campaignId'] ??
          data['donationId'],
      actionUrl: data['actionUrl'],
      conversationId: data['conversationId'],
      offerId: data['offerId'],
      sourceType: sourceType.isNotEmpty ? sourceType : null,
      campaignId: data['campaignId']?.toString(),
      donationId: data['donationId']?.toString(),
      giftId: data['giftId']?.toString(),
      requestId: data['requestId']?.toString(),
      kind: data['kind']?.toString(),
    );
  }

  void _addWebSocketToProvider(
    NotificationProvider provider,
    Map<String, dynamic> data,
  ) {
    final id = (data['id'] ?? 'ws_${DateTime.now().millisecondsSinceEpoch}') as String;
    final title = (data['title'] ?? 'New notification') as String;
    final message = (data['message'] ?? data['body'] ?? '') as String;
    final typeStr =
        ((data['notificationType'] ?? data['type']) as String?)?.toUpperCase() ??
            '';
    final sourceType = (data['sourceType'] as String?)?.toLowerCase() ?? '';
    final type = _parseType(typeStr, sourceType);

    provider.addNotificationFromPayload(
      id: id,
      title: title,
      message: message,
      type: type,
      targetId: data['sourceId'] ??
          data['tradeId'] ??
          data['giftId'] ??
          data['campaignId'] ??
          data['donationId'],
      actionUrl: data['actionUrl'],
      conversationId: data['conversationId'],
      offerId: data['offerId'],
      sourceType: sourceType.isNotEmpty ? sourceType : null,
      campaignId: data['campaignId']?.toString(),
      donationId: data['donationId']?.toString(),
    );
  }

  NotificationType _parseType(String typeStr, String sourceType) {
    if (sourceType == 'gift_request') return NotificationType.gift;
    if (sourceType == 'transfer' ||
        sourceType == 'wallet' ||
        typeStr.contains('TRANSFER')) {
      return NotificationType.system;
    }
    if (typeStr.contains('TRADE') || sourceType == 'trade') return NotificationType.trade;
    if (typeStr.contains('GIFT') || sourceType == 'gift') return NotificationType.gift;
    if (typeStr.contains('CAMPAIGN') ||
        typeStr.contains('DONATION') ||
        sourceType == 'campaign' ||
        sourceType == 'donation') {
      return NotificationType.campaign;
    }
    if (typeStr.contains('CHAT') ||
        typeStr == 'CHAT' ||
        sourceType == 'chat_message' ||
        sourceType == 'chat') {
      return NotificationType.message;
    }
    if (typeStr.contains('ACHIEVEMENT')) return NotificationType.achievement;
    return NotificationType.system;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, NotificationProvider>(
      builder: (context, auth, notificationProvider, _) {
        if (auth.isAuthenticated) {
          _setupForAuthenticatedUser(
            notificationProvider,
            auth.currentUser?.id,
          );
        } else {
          _teardown(notificationProvider);
        }
        return widget.child;
      },
    );
  }
}
