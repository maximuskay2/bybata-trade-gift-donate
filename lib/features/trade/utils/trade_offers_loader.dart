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

    final receivedTradeStatuses = ['OPEN', 'IN_OFFER'];
    final tradesForReceived = <Map<String, dynamic>>[];
    for (final status in receivedTradeStatuses) {
      try {
        final res = await backend.listMyTrades(
          ownerId: userId,
          status: status,
          page: 1,
          size: 50,
          forceRefresh: true,
        );
        final items = (res['items'] as List?) ?? [];
        for (final t in items) {
          if (t is Map) {
            tradesForReceived.add(Map<String, dynamic>.from(t));
          }
        }
      } catch (_) {}
    }

    final seenTradeIds = <String>{};
    for (final trade in tradesForReceived) {
      final tradeId = trade['id']?.toString() ?? '';
      if (tradeId.isEmpty || seenTradeIds.contains(tradeId)) continue;
      seenTradeIds.add(tradeId);
      try {
        final list = await backend.listOffers(tradeId);
        for (final o in list) {
          final bidderId = (o['bidderId'] ?? '').toString();
          if (bidderId == userId) continue;
          if (!isOfferVisible(o['status'])) continue;
          final offer = tryParseOffer(o, trade);
          if (offer != null) aggregated.add(offer);
        }
      } catch (_) {}
    }

    try {
      final allTradesRes =
          await backend.listMyTrades(ownerId: '', page: 1, size: 50, forceRefresh: true);
      final allTrades = (allTradesRes['items'] as List?) ?? [];
      for (final raw in allTrades) {
        if (raw is! Map) continue;
        final trade = Map<String, dynamic>.from(raw);
        final tradeId = trade['id']?.toString() ?? '';
        final ownerId =
            (trade['owner'] is Map) ? (trade['owner']['id']?.toString() ?? '') : '';
        final tradeStatus = (trade['status'] ?? '').toString().toUpperCase();
        if (tradeId.isEmpty || ownerId == userId) continue;
        if (tradeStatus == 'CLOSED' || tradeStatus == 'CANCELLED') continue;

        try {
          final list = await backend.listOffers(tradeId);
          for (final o in list) {
            final bidderId = (o['bidderId'] ?? '').toString();
            if (bidderId != userId) continue;
            if (!isOfferVisible(o['status'])) continue;
            final offer = tryParseOffer(o, trade);
            if (offer != null) aggregated.add(offer);
          }
        } catch (_) {}
      }
    } catch (_) {}

    aggregated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return aggregated;
  }

  static Future<List<TradeOffer>> _loadForTrade(
    TradeBackendProvider backend,
    String tradeId,
  ) async {
    final tradeJson = await backend.getTrade(tradeId);
    if (tradeJson == null) return [];

    final list = await backend.listOffers(tradeId);
    final offers = <TradeOffer>[];
    for (final o in list) {
      if (!isOfferVisible(o['status'])) continue;
      final offer = tryParseOffer(o, tradeJson);
      if (offer != null) offers.add(offer);
    }
    offers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return offers;
  }
}
