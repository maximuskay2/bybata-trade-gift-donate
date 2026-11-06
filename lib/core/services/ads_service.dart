import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';
import '../config/env_config.dart';
import '../models/ad_item.dart';

class AdsService {
  final Set<String> _viewedKeys = {};

  Future<List<AdItem>> fetchPlacementAds(String placementKey) async {
    try {
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, storage);
      final res = await api.get('/v1/ads/placements/$placementKey');
      final data = res.data as List? ?? [];
      final ads = data
          .map((e) => AdItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      debugPrint('AdsService: $placementKey → ${ads.length} ad(s)');
      return ads;
    } catch (e) {
      debugPrint('AdsService: failed to load $placementKey — $e');
      rethrow;
    }
  }

  Future<void> trackView(AdItem ad) async {
    final dedupeKey = '${ad.kind}:${ad.id}';
    if (ad.id.isEmpty || _viewedKeys.contains(dedupeKey)) return;
    _viewedKeys.add(dedupeKey);
    try {
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, storage);
      if (ad.isBoost) {
        await api.post('/v1/ads/boosts/${ad.id}/track/view');
      } else {
        await api.post('/v1/wallet/ads/${ad.id}/track/view');
      }
    } catch (e) {
      debugPrint('Ad view track failed: $e');
    }
  }

  Future<void> trackClick(AdItem ad) async {
    if (ad.id.isEmpty) return;
    try {
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, storage);
      if (ad.isBoost) {
        await api.post('/v1/ads/boosts/${ad.id}/track/click');
      } else {
        await api.post('/v1/wallet/ads/${ad.id}/track/click');
      }
    } catch (e) {
      debugPrint('Ad click track failed: $e');
    }
  }
}
