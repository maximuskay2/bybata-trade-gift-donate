import '../../feed/models/social_listing_card_data.dart';
import 'conversational_ranker.dart';
import 'intent_module.dart';

enum _HubSlot { primary, secondary, banner }

/// Turns an interpret payload and grouped search rows into the existing
/// [RankedFeedItem] list. [BentoResultsGrid] is unchanged.
class BentoLayoutAdapter {
  BentoLayoutAdapter._();

  static List<RankedFeedItem> adapt({
    required Map<String, dynamic> interpret,
    required Map<String, List<SocialListingCardData>> grouped,
  }) {
    final layout = interpret['layout'];
    final primary = _hub(layout is Map ? layout['primary'] : null) ?? IntentModule.gift;
    final secondary = _hub(layout is Map ? layout['secondary'] : null) ?? IntentModule.trade;
    final banner = _hub(layout is Map ? layout['banner'] : null) ?? IntentModule.donation;
    final weights = _weights(interpret['hubs']);
    final query = interpret['query']?.toString();

    final seen = <String>{};
    final out = <RankedFeedItem>[];

    void take(IntentModule hub, _HubSlot slot) {
      final fresh = <SocialListingCardData>[];
      for (final item in _items(grouped, hub)) {
        if (seen.add('${item.module.name}_${item.id}')) fresh.add(item);
      }
      if (fresh.isEmpty) return;
      final ranked = ConversationalRanker.rankAndSize(
        items: fresh,
        query: query,
        moduleBias: hub,
        hubWeights: weights,
      );
      for (var i = 0; i < ranked.length; i++) {
        out.add(ranked[i].copyWith(size: _size(slot, i, ranked[i])));
      }
    }

    take(primary, _HubSlot.primary);
    if (secondary != primary) take(secondary, _HubSlot.secondary);
    if (banner != primary && banner != secondary) take(banner, _HubSlot.banner);
    return out;
  }

  static List<SocialListingCardData> _items(
    Map<String, List<SocialListingCardData>> grouped,
    IntentModule hub,
  ) {
    switch (hub) {
      case IntentModule.gift:
        return grouped['gift'] ?? const [];
      case IntentModule.trade:
        return grouped['trade'] ?? const [];
      case IntentModule.donation:
        return grouped['campaign'] ?? const [];
      default:
        return const [];
    }
  }

  static IntentModule? _hub(Object? raw) {
    switch (raw?.toString()) {
      case 'gift':
        return IntentModule.gift;
      case 'trade':
        return IntentModule.trade;
      case 'campaign':
        return IntentModule.donation;
      default:
        return null;
    }
  }

  static Map<IntentModule, double> _weights(Object? hubs) {
    double priority(Object? value) {
      switch (value?.toString()) {
        case 'high':
          return 200;
        case 'medium':
          return 80;
        case 'low':
          return 20;
        default:
          return 40;
      }
    }

    String? of(String hub) {
      if (hubs is! Map) return null;
      final row = hubs[hub];
      if (row is Map) return row['priority']?.toString();
      return null;
    }

    return {
      IntentModule.gift: priority(of('gift')),
      IntentModule.trade: priority(of('trade')),
      IntentModule.donation: priority(of('campaign')),
    };
  }

  static BentoTileSize _size(_HubSlot slot, int index, RankedFeedItem item) {
    if (slot == _HubSlot.primary) {
      return index == 0 ? BentoTileSize.hero : BentoTileSize.standard;
    }
    if (slot == _HubSlot.banner && item.data.module == SocialListingModule.donation) {
      return BentoTileSize.hero;
    }
    final noImage = (item.data.previewImageUrl == null || item.data.previewImageUrl!.isEmpty) &&
        item.data.media.previewImageKey == null;
    if (slot == _HubSlot.secondary && (item.size == BentoTileSize.compact || noImage)) {
      return BentoTileSize.compact;
    }
    if (item.size == BentoTileSize.hero) return BentoTileSize.standard;
    return item.size;
  }
}
