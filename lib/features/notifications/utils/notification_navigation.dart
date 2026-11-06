import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/navigation/main_navigation.dart';
import '../../gifting/screens/gift_details_loader.dart';
import '../../donations/screens/campaign_details_loader.dart';
import '../../trade/screens/trade_details_loader.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/models/chat_conversation.dart';
import '../../chat/providers/chat_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/app_models.dart';
import '../../../screens/coming_soon_screen.dart';
import '../../donations/screens/donations_screen.dart';
import '../../../core/constants/app_constants.dart' hide NotificationType;
import 'package:bybata/core/navigation/guarded_navigator.dart';
import 'package:bybata/core/widgets/debounced_tap.dart';

/// Handles navigation when user taps a notification (push or in-app).
/// Routes to the specific screen for trade, gift, campaign, or chat.
class NotificationNavigation {
  /// Resolves campaign id from notification payload. Never treats donation ids as campaigns.
  static String? resolveCampaignId(Map<String, dynamic> data) {
    final explicit = data['campaignId']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final actionUrl = data['actionUrl']?.toString() ?? '';
    final match = RegExp(r'/campaigns?/([^/?&#]+)', caseSensitive: false)
        .firstMatch(actionUrl);
    if (match != null) {
      final id = match.group(1);
      if (id != null && id.isNotEmpty) return id;
    }

    final sourceType = (data['sourceType'] as String?)?.toLowerCase() ?? '';
    if (sourceType == 'campaign') {
      final id = data['sourceId']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  static bool _isDonationPayload(Map<String, dynamic> data) {
    final type =
        ((data['notificationType'] ?? data['type']) as String?)?.toUpperCase() ??
            '';
    final sourceType = (data['sourceType'] as String?)?.toLowerCase() ?? '';
    return type.contains('DONATION') || sourceType == 'donation';
  }

  static bool isGiftRequestPayload(Map<String, dynamic> data) {
    final kind = (data['kind'] as String?)?.toLowerCase() ?? '';
    if (kind == 'gift_request') return true;
    final sourceType = (data['sourceType'] as String?)?.toLowerCase() ?? '';
    if (sourceType == 'gift_request') return true;
    final actionUrl = (data['actionUrl'] as String?) ?? '';
    if (actionUrl.contains('/gifting/requests') ||
        actionUrl.contains('/gifts/requests')) {
      return true;
    }
    final requestId = data['requestId']?.toString() ?? '';
    final title =
        ((data['title'] as String?) ?? '').toLowerCase();
    if (requestId.isNotEmpty &&
        (title.contains('gift request') || title.contains('requested your gift'))) {
      return true;
    }
    return false;
  }

  static void openGiftRequestsHub({
    String? giftId,
    String? requestId,
    bool force = false,
  }) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    GuardedNavigator.pushNamed(
      navigator.context,
      AppConstants.giftingRoute,
      force: force,
      arguments: {
        'initialTabIndex': 2,
        if (requestId != null && requestId.isNotEmpty)
          'highlightRequestId': requestId,
        if (giftId != null && giftId.isNotEmpty) 'highlightGiftId': giftId,
      },
    );
  }

  static bool isTradeOfferPayload(Map<String, dynamic> data) {
    final kind = (data['kind'] as String?)?.toLowerCase() ?? '';
    if (kind == 'trade_offer') return true;

    final type =
        ((data['notificationType'] ?? data['type']) as String?)?.toUpperCase() ??
            '';
    if (type.contains('TRADE_OFFER')) return true;

    final offerId = data['offerId']?.toString() ?? '';
    if (offerId.isEmpty) return false;

    final sourceType = (data['sourceType'] as String?)?.toLowerCase() ?? '';
    return type.contains('TRADE') || sourceType == 'trade';
  }

  static void openTradeOffersHub({
    String? tradeId,
    String? offerId,
    bool force = false,
  }) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    GuardedNavigator.pushNamed(
      navigator.context,
      AppConstants.tradeRoute,
      force: force,
      arguments: {
        'initialTabIndex': 3,
        if (offerId != null && offerId.isNotEmpty) 'highlightOfferId': offerId,
        if (tradeId != null && tradeId.isNotEmpty) 'highlightTradeId': tradeId,
      },
    );
  }

