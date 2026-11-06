import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/listing_delete_helper.dart';
import '../../../core/utils/network_error_message.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/utils/offline_json_cache.dart';
import '../api/gift_api.dart';
import '../models/gift_models.dart' as gift_models;

/// Gift claim model for history
class GiftClaim {
  final String id;
  final String giftId;
  final String claimerId;
  final gift_models.Gift gift;
  final DateTime claimedAt;
  final String code;
  final int karmaAwarded;

  const GiftClaim({
    required this.id,
    required this.giftId,
    required this.claimerId,
    required this.gift,
    required this.claimedAt,
    required this.code,
    required this.karmaAwarded,
  });

  bool isReceivedBy(String userId) => claimerId == userId;

  bool isGivenBy(String userId) => gift.giver.id == userId;
}

class GiftProvider with ChangeNotifier {
  final GiftApi _giftApi;
  
  GiftProvider(ApiClient apiClient, {GiftApi? giftApi}) : _giftApi = giftApi ?? GiftApi(apiClient);

  bool _disposed = false;

  List<gift_models.Gift> _gifts = [];
  List<gift_models.Gift> _myGifts = [];
  List<GiftClaim> _giftHistory = [];
  List<gift_models.GiftRequest> _giftRequests = [];
  List<gift_models.Gift> _recommendedGifts = [];
  gift_models.GiftAnalytics? _userAnalytics;
  bool _isLoading = false;
  String? _error;
  // Per-tab error fields
  String? _giftsError;
  String? _myGiftsError;
  String? _historyError;
  String? _requestsError;
  // Debounce/single-flight state for history loads
  bool _isLoadingHistory = false;
  DateTime? _lastHistoryFetchAt;
  // Debounce/single-flight state for requests loads
  bool _isLoadingRequests = false;
  DateTime? _lastRequestsFetchAt;
  // Exclude gifts created by this user from the Available tab
  String? _excludedUserId;
  
  // Cache timestamps for smart refetching
  DateTime? _lastGiftsFetchAt;
  DateTime? _lastMyGiftsFetchAt;
  bool _giftsInitialized = false;
  bool _myGiftsInitialized = false;
  bool _historyInitialized = false;
  bool _requestsInitialized = false;
  
  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  List<gift_models.Gift> get gifts => _gifts;
  List<gift_models.Gift> get myGifts => _myGifts;
  List<GiftClaim> get giftHistory => _giftHistory;

  /// Claims where the current user received the gift.
  List<GiftClaim> receivedGiftsFor(String userId) =>
      _giftHistory.where((c) => c.isReceivedBy(userId)).toList();

  /// Claims on gifts the user gave away (someone claimed their gift).
  List<GiftClaim> givenClaimsFor(String userId) =>
      _giftHistory.where((c) => c.isGivenBy(userId)).toList();
  List<gift_models.GiftRequest> get giftRequests => _giftRequests;
  List<gift_models.Gift> get recommendedGifts => _recommendedGifts;
  gift_models.GiftAnalytics? get userAnalytics => _userAnalytics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get giftsError => _giftsError;
  String? get myGiftsError => _myGiftsError;
  String? get historyError => _historyError;
  String? get requestsError => _requestsError;
  String? get excludedUserId => _excludedUserId;

  // Map client GiftRequestStatus to server-supported enum values.
  // Server supports: PENDING, APPROVED, DECLINED. Client also has EXPIRED.
  // When an unsupported status is selected (e.g., EXPIRED), omit the filter.
  String? _serverRequestStatus(gift_models.GiftRequestStatus? status) {
    switch (status) {
      case gift_models.GiftRequestStatus.pending:
        return 'PENDING';
      case gift_models.GiftRequestStatus.approved:
        return 'APPROVED';
      case gift_models.GiftRequestStatus.declined:
        return 'DECLINED';
      default:
        return null;
    }
  }

  void _setLoading(bool loading) {
    if (_disposed) return;
    _isLoading = loading;
    notifyListeners();
  }

  /// Set the user ID to exclude their gifts from the available list
  void setExcludedUserId(String? userId) {
    _excludedUserId = userId;
    try {
      if (userId != null && _gifts.isNotEmpty) {
        _gifts = _gifts.where((g) => g.giver.id != userId).toList();
      }
    } catch (e) {
      _giftsError = 'Failed to apply available filter: $e';
    }
    unawaited(_hydrateGiftsFromDisk());
    notifyListeners();
  }

  static const _giftBox = 'gifts_cache';

  String get _diskUserId =>
      (_excludedUserId != null && _excludedUserId!.isNotEmpty)
          ? _excludedUserId!
          : 'guest';

