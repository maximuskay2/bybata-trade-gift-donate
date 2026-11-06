import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../../../core/config/env_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/cache_store.dart';
import '../../../core/utils/listing_delete_helper.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/utils/offline_json_cache.dart';
import '../../trade/api/trade_api.dart';
import '../../../core/widgets/listing_creation_progress.dart';
import '../../storage/repository/storage_repository.dart';
import '../../../core/models/listing_media.dart';
import '../../../core/services/listing_media_upload_service.dart';

class TradeBackendProvider extends ChangeNotifier {
  ApiClient? _client;
  TradeApi? _tradeApi;
  StorageRepository? _storage;
  bool _busy = false;
  String? _error;
  int _uploadTotal = 0;
  int _uploadCompleted = 0;
  double _uploadProgress = 0.0;

  // Simple in-memory caches to avoid refetching the same pages repeatedly
  // when the user navigates around the app.
  final CacheStore<String, Map<String, dynamic>> _myTradesCache =
      CacheStore<String, Map<String, dynamic>>(ttl: const Duration(seconds: 60));
  final CacheStore<String, Map<String, dynamic>> _tradeHistoryCache =
      CacheStore<String, Map<String, dynamic>>(ttl: const Duration(seconds: 60));

  bool get isBusy => _busy;
  String? get error => _error;
  String? _duplicateOfferId;
  String? get duplicateOfferId => _duplicateOfferId;
  String? _lastCreatedTradeId;
  String? get lastCreatedTradeId => _lastCreatedTradeId;
  int get uploadTotal => _uploadTotal;
  int get uploadCompleted => _uploadCompleted;
  double get uploadProgress => _uploadProgress;

  Future<void> _ensureClient() async {
    if (_client != null && _tradeApi != null && _storage != null) return;
    final base = await EnvConfig.getBaseUrl();
    final storage = const FlutterSecureStorage();
    _client = ApiClient(base, storage);
    _tradeApi = TradeApi(_client!);
    _storage = StorageRepository(_client!.dio);
  }

  // Create trade with media upload (optional)
  Future<bool> createTrade({
    required String title,
    String? description,
    ListingMediaDraft? mediaDraft,
    List<String>? localImagePaths,
    String? category,
    bool? isNegotiable,
    bool? requiresPickup,
    bool? allowDelivery,
    bool? allowShipping,
    bool? enableBYCPromotion,
    String? location,
    double? latitude,
    double? longitude,
    bool asDraft = false,
    bool isSeedingListing = false,
    ListingCreationReporter? onProgress,
  }) async {
    _busy = true;
    _error = null;
    final draft = mediaDraft ??
        (localImagePaths != null && localImagePaths.isNotEmpty
            ? ListingMediaDraft(imagePaths: localImagePaths)
            : const ListingMediaDraft());
    _uploadTotal = draft.mediaType == ListingMediaType.video
        ? 1
        : draft.imagePaths.length;
    _uploadCompleted = 0;
    _uploadProgress = 0.0;
    notifyListeners();
    try {
      await _ensureClient();
      onProgress?.call(0.05, 'Preparing your trade…');
      Map<String, dynamic> uploaded = {};
      if (!draft.isEmpty) {
        uploaded = await ListingMediaUploadService.uploadDraft(
          draft: draft,
          domain: 'trades',
          dio: _client!.dio,
          onProgress: (p, stage) => onProgress?.call(0.05 + p * 0.65, stage),
        );
      } else {
        onProgress?.call(0.35, 'No media to upload');
      }
      onProgress?.call(0.82, 'Publishing your trade…');
      final created = await _tradeApi!.createTrade(
        title: title,
        description: description,
        mediaType: uploaded['mediaType'] as String?,
        mediaKeys: (uploaded['mediaKeys'] as List?)?.cast<String>(),
        videoKey: uploaded['videoKey'] as String?,
        thumbnailKey: uploaded['thumbnailKey'] as String?,
        category: category,
        isNegotiable: isNegotiable,
        requiresPickup: requiresPickup,
        allowDelivery: allowDelivery,
        allowShipping: allowShipping,
        enableBYCPromotion: enableBYCPromotion,
        location: location,
        latitude: latitude,
        longitude: longitude,
        asDraft: asDraft,
        isSeedingListing: isSeedingListing,
      );
      _lastCreatedTradeId = created['id']?.toString();
      onProgress?.call(0.96, 'Trade created!');
      return true;
    } catch (e) {
      _error = e.toString().contains('upload')
          ? 'Media upload failed. Check API connection.'
          : 'Failed to create trade';
      return false;
    } finally {
      _busy = false;
      _uploadTotal = 0;
      _uploadCompleted = 0;
      _uploadProgress = 0.0;
      notifyListeners();
    }
  }