  static Map<String, dynamic> buildPayloadFromNotification(
    AppNotification notification,
  ) {
    final data = Map<String, dynamic>.from(notification.data ?? {});
    final sourceType = (data['sourceType'] as String?)?.toLowerCase() ?? '';
    final resolvedSource = sourceType.isNotEmpty
        ? sourceType
        : (_isDonationPayload(data)
            ? 'donation'
            : _sourceTypeFor(notification.type));
    // Prefer app-mapped category for routing. Server chat rows are often
    // SYSTEM_ANNOUNCEMENT and must still open chat — not the inbox again.
    final routingType = _routingTypeString(notification, resolvedSource, data);

    final merged = <String, dynamic>{
      'type': routingType,
      'notificationType': routingType,
      'title': notification.title,
      'sourceType': resolvedSource,
      'actionUrl': notification.actionUrl ?? '',
      'sourceId': data['sourceId'] ?? notification.targetId ?? '',
      'donationId':
          data['donationId'] ?? (sourceType == 'donation' ? notification.targetId : null),
      'tradeId': data['tradeId'],
      'giftId': data['giftId'] ?? notification.targetId,
      'requestId': data['requestId'],
      'kind': data['kind'],
      'conversationId': data['conversationId'],
      'offerId': data['offerId'],
    };
    merged['campaignId'] = resolveCampaignId({
      ...data,
      'actionUrl': merged['actionUrl'],
      'sourceType': merged['sourceType'],
      'sourceId': merged['sourceId'],
    });
    merged.removeWhere((_, v) => v == null || v == '');
    return merged;
  }

  static String _routingTypeString(
    AppNotification notification,
    String sourceType,
    Map<String, dynamic> data,
  ) {
    if (sourceType == 'chat_message' ||
        sourceType == 'chat' ||
        (data['type']?.toString().toLowerCase() == 'chat') ||
        (notification.actionUrl ?? '').startsWith('/chat/') ||
        notification.type == NotificationType.message) {
      return 'CHAT';
    }
    if (sourceType == 'broadcast' ||
        (data['notificationType']?.toString().toUpperCase() == 'BROADCAST')) {
      return 'BROADCAST';
    }
    return _typeToPayloadString(notification.type);
  }

  static String _typeToPayloadString(NotificationType type) {
    switch (type) {
      case NotificationType.trade:
        return 'TRADE';
      case NotificationType.gift:
        return 'GIFT';
      case NotificationType.campaign:
        return 'CAMPAIGN';
      case NotificationType.message:
        return 'CHAT';
      case NotificationType.achievement:
        return 'ACHIEVEMENT';
      default:
        return 'SYSTEM';
    }
  }

  static String _sourceTypeFor(NotificationType type) {
    switch (type) {
      case NotificationType.trade:
        return 'trade';
      case NotificationType.gift:
        return 'gift';
      case NotificationType.campaign:
        return 'campaign';
      case NotificationType.message:
        return 'chat_message';
      default:
        return '';
    }
  }

  static void navigateFromPayload(Map<String, dynamic> data) {
    // Lock immediately so double-taps cannot start two async navigations
    // (e.g. chat) before the first GuardedNavigator.push runs.
    if (!NavigationTapGuard.tryAcquire()) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      NavigationTapGuard.releaseInFlight();
      return;
    }

    void abort() => NavigationTapGuard.releaseInFlight();

    if (isGiftRequestPayload(data)) {
      openGiftRequestsHub(
        giftId: data['giftId']?.toString() ?? data['sourceId']?.toString(),
        requestId: data['requestId']?.toString(),
        force: true,
      );
      return;
    }

    if (isTradeOfferPayload(data)) {
      openTradeOffersHub(
        tradeId: data['tradeId']?.toString() ?? data['sourceId']?.toString(),
        offerId: data['offerId']?.toString(),
        force: true,
      );
      return;
    }

