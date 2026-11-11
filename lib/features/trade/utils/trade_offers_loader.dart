import '../models/trade_models.dart';
import '../providers/trade_backend_provider.dart';

/// Loads trade offers from the API (received on own trades + sent on others' trades).
class TradeOffersLoader {
  TradeOffersLoader._();

  static const Set<String> _visibleStatuses = {
    'pending',
    'accepted',
    'acceptedawaitingfinalization',
    'rejected',
    'withdrawn',
  };

  static bool isOfferVisible(dynamic status) {
    final normalized =
        (status ?? 'pending').toString().toLowerCase().replaceAll('_', '');
    return _visibleStatuses.contains(normalized);
  }

  static TradeOffer? tryParseOffer(
    Map<String, dynamic> raw,
    Map<String, dynamic> tradeJson,
  ) {
    try {
      final enriched = Map<String, dynamic>.from(raw);
      enriched['trade'] = tradeJson;
      return TradeOffer.fromJson(enriched);
    } catch (_) {
      return null;
    }
  }

  /// When [filterTradeId] is set, only offers for that trade are returned.
  static Future<List<TradeOffer>> load({
    required TradeBackendProvider backend,
    required String userId,
    String? filterTradeId,
  }) async {
    if (userId.isEmpty) return [];

    if (filterTradeId != null && filterTradeId.isNotEmpty) {
      return _loadForTrade(backend, filterTradeId);
    }

    final aggregated = <TradeOffer>[];
    try {
      final res = await backend.listMyOffers(page: 1, size: 50);
      final items = (res['items'] as List?) ?? [];
      for (final raw in items) {
        if (raw is! Map) continue;
        final o = Map<String, dynamic>.from(raw);
        if (!isOfferVisible(o['status'])) continue;
        final trade = o['trade'] is Map
            ? Map<String, dynamic>.from(o['trade'] as Map)
            : <String, dynamic>{
                'id': o['tradeId'],
                'title': o['tradeTitle'] ?? 'Trade',
                'ownerId': o['ownerId'],
                'owner': {
                  'id': o['ownerId'],
                  'profile': {'displayName': o['ownerName']},
                },
              };
        final offer = tryParseOffer(o, trade);
        if (offer != null) aggregated.add(offer);
      }
    } catch (_) {}

    aggregated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return aggregated;
  }

  static Future<List<TradeOffer>> _loadForTrade(
    TradeBackendProvider backend,
    String tradeId,
  ) async {
    final aggregated = <TradeOffer>[];
    try {
      final list = await backend.listOffers(tradeId);
      final trade = <String, dynamic>{'id': tradeId};
      for (final o in list) {
        if (!isOfferVisible(o['status'])) continue;
        final offer = tryParseOffer(o, trade);
        if (offer != null) aggregated.add(offer);
      }
    } catch (_) {}
    return aggregated;
  }
}
