import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/utils/network_error_message.dart';

/// Result of a geo-cascaded browse query (5 → 50 → 500 km).
class CascadingLiquidityResult {
  final Map<String, dynamic> payload;
  final double? radiusKmUsed;
  final bool liquidityExhausted;

  const CascadingLiquidityResult({
    required this.payload,
    required this.radiusKmUsed,
    required this.liquidityExhausted,
  });
}

/// Optional geo filter for listing browse/search endpoints.
class ListingGeoQuery {
  final double? lat;
  final double? lng;
  final double radiusKm;
  final String? locationLabel;

  const ListingGeoQuery({
    this.lat,
    this.lng,
    this.radiusKm = 50,
    this.locationLabel,
  });

  bool get isActive =>
      (lat != null && lng != null) ||
      (locationLabel != null && locationLabel!.trim().isNotEmpty);

  Map<String, dynamic> toParams() => {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (lat != null && lng != null) 'radiusKm': radiusKm,
        if (locationLabel != null && locationLabel!.trim().isNotEmpty)
          'location': locationLabel!.trim(),
      };
}

class SearchApiService {
  final ApiClient _apiClient;

  SearchApiService(this._apiClient);

  static const List<double> _cascadeRadiiKm = [5.0, 50.0, 500.0];

  bool _isEmptyPayload(Map<String, dynamic> payload) {
    final items = payload['items'];
    if (items is List) return items.isEmpty;
    return true;
  }

  void _seedListingPayload(Map<String, dynamic> payload) {
    final items = payload['items'];
    if (items is List) {
      MediaResolver.seedUrlsFromListingMaps(
        items.whereType<Map<String, dynamic>>(),
      );
    }
  }

  Map<String, dynamic> _listingPayload(Map<String, dynamic> payload) {
    _seedListingPayload(payload);
    return payload;
  }

  ListingGeoQuery _geoAtStep(ListingGeoQuery? base, int radiusStep) {
    if (base == null || base.lat == null || base.lng == null) {
      return base ?? const ListingGeoQuery();
    }
    final idx = (radiusStep - 1).clamp(0, _cascadeRadiiKm.length - 1);
    return ListingGeoQuery(
      lat: base.lat,
      lng: base.lng,
      radiusKm: _cascadeRadiiKm[idx],
      locationLabel: base.locationLabel,
    );
  }

  Future<CascadingLiquidityResult> listTradesPublicWithCascadingLiquidity({
    String? query,
    String? status,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
    int radiusStep = 1,
  }) async {
    final stepGeo = _geoAtStep(geo, radiusStep);
    final payload = await listTradesPublic(
      query: query,
      status: status,
      geo: stepGeo.isActive ? stepGeo : geo,
      page: page,
      size: size,
    );
    final canCascade = geo?.lat != null &&
        geo?.lng != null &&
        _isEmptyPayload(payload) &&
        radiusStep < _cascadeRadiiKm.length;
    if (canCascade) {
      return listTradesPublicWithCascadingLiquidity(
        query: query,
        status: status,
        geo: geo,
        page: page,
        size: size,
        radiusStep: radiusStep + 1,
      );
    }
    final exhausted = geo?.lat != null &&
        geo?.lng != null &&
        _isEmptyPayload(payload) &&
        radiusStep >= _cascadeRadiiKm.length;
    return CascadingLiquidityResult(
      payload: payload,
      radiusKmUsed: stepGeo.isActive ? stepGeo.radiusKm : null,
      liquidityExhausted: exhausted,
    );
  }

  Future<CascadingLiquidityResult> listGiftsPublicWithCascadingLiquidity({
    String? query,
    String? status,
    String? category,
    String? type,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
    int radiusStep = 1,
  }) async {
    final stepGeo = _geoAtStep(geo, radiusStep);
    final payload = await listGiftsPublic(
      query: query,
      status: status,
      category: category,
      type: type,
      geo: stepGeo.isActive ? stepGeo : geo,
      page: page,
      size: size,
    );
    final canCascade = geo?.lat != null &&
        geo?.lng != null &&
        _isEmptyPayload(payload) &&
        radiusStep < _cascadeRadiiKm.length;
    if (canCascade) {
      return listGiftsPublicWithCascadingLiquidity(
        query: query,
        status: status,
        category: category,
        type: type,
        geo: geo,
        page: page,
        size: size,
        radiusStep: radiusStep + 1,
      );
    }
    final exhausted = geo?.lat != null &&
        geo?.lng != null &&
        _isEmptyPayload(payload) &&
        radiusStep >= _cascadeRadiiKm.length;
    return CascadingLiquidityResult(
      payload: payload,
      radiusKmUsed: stepGeo.isActive ? stepGeo.radiusKm : null,
      liquidityExhausted: exhausted,
    );
  }