  Future<void> _hydrateGiftsFromDisk() async {
    try {
      final userId = _diskUserId;
      if (_gifts.isEmpty) {
        final maps = await OfflineJsonCache.getList(_giftBox, userId, 'available');
        if (maps.isNotEmpty) {
          _gifts = maps.map(_parseGiftFromApi).toList();
          _giftsInitialized = true;
        }
      }
      if (_myGifts.isEmpty) {
        final maps = await OfflineJsonCache.getList(_giftBox, userId, 'my_gifts');
        if (maps.isNotEmpty) {
          _myGifts = maps.map(_parseGiftFromApi).toList();
          _myGiftsInitialized = true;
        }
      }
      if (_gifts.isNotEmpty || _myGifts.isNotEmpty) {
        _giftsError = null;
        _myGiftsError = null;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _persistGiftList(String key, List<Map<String, dynamic>> raw) async {
    await OfflineJsonCache.putList(_giftBox, _diskUserId, key, raw);
  }

  /// Update an existing gift
  Future<gift_models.Gift?> updateGift(
    String giftId, {
    String? title,
    String? description,
    String? mediaType,
    List<String>? mediaKeys,
    String? videoKey,
    String? thumbnailKey,
    int? karmaReward,
    int? maxClaims,
    String? location,
    List<String>? tags,
    DateTime? expiresAt,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _giftApi.updateGift(
        giftId,
        title: title,
        description: description,
        mediaType: mediaType,
        mediaKeys: mediaKeys,
        videoKey: videoKey,
        thumbnailKey: thumbnailKey,
        karmaReward: karmaReward,
        maxClaims: maxClaims,
        location: location,
        tags: tags,
        expiresAt: expiresAt,
      );

      final updated = _parseGiftFromApi(response);
      _updateGiftInLists(giftId, (_) => updated);
      return updated;
    } catch (e) {
      _setError('Failed to update gift: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }
  void _setError(String? error) {
    if (_disposed) return;
    _error = error == null ? null : NetworkErrorMessage.sanitize(error);
    notifyListeners();
  }

  /// Create a new gift
  Future<gift_models.Gift?> createGift({
    required String title,
    String? description,
    gift_models.GiftType? type,
    gift_models.GiftCategory? category,
    String? mediaType,
    List<String>? mediaKeys,
    String? videoKey,
    String? thumbnailKey,
    int? karmaReward,
    int? maxClaims,
    String? location,
    bool? isLocationRestricted,
    bool? isChainGift,
    String? chainParentId,
    String? targetUserId,
    Map<String, dynamic>? targetCriteria,
    gift_models.KarmaLevel? minimumKarmaLevel,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    double? latitude,
    double? longitude,
    DateTime? expiresAt,
    bool isSeedingListing = false,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _giftApi.createGift(
        title: title,
        description: description,
        type: type?.name.toUpperCase(),
        category: category?.name.toUpperCase(),
        mediaType: mediaType,
        mediaKeys: mediaKeys,
        videoKey: videoKey,
        thumbnailKey: thumbnailKey,
        karmaReward: karmaReward,
        maxClaims: maxClaims,
        location: location,
        isLocationRestricted: isLocationRestricted,
        isChainGift: isChainGift,
        chainParentId: chainParentId,
        targetUserId: targetUserId,
        targetCriteria: targetCriteria,
        minimumKarmaLevel: minimumKarmaLevel?.name,
        tags: tags,
        metadata: metadata,
        latitude: latitude,
        longitude: longitude,
        expiresAt: expiresAt,
        isSeedingListing: isSeedingListing,
      );

      final gift = _applyCreateMediaFallback(
        _parseGiftFromApi(response),
        mediaType: mediaType,
        mediaKeys: mediaKeys,
        videoKey: videoKey,
        thumbnailKey: thumbnailKey,
      );
      
      // Add to my gifts list if it exists
      if (_myGifts.isNotEmpty) {
        _myGifts.insert(0, gift);
      } else {
        _myGifts = [gift];
      }

      // Surface in browse feed immediately (same as trades hub).
      if (gift.isAvailable) {
        _gifts.removeWhere((g) => g.id == gift.id);
        _gifts.insert(0, gift);
      }
      _lastGiftsFetchAt = null;
      _giftsInitialized = false;
      notifyListeners();

      unawaited(refreshGiftById(gift.id));
      
      return gift;
    } catch (e) {
      _setError('Failed to create gift: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Load user gift analytics
  Future<void> loadUserAnalytics() async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _giftApi.getUserGiftAnalytics();
      _userAnalytics = gift_models.GiftAnalytics.fromJson(response);
      notifyListeners();
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        // Rate limited - don't show error, just skip loading for now
        // The UI should handle this gracefully by not showing analytics section
        _setError(null); // Clear any previous errors
        print('[GiftProvider] Rate limited, skipping analytics load');
      } else {
        _setError('Failed to load analytics: ${e.message}');
      }
    } catch (e) {
      // Only set error for non-rate-limit exceptions
      if (e.toString().contains('Too many requests')) {
        _setError(null);
        print('[GiftProvider] Rate limited, skipping analytics load');
      } else {
        _setError('Failed to load analytics: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Load recommended gifts
  Future<void> loadRecommendedGifts() async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _giftApi.getRecommendedGifts();
      _recommendedGifts = response.map((item) => _parseGiftFromApi(item as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load recommendations: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Share a gift
  Future<bool> shareGift(String giftId, String platform, {String? message}) async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _giftApi.shareGift(giftId, platform, message: message);
      // Update the gift in our lists if it exists
      _updateGiftInLists(giftId, (gift) {
        // In a real implementation, we would update share counts
        return gift;
      });
      
      return response['success'] as bool || false;
    } catch (e) {
      _setError('Failed to share gift: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Load available gifts
  Future<void> loadGifts({
    String? query,
    gift_models.GiftCategory? category,
    gift_models.GiftType? type,
    gift_models.GiftStatus? status,
    String? location,
    int? minKarma,
    int? maxKarma,
    String? sortBy,
    String? sortOrder,
    int page = 1,
    bool force = false,
  }) async {
    // Smart caching: skip if already loaded and cache is fresh
    if (!force && _giftsInitialized && _lastGiftsFetchAt != null) {
      final cacheAge = DateTime.now().difference(_lastGiftsFetchAt!);
      if (cacheAge < _cacheDuration && _gifts.isNotEmpty) {
        print('[GiftProvider] Using cached gifts (${cacheAge.inSeconds}s old)');
        return;
      }
    }

    if (!_giftsInitialized && _gifts.isEmpty) {
      await _hydrateGiftsFromDisk();
    }
    
    try {
      _setLoading(true);
      _giftsError = null;

      final response = await _giftApi.listGifts(
        query: query,
        category: category?.name.toUpperCase(),
        type: type?.name.toUpperCase(),
        status: status?.name.toUpperCase(),
        location: location,
        minKarma: minKarma,
        maxKarma: maxKarma,
        sortBy: sortBy,
        sortOrder: sortOrder,
        page: page,
      );

      final items = response['items'] as List? ?? [];
      MediaResolver.seedUrlsFromListingMaps(
        items.whereType<Map<String, dynamic>>(),
      );
      var newGifts = items.map((item) => _parseGiftFromApi(item as Map<String, dynamic>)).toList();

      // Filter out claimed, expired, and fully claimed gifts
      newGifts = newGifts.where((g) => g.isAvailable).toList();

      if (page == 1) {
        final previousById = {for (final g in _gifts) g.id: g};
        newGifts = newGifts
            .map((g) => _preferRicherGiftMedia(g, previousById[g.id]))
            .toList();

        // Keep freshly created gifts visible when the server list cache is stale.
        final incomingIds = newGifts.map((g) => g.id).toSet();
        final localOnly = _gifts
            .where((g) => g.isAvailable && !incomingIds.contains(g.id))
            .toList();
        if (localOnly.isNotEmpty) {
          newGifts = [...localOnly, ...newGifts];
        }
      }

      // Apply exclusion filter for user-owned gifts, if configured
      try {
        if (_excludedUserId != null) {
          newGifts = newGifts.where((g) => g.giver.id != _excludedUserId).toList();
        }
      } catch (e) {
        // Non-fatal: keep unfiltered list but surface error for visibility
        _giftsError = 'Failed to filter available gifts: $e';
      }
      
      if (page == 1) {
        _gifts = newGifts;
      } else {
        _gifts.addAll(newGifts);
      }

      // Update cache metadata
      _lastGiftsFetchAt = DateTime.now();
      _giftsInitialized = true;

      notifyListeners();
      if (page == 1) {
        final raw = items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        unawaited(_persistGiftList('available', raw));
      }
    } catch (e) {
      if (_gifts.isNotEmpty) {
        _giftsError = null;
      } else {
        _giftsError = NetworkErrorMessage.forListingLoad(e);
      }
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Loads gifts created by the user plus full claim history for the journey screen.
  Future<void> loadGivingJourney({bool force = false}) async {
    await loadMyGifts(page: 1, force: force, size: 100);
    await loadGiftHistory(page: 1, force: force, size: 100);
    unawaited(loadUserAnalytics());
  }

  /// Load my gifts
  Future<void> loadMyGifts({
    gift_models.GiftStatus? status,
    int page = 1,
    int size = 50,
    bool force = false,
  }) async {
    // Smart caching: skip if already loaded and cache is fresh
    if (!force && _myGiftsInitialized && _lastMyGiftsFetchAt != null) {
      final cacheAge = DateTime.now().difference(_lastMyGiftsFetchAt!);
      if (cacheAge < _cacheDuration && _myGifts.isNotEmpty) {
        print('[GiftProvider] Using cached my gifts (${cacheAge.inSeconds}s old)');
        return;
      }
    }
    
    try {
      _setLoading(true);
      _myGiftsError = null;

      final response = await _giftApi.getMyGifts(
        status: status?.name.toUpperCase(),
        page: page,
        size: size,
      );

      final items = response['items'] as List? ?? [];
      final newGifts = items.map((item) => _parseGiftFromApi(item as Map<String, dynamic>)).toList();
      
      if (page == 1) {
        _myGifts = newGifts;
      } else {
        _myGifts.addAll(newGifts);
      }

      // Update cache metadata
      _lastMyGiftsFetchAt = DateTime.now();
      _myGiftsInitialized = true;

      notifyListeners();
      if (page == 1) {
        final raw = items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        unawaited(_persistGiftList('my_gifts', raw));
      }
    } catch (e) {
      _myGiftsError = NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t load your gifts. Please try again.',
      );
      if (_myGifts.isNotEmpty) _myGiftsError = null;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Load gift history
  Future<void> loadGiftHistory({
    int page = 1,
    int size = 50,
    bool force = false,
  }) async {
    // Smart caching: skip if already loaded and cache is fresh
    if (!force && _historyInitialized && _lastHistoryFetchAt != null) {
      final cacheAge = DateTime.now().difference(_lastHistoryFetchAt!);
      if (cacheAge < _cacheDuration && _giftHistory.isNotEmpty) {
        print('[GiftProvider] Using cached gift history (${cacheAge.inSeconds}s old)');
        return;
      }
    }
    
    // Prevent overlapping requests
    if (_isLoadingHistory) return;
    
    try {
      _isLoadingHistory = true;
      _setLoading(true);
      _historyError = null;

      final response = await _giftApi.getGiftHistory(page: page, size: size);

      final items = response['items'] as List? ?? [];
      final newHistory = items.map((item) => _parseGiftClaimFromApi(item as Map<String, dynamic>)).toList();
      
      if (page == 1) {
        _giftHistory = newHistory;
      } else {
        _giftHistory.addAll(newHistory);
      }

      // Update cache metadata
      _lastHistoryFetchAt = DateTime.now();
      _historyInitialized = true;

      notifyListeners();
    } catch (e) {
      _historyError = NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t load gift history. Please try again.',
      );
      notifyListeners();
    } finally {
      _isLoadingHistory = false;
      _setLoading(false);
    }
  }

  /// Load gift requests (incoming/outgoing for current user)
  Future<void> loadGiftRequests({int page = 1, bool force = false, gift_models.GiftRequestStatus? status}) async {
    // Smart caching: skip if already loaded and cache is fresh
    if (!force && _requestsInitialized && _lastRequestsFetchAt != null) {
      final cacheAge = DateTime.now().difference(_lastRequestsFetchAt!);
      if (cacheAge < _cacheDuration && _giftRequests.isNotEmpty) {
        print('[GiftProvider] Using cached gift requests (${cacheAge.inSeconds}s old)');
        return;
      }
    }
    
    if (_isLoadingRequests) return;
    
    try {
      _isLoadingRequests = true;
      _setLoading(true);
      _requestsError = null;

      final response = await _giftApi.listGiftRequests(
        page: page,
        status: _serverRequestStatus(status),
      );

      final items = response['items'] as List? ?? [];
      final newRequests = items.map((item) => _parseGiftRequestFromApi(item as Map<String, dynamic>)).toList();

      if (page == 1) {
        _giftRequests = newRequests;
      } else {
        _giftRequests.addAll(newRequests);
      }

      // Update cache metadata
      _lastRequestsFetchAt = DateTime.now();
      _requestsInitialized = true;

      notifyListeners();
    } catch (e) {
      _requestsError = NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t load gift requests. Please try again.',
      );
      notifyListeners();
    } finally {
      _isLoadingRequests = false;
      _setLoading(false);
    }
  }

  /// Get specific gift
  Future<gift_models.Gift?> getGift(String giftId) async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _giftApi.getGift(giftId);
      return _parseGiftFromApi(response);
    } catch (e) {
      _setError('Failed to load gift: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Increment gift view count (call when user opens gift details)
  Future<Map<String, dynamic>> incrementGiftView(String giftId) async {
    return await _giftApi.incrementGiftView(giftId);
  }

  /// Get similar gifts (same category and type as the given gift)
  Future<List<gift_models.Gift>> getSimilarGifts(String giftId, {int limit = 8}) async {
    try {
      final list = await _giftApi.getSimilarGifts(giftId, limit: limit);
      return list.map((e) => _parseGiftFromApi(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Like a gift
  Future<Map<String, dynamic>> likeGift(String giftId) async {
    return await _giftApi.likeGift(giftId);
  }

  /// Unlike a gift
  Future<Map<String, dynamic>> unlikeGift(String giftId) async {
    return await _giftApi.unlikeGift(giftId);
  }

  /// Get comments for a gift
  Future<Map<String, dynamic>> getGiftComments(String giftId, {int page = 1, int size = 50}) async {
    try {
      return await _giftApi.getComments(giftId, page: page, size: size);
    } catch (e) {
      return {'comments': [], 'total': 0};
    }
  }

  /// Add a comment to a gift
  Future<Map<String, dynamic>?> addGiftComment(String giftId, String content, {String? parentId}) async {
    try {
      return await _giftApi.addComment(giftId, content, parentId: parentId);
    } catch (e) {
      _setError('Failed to add comment: $e');
      return null;
    }
  }

  /// Claim a gift: create a pending request for owner approval
  Future<gift_models.GiftRequest?> claimGift(String giftId, {String? claimCode, required gift_models.GiftUser requester, String? message}) async {
    try {
      _setLoading(true);
      _setError(null);

      // Client-side guard: prevent multiple pending outgoing claims for the same user
      try {
        final hasPending = await hasPendingOutgoingClaim(requester.id);
        if (hasPending) {
          _setError('You already have a pending gift claim. Please wait until it is approved or declined.');
          notifyListeners();
          return null;
        }
      } catch (_) {
        // If the check fails, fall through and rely on server-side validation
      }

      final response = await _giftApi.claimGift(giftId, claimCode: claimCode);
      final maybeRequest = response['request'] as Map<String, dynamic>?;
      final request = maybeRequest != null
          ? _parseGiftRequestFromApi(maybeRequest)
          : gift_models.GiftRequest(
              id: response['requestId']?.toString() ?? 'req_${DateTime.now().millisecondsSinceEpoch}',
              giftId: giftId,
              gift: _gifts.firstWhere(
                (g) => g.id == giftId,
                orElse: () => gift_models.Gift(
                  id: giftId,
                  title: 'Gift',
                  description: '',
                  giver: gift_models.GiftUser(
                    id: 'unknown',
                    name: 'Unknown',
                    username: '@unknown',
                    rating: 0.0,
                    completedGifts: 0,
                    karmaPoints: 0,
                    joinedDate: DateTime.now(),
                    isVerified: false,
                  ),
                  type: gift_models.GiftType.random,
                  category: gift_models.GiftCategory.others,
                  status: gift_models.GiftStatus.active,
                  createdAt: DateTime.now(),
                  karmaReward: 0,
                ),
              ),
              requester: requester,
              message: message,
              createdAt: DateTime.now(),
              status: gift_models.GiftRequestStatus.pending,
              respondedAt: null,
              responseMessage: null,
            );

      // Add to provider requests list
      _giftRequests.insert(0, request);
      
      // Update gift status in lists to reflect that it has a pending request
      _updateGiftInLists(giftId, (gift) => gift_models.Gift(
            id: gift.id,
            title: gift.title,
            description: gift.description,
            giver: gift.giver,
            type: gift.type,
            category: gift.category,
            status: gift_models.GiftStatus.active, // Keep as active but with pending request
            createdAt: gift.createdAt,
            expiresAt: gift.expiresAt,
            claimedAt: gift.claimedAt,
            claimedBy: gift.claimedBy,
            karmaReward: gift.karmaReward,
            minimumKarmaLevel: gift.minimumKarmaLevel,
            location: gift.location,
            isLocationRestricted: gift.isLocationRestricted,
            maxClaims: gift.maxClaims,
            currentClaims: gift.currentClaims + 1, // Increment current claims to reflect pending request
            imageUrls: gift.imageUrls,
            metadata: gift.metadata,
            tags: gift.tags,
            targetUserId: gift.targetUserId,
            targetCriteria: gift.targetCriteria,
            isChainGift: gift.isChainGift,
            chainParentId: gift.chainParentId,
            viewCount: gift.viewCount,
            likeCount: gift.likeCount,
            requestCount: gift.requestCount,
            rating: gift.rating,
            reviews: gift.reviews,
            isFeatured: gift.isFeatured,
            isSurpriseGift: gift.isSurpriseGift,
          ));      
      notifyListeners();
      return request;
    } catch (e) {
      _setError('Failed to claim gift: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Check if the given user has any pending outgoing claim requests
  Future<bool> hasPendingOutgoingClaim(String userId) async {
    try {
      final resp = await _giftApi.listGiftRequests(status: 'PENDING', page: 1, size: 20);
      final items = (resp['items'] as List?) ?? const [];
      for (final item in items) {
        final req = _parseGiftRequestFromApi(Map<String, dynamic>.from(item as Map));
        if (req.requester.id == userId && req.status == gift_models.GiftRequestStatus.pending) {
          return true;
        }
      }
      return false;
    } catch (e) {
      // On error, default to no pending to avoid blocking due to transient failures
      return false;
    }
  }

  /// Cancel a gift
  Future<bool> cancelGift(String giftId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _giftApi.cancelGift(giftId);
      
      // Update gift status in lists
      _updateGiftInLists(giftId, (gift) {
        return gift_models.Gift(
          id: gift.id,
          title: gift.title,
          description: gift.description,
          giver: gift.giver,
          type: gift.type,
          category: gift.category,
          status: gift_models.GiftStatus.completed, // Using completed as cancelled status
          createdAt: gift.createdAt,
          expiresAt: gift.expiresAt,
          claimedAt: gift.claimedAt,
          claimedBy: gift.claimedBy,
          karmaReward: gift.karmaReward,
          minimumKarmaLevel: gift.minimumKarmaLevel,
          location: gift.location,
          isLocationRestricted: gift.isLocationRestricted,
          maxClaims: gift.maxClaims,
          currentClaims: gift.currentClaims,
          imageUrls: gift.imageUrls,
          metadata: gift.metadata,
          tags: gift.tags,
          targetUserId: gift.targetUserId,
          targetCriteria: gift.targetCriteria,
          isChainGift: gift.isChainGift,
          chainParentId: gift.chainParentId,
          viewCount: gift.viewCount,
          likeCount: gift.likeCount,
          requestCount: gift.requestCount,
          rating: gift.rating,
          reviews: gift.reviews,
          isFeatured: gift.isFeatured,
          isSurpriseGift: gift.isSurpriseGift,
        );
      });
      
      return true;
    } catch (e) {
      _setError('Failed to cancel gift: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Permanently delete a gift (no claims / approved requests).
  Future<bool> deleteGift(String giftId) async {
    try {
      _setLoading(true);
      _setError(null);
      await _giftApi.deleteGift(giftId);
      _myGifts.removeWhere((g) => g.id == giftId);
      _gifts.removeWhere((g) => g.id == giftId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(parseDeleteListingError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Approve a gift request
  Future<bool> approveGiftRequest(String requestId, {String? message}) async {
    try {
      _setLoading(true);
      _setError(null);
      final response = await _giftApi.approveGiftRequest(requestId, message: message);

      final updatedReq = _parseGiftRequestFromApi((response['request'] as Map<String, dynamic>?) ?? {
        'id': requestId,
        'status': 'APPROVED',
        'responded_at': DateTime.now().toIso8601String(),
      });

      // Remove from pending requests
      _giftRequests = _giftRequests.where((r) => r.id != requestId).toList();

      // Update gift: mark claimed by requester
      final giftId = updatedReq.giftId;
      final requester = updatedReq.requester;
      final now = DateTime.now();
      _updateGiftInLists(giftId, (gift) => gift_models.Gift(
            id: gift.id,
            title: gift.title,
            description: gift.description,
            giver: gift.giver,
            type: gift.type,
            category: gift.category,
            status: gift_models.GiftStatus.claimed,
            createdAt: gift.createdAt,
            expiresAt: gift.expiresAt,
            claimedAt: now,
            claimedBy: requester,
            karmaReward: gift.karmaReward,
            minimumKarmaLevel: gift.minimumKarmaLevel,
            location: gift.location,
            isLocationRestricted: gift.isLocationRestricted,
            maxClaims: gift.maxClaims,
            currentClaims: (gift.currentClaims + 1).clamp(0, gift.maxClaims),
            imageUrls: gift.imageUrls,
            metadata: gift.metadata,
            tags: gift.tags,
            targetUserId: gift.targetUserId,
            targetCriteria: gift.targetCriteria,
            isChainGift: gift.isChainGift,
            chainParentId: gift.chainParentId,
            viewCount: gift.viewCount,
            likeCount: gift.likeCount,
            requestCount: gift.requestCount,
            rating: gift.rating,
            reviews: gift.reviews,
            isFeatured: gift.isFeatured,
            isSurpriseGift: gift.isSurpriseGift,
          ));
      
      // Also remove the gift from the available gifts list since it's now claimed
      _gifts = _gifts.where((g) => g.id != giftId).toList();
      // Add to history
      _giftHistory.insert(
        0,
        GiftClaim(
          id: (response['claimId']?.toString()) ?? 'claim_${DateTime.now().millisecondsSinceEpoch}',
          giftId: giftId,
          claimerId: requester.id,
          gift: _gifts.firstWhere(
            (g) => g.id == giftId,
            orElse: () => _myGifts.firstWhere(
              (g) => g.id == giftId,
              orElse: () => gift_models.Gift(
                id: giftId,
                title: '',
                description: '',
                giver: requester,
                type: gift_models.GiftType.random,
                category: gift_models.GiftCategory.others,
                status: gift_models.GiftStatus.claimed,
                createdAt: now,
                karmaReward: 0,
              ),
            ),
          ),
          claimedAt: now,
          code: (response['code']?.toString()) ?? '',
          karmaAwarded: (response['karmaAwarded'] as int?) ?? 0,
        ),
      );

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to approve request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Decline a gift request
  Future<bool> declineGiftRequest(String requestId, {String? reason}) async {
    try {
      _setLoading(true);
      _setError(null);
      await _giftApi.declineGiftRequest(requestId, reason: reason);

      // Locate and remove request
      final declined = _giftRequests.firstWhere(
        (r) => r.id == requestId,
        orElse: () => gift_models.GiftRequest(
          id: requestId,
          giftId: '',
          gift: gift_models.Gift(
            id: '',
            title: 'Unknown Gift',
            description: '',
            giver: gift_models.GiftUser(
              id: 'unknown',
              name: 'Unknown',
              username: '@unknown',
              rating: 0.0,
              completedGifts: 0,
              karmaPoints: 0,
              joinedDate: DateTime.now(),
              isVerified: false,
            ),
            type: gift_models.GiftType.random,
            category: gift_models.GiftCategory.others,
            status: gift_models.GiftStatus.active,
            createdAt: DateTime.now(),
            karmaReward: 0,
          ),
          requester: gift_models.GiftUser(
            id: 'unknown',
            name: 'Unknown',
            username: '@unknown',
            rating: 0.0,
            completedGifts: 0,
            karmaPoints: 0,
            joinedDate: DateTime.now(),
            isVerified: false,
          ),
          createdAt: DateTime.now(),
          status: gift_models.GiftRequestStatus.declined,
        ),
      );
      _giftRequests = _giftRequests.where((r) => r.id != requestId).toList();

      // Return gift to available (owner view)
      // Also add the gift back to the available gifts list if it should be available after declining
      if (declined.giftId.isNotEmpty) {
        _updateGiftInLists(declined.giftId, (gift) => gift_models.Gift(              id: gift.id,
              title: gift.title,
              description: gift.description,
              giver: gift.giver,
              type: gift.type,
              category: gift.category,
              status: gift_models.GiftStatus.active,
              createdAt: gift.createdAt,
              expiresAt: gift.expiresAt,
              claimedAt: null,
              claimedBy: null,
              karmaReward: gift.karmaReward,
              minimumKarmaLevel: gift.minimumKarmaLevel,
              location: gift.location,
              isLocationRestricted: gift.isLocationRestricted,
              maxClaims: gift.maxClaims,
              currentClaims: gift.currentClaims > 0 ? gift.currentClaims - 1 : 0, // Decrement current claims when request is declined
              imageUrls: gift.imageUrls,
              metadata: gift.metadata,
              tags: gift.tags,
              targetUserId: gift.targetUserId,
              targetCriteria: gift.targetCriteria,
              isChainGift: gift.isChainGift,
              chainParentId: gift.chainParentId,
              viewCount: gift.viewCount,
              likeCount: gift.likeCount,
              requestCount: gift.requestCount,
              rating: gift.rating,
              reviews: gift.reviews,
              isFeatured: gift.isFeatured,
              isSurpriseGift: gift.isSurpriseGift,
            ));
      }
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to decline request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  void _updateGiftInLists(String giftId, gift_models.Gift Function(gift_models.Gift) updater) {
    // Update in main gifts list
    final giftIndex = _gifts.indexWhere((g) => g.id == giftId);
    if (giftIndex != -1) {
      _gifts[giftIndex] = updater(_gifts[giftIndex]);
    }
    
    // Update in my gifts list
    final myGiftIndex = _myGifts.indexWhere((g) => g.id == giftId);
    if (myGiftIndex != -1) {
      _myGifts[myGiftIndex] = updater(_myGifts[myGiftIndex]);
    }
    
    notifyListeners();
  }

  /// Parse gift from API response
  gift_models.Gift _parseGiftFromApi(Map<String, dynamic> data) {
    // Create a mock giver user since the API structure might differ
    final giverData = data['giver'] as Map<String, dynamic>? ?? {};
    final giverProfile = giverData['profile'] as Map<String, dynamic>? ?? {};
    
    final giver = gift_models.GiftUser(
      id: giverData['id'] ?? '',
      name: giverProfile['displayName'] ?? 'Unknown User',
      username: '@${giverData['email']?.split('@')[0] ?? 'unknown'}',
      rating: 4.5, // Default rating
      completedGifts: 0, // Default value
      karmaPoints: 100, // Default value
      joinedDate: DateTime.tryParse(giverData['createdAt'] ?? '') ?? DateTime.now(),
      isVerified: giverProfile['kycStatus'] == 'VERIFIED',
      profileImageUrl: giverProfile['avatarKey'],
    );

    final meta = data['metadata'] as Map<String, dynamic>? ?? {};
    return gift_models.Gift(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      giver: giver,
      type: _parseGiftType(data['type']),
      category: _parseGiftCategory(data['category']),
      status: _parseGiftStatus(data['status']),
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      expiresAt: data['expiresAt'] != null ? DateTime.tryParse(data['expiresAt']) : null,
      karmaReward: data['karmaReward'] ?? 30,
      maxClaims: data['maxClaims'] ?? 1,
      currentClaims: data['currentClaims'] ?? 0,
      location: data['location'],
      isLocationRestricted: data['isLocationRestricted'] ?? false,
      imageUrls: List<String>.from(data['mediaKeys'] ?? []),
      mediaType: data['mediaType']?.toString(),
      videoKey: data['videoKey']?.toString(),
      thumbnailKey: data['thumbnailKey']?.toString(),
      tags: List<String>.from(data['tags'] ?? []),
      metadata: meta,
      targetUserId: data['targetUserId'],
      targetCriteria: data['targetCriteria'] as Map<String, dynamic>?,
      isChainGift: data['isChainGift'] ?? false,
      chainParentId: data['chainParentId'],
      viewCount: (data['viewCount'] ?? meta['viewCount'] ?? 0) as int,
      likeCount: (data['likeCount'] ?? meta['likes'] ?? 0) as int,
      requestCount: (data['requestCount'] ?? 0) as int,
    );
  }

  /// Parse gift claim from API response  
  GiftClaim _parseGiftClaimFromApi(Map<String, dynamic> data) {
    final giftData = data['gift'] as Map<String, dynamic>? ?? {};
    var gift = _parseGiftFromApi(giftData);
    final claimerData = data['claimer'] as Map<String, dynamic>?;
    if (claimerData != null && gift.claimedBy == null) {
      final claimer = gift_models.GiftUser.fromJson(claimerData);
      gift = gift_models.Gift(
        id: gift.id,
        title: gift.title,
        description: gift.description,
        giver: gift.giver,
        type: gift.type,
        category: gift.category,
        status: gift.status,
        createdAt: gift.createdAt,
        expiresAt: gift.expiresAt,
        claimedAt: gift.claimedAt,
        claimedBy: claimer,
        karmaReward: gift.karmaReward,
        minimumKarmaLevel: gift.minimumKarmaLevel,
        location: gift.location,
        isLocationRestricted: gift.isLocationRestricted,
        maxClaims: gift.maxClaims,
        currentClaims: gift.currentClaims,
        imageUrls: gift.imageUrls,
        mediaType: gift.mediaType,
        videoKey: gift.videoKey,
        thumbnailKey: gift.thumbnailKey,
        metadata: gift.metadata,
        tags: gift.tags,
        targetUserId: gift.targetUserId,
        targetCriteria: gift.targetCriteria,
        isChainGift: gift.isChainGift,
        chainParentId: gift.chainParentId,
        viewCount: gift.viewCount,
        likeCount: gift.likeCount,
        requestCount: gift.requestCount,
        rating: gift.rating,
        reviews: gift.reviews,
        isFeatured: gift.isFeatured,
        isSurpriseGift: gift.isSurpriseGift,
      );
    }
    final claimerId = (data['claimerId'] ?? claimerData?['id'] ?? gift.claimedBy?.id ?? '')
        .toString();
    return GiftClaim(
      id: data['id'] ?? '',
      giftId: data['giftId'] ?? gift.id,
      claimerId: claimerId,
      gift: gift,
      claimedAt: DateTime.tryParse(data['claimedAt'] ?? '') ?? DateTime.now(),
      code: data['code'] ?? '',
      karmaAwarded: data['karmaAwarded'] ?? 0,
    );
  }

  gift_models.GiftType _parseGiftType(dynamic type) {
    if (type == null) return gift_models.GiftType.random;
    final typeStr = type.toString().toLowerCase();
    return gift_models.GiftType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => gift_models.GiftType.random,
    );
  }

  gift_models.GiftCategory _parseGiftCategory(dynamic category) {
    if (category == null) return gift_models.GiftCategory.others;
    final categoryStr = category.toString().toLowerCase();
    return gift_models.GiftCategory.values.firstWhere(
      (c) => c.name == categoryStr,
      orElse: () => gift_models.GiftCategory.others,
    );
  }

  gift_models.GiftStatus _parseGiftStatus(dynamic status) {
    if (status == null) return gift_models.GiftStatus.active;
    final statusStr = status.toString().toLowerCase();
    
    switch (statusStr) {
      case 'active':
        return gift_models.GiftStatus.active;
      case 'claimed':
        return gift_models.GiftStatus.claimed;
      case 'expired':
        return gift_models.GiftStatus.expired;
      case 'cancelled':
        return gift_models.GiftStatus.completed; // Map cancelled to completed
      default:
        return gift_models.GiftStatus.active;
    }
  }

  /// Parse GiftRequest from API or constructed map
  gift_models.GiftRequest _parseGiftRequestFromApi(Map<String, dynamic> json) {
    final requesterJson = json['requester'] as Map<String, dynamic>? ?? json['claimer'] as Map<String, dynamic>? ?? {
      'id': (json['requester_id'] ?? 'unknown').toString(),
      'name': (json['requester_name'] ?? 'Unknown').toString(),
      'username': '@unknown',
      'rating': 0.0,
      'completed_gifts': 0,
      'karma_points': 0,
      'joined_date': DateTime.now().toIso8601String(),
      'is_verified': false,
    };
    
    final giftJson = (json['gift'] as Map<String, dynamic>?) ?? {
      'id': json['giftId'] ?? json['gift_id'] ?? '',
      'title': 'Gift',
      'description': '',
      'giver': requesterJson,
      'type': 'RANDOM',
      'category': 'OTHERS',
      'status': 'ACTIVE',
      'createdAt': DateTime.now().toIso8601String(),
      'karmaReward': 0,
    };
    // Prefer the provider's gift parsing to normalize server payloads
    return gift_models.GiftRequest(
      id: (json['id'] ?? json['requestId'] ?? '').toString(),
      giftId: (json['gift_id'] ?? json['giftId'] ?? '').toString(),
      gift: _parseGiftFromApi(giftJson),
      requester: gift_models.GiftUser.fromJson(requesterJson),
      message: json['message'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()).toString()) ?? DateTime.now(),
      status: _mapRequestStatus(json['status']?.toString()),
      respondedAt: json['responded_at'] != null ? DateTime.tryParse(json['responded_at'].toString()) : null,
      responseMessage: json['response_message'] as String?,
    );
  }

  gift_models.GiftRequestStatus _mapRequestStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'APPROVED':
        return gift_models.GiftRequestStatus.approved;
      case 'DECLINED':
        return gift_models.GiftRequestStatus.declined;
      case 'EXPIRED':
        return gift_models.GiftRequestStatus.expired;
      case 'PENDING':
      default:
        return gift_models.GiftRequestStatus.pending;
    }
  }

  /// Re-fetch a single gift and merge into browse / my-gifts lists.
  Future<void> refreshGiftById(String giftId) async {
    if (giftId.trim().isEmpty) return;
    try {
      final response = await _giftApi.getGift(giftId);
      final fresh = _parseGiftFromApi(response);
      _upsertGiftInLists(fresh);
      notifyListeners();
    } catch (_) {}
  }

  void _upsertGiftInLists(gift_models.Gift gift) {
    final browseIndex = _gifts.indexWhere((g) => g.id == gift.id);
    if (browseIndex >= 0) {
      _gifts[browseIndex] = _preferRicherGiftMedia(gift, _gifts[browseIndex]);
    } else if (gift.isAvailable) {
      _gifts.insert(0, gift);
    }

    final mineIndex = _myGifts.indexWhere((g) => g.id == gift.id);
    if (mineIndex >= 0) {
      _myGifts[mineIndex] = _preferRicherGiftMedia(gift, _myGifts[mineIndex]);
    } else {
      _myGifts.insert(0, gift);
    }
  }

  gift_models.Gift _preferRicherGiftMedia(
    gift_models.Gift primary,
    gift_models.Gift? fallback,
  ) {
    if (primary.listingMedia.hasMedia) return primary;
    if (fallback == null || !fallback.listingMedia.hasMedia) return primary;
    return _applyCreateMediaFallback(
      primary,
      mediaType: fallback.mediaType,
      mediaKeys: fallback.imageUrls,
      videoKey: fallback.videoKey,
      thumbnailKey: fallback.thumbnailKey,
    );
  }

  gift_models.Gift _applyCreateMediaFallback(
    gift_models.Gift gift, {
    String? mediaType,
    List<String>? mediaKeys,
    String? videoKey,
    String? thumbnailKey,
  }) {
    if (gift.listingMedia.hasMedia) return gift;

    final keys = mediaKeys?.where((k) => k.trim().isNotEmpty).toList() ?? const [];
    final video = videoKey?.trim();
    final thumb = thumbnailKey?.trim();
    final isVideo = (mediaType?.toUpperCase() == 'VIDEO') ||
        ((video?.isNotEmpty ?? false) && keys.isEmpty);
    if (!isVideo && keys.isEmpty) return gift;

    return gift_models.Gift(
      id: gift.id,
      title: gift.title,
      description: gift.description,
      giver: gift.giver,
      type: gift.type,
      category: gift.category,
      status: gift.status,
      createdAt: gift.createdAt,
      expiresAt: gift.expiresAt,
      claimedAt: gift.claimedAt,
      claimedBy: gift.claimedBy,
      karmaReward: gift.karmaReward,
      minimumKarmaLevel: gift.minimumKarmaLevel,
      location: gift.location,
      isLocationRestricted: gift.isLocationRestricted,
      maxClaims: gift.maxClaims,
      currentClaims: gift.currentClaims,
      imageUrls: isVideo ? const [] : keys,
      mediaType: isVideo ? 'VIDEO' : (mediaType ?? 'IMAGE'),
      videoKey: isVideo ? video : null,
      thumbnailKey: isVideo ? thumb : (keys.isNotEmpty ? keys.first : thumb),
      metadata: gift.metadata,
      tags: gift.tags,
      targetUserId: gift.targetUserId,
      targetCriteria: gift.targetCriteria,
      isChainGift: gift.isChainGift,
      chainParentId: gift.chainParentId,
      viewCount: gift.viewCount,
      likeCount: gift.likeCount,
      requestCount: gift.requestCount,
      rating: gift.rating,
      reviews: gift.reviews,
      isFeatured: gift.isFeatured,
      isSurpriseGift: gift.isSurpriseGift,
    );
  }
}