  Future<bool> publishDraft(String tradeId) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureClient();
      await _tradeApi!.publishDraft(tradeId);
      invalidateMyTradesCache();
      return true;
    } catch (e) {
      _error = 'Failed to publish draft';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> cancelTrade(String tradeId) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureClient();
      await _tradeApi!.cancelTrade(tradeId);
      invalidateMyTradesCache();
      return true;
    } catch (e) {
      _error = 'Failed to cancel trade';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTrade(String tradeId) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureClient();
      await _tradeApi!.deleteTrade(tradeId);
      invalidateMyTradesCache();
      return true;
    } catch (e) {
      _error = parseDeleteListingError(e);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> listMyTrades({
    required String ownerId,
    String? status,
    String? category,
    int page = 1,
    int size = 20,
    bool forceRefresh = false,
  }) async {
    await _ensureClient();
    final ownerParam = ownerId.isEmpty ? null : ownerId;

    final cacheKey = 'my:$ownerParam:$status:$category:$page:$size';
    if (!forceRefresh) {
      final cached = _myTradesCache.getIfFresh(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    final diskKey = 'my_trades:$status:$page';
    try {
      final result = await _tradeApi!.listTrades(
        ownerId: ownerParam,
        status: status,
        category: category,
        page: page,
        size: size,
      );
      final rawItems = result['items'];
      if (rawItems is List) {
        MediaResolver.seedUrlsFromListingMaps(
          rawItems.whereType<Map<String, dynamic>>(),
        );
      }
      _myTradesCache.set(cacheKey, result);
      if (page == 1) {
        await OfflineJsonCache.putMap(
          'trades_cache',
          ownerId,
          diskKey,
          Map<String, dynamic>.from(result),
        );
      }
      return result;
    } catch (e) {
      final disk = await OfflineJsonCache.getMap(
        'trades_cache',
        ownerId,
        diskKey,
      );
      if (disk != null && disk.isNotEmpty) {
        _myTradesCache.set(cacheKey, disk);
        return disk;
      }
      rethrow;
    }
  }

  /// Manually invalidate cached "my trades" pages (e.g., after creating/updating).
  void invalidateMyTradesCache() {
    _myTradesCache.invalidate();
  }

  /// Combined trade history (owned + where user was bidder on accepted offers)
  Future<Map<String, dynamic>> getMyTradeHistory({
    int page = 1,
    int size = 20,
    bool forceRefresh = false,
  }) async {
    await _ensureClient();
    final cacheKey = 'history:$page:$size';
    if (!forceRefresh) {
      final cached = _tradeHistoryCache.getIfFresh(cacheKey);
      if (cached != null) {
        return cached;
      }
    }
    final result = await _tradeApi!.getMyTradeHistory(page: page, size: size);
    final rawItems = result['items'];
    if (rawItems is List) {
      MediaResolver.seedUrlsFromListingMaps(
        rawItems.whereType<Map<String, dynamic>>(),
      );
    }
    _tradeHistoryCache.set(cacheKey, result);
    return result;
  }

  void invalidateTradeHistoryCache() {
    _tradeHistoryCache.invalidate();
  }

  Future<List<Map<String, dynamic>>> listOffers(String tradeId) async {
    await _ensureClient();
    return _tradeApi!.listOffers(tradeId);
  }

  Future<bool> createOffer(
    String tradeId, {
    String? amount,
    String? offeredTradeId,
    String? message,
    String? parentOfferId,
    String? requestedTradeId,
    String? requestedAmount,
  }) async {
    _busy = true;
    _error = null;
    _duplicateOfferId = null;
    notifyListeners();
    try {
      await _ensureClient();
      await _tradeApi!.createOffer(
        tradeId,
        amount: amount,
        offeredTradeId: offeredTradeId,
        message: message,
        parentOfferId: parentOfferId,
        requestedTradeId: requestedTradeId,
        requestedAmount: requestedAmount,
      );
      return true;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['code'] == 'DUPLICATE_OFFER') {
        _duplicateOfferId = data['existingOfferId']?.toString();
        _error = data['message']?.toString() ?? 'You already have a pending offer for this trade.';
      } else {
        _error = (data is Map ? data['message']?.toString() : null) ?? 'Failed to create offer';
      }
      return false;
    } catch (e) {
      _error = 'Failed to create offer';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getOfferHistory(String offerId) async {
    try {
      await _ensureClient();
      return await _tradeApi!.getOfferHistory(offerId);
    } catch (e) {
      _error = 'Failed to fetch offer history';
      return null;
    }
  }

  Future<bool> acceptOffer(String offerId) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureClient();
      await _tradeApi!.acceptOffer(offerId);
      return true;
    } on DioException catch (e) {
      _error = _parseOfferApiError(e, 'accept');
      return false;
    } catch (e) {
      _error = 'Failed to accept offer';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> finalizeOffer(String offerId) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureClient();
      await _tradeApi!.finalizeOffer(offerId);
      return true;
    } catch (e) {
      _error = 'Failed to finalize offer';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> rejectOffer(String offerId) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureClient();
      await _tradeApi!.rejectOffer(offerId);
      return true;
    } on DioException catch (e) {
      _error = _parseOfferApiError(e, 'reject');
      return false;
    } catch (e) {
      _error = 'Failed to reject offer';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> withdrawOffer(String offerId) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureClient();
      await _tradeApi!.withdrawOffer(offerId);
      return true;
    } on DioException catch (e) {
      _error = _parseOfferApiError(e, 'withdraw');
      return false;
    } catch (e) {
      _error = 'Failed to withdraw offer';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // Update existing trade
  Future<bool> updateTrade({
    required String tradeId,
    required String title,
    String? description,
    String? mediaType,
    List<String>? mediaKeys,
    String? videoKey,
    String? thumbnailKey,
    String? category,
    bool? isNegotiable,
    bool? requiresPickup,
    bool? allowDelivery,
    bool? allowShipping,
    bool? enableBYCPromotion,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureClient();
      await _tradeApi!.updateTrade(
        tradeId,
        title: title,
        description: description,
        mediaType: mediaType,
        mediaKeys: mediaKeys,
        videoKey: videoKey,
        thumbnailKey: thumbnailKey,
        category: category,
        isNegotiable: isNegotiable,
        requiresPickup: requiresPickup,
        allowDelivery: allowDelivery,
        allowShipping: allowShipping,
        enableBYCPromotion: enableBYCPromotion,
      );
      return true;
    } catch (e) {
      _error = 'Failed to update trade';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
  
  // Get single trade details
  Future<Map<String, dynamic>?> getTrade(String tradeId) async {
    try {
      await _ensureClient();
      return await _tradeApi!.getTrade(tradeId);
    } catch (e) {
      _error = 'Failed to fetch trade details';
      return null;
    }
  }

  Future<Map<String, dynamic>> likeTrade(String tradeId) async {
    await _ensureClient();
    return _tradeApi!.likeTrade(tradeId);
  }

  Future<Map<String, dynamic>> unlikeTrade(String tradeId) async {
    await _ensureClient();
    return _tradeApi!.unlikeTrade(tradeId);
  }

  // Get comments for a trade
  Future<Map<String, dynamic>> getTradeComments(String tradeId, {int page = 1, int size = 50}) async {
    try {
      await _ensureClient();
      return await _tradeApi!.getTradeComments(tradeId, page: page, size: size);
    } catch (e) {
      _error = 'Failed to fetch trade comments';
      return {'comments': []};
    }
  }

  // Add comment to a trade
  Future<Map<String, dynamic>?> addTradeComment(String tradeId, String content, {String? parentId}) async {
    try {
      await _ensureClient();
      return await _tradeApi!.addTradeComment(tradeId, content, parentId: parentId);
    } catch (e) {
      _error = 'Failed to add comment';
      return null;
    }
  }

  // Get similar trades based on category
  Future<Map<String, dynamic>> getSimilarTrades({
    required int categoryId,
    required String excludeTradeId,
    int limit = 10,
  }) async {
    try {
      await _ensureClient();
      return await _tradeApi!.getSimilarTrades(
        categoryId: categoryId,
        excludeTradeId: excludeTradeId,
        limit: limit,
      );
    } catch (e) {
      _error = 'Failed to fetch similar trades';
      return {'items': []};
    }
  }

  String _inferExt(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'png';
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'jpg';
    if (p.endsWith('.heic')) return 'heic';
    return 'bin';
  }

  String _contentTypeFromExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  /// Parses DioException from accept/reject offer API to show user-friendly messages.
  String _parseOfferApiError(DioException e, String action) {
    final statusCode = e.response?.statusCode;
    final msg = (e.response?.data is Map)
        ? (e.response!.data['message'] as String?)
        : null;
    final str = msg?.toLowerCase() ?? '';

    if (statusCode == 409 || str.contains('no longer pending')) {
      return 'This offer is no longer pending (already accepted, rejected, or withdrawn)';
    }
    if (statusCode == 400 && str.contains('no longer available')) {
      return 'Trade no longer available';
    }
    if (statusCode == 400 && str.contains('not open')) {
      return 'This trade is not open for that action right now';
    }
    return 'Failed to $action offer';
  }
}
