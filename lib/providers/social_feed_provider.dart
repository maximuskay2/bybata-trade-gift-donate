import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/utils/network_utils.dart';
import '../features/feed/mappers/social_listing_mapper.dart';
import '../features/feed/models/social_listing_card_data.dart';

/// Paginated browse feed for a single listing module (trade / gift / donation).
class SocialFeedProvider with ChangeNotifier {
  SocialFeedProvider(this._apiClient, this.module);

  final ApiClient _apiClient;
  final SocialListingModule module;

  static const int _pageSize = 20;

  final List<SocialListingCardData> _items = [];
  final Set<String> _seenIds = {};

  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

  List<SocialListingCardData> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get isEmpty => _items.isEmpty && !_isLoading;

  String get _path {
    switch (module) {
      case SocialListingModule.trade:
        return '/v1/public/browse/trades';
      case SocialListingModule.gift:
        return '/v1/public/browse/gifts';
      case SocialListingModule.donation:
        return '/v1/public/browse/campaigns';
    }
  }

  Future<void> load({bool refresh = false}) async {
    if (_isLoading) return;
    if (!refresh && !_hasMore) return;

    if (refresh) {
      _page = 1;
      _hasMore = true;
      _items.clear();
      _seenIds.clear();
      _error = null;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final resp = await _apiClient.get(
        _path,
        queryParameters: {'page': '$_page', 'size': '$_pageSize'},
      );
      final data = resp.data;
      if (data is! Map) {
        _hasMore = false;
        _isLoading = false;
        notifyListeners();
        return;
      }

      final map = Map<String, dynamic>.from(data);
      final rawItems = (map['items'] as List?) ?? const [];
      final total = (map['total'] as num?)?.toInt() ?? rawItems.length;

      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final itemMap = Map<String, dynamic>.from(raw);
        final card = _mapRaw(itemMap);
        if (card == null || card.id.isEmpty || _seenIds.contains(card.id)) {
          continue;
        }
        _seenIds.add(card.id);
        _items.add(card);
      }

      _hasMore = _page * _pageSize < total;
      _page += 1;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = NetworkUtils.getErrorMessage(e);
      debugPrint('[SocialFeedProvider] load failed: $_error');
      notifyListeners();
    }
  }

  Future<void> loadMore() => load();

  Future<void> refresh() => load(refresh: true);

  SocialListingCardData? _mapRaw(Map<String, dynamic> raw) {
    try {
      switch (module) {
        case SocialListingModule.trade:
          return SocialListingMapper.fromTradeMap(raw);
        case SocialListingModule.gift:
          return SocialListingMapper.fromGiftMap(raw);
        case SocialListingModule.donation:
          return SocialListingMapper.fromCampaignMap(raw);
      }
    } catch (e) {
      debugPrint('[SocialFeedProvider] map failed: $e');
      return null;
    }
  }
}