    final type = ((data['notificationType'] ?? data['type']) as String?)
            ?.toUpperCase() ??
        '';
    final sourceType = (data['sourceType'] as String?)?.toLowerCase() ?? '';
    final conversationId = data['conversationId']?.toString();
    final actionUrl = (data['actionUrl'] as String?) ?? '';
    final title = (data['title'] as String?)?.toLowerCase() ?? '';
    final kind = (data['kind'] as String?)?.toLowerCase() ?? '';

    // Chat first — many chat alerts are stored as SYSTEM_ANNOUNCEMENT.
    if (type == 'CHAT' ||
        sourceType == 'chat_message' ||
        sourceType == 'chat' ||
        (conversationId != null && conversationId.isNotEmpty) ||
        actionUrl.startsWith('/chat/') ||
        title.startsWith('message from') ||
        title.contains('mentioned you')) {
      final convId = conversationId ??
          (actionUrl.startsWith('/chat/')
              ? actionUrl.replaceFirst('/chat/', '').split('/').first
              : null);
      if (convId != null && convId.isNotEmpty) {
        openChatScreen(navigator.context, convId, force: true);
        return;
      }
      abort();
      return;
    }

    // BYC transfer / wallet — must run before TRADE_* matching.
    if (sourceType == 'transfer' ||
        sourceType == 'wallet' ||
        kind == 'byc_transfer' ||
        type.contains('TRANSFER') ||
        actionUrl.startsWith('/wallet')) {
      GuardedNavigator.pushNamed(
        navigator.context,
        AppConstants.walletRoute,
        force: true,
      );
      return;
    }

    final sourceId =
        data['sourceId'] ?? data['tradeId'] ?? data['giftId'] ?? data['campaignId'];
    final id = sourceId?.toString() ?? '';

    // Trade
    if (type.contains('TRADE') ||
        sourceType == 'trade' ||
        sourceType == 'nearby_trade' ||
        actionUrl.startsWith('/trades/')) {
      final tradeId = actionUrl.startsWith('/trades/')
          ? actionUrl.replaceFirst('/trades/', '').split('/').first
          : id;
      if (tradeId.isNotEmpty) {
        GuardedNavigator.push(
          navigator.context,
          MaterialPageRoute(
            builder: (_) => TradeDetailsLoader(tradeId: tradeId),
          ),
          force: true,
        );
      } else {
        abort();
      }
      return;
    }

    // Gift
    if (type.contains('GIFT') ||
        sourceType == 'gift' ||
        sourceType == 'nearby_gift' ||
        sourceType == 'gift_request' ||
        actionUrl.startsWith('/gifts/')) {
      final giftId = actionUrl.startsWith('/gifts/')
          ? actionUrl.replaceFirst('/gifts/', '').split('/').first
          : (data['giftId']?.toString() ?? id);
      if (giftId.isNotEmpty) {
        GuardedNavigator.push(
          navigator.context,
          MaterialPageRoute(
            builder: (_) => GiftDetailsLoader(giftId: giftId),
          ),
          force: true,
        );
      } else {
        abort();
      }
      return;
    }

    // Campaign / Donation
    if (type.contains('CAMPAIGN') ||
        type.contains('DONATION') ||
        type.contains('NEARBY') ||
        sourceType == 'campaign' ||
        sourceType == 'nearby_campaign' ||
        sourceType == 'donation' ||
        actionUrl.contains('campaign')) {
      final campaignId = resolveCampaignId(data);
      if (campaignId != null && campaignId.isNotEmpty) {
        GuardedNavigator.push(
          navigator.context,
          MaterialPageRoute(
            builder: (_) => CampaignDetailsLoader(campaignId: campaignId),
          ),
          force: true,
        );
        return;
      }
      if (_isDonationPayload(data)) {
        GuardedNavigator.push(
          navigator.context,
          MaterialPageRoute(
            builder: (_) => const DonationsScreen(initialTabIndex: 3),
          ),
          force: true,
        );
        return;
      }
      if (sourceType == 'campaign' && id.isNotEmpty) {
        GuardedNavigator.push(
          navigator.context,
          MaterialPageRoute(
            builder: (_) => CampaignDetailsLoader(campaignId: id),
          ),
          force: true,
        );
      } else {
        abort();
      }
      return;
    }

