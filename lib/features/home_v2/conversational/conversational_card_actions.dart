import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/compliance/ios_campaign_support.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/app_toast.dart';
import '../../chat/models/chat_conversation.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/utils/item_context_chat_message.dart';
import '../../donations/models/donation_models.dart';
import '../../feed/models/social_listing_card_data.dart';
import '../../gifting/models/gift_models.dart' as gift_models;
import '../../notifications/utils/notification_navigation.dart';
import '../../trade/models/trade_models.dart' as trade_models;
import '../../trade/providers/trade_backend_provider.dart';
import '../../trade/screens/negotiation_screen.dart';
import 'conversational_analytics.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Opens listing detail, primary CTAs, and owner messaging from conversational feed.
class ConversationalCardActions {
  ConversationalCardActions._();

  static void openDetail(BuildContext context, SocialListingCardData data) {
    ConversationalAnalytics.resultTap(
      module: data.module.name,
      listingId: data.id,
    );
    ConversationalAnalytics.aiIntentSlotTap(
      module: data.module.name,
      listingId: data.id,
      size: data.bentoSize.name,
    );
    switch (data.module) {
      case SocialListingModule.trade:
        AppRoutes.navigateToTradeDetailsById(context, data.id);
      case SocialListingModule.gift:
        AppRoutes.navigateToGiftDetailsById(context, data.id);
      case SocialListingModule.donation:
        AppRoutes.navigateToCampaignDetailsById(context, data.id);
    }
  }

  static Future<void> primaryAction(
    BuildContext context,
    SocialListingCardData data,
  ) async {
    ConversationalAnalytics.resultTap(
      module: data.module.name,
      listingId: data.id,
    );
    switch (data.module) {
      case SocialListingModule.trade:
        ConversationalAnalytics.aiIntentConversion(
          kind: 'offer',
          listingId: data.id,
        );
        await _tradeOffer(context, data);
      case SocialListingModule.gift:
        ConversationalAnalytics.aiIntentConversion(
          kind: 'claim',
          listingId: data.id,
        );
        await _giftClaim(context, data);
      case SocialListingModule.donation:
        ConversationalAnalytics.aiIntentConversion(
          kind: 'donation',
          listingId: data.id,
        );
        await _donationSupport(context, data);
    }
  }

  static Future<void> messageOwner(
    BuildContext context,
    SocialListingCardData data,
  ) async {
    if (AppRoutes.requireSignIn(context)) return;
    ConversationalAnalytics.messageOwnerTap(
      module: data.module.name,
      listingId: data.id,
    );

    final chatProvider = context.read<ChatProvider>();
    ChatConversation? conversation = chatProvider.findConversationInCache(
      contextId: data.id,
      partnerId: data.ownerId,
    );

    if (conversation == null) {
      conversation = await chatProvider.startDirectMessage(
        recipientId: data.ownerId,
        recipientName: data.ownerName,
        initialMessage: _introMessage(data),
        contextTitle: _contextTitle(data),
        contextId: data.id,
        apiType: 'DIRECT',
      );
    }

    if (!context.mounted) return;
    if (conversation == null) {
      AppToast.show(context, 'Could not open chat');
      return;
    }

    GuardedNavigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(conversation: conversation!, chatType: _chatType(data)),
      ),
    );
  }

  static Future<void> _tradeOffer(
    BuildContext context,
    SocialListingCardData data,
  ) async {
    if (AppRoutes.requireSignIn(context)) return;

    trade_models.Trade? target = _tradeFromCard(data);
    final provider = context.read<TradeBackendProvider>();

    if (target == null) {
      final raw = await provider.getTrade(data.id);
      if (raw != null) {
        try {
          target = trade_models.Trade.fromJson(raw);
        } catch (_) {}
      }
    }

    if (!context.mounted) return;
    if (target == null) {
      AppRoutes.navigateToTradeDetailsById(context, data.id);
      return;
    }

    List<trade_models.Trade> userTrades = [];
    try {
      final ownerId = context.read<AuthProvider>().currentUser?.id ?? '';
      if (ownerId.isNotEmpty) {
        final payload = await provider.listMyTrades(
          ownerId: ownerId,
          status: 'OPEN',
        );
        final items = payload['items'] as List? ?? [];
        userTrades = items
            .whereType<Map>()
            .map(
              (m) => trade_models.Trade.fromJson(Map<String, dynamic>.from(m)),
            )
            .toList();
      }
    } catch (_) {}

    if (!context.mounted) return;

    await GuardedNavigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NegotiationScreen(targetTrade: target!, userTrades: userTrades),
      ),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('View your offers in Trade Center'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () =>
              NotificationNavigation.openTradeOffersHub(tradeId: data.id),
        ),
      ),
    );
  }

  static Future<void> _giftClaim(
    BuildContext context,
    SocialListingCardData data,
  ) async {
    if (AppRoutes.requireSignIn(context)) return;
    final gift = _giftFromCard(data);
    if (gift != null) {
      await GuardedNavigator.pushNamed(
        context,
        AppConstants.claimGiftRoute,
        arguments: AppRoutes.giftToLegacyMap(gift),
      );
      return;
    }
    AppRoutes.navigateToGiftDetailsById(context, data.id);
  }

  static Future<void> _donationSupport(
    BuildContext context,
    SocialListingCardData data,
  ) async {
    final campaign = _campaignFromCard(data);
    if (campaign != null) {
      CampaignSupportCompliance.handleSupportTap(
        context,
        campaign: campaign,
        requireSignIn: true,
      );
      return;
    }
    AppRoutes.navigateToCampaignDetailsById(context, data.id);
  }

  static String _contextTitle(SocialListingCardData data) {
    switch (data.module) {
      case SocialListingModule.trade:
        return 'Trade: ${data.title}';
      case SocialListingModule.gift:
        return 'Gift: ${data.title}';
      case SocialListingModule.donation:
        return 'Campaign: ${data.title}';
    }
  }

  static String _introMessage(SocialListingCardData data) {
    switch (data.module) {
      case SocialListingModule.trade:
        final trade = _tradeFromCard(data);
        if (trade != null) {
          return ItemContextChatMessage.tradeIntroForOwner(trade);
        }
        return "Hi — I'm interested in your trade listing \"${data.title}\".";
      case SocialListingModule.gift:
        final gift = _giftFromCard(data);
        if (gift != null) {
          return ItemContextChatMessage.giftIntroForGiver(gift);
        }
        return "Hi — I'm interested in your gift \"${data.title}\".";
      case SocialListingModule.donation:
        return "Hi — I have a question about your campaign \"${data.title}\".";
    }
  }

  static ChatType _chatType(SocialListingCardData data) {
    switch (data.module) {
      case SocialListingModule.trade:
        return ChatType.trade;
      case SocialListingModule.gift:
        return ChatType.gifting;
      case SocialListingModule.donation:
        return ChatType.direct;
    }
  }

  static trade_models.Trade? _tradeFromCard(SocialListingCardData data) {
    final raw = data.raw;
    if (raw == null || raw.isEmpty) return null;
    try {
      return trade_models.Trade.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static gift_models.Gift? _giftFromCard(SocialListingCardData data) {
    final raw = data.raw;
    if (raw == null) return null;
    final nested = raw['gift'];
    if (nested is gift_models.Gift) return nested;
    try {
      return gift_models.Gift.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  static Campaign? _campaignFromCard(SocialListingCardData data) {
    final raw = data.raw;
    if (raw == null) return null;
    final nested = raw['campaign'];
    if (nested is Campaign) return nested;
    try {
      return Campaign.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }
}
