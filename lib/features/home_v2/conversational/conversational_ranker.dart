import '../../feed/models/social_listing_card_data.dart';
import 'intent_module.dart';

class RankedFeedItem {
  final SocialListingCardData data;
  final BentoTileSize size;
  final double score;

  const RankedFeedItem({
    required this.data,
    required this.size,
    required this.score,
  });

  RankedFeedItem copyWith({
    SocialListingCardData? data,
    BentoTileSize? size,
    double? score,
  }) {
    return RankedFeedItem(
      data: data ?? this.data,
      size: size ?? this.size,
      score: score ?? this.score,
    );
  }
}

/// Rules-based ranking for conversational home results.
class ConversationalRanker {
  ConversationalRanker._();

  static const _donationKeywords = {
    'donate',
    'donation',
    'campaign',
    'fund',
    'fundraiser',
    'charity',
    'crowdfund',
    'help',
    'surgery',
    'rent',
    'school',
    'urgent',
  };

  static const _tradeKeywords = {
    'trade',
    'swap',
    'barter',
    'exchange',
    'offer',
    'sell',
  };

  static const _giftKeywords = {
    'gift',
    'give',
    'free',
    'share',
  };

  static List<RankedFeedItem> rankAndSize({
    required List<SocialListingCardData> items,
    String? query,
    IntentModule? moduleBias,
    bool verifiedOnly = false,
    Map<IntentModule, double>? hubWeights,
  }) {
    if (items.isEmpty) return const [];

    final q = query?.trim().toLowerCase() ?? '';
    final donationBias = moduleBias == IntentModule.donation ||
        _donationKeywords.any(q.contains);
    final tradeBias =
        moduleBias == IntentModule.trade || _tradeKeywords.any(q.contains);
    final giftBias =
        moduleBias == IntentModule.gift || _giftKeywords.any(q.contains);

    final scored = <RankedFeedItem>[];
    for (final item in items) {
      if (verifiedOnly && item.module == SocialListingModule.donation && !item.isVerified) {
        continue;
      }
      scored.add(
        RankedFeedItem(
          data: item,
          size: BentoTileSize.standard,
          score: _score(
            item,
            donationBias: donationBias,
            tradeBias: tradeBias,
            giftBias: giftBias,
            hubWeights: hubWeights,
          ),
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    if (scored.isEmpty) return const [];

    final heroIndex = _pickHeroIndex(scored);
    if (heroIndex != null) {
      final hero = scored[heroIndex];
      scored[heroIndex] = hero.copyWith(size: BentoTileSize.hero);
    }

    for (var i = 0; i < scored.length; i++) {
      if (scored[i].size == BentoTileSize.hero) continue;
      final compact = !_hasPreviewImage(scored[i].data);
      scored[i] = scored[i].copyWith(
        size: compact ? BentoTileSize.compact : BentoTileSize.standard,
      );
    }

    return scored;
  }

  static double _score(
    SocialListingCardData item, {
    required bool donationBias,
    required bool tradeBias,
    required bool giftBias,
    Map<IntentModule, double>? hubWeights,
  }) {
    var score = 0.0;
    final weight = hubWeights?[_intentFor(item.module)];
    if (weight != null) score += weight;

    final distanceKm = _distanceKm(item);
    if (distanceKm != null) {
      score += (50 - distanceKm.clamp(0, 50)) * 2;
    } else {
      score += 10;
    }

    switch (item.module) {
      case SocialListingModule.donation:
        score += donationBias ? 40 : 8;
        if (item.isVerified) score += 25;
        final progress = item.progress;
        if (progress != null) {
          if (progress < 0.2) score += 20;
          if (progress > 0.75) score += 6;
        }
        if (_isEndingSoon(item)) score += 15;
      case SocialListingModule.trade:
        score += tradeBias ? 35 : 10;
      case SocialListingModule.gift:
        score += giftBias ? 30 : 10;
    }

    if (item.karmaTier != null && item.karmaTier!.isNotEmpty) {
      score += 5;
    }

    return score;
  }

  static IntentModule _intentFor(SocialListingModule module) {
    switch (module) {
      case SocialListingModule.trade:
        return IntentModule.trade;
      case SocialListingModule.gift:
        return IntentModule.gift;
      case SocialListingModule.donation:
        return IntentModule.donation;
    }
  }

  static int? _pickHeroIndex(List<RankedFeedItem> scored) {
    for (var i = 0; i < scored.length; i++) {
      final d = scored[i].data;
      if (d.module == SocialListingModule.donation &&
          d.isVerified &&
          (_isUrgentCampaign(d) || i == 0)) {
        return i;
      }
    }
    return scored.isNotEmpty ? 0 : null;
  }

  static bool _isUrgentCampaign(SocialListingCardData data) {
    final progress = data.progress;
    if (progress != null && progress < 0.2) return true;
    return _isEndingSoon(data);
  }

  static bool _isEndingSoon(SocialListingCardData data) {
    final raw = data.raw;
    if (raw == null) return false;
    final end = raw['endDate'] ?? raw['endsAt'] ?? raw['deadline'];
    if (end == null) return false;
    DateTime? dt;
    if (end is DateTime) {
      dt = end;
    } else if (end is String) {
      dt = DateTime.tryParse(end);
    }
    if (dt == null) return false;
    return dt.difference(DateTime.now()).inDays <= 7;
  }

  static double? _distanceKm(SocialListingCardData item) {
    final raw = item.raw;
    if (raw == null) return null;
    final d = raw['distanceKm'];
    if (d is num) return d.toDouble();
    if (d is String) return double.tryParse(d);
    return null;
  }

  static bool _hasPreviewImage(SocialListingCardData item) {
    if (item.previewImageUrl != null && item.previewImageUrl!.isNotEmpty) {
      return true;
    }
    return item.media.previewImageKey != null;
  }
}