    // Achievement / referral
    if (type.contains('ACHIEVEMENT') ||
        type.contains('KARMA') ||
        type.contains('REFERRAL') ||
        sourceType == 'referral') {
      GuardedNavigator.pushNamed(
        navigator.context,
        '/karma/achievements',
        force: true,
      );
      return;
    }

    // Community — deferred; always Coming Soon for now.
    if (type.contains('COMMUNITY') || sourceType == 'community') {
      GuardedNavigator.push(
        navigator.context,
        MaterialPageRoute(
          builder: (_) => const ComingSoonScreen(title: 'Community'),
        ),
        force: true,
      );
      return;
    }

    // True admin broadcasts only — do not reopen inbox for SYSTEM_ANNOUNCEMENT.
    if (type == 'BROADCAST' || sourceType == 'broadcast') {
      abort();
      return;
    }

    // Explicit deep links (fallback)
    if (actionUrl.startsWith('/trades/')) {
      final tradeId = actionUrl.replaceFirst('/trades/', '').split('/').first;
      if (tradeId.isNotEmpty) {
        GuardedNavigator.push(
          navigator.context,
          MaterialPageRoute(
            builder: (_) => TradeDetailsLoader(tradeId: tradeId),
          ),
          force: true,
        );
      } else {
        abort();
      }
      return;
    }
    if (actionUrl.startsWith('/gifts/')) {
      final giftId = actionUrl.replaceFirst('/gifts/', '').split('/').first;
      if (giftId.isNotEmpty) {
        GuardedNavigator.push(
          navigator.context,
          MaterialPageRoute(
            builder: (_) => GiftDetailsLoader(giftId: giftId),
          ),
          force: true,
        );
      } else {
        abort();
      }
      return;
    }
    if (actionUrl.contains('campaign')) {
      final campaignId = resolveCampaignId(data);
      if (campaignId != null && campaignId.isNotEmpty) {
        GuardedNavigator.push(
          navigator.context,
          MaterialPageRoute(
            builder: (_) => CampaignDetailsLoader(campaignId: campaignId),
          ),
          force: true,
        );
      } else {
        abort();
      }
      return;
    }
    if (actionUrl.contains('community')) {
      GuardedNavigator.push(
        navigator.context,
        MaterialPageRoute(
          builder: (_) => const ComingSoonScreen(title: 'Community'),
        ),
        force: true,
      );
      return;
    }
    abort();
  }

  /// Opens the chat screen for the given conversation. Used by both push and in-app notification taps.
  ///
  /// [force] skips the navigation throttle when the caller already acquired it.
  static Future<void> openChatScreen(
    BuildContext context,
    String conversationId, {
    bool force = false,
  }) async {
    if (!force && !NavigationTapGuard.tryAcquire()) return;

    try {
      final auth = context.read<AuthProvider>();
      if (!auth.isAuthenticated) {
        if (context.mounted) {
          GuardedNavigator.pushNamed(context, '/login', force: true);
        } else {
          NavigationTapGuard.releaseInFlight();
        }
        return;
      }

      final chatProvider = context.read<ChatProvider>();

      // Prefer cache so the screen opens immediately — never block on a full list refresh.
      ChatConversation? convo;
      for (final c in chatProvider.conversations) {
        if (c.id == conversationId) {
          convo = c;
          break;
        }
      }
      convo ??= await chatProvider.fetchAndUpsertConversation(conversationId);
      if (!context.mounted) {
        NavigationTapGuard.releaseInFlight();
        return;
      }

      if (convo == null) {
        GuardedNavigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MainNavigation(initialScreen: 'chat'),
          ),
          force: true,
        );
        return;
      }

      final resolved = convo;
      GuardedNavigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversation: resolved,
            chatType: resolved.chatType,
          ),
        ),
        force: true,
      );

      // Keep conversation list fresh without delaying the open.
      unawaited(chatProvider.refreshConversations());
    } catch (_) {
      if (context.mounted) {
        GuardedNavigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MainNavigation(initialScreen: 'chat'),
          ),
          force: true,
        );
      } else {
        NavigationTapGuard.releaseInFlight();
      }
    }
  }
}