  Future<CascadingLiquidityResult> listCampaignsPublicWithCascadingLiquidity({
    String? query,
    String? status,
    String? category,
    bool? urgent,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
    int radiusStep = 1,
  }) async {
    final stepGeo = _geoAtStep(geo, radiusStep);
    final payload = await listCampaignsPublic(
      query: query,
      status: status,
      category: category,
      urgent: urgent,
      geo: stepGeo.isActive ? stepGeo : geo,
      page: page,
      size: size,
    );
    final canCascade = geo?.lat != null &&
        geo?.lng != null &&
        _isEmptyPayload(payload) &&
        radiusStep < _cascadeRadiiKm.length;
    if (canCascade) {
      return listCampaignsPublicWithCascadingLiquidity(
        query: query,
        status: status,
        category: category,
        urgent: urgent,
        geo: geo,
        page: page,
        size: size,
        radiusStep: radiusStep + 1,
      );
    }
    final exhausted = geo?.lat != null &&
        geo?.lng != null &&
        _isEmptyPayload(payload) &&
        radiusStep >= _cascadeRadiiKm.length;
    return CascadingLiquidityResult(
      payload: payload,
      radiusKmUsed: stepGeo.isActive ? stepGeo.radiusKm : null,
      liquidityExhausted: exhausted,
    );
  }

  Future<CascadingLiquidityResult> listTradesWithCascadingLiquidity({
    String? status,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
    int radiusStep = 1,
  }) async {
    final stepGeo = _geoAtStep(geo, radiusStep);
    final payload = await listTrades(
      status: status,
      geo: stepGeo.isActive ? stepGeo : geo,
      page: page,
      size: size,
    );
    final canCascade = geo?.lat != null &&
        geo?.lng != null &&
        _isEmptyPayload(payload) &&
        radiusStep < _cascadeRadiiKm.length;
    if (canCascade) {
      return listTradesWithCascadingLiquidity(
        status: status,
        geo: geo,
        page: page,
        size: size,
        radiusStep: radiusStep + 1,
      );
    }
    final exhausted = geo?.lat != null &&
        geo?.lng != null &&
        _isEmptyPayload(payload) &&
        radiusStep >= _cascadeRadiiKm.length;
    return CascadingLiquidityResult(
      payload: payload,
      radiusKmUsed: stepGeo.isActive ? stepGeo.radiusKm : null,
      liquidityExhausted: exhausted,
    );
  }

  Future<CascadingLiquidityResult> listGiftsWithCascadingLiquidity({
    String? status,
    String? category,
    String? type,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
    int radiusStep = 1,
  }) async {
    final stepGeo = _geoAtStep(geo, radiusStep);
    final payload = await listGifts(
      status: status,
      category: category,
      type: type,
      geo: stepGeo.isActive ? stepGeo : geo,
      page: page,
      size: size,
    );
    final canCascade = geo?.lat != null &&
        geo?.lng != null &&
        _isEmptyPayload(payload) &&
        radiusStep < _cascadeRadiiKm.length;
    if (canCascade) {
      return listGiftsWithCascadingLiquidity(
        status: status,
        category: category,
        type: type,
        geo: geo,
        page: page,
        size: size,
        radiusStep: radiusStep + 1,
      );
    }
    final exhausted = geo?.lat != null &&
        geo?.lng != null &&
        _isEmptyPayload(payload) &&
        radiusStep >= _cascadeRadiiKm.length;
    return CascadingLiquidityResult(
      payload: payload,
      radiusKmUsed: stepGeo.isActive ? stepGeo.radiusKm : null,
      liquidityExhausted: exhausted,
    );
  }

  Future<CascadingLiquidityResult> listCampaignsWithCascadingLiquidity({
    String? status,
    String? category,
    bool? urgent,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
    int radiusStep = 1,
  }) async {
    final stepGeo = _geoAtStep(geo, radiusStep);
    final payload = await listCampaigns(
      status: status,
      category: category,
      urgent: urgent,
      geo: stepGeo.isActive ? stepGeo : geo,
      page: page,
      size: size,
    );
    final canCascade = geo?.lat != null &&
        geo?.lng != null &&
        _isEmptyPayload(payload) &&
        radiusStep < _cascadeRadiiKm.length;
    if (canCascade) {
      return listCampaignsWithCascadingLiquidity(
        status: status,
        category: category,
        urgent: urgent,
        geo: geo,
        page: page,
        size: size,
        radiusStep: radiusStep + 1,
      );
    }
    final exhausted = geo?.lat != null &&
        geo?.lng != null &&
        _isEmptyPayload(payload) &&
        radiusStep >= _cascadeRadiiKm.length;
    return CascadingLiquidityResult(
      payload: payload,
      radiusKmUsed: stepGeo.isActive ? stepGeo.radiusKm : null,
      liquidityExhausted: exhausted,
    );
  }

