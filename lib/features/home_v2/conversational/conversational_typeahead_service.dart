import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/signup_location_service.dart';
import '../../feed/mappers/social_listing_mapper.dart';
import '../../feed/models/social_listing_card_data.dart';
import '../../search/services/search_api_service.dart';
import 'conversational_ranker.dart';
import 'intent_module.dart';
import 'intent_recommendation_parser.dart';

/// Lightweight debounced lookup for conversational home typing suggestions.
class ConversationalTypeaheadService {
  int _generation = 0;

  /// Returns up to [limit] trade/gift/donation matches (aims for at least [minimum]).
  Future<List<SocialListingCardData>> fetchRelatedItems({
    required String query,
    required bool isAuthed,
    int minimum = 3,
    int limit = 5,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final gen = ++_generation;
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = SearchApiService(
        ApiClient(baseUrl, const FlutterSecureStorage()),
      );
      final geo = await _resolveGeo();
      final perModule = minimum.clamp(2, 4);

      Map<String, dynamic> response;
      if (isAuthed) {
        response = await api.search(
          query: trimmed,
          page: 1,
          size: limit + 2,
        );
      } else {
        final responses = await Future.wait([
          api.listTradesPublic(
            query: trimmed,
            geo: geo,
            page: 1,
            size: perModule,
          ),
          api.listGiftsPublic(
            query: trimmed,
            geo: geo,
            page: 1,
            size: perModule,
          ),
          api.listCampaignsPublic(
            query: trimmed,
            geo: geo,
            page: 1,
            size: perModule,
          ),
        ]);
        response = _mergePublicResponses(responses);
      }

      if (gen != _generation) return const [];

      final mapped = _mapPayload(response);
      if (mapped.isEmpty) return const [];

      IntentModule? bias;
      final intents = IntentRecommendationParser.parse(trimmed);
      for (final intent in intents) {
        if (intent.action == IntentAction.searchFeed) {
          bias = intent.module;
          break;
        }
      }

      final ranked = ConversationalRanker.rankAndSize(
        items: mapped,
        query: trimmed,
        moduleBias: bias,
      );

      final ordered = ranked.map((e) => e.data).toList();
      if (ordered.length >= minimum) {
        return ordered.take(limit).toList();
      }
      return ordered;
    } catch (_) {
      if (gen != _generation) return const [];
      return const [];
    }
  }

  void cancel() => _generation++;

  Future<ListingGeoQuery?> _resolveGeo() async {
    final place = await SignupLocationService.resolveForAuth();
    final pos = await LocationService.instance.getCachedPositionOnly();
    if (pos != null) {
      return ListingGeoQuery(
        lat: pos.latitude,
        lng: pos.longitude,
        radiusKm: 50,
        locationLabel: place,
      );
    }
    if (place != null) {
      return ListingGeoQuery(locationLabel: place);
    }
    return null;
  }

  List<SocialListingCardData> _mapPayload(Map<String, dynamic> payload) {
    final rawItems = payload['items'];
    if (rawItems is! List) return const [];
    final out = <SocialListingCardData>[];
    for (final item in rawItems) {
      if (item is! Map) continue;
      final card = SocialListingMapper.fromSearchItemMap(
        Map<String, dynamic>.from(item),
      );
      if (card != null) out.add(card);
    }
    return out;
  }

  Map<String, dynamic> _mergePublicResponses(
    List<Map<String, dynamic>> responses,
  ) {
    final trades = (responses[0]['items'] as List? ?? [])
        .map((item) => {...item as Map<String, dynamic>, 'type': 'trade'})
        .toList();
    final gifts = (responses[1]['items'] as List? ?? [])
        .map((item) => {...item as Map<String, dynamic>, 'type': 'gift'})
        .toList();
    final campaigns = (responses[2]['items'] as List? ?? [])
        .map((item) => {...item as Map<String, dynamic>, 'type': 'campaign'})
        .toList();
    return {
      'items': [...trades, ...gifts, ...campaigns],
    };
  }
}
