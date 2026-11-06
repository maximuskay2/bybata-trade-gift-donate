import '../../../core/models/listing_media.dart';
import '../../../core/utils/media_utils.dart';
import '../../../models/feed_item.dart';
import '../../../models/intent_types.dart';
import '../../donations/models/donation_models.dart';
import '../../gifting/models/gift_models.dart' as gift_models;
import '../models/social_listing_card_data.dart';

class SocialListingMapper {
  SocialListingMapper._();

  static void _seedListingMediaUrls(Map<String, dynamic> raw) {
    MediaResolver.seedUrlsFromListingMaps([raw]);
  }

  static SocialListingCardData fromTradeMap(Map<String, dynamic> trade) {
    _seedListingMediaUrls(trade);
    final owner = (trade['owner'] as Map?)?.cast<String, dynamic>() ?? {};
    final profile = (owner['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final media = ListingMediaFields(
      mediaType: (trade['mediaType']?.toString().toUpperCase() == 'VIDEO')
          ? ListingMediaType.video
          : ListingMediaType.image,
      mediaKeys: List<String>.from(trade['mediaKeys'] ?? []),
      videoKey: trade['videoKey']?.toString(),
      thumbnailKey: trade['thumbnailKey']?.toString(),
    );

    return SocialListingCardData(
      id: trade['id']?.toString() ?? '',
      module: SocialListingModule.trade,
      title: trade['title']?.toString() ?? 'Untitled trade',
      description: trade['description']?.toString() ?? '',
      ownerId: owner['id']?.toString() ?? '',
      ownerName: profile['displayName']?.toString() ??
          trade['ownerFirstName']?.toString() ??
          'Member',
      ownerAvatarKey: profile['avatarKey']?.toString(),
      karmaTier: _readTier(trade, owner),
      distanceLabel: _readDistance(trade),
      media: media,
      previewImageUrl: _previewUrlFor(media, trade),
      ownerAvatarUrl: trade['ownerAvatarUrl']?.toString(),
      latestCommentPreview: _readCommentPreview(trade),
      isVerified: _readVerified(trade, owner),
      hasUnreadMessages: _readHasUnread(trade),
      raw: trade,
    );
  }

  static String? _previewUrlFor(ListingMediaFields media, [Map<String, dynamic>? raw]) {
    final key = media.previewImageKey;
    if (key != null) {
      final cached = MediaResolver.peekCachedUrl(key);
      if (cached != null) return cached;
    }
    if (raw != null) {
      final direct = raw['previewImageUrl'] ?? raw['thumbnailUrl'];
      if (direct != null && direct.toString().trim().isNotEmpty) {
        return direct.toString();
      }
    }
    return null;
  }

  static SocialListingCardData fromGift(gift_models.Gift gift) {
    final media = gift.listingMedia;
    return SocialListingCardData(
      id: gift.id,
      module: SocialListingModule.gift,
      title: gift.title,
      description: gift.description,
      ownerId: gift.giver.id,
      ownerName: gift.giver.name,
      ownerAvatarKey: gift.giver.profileImageUrl,
      karmaTier: gift.minimumKarmaLevel?.name.toUpperCase(),
      distanceLabel: gift.location,
      media: media,
      previewImageUrl: _previewUrlFor(media),
      latestCommentPreview: null,
      raw: {'gift': gift},
    );
  }

  static SocialListingCardData fromCampaign(Campaign campaign) {
    final progress = campaign.goalAmount > 0
        ? (campaign.raisedAmount / campaign.goalAmount).clamp(0.0, 1.0)
        : 0.0;
    final media = campaign.listingMedia;
    return SocialListingCardData(
      id: campaign.id,
      module: SocialListingModule.donation,
      title: campaign.title,
      description: campaign.story,
      ownerId: campaign.creator.id,
      ownerName: campaign.creator.name,
      ownerAvatarKey: null,
      karmaTier: null,
      distanceLabel: campaign.location.isNotEmpty ? campaign.location : null,
      media: media,
      previewImageUrl: _previewUrlFor(media),
      progress: progress,
      progressLabel:
          '${campaign.formattedRaised} raised of ${campaign.formattedGoal}',
      latestCommentPreview: null,
      raw: {'campaign': campaign},
    );
  }

  static SocialListingCardData fromGiftMap(Map<String, dynamic> g) {
    _seedListingMediaUrls(g);
    final giver = (g['giver'] as Map?)?.cast<String, dynamic>() ?? {};
    final profile = (giver['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final mediaKeys = <String>[];
    final mk = g['mediaKeys'];
    if (mk is List) {
      for (final v in mk) {
        if (v is String && v.isNotEmpty) mediaKeys.add(v);
      }
    }
    final media = ListingMediaFields(
      mediaType: (g['mediaType']?.toString().toUpperCase() == 'VIDEO')
          ? ListingMediaType.video
          : ListingMediaType.image,
      mediaKeys: mediaKeys,
      videoKey: g['videoKey']?.toString(),
      thumbnailKey: g['thumbnailKey']?.toString(),
    );
    return SocialListingCardData(
      id: g['id']?.toString() ?? '',
      module: SocialListingModule.gift,
      title: g['title']?.toString() ?? 'Gift',
      description: g['description']?.toString() ?? '',
      ownerId: giver['id']?.toString() ?? '',
      ownerName: profile['displayName']?.toString() ?? 'Member',
      ownerAvatarKey: profile['avatarKey']?.toString(),
      karmaTier: _readTier(g, giver),
      distanceLabel: _readDistance(g),
      media: media,
      previewImageUrl: _previewUrlFor(media, g),
      ownerAvatarUrl: g['ownerAvatarUrl']?.toString(),
      latestCommentPreview: _readCommentPreview(g),
      isVerified: _readVerified(g, giver),
      hasUnreadMessages: _readHasUnread(g),
      raw: g,
    );
  }

  static SocialListingCardData fromCampaignMap(Map<String, dynamic> c) {
    _seedListingMediaUrls(c);
    final creator =
        (c['creator'] as Map?)?.cast<String, dynamic>() ??
        (c['founder'] as Map?)?.cast<String, dynamic>() ??
        (c['owner'] as Map?)?.cast<String, dynamic>() ??
        {};
    final profile = (creator['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final mediaKeys = <String>[];
    final mk = c['mediaKeys'];
    if (mk is List) {
      for (final v in mk) {
        if (v is String && v.isNotEmpty) mediaKeys.add(v);
      }
    }
    final goal = _toDouble(c['goalAmount']);
    final raised = _toDouble(c['currentAmount'] ?? c['raisedAmount']);
    final progress = goal > 0 ? (raised / goal).clamp(0.0, 1.0) : null;

    final media = ListingMediaFields(
      mediaType: (c['mediaType']?.toString().toUpperCase() == 'VIDEO')
          ? ListingMediaType.video
          : ListingMediaType.image,
      mediaKeys: mediaKeys,
      videoKey: c['videoKey']?.toString(),
      thumbnailKey: c['thumbnailKey']?.toString(),
    );

    return SocialListingCardData(
      id: c['id']?.toString() ?? '',
      module: SocialListingModule.donation,
      title: c['title']?.toString() ?? 'Campaign',
      description: (c['story'] ?? c['description'])?.toString() ?? '',
      ownerId: creator['id']?.toString() ?? '',
      ownerName: profile['displayName']?.toString() ?? 'Campaign',
      ownerAvatarKey: profile['avatarKey']?.toString(),
      karmaTier: _readTier(c, creator),
      distanceLabel: _readDistance(c),
      media: media,
      previewImageUrl: _previewUrlFor(media, c),
      ownerAvatarUrl: c['ownerAvatarUrl']?.toString(),
      progress: progress,
      progressLabel: goal > 0
          ? '\$${raised.toStringAsFixed(0)} raised of \$${goal.toStringAsFixed(0)}'
          : null,
      latestCommentPreview: _readCommentPreview(c),
      isVerified: _readVerified(c, creator),
      hasUnreadMessages: _readHasUnread(c),
      raw: c,
    );
  }

  static SocialListingCardData fromFeedItem(FeedItem item) {
    final raw = item.metadata ?? {};
    final mediaKeys = <String>[];
    final mk = raw['mediaKeys'];
    if (mk is List) {
      for (final v in mk) {
        if (v is String && v.isNotEmpty) mediaKeys.add(v);
      }
    }
    if (mediaKeys.isEmpty && item.imageUrl != null) {
      mediaKeys.add(item.imageUrl!);
    }

    final module = switch (item.sourceType) {
      FeedSourceType.trade => SocialListingModule.trade,
      FeedSourceType.gift => SocialListingModule.gift,
      FeedSourceType.campaign => SocialListingModule.donation,
      FeedSourceType.post => SocialListingModule.trade,
    };

    double? progress;
    String? progressLabel;
    if (module == SocialListingModule.donation) {
      final goal = _toDouble(raw['goalAmount']);
      final raised = _toDouble(raw['currentAmount'] ?? raw['raisedAmount']);
      if (goal > 0) {
        progress = (raised / goal).clamp(0.0, 1.0);
        progressLabel = '\$${raised.toStringAsFixed(0)} raised of \$${goal.toStringAsFixed(0)}';
      }
    }

    final media = ListingMediaFields(
      mediaType: (raw['mediaType']?.toString().toUpperCase() == 'VIDEO')
          ? ListingMediaType.video
          : ListingMediaType.image,
      mediaKeys: mediaKeys,
      videoKey: raw['videoKey']?.toString(),
      thumbnailKey: raw['thumbnailKey']?.toString(),
    );

    return SocialListingCardData(
      id: item.id,
      module: module,
      title: item.title,
      description: item.summary,
      ownerId: item.author.id,
      ownerName: item.author.name,
      ownerAvatarKey: item.author.avatar,
      karmaTier: raw['ownerMembershipTier']?.toString() ??
          raw['membershipTier']?.toString(),
      distanceLabel: item.location,
      media: media,
      previewImageUrl: _previewUrlFor(media, raw),
      progress: progress,
      progressLabel: progressLabel,
      latestCommentPreview: _readCommentPreview(raw),
      raw: raw,
    );
  }

  static String? _readTier(Map<String, dynamic> raw, [Map<String, dynamic>? owner]) {
    final direct = raw['ownerMembershipTier'] ?? raw['membershipTier'];
    if (direct != null) return direct.toString();
    final membership = owner?['membership'];
    if (membership is Map) {
      return membership['tier']?.toString();
    }
    return owner?['trustLevel']?.toString();
  }

  static String? _readDistance(Map<String, dynamic> raw) {
    final d = raw['distanceKm'] ?? raw['distanceLabel'] ?? raw['location'];
    if (d == null) return null;
    if (d is num) return '${d.toStringAsFixed(1)} km away';
    final s = d.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _readCommentPreview(Map<String, dynamic> raw) {
    final c = raw['latestComment'] ?? raw['topComment'];
    if (c is Map) {
      final text = c['content'] ?? c['text'] ?? c['body'];
      if (text is String && text.trim().isNotEmpty) return text.trim();
    }
    if (c is String && c.trim().isNotEmpty) return c.trim();
    return null;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static bool _readHasUnread(Map<String, dynamic> raw) {
    final value = raw['hasUnreadMessages'];
    if (value is bool) return value;
    if (value is num) return value > 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }

  static bool _readVerified(Map<String, dynamic> raw, [Map<String, dynamic>? owner]) {
    if (raw['isVerified'] == true) return true;
    final creator = owner ??
        (raw['creator'] as Map?)?.cast<String, dynamic>() ??
        (raw['founder'] as Map?)?.cast<String, dynamic>() ??
        (raw['owner'] as Map?)?.cast<String, dynamic>();
    if (creator != null && creator['isVerified'] == true) return true;
    final campaign = raw['campaign'];
    if (campaign != null) {
      try {
        final dynamic c = campaign;
        if (c is Campaign && c.creator.isVerified) return true;
      } catch (_) {}
    }
    return false;
  }

  /// Maps a unified search / browse API row to [SocialListingCardData].
  static SocialListingCardData? fromSearchItemMap(Map<String, dynamic> raw) {
    final type = (raw['type'] ?? raw['entityType'] ?? raw['module'])
        ?.toString()
        .toLowerCase();
    switch (type) {
      case 'trade':
        return fromTradeMap(raw);
      case 'gift':
        return fromGiftMap(raw);
      case 'campaign':
      case 'donation':
        return fromCampaignMap(raw);
      default:
        if (raw.containsKey('goalAmount') ||
            raw.containsKey('raisedAmount') ||
            raw.containsKey('currentAmount')) {
          return fromCampaignMap(raw);
        }
        if (raw.containsKey('giver') || type == 'gift') {
          return fromGiftMap(raw);
        }
        if (raw.containsKey('owner') || raw.containsKey('tradeStatus')) {
          return fromTradeMap(raw);
        }
        return null;
    }
  }
}