  /// General search across all modules
  Future<Map<String, dynamic>> search({
    required String query,
    String? type,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/search',
        queryParameters: {
          'q': query,
          if (type != null) 'type': type,
          'page': page,
          'size': size,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception('Search failed: ${e.message}');
    }
  }

  /// Grouped intent search (`POST /v1/search/intent`).
  /// Category overrides set [skipAi] so refinement does not call the model.
  Future<Map<String, dynamic>?> searchIntent({
    required String query,
    ListingGeoQuery? geo,
    List<String>? categories,
    bool skipAi = false,
    bool widenRadius = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return null;
    try {
      final response = await _apiClient.post(
        '/v1/search/intent',
        data: {
          'query': trimmed,
          'locale': 'en-NG',
          ...?geo?.toParams(),
          if (categories != null && categories.isNotEmpty) 'categories': categories,
          if (skipAi) 'skipAi': true,
          if (widenRadius) 'widenRadius': true,
        },
      );
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } on DioException {
      return null;
    }
  }

  /// Best-effort cohort event. Failures must not affect search.
  Future<void> trackIntentEvent({
    required String event,
    required String cohort,
    String? module,
    String? size,
    String? reason,
    String? kind,
    int? latencyMs,
    bool cached = false,
  }) async {
    try {
      await _apiClient.post(
        '/v1/search/intent/event',
        data: {
          'event': event,
          'cohort': cohort,
          if (module != null) 'module': module,
          if (size != null) 'size': size,
          if (reason != null) 'reason': reason,
          if (kind != null) 'kind': kind,
          if (latencyMs != null) 'latencyMs': latencyMs,
          if (cached) 'cached': true,
        },
      );
    } on DioException {
      return;
    }
  }

  /// Rules/AI query interpretation (`POST /v1/search/interpret`).
  Future<Map<String, dynamic>?> interpretSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return null;
    try {
      final response = await _apiClient.post(
        '/v1/search/interpret',
        data: {'q': trimmed},
      );
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } on DioException {
      return null;
    }
  }

  /// Search trades
  Future<Map<String, dynamic>> searchTrades({
    required String query,
    String? status,
    String? category,
    String? location,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/search/trades',
        queryParameters: {
          'q': query,
          if (status != null) 'status': status,
          if (category != null) 'category': category,
          if (location != null) 'location': location,
          'page': page,
          'size': size,
          ...?geo?.toParams(),
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception('Trade search failed: ${e.message}');
    }
  }

  /// List trades (no query required)
  Future<Map<String, dynamic>> listTrades({
    String? status,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/trades',
        queryParameters: {
          if (status != null) 'status': status,
          'page': page,
          'size': size,
          ...?geo?.toParams(),
        },
      );
      return _listingPayload(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw Exception('Trade list failed: ${e.message}');
    }
  }

  /// Search users
  Future<Map<String, dynamic>?> searchUsers({
    required String query,
    bool? verified,
    String? location,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/search/users',
        queryParameters: {
          'q': query,
          if (verified != null) 'verified': verified.toString(),
          if (location != null) 'location': location,
          'page': page,
          'size': size,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception('User search failed: ${e.message}');
    }
  }

  /// List users (no query required)
  Future<Map<String, dynamic>> listUsers({
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/users/search',
        queryParameters: {
          'q': '',
          'page': page,
          'size': size,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception('User list failed: ${e.message}');
    }
  }

  /// Search communities
  Future<Map<String, dynamic>> searchCommunities({
    required String query,
    String? type,
    String? category,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/search/communities',
        queryParameters: {
          'q': query,
          if (type != null) 'type': type,
          if (category != null) 'category': category,
          'page': page,
          'size': size,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception('Community search failed: ${e.message}');
    }
  }

  /// List communities (no query required)
  Future<Map<String, dynamic>> listCommunities({
    String? type,
    String? category,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/communities',
        queryParameters: {
          'page': page,
          'size': size,
          if (category != null) 'category': category,
          if (type != null) 'type': type,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception('Community list failed: ${e.message}');
    }
  }

  /// Search gifts
  Future<Map<String, dynamic>> searchGifts({
    required String query,
    String? type,
    String? category,
    String? location,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/search/gifts',
        queryParameters: {
          'q': query,
          if (type != null) 'type': type,
          if (category != null) 'category': category,
          if (location != null) 'location': location,
          'page': page,
          'size': size,
          ...?geo?.toParams(),
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception('Gift search failed: ${e.message}');
    }
  }

  /// List gifts (no query required)
  Future<Map<String, dynamic>> listGifts({
    String? status,
    String? category,
    String? type,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/gifts',
        queryParameters: {
          if (status != null) 'status': status,
          if (category != null) 'category': category,
          if (type != null) 'type': type,
          'page': page,
          'size': size,
          ...?geo?.toParams(),
        },
      );
      return _listingPayload(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw Exception('Gift list failed: ${e.message}');
    }
  }

  /// Search campaigns
  Future<Map<String, dynamic>> searchCampaigns({
    required String query,
    String? status,
    String? category,
    String? location,
    bool? urgent,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/search/campaigns',
        queryParameters: {
          'q': query,
          if (status != null) 'status': status,
          if (category != null) 'category': category,
          if (location != null && location.isNotEmpty) 'location': location,
          if (urgent != null) 'urgent': urgent.toString(),
          'page': page,
          'size': size,
          ...?geo?.toParams(),
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception('Campaign search failed: ${e.message}');
    }
  }

  /// List campaigns (no query required)
  Future<Map<String, dynamic>> listCampaigns({
    String? status,
    String? category,
    bool? urgent,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/campaigns',
        queryParameters: {
          if (status != null) 'status': status,
          if (category != null) 'category': category,
          if (urgent != null) 'isUrgent': urgent.toString(),
          'page': page,
          'size': size,
          ...?geo?.toParams(),
        },
      );
      return _listingPayload(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw Exception('Campaign list failed: ${e.message}');
    }
  }

  /// Get search suggestions
  Future<Map<String, dynamic>> getSearchSuggestions({
    required String query,
    String? type,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/search/suggestions',
        queryParameters: {
          'q': query,
          if (type != null) 'type': type,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception('Search suggestions failed: ${e.message}');
    }
  }

  // ========== Public Browse Endpoints (no auth required) ==========

  /// List/search trades publicly (no authentication required).
  ///
  /// The public browse controller accepts an optional `query` parameter
  /// so the same endpoint serves both the no-query "browse" use case and
  /// the query-driven search from the SearchScreen when the visitor is
  /// logged out.
  Future<Map<String, dynamic>> listTradesPublic({
    String? query,
    String? status,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/public/browse/trades',
        queryParameters: {
          if (query != null && query.isNotEmpty) 'query': query,
          if (status != null) 'status': status,
          'page': page,
          'size': size,
          ...?geo?.toParams(),
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception(NetworkErrorMessage.fromDio(e));
    }
  }

  /// List/search gifts publicly (no authentication required).
  Future<Map<String, dynamic>> listGiftsPublic({
    String? query,
    String? status,
    String? category,
    String? type,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/public/browse/gifts',
        queryParameters: {
          if (query != null && query.isNotEmpty) 'query': query,
          if (status != null) 'status': status,
          if (category != null) 'category': category,
          if (type != null) 'type': type,
          'page': page,
          'size': size,
          ...?geo?.toParams(),
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception(NetworkErrorMessage.fromDio(e));
    }
  }

  /// List/search campaigns publicly (no authentication required).
  Future<Map<String, dynamic>> listCampaignsPublic({
    String? query,
    String? status,
    String? category,
    bool? urgent,
    ListingGeoQuery? geo,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/public/browse/campaigns',
        queryParameters: {
          if (query != null && query.isNotEmpty) 'query': query,
          if (status != null) 'status': status,
          if (category != null) 'category': category,
          if (urgent != null) 'isUrgent': urgent.toString(),
          'page': page,
          'size': size,
          ...?geo?.toParams(),
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception(NetworkErrorMessage.fromDio(e));
    }
  }

  /// List/search communities publicly (no authentication required).
  ///
  /// Note: the public communities endpoint uses `search` (not `query`)
  /// as its free-text filter parameter — preserved for backwards compat
  /// with the existing controller signature.
  Future<Map<String, dynamic>> listCommunitiesPublic({
    String? query,
    String? type,
    String? category,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/public/browse/communities',
        queryParameters: {
          'page': page,
          'size': size,
          if (category != null) 'category': category,
          if (type != null) 'type': type,
          if (query != null && query.isNotEmpty) 'search': query,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception(NetworkErrorMessage.fromDio(e));
    }
  }
}

