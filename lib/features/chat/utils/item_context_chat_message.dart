import '../../donations/models/donation_models.dart' as donation_models;
import '../../gifting/models/gift_models.dart' as gift_models;
import '../../trade/models/trade_models.dart' as trade_models;
import '../../../core/models/listing_media.dart';

/// Structured first message when someone opens a chat about a listing so the
/// listing owner gets immediate context (notification + thread).
class ItemContextChatMessage {
  ItemContextChatMessage._();

  /// True when [partnerId] is the listing owner and the current user is not
  /// the owner (the interested party is messaging the owner).
  static bool shouldSendListingDetailsToOwner({
    required String currentUserId,
    required String partnerId,
    required String listingOwnerId,
  }) =>
      currentUserId != listingOwnerId && partnerId == listingOwnerId;

  static String tradeIntroForOwner(
    trade_models.Trade trade, {
    String? offerId,
  }) {
    final b = StringBuffer()
      ..writeln('[Trade listing]')
      ..writeln('Title: ${trade.title}')
      ..writeln('Category: ${trade.categoryName}')
      ..writeln('Condition: ${trade.condition.displayText}')
      ..writeln('Est. value: ${trade.estimatedValue} BYC');
    if (trade.location.isNotEmpty) {
      b.writeln('Location: ${trade.location}');
    }
    b.writeln('Listing ID: ${trade.id}');
    if (offerId != null && offerId.isNotEmpty) {
      b.writeln('Related offer: $offerId');
    }
    b.writeln();
    b.writeln("Hi — I'm reaching out about this trade listing.");
    return b.toString().trim();
  }

  static String tradeOwnerMessageToBuyer(trade_models.Trade trade) =>
      "Hi! Thanks for your interest in '${trade.title}'. Let's coordinate.";

  static String donationIntroForCreator(donation_models.Campaign campaign) {
    final b = StringBuffer()
      ..writeln('[Donation / campaign]')
      ..writeln('Title: ${campaign.title}')
      ..writeln('Category: ${campaign.category.name}')
      ..writeln('Goal: ${campaign.goalAmount.toStringAsFixed(0)} · Raised: ${campaign.raisedAmount.toStringAsFixed(0)}')
      ..writeln('Status: ${campaign.status.name}');
    if (campaign.location.isNotEmpty) {
      b.writeln('Location: ${campaign.location}');
    }
    b.writeln('Campaign ID: ${campaign.id}');
    b.writeln();
    b.writeln("Hi — I'm reaching out about this campaign.");
    return b.toString().trim();
  }

  static String donationCreatorMessageToSupporter(donation_models.Campaign campaign) =>
      "Hi! Thanks for your interest in '${campaign.title}'. How can I help?";

  static String giftIntroForGiver(gift_models.Gift gift) {
    final b = StringBuffer()
      ..writeln('[Gift listing]')
      ..writeln('Title: ${gift.title}')
      ..writeln('Category: ${gift.category.label}')
      ..writeln('Type: ${gift.type.label}')
      ..writeln('Status: ${gift.status.label}');
    if (gift.location != null && gift.location!.isNotEmpty) {
      b.writeln('Location: ${gift.location}');
    }
    b.writeln('Gift ID: ${gift.id}');
    b.writeln();
    b.writeln("Hi — I'm reaching out about this gift.");
    return b.toString().trim();
  }

  static String giftGiverMessageToRequester(gift_models.Gift gift) =>
      "Hi! Thanks for your interest in '${gift.title}'. Let's coordinate.";

  static String giftRequestIntroForGiver(gift_models.GiftRequest request) =>
      giftIntroForGiver(request.gift);

  static String? previewImageKey(ListingMediaFields media) =>
      media.previewImageKey;

  static String? previewImageKeyForTrade(trade_models.Trade trade) =>
      trade.listingMedia.previewImageKey;

  static String? previewImageKeyForGift(gift_models.Gift gift) =>
      gift.listingMedia.previewImageKey;

  static String? previewImageKeyForCampaign(donation_models.Campaign campaign) =>
      campaign.listingMedia.previewImageKey;
}
