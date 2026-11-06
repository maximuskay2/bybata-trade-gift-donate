import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/listing_delete_helper.dart';
import '../../../core/utils/network_error_message.dart';
import '../../../core/utils/offline_json_cache.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:bybata/core/config/env_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/compliance/ios_campaign_support.dart';
import '../../../core/utils/media_utils.dart';
import '../api/campaign_api.dart';
import '../models/donation_models.dart';

/// Campaign donation model for history
class CampaignDonation {
  final String id;
  final String campaignId;
  final Campaign campaign;
  final DateTime donatedAt;
  final double amount;
  final String currency;
  final bool isAnonymous;
  final String? message;
  final int karmaAwarded;
  final DonationStatus status;

  const CampaignDonation({
    required this.id,
    required this.campaignId,
    required this.campaign,
    required this.donatedAt,
    required this.amount,
    required this.currency,
    required this.isAnonymous,
    this.message,
    required this.karmaAwarded,
    required this.status,
  });
}

class CampaignProvider with ChangeNotifier {
  final CampaignApi _campaignApi;
  final ApiClient _apiClient;
  IO.Socket? _socket;

  bool _disposed = false;

  CampaignProvider(ApiClient apiClient)
    : _campaignApi = CampaignApi(apiClient),
      _apiClient = apiClient;

  ApiClient get apiClient => _apiClient;

  List<Campaign> _campaigns = [];
  List<Campaign> _myCampaigns = [];
  List<CampaignDonation> _donationHistory = [];
  bool _isLoading = false;
  bool _isLoadingCampaigns = false;
  bool _isLoadingMyCampaigns = false;
  bool _isLoadingHistory = false;
  String? _error;
  
  // Cache timestamps for smart refetching
  DateTime? _lastCampaignsFetchAt;
  DateTime? _lastMyCampaignsFetchAt;
  DateTime? _lastHistoryFetchAt;
  bool _campaignsInitialized = false;
  bool _myCampaignsInitialized = false;
  bool _historyInitialized = false;
  
  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  List<Campaign> get campaigns => _campaigns;
  List<Campaign> get myCampaigns => _myCampaigns;
  List<CampaignDonation> get donationHistory => _donationHistory;
  bool get isLoading =>
      _isLoading ||
      _isLoadingCampaigns ||
      _isLoadingMyCampaigns ||
      _isLoadingHistory;
  bool get isLoadingCampaigns => _isLoadingCampaigns;
  bool get isLoadingMyCampaigns => _isLoadingMyCampaigns;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get error => _error;

  static const _campaignBox = 'campaigns_cache';
  String _diskUserId = 'guest';

  /// Call when auth user is known so disk cache is scoped per account.
  void setCacheUserId(String? userId) {
    _diskUserId =
        (userId != null && userId.isNotEmpty) ? userId : 'guest';
    unawaited(_hydrateCampaignsFromDisk());
  }

  Future<void> _hydrateCampaignsFromDisk() async {
    try {
      if (_campaigns.isEmpty) {
        final maps =
            await OfflineJsonCache.getList(_campaignBox, _diskUserId, 'browse');
        if (maps.isNotEmpty) {
          _campaigns = maps.map(_parseCampaignFromApi).toList();
          _campaignsInitialized = true;
        }
      }
      if (_myCampaigns.isEmpty) {
        final maps = await OfflineJsonCache.getList(
          _campaignBox,
          _diskUserId,
          'my_campaigns',
        );
        if (maps.isNotEmpty) {
          _myCampaigns = maps.map(_parseCampaignFromApi).toList();
          _myCampaignsInitialized = true;
        }
      }
      if (_campaigns.isNotEmpty || _myCampaigns.isNotEmpty) {
        _setError(null);
        notifyListeners();
      }
    } catch (_) {}
  }

  // Search state
  bool _isSearching = false;
  String? _searchError;
  List<Campaign> _searchResults = [];
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  List<Campaign> get searchResults => _searchResults;

  // Real-time update callbacks
  final Map<String, Function(Map<String, dynamic>)> _campaignUpdateCallbacks = {};

  /// Register a callback for real-time updates to a specific campaign
  void onCampaignUpdate(String campaignId, Function(Map<String, dynamic>) callback) {
    _campaignUpdateCallbacks[campaignId] = callback;
  }

  /// Unregister callback for a campaign
  void removeCampaignUpdateCallback(String campaignId) {
    _campaignUpdateCallbacks.remove(campaignId);
  }

  @override
  void dispose() {
    _disposed = true;
    _socket?.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  Future<void> startRealtime() async {
    try {
      _socket?.dispose();
      final storage = _apiClient.storage;
      final token = await storage.read(key: 'access');

      // Derive the WebSocket base from the active HTTP API base so that
      // debug builds connect to the local dev backend instead of
      // accidentally hitting production.
      final httpBase = await EnvConfig.getBaseUrl();
      final httpUri = Uri.parse(httpBase);
      final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
      final wsBase = Uri(
        scheme: wsScheme,
        host: httpUri.host,
        port: httpUri.hasPort
            ? httpUri.port
            : (httpUri.scheme == 'https' ? 443 : 80),
      ).toString();

      final client = IO.io(
        '$wsBase/chat',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setExtraHeaders(
              token != null ? {'authorization': 'Bearer $token'} : {},
            )
            .enableReconnection()
            .build(),
      );
      _socket = client;
      client.onConnect((_) {
        // Connected
      });
      client.on('donation.created', (data) async {
        final donationData = data as Map<String, dynamic>? ?? {};
        final campaignId = donationData['campaignId']?.toString();
        final donorId = donationData['donorId']?.toString();
        final amount = (donationData['amount'] as num?)?.toDouble();
        final donorCount = (donationData['donorCount'] as num?)?.toInt();
        final campaignStatus = donationData['campaignStatus']?.toString();

        // Reload campaigns list
        await loadCampaigns(status: CampaignStatus.active);

        // Notify specific campaign listeners
        if (campaignId != null && _campaignUpdateCallbacks.containsKey(campaignId)) {
          final callback = _campaignUpdateCallbacks[campaignId];
          if (callback != null) {
            callback({
              'type': 'donation',
              'campaignId': campaignId,
              'donorId': donorId,
              'amount': amount,
              'donorCount': donorCount,
              'campaignStatus': campaignStatus,
            });
          }
        }

        // Notify all listeners
        notifyListeners();
      });
      client.onDisconnect((_) {});
    } catch (_) {}
  }

  void _setLoading(bool loading) {
    if (_disposed) return;
    _isLoading = loading;
    notifyListeners();
  }

  void _setLoadingCampaigns(bool loading) {
    if (_disposed) return;
    _isLoadingCampaigns = loading;
    notifyListeners();
  }

  void _setLoadingMyCampaigns(bool loading) {
    if (_disposed) return;
    _isLoadingMyCampaigns = loading;
    notifyListeners();
  }

  void _setLoadingHistory(bool loading) {
    if (_disposed) return;
    _isLoadingHistory = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    if (_disposed) return;
    _error = error == null ? null : NetworkErrorMessage.sanitize(error);
    notifyListeners();
  }

  /// Create a new campaign
  Future<Campaign?> createCampaign({
    required String title,
    String? description,
    String? shortDescription,
    CampaignCategory? category,
    required double goalAmount,
    String? currency,
    String? mediaType,
    List<String>? mediaKeys,
    String? videoKey,
    String? thumbnailKey,
    List<String>? tags,
    String? location,
    bool? isUrgent,
    double? minimumDonation,
    DateTime? endsAt,
    Map<String, dynamic>? metadata,
    double? latitude,
    double? longitude,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _campaignApi.createCampaign(
        title: title,
        description: description,
        shortDescription: shortDescription,
        category: category?.name.toUpperCase(),
        goalAmount: goalAmount,
        currency: currency,
        mediaType: mediaType,
        mediaKeys: mediaKeys,
        videoKey: videoKey,
        thumbnailKey: thumbnailKey,
        tags: tags,
        location: location,
        isUrgent: isUrgent,
        minimumDonation: minimumDonation,
        endsAt: endsAt,
        metadata: metadata,
        latitude: latitude,
        longitude: longitude,
      );

      final campaign = _parseCampaignFromApi(response);

      // Add to my campaigns list if it exists
      if (_myCampaigns.isNotEmpty) {
        _myCampaigns.insert(0, campaign);
      }

      return campaign;
    } catch (e) {
      _setError('Failed to create campaign: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Update an existing campaign (used when editing donations)
  Future<Campaign?> updateCampaign(
    String campaignId, {
    String? title,
    String? description,
    String? shortDescription,
    CampaignCategory? category,
    double? goalAmount,
    String? mediaType,
    List<String>? mediaKeys,
    String? videoKey,
    String? thumbnailKey,
    List<String>? tags,
    String? location,
    bool? isUrgent,
    double? minimumDonation,
    DateTime? endsAt,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _campaignApi.updateCampaign(
        campaignId,
        title: title,
        description: description,
        shortDescription: shortDescription,
        category: category?.name.toUpperCase(),
        goalAmount: goalAmount,
        mediaType: mediaType,
        mediaKeys: mediaKeys,
        videoKey: videoKey,
        thumbnailKey: thumbnailKey,
        tags: tags,
        location: location,
        isUrgent: isUrgent,
        minimumDonation: minimumDonation,
        endsAt: endsAt,
        metadata: metadata,
      );

      final updated = _parseCampaignFromApi(response);
      _updateCampaignInLists(updated);
      notifyListeners();
      return updated;
    } catch (e) {
      _setError('Failed to update campaign: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Load campaigns
  Future<void> loadCampaigns({
    String? query,
    CampaignCategory? category,
    CampaignStatus? status,
    String? location,
    bool? isUrgent,
    bool? isFeatured,
    int page = 1,
    bool force = false,
  }) async {
    // Smart caching: skip if already loaded and cache is fresh
    if (!force && _campaignsInitialized && _lastCampaignsFetchAt != null) {
      final cacheAge = DateTime.now().difference(_lastCampaignsFetchAt!);
      if (cacheAge < _cacheDuration && _campaigns.isNotEmpty) {
        print('[CampaignProvider] Using cached campaigns (${cacheAge.inSeconds}s old)');
        notifyListeners();
        return;
      }
    }

    if (!_campaignsInitialized && _campaigns.isEmpty) {
      await _hydrateCampaignsFromDisk();
    }
    
    try {
      _setLoadingCampaigns(true);
      _setError(null);

      final response = await _campaignApi.listCampaigns(
        query: query,
        category: category?.name.toUpperCase(),
        status: status?.name.toUpperCase(),
        location: location,
        isUrgent: isUrgent,
        isFeatured: isFeatured,
        page: page,
      );

      final items = response['items'] as List? ?? [];
      MediaResolver.seedUrlsFromListingMaps(
        items.whereType<Map<String, dynamic>>(),
      );
      if (kDebugMode) {
        debugPrint(
          '[CampaignProvider] loadCampaigns page=$page status=${status?.name} count=${items.length}',
        );
        for (var i = 0; i < (items.length < 5 ? items.length : 5); i++) {
          final it = items[i] as Map<String, dynamic>;
          debugPrint(
            '  item[$i]: id=${it['id']} status=${it['status']} createdAt=${it['createdAt']} title=${it['title']}',
          );
        }
      }
      final newCampaigns = items
          .map((item) => _parseCampaignFromApi(item as Map<String, dynamic>))
          .toList();

      if (page == 1) {
        _campaigns = newCampaigns;
      } else {
        _campaigns.addAll(newCampaigns);
      }

      // Update cache metadata
      _lastCampaignsFetchAt = DateTime.now();
      _campaignsInitialized = true;

      notifyListeners();
      if (page == 1) {
        final raw = items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        unawaited(
          OfflineJsonCache.putList(_campaignBox, _diskUserId, 'browse', raw),
        );
      }
    } catch (e) {
      if (_campaigns.isNotEmpty) {
        _setError(null);
      } else {
        _setError(NetworkErrorMessage.forListingLoad(e));
      }
    } finally {
      _setLoadingCampaigns(false);
    }
  }

  /// Load my campaigns
  Future<void> loadMyCampaigns({CampaignStatus? status, int page = 1, bool force = false}) async {
    // Smart caching: skip if already loaded and cache is fresh
    if (!force && _myCampaignsInitialized && _lastMyCampaignsFetchAt != null) {
      final cacheAge = DateTime.now().difference(_lastMyCampaignsFetchAt!);
      if (cacheAge < _cacheDuration && _myCampaigns.isNotEmpty) {
        print('[CampaignProvider] Using cached my campaigns (${cacheAge.inSeconds}s old)');
        notifyListeners();
        return;
      }
    }
    
    try {
      _setLoadingMyCampaigns(true);
      _setError(null);

      final response = await _campaignApi.getMyCampaigns(
        status: status?.name.toUpperCase(),
        page: page,
      );

      final items = response['items'] as List? ?? [];
      final newCampaigns = items
          .map((item) => _parseCampaignFromApi(item as Map<String, dynamic>))
          .toList();

      if (page == 1) {
        _myCampaigns = newCampaigns;
      } else {
        _myCampaigns.addAll(newCampaigns);
      }

      // Update cache metadata
      _lastMyCampaignsFetchAt = DateTime.now();
      _myCampaignsInitialized = true;

      notifyListeners();
      if (page == 1) {
        final raw = items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        unawaited(
          OfflineJsonCache.putList(
            _campaignBox,
            _diskUserId,
            'my_campaigns',
            raw,
          ),
        );
      }
    } catch (e) {
      if (_myCampaigns.isNotEmpty) {
        _setError(null);
      } else {
        _setError(NetworkErrorMessage.from(
          e,
          fallback: 'Couldn\'t load your campaigns. Please try again.',
        ));
      }
    } finally {
      _setLoadingMyCampaigns(false);
    }
  }

  /// Permanently delete a campaign (only when no donations received).
  Future<bool> deleteCampaign(String campaignId) async {
    try {
      _setLoading(true);
      _setError(null);
      await _campaignApi.deleteCampaign(campaignId);
      _myCampaigns.removeWhere((c) => c.id == campaignId);
      _campaigns.removeWhere((c) => c.id == campaignId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(parseDeleteListingError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Load donation history
  Future<void> loadDonationHistory({int page = 1, bool force = false}) async {
    // Smart caching: skip if already loaded and cache is fresh
    if (!force && _historyInitialized && _lastHistoryFetchAt != null) {
      final cacheAge = DateTime.now().difference(_lastHistoryFetchAt!);
      if (cacheAge < _cacheDuration && _donationHistory.isNotEmpty) {
        print('[CampaignProvider] Using cached donation history (${cacheAge.inSeconds}s old)');
        notifyListeners();
        return;
      }
    }
    
    try {
      _setLoadingHistory(true);
      _setError(null);

      final response = await _campaignApi.getDonationHistory(page: page);

      final items = response['items'] as List? ?? [];
      final newHistory = items
          .map((item) => _parseDonationFromApi(item as Map<String, dynamic>))
          .toList();

      if (page == 1) {
        _donationHistory = newHistory;
      } else {
        _donationHistory.addAll(newHistory);
      }

      // Update cache metadata
      _lastHistoryFetchAt = DateTime.now();
      _historyInitialized = true;

      notifyListeners();
    } catch (e) {
      _setError(NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t load donation history. Please try again.',
      ));
    } finally {
      _setLoadingHistory(false);
    }
  }

  /// Update campaign status
  Future<Campaign?> updateCampaignStatus(
    String campaignId,
    CampaignStatus status,
  ) async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _campaignApi.updateCampaignStatus(
        campaignId,
        status.name.toUpperCase(),
      );
      final updatedCampaign = _parseCampaignFromApi(response);

      // Update in my campaigns list
      final index = _myCampaigns.indexWhere((c) => c.id == campaignId);
      if (index != -1) {
        _myCampaigns[index] = updatedCampaign;
        notifyListeners();
      }

      return updatedCampaign;
    } catch (e) {
      _setError('Failed to update campaign status: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Donate to campaign
  Future<CampaignDonation?> donateToCampaign(
    String campaignId, {
    required double amount,
    String? currency,
    bool? isAnonymous,
    String? message,
    String? rewardTierId,
  }) async {
    if (CampaignSupportCompliance.blocksInAppDonations) {
      _setError('Campaign support on iOS must be completed on the web.');
      return null;
    }
    try {
      _setLoading(true);
      _setError(null);

      final response = await _campaignApi.donateToCampaign(
        campaignId,
        amount: amount,
        currency: currency,
        isAnonymous: isAnonymous,
        message: message,
        rewardTierId: rewardTierId,
      );

      final donation = _parseDonationFromApi(response);

      // Add to donation history
      _donationHistory.insert(0, donation);

      // Update campaign in lists if present
      _updateCampaignInLists(donation.campaign);

      notifyListeners();
      return donation;
    } catch (e) {
      _setError('Failed to make donation: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get campaign by ID
  Future<Campaign?> getCampaign(String campaignId) async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _campaignApi.getCampaign(campaignId);
      return _parseCampaignFromApi(response);
    } catch (e) {
      _setError(NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t load this campaign. Please try again.',
      ));
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> likeCampaign(String campaignId) async {
    return _campaignApi.likeCampaign(campaignId);
  }

  Future<Map<String, dynamic>> unlikeCampaign(String campaignId) async {
    return _campaignApi.unlikeCampaign(campaignId);
  }

  /// Get comments for a campaign
  Future<Map<String, dynamic>> getCampaignComments(String campaignId, {int page = 1, int size = 50}) async {
    try {
      return await _campaignApi.getComments(campaignId, page: page, size: size);
    } catch (e) {
      return {'comments': [], 'total': 0};
    }
  }

  /// Add a comment to a campaign
  Future<Map<String, dynamic>?> addCampaignComment(String campaignId, String content, {String? parentId}) async {
    try {
      return await _campaignApi.addComment(campaignId, content, parentId: parentId);
    } catch (e) {
      _setError('Failed to add comment: $e');
      return null;
    }
  }

  /// Parse campaign from API response
  Campaign _parseCampaignFromApi(Map<String, dynamic> data) =>
      Campaign.fromJson(data);

  /// Parse donation from API response
  CampaignDonation _parseDonationFromApi(Map<String, dynamic> data) {
    final rawStatus = data['status']?.toString();
    final refundedAt = data['refundedAt'];

    DonationStatus status;
    if (refundedAt != null) {
      status = DonationStatus.refunded;
    } else {
      switch (rawStatus?.toUpperCase()) {
        case 'PENDING':
          status = DonationStatus.pending;
          break;
        case 'FAILED':
          status = DonationStatus.failed;
          break;
        case 'SUCCESS':
        default:
          status = DonationStatus.completed;
      }
    }

    return CampaignDonation(
      id: (data['id'] ?? '').toString(),
      campaignId: (data['campaignId'] ?? '').toString(),
      campaign: _parseCampaignFromApi(data['campaign'] ?? {}),
      donatedAt:
          DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      amount: _toDouble(data['amount']),
      currency: (data['currency'] ?? 'BYC').toString(),
      isAnonymous: data['isAnonymous'] == true,
      message: data['message']?.toString(),
      karmaAwarded: _toInt(data['karmaAwarded']),
      status: status,
    );
  }

  void _updateCampaignInLists(Campaign updatedCampaign) {
    // Update in campaigns list
    final campaignIndex = _campaigns.indexWhere(
      (c) => c.id == updatedCampaign.id,
    );
    if (campaignIndex != -1) {
      _campaigns[campaignIndex] = updatedCampaign;
    }

    // Update in my campaigns list
    final myCampaignIndex = _myCampaigns.indexWhere(
      (c) => c.id == updatedCampaign.id,
    );
    if (myCampaignIndex != -1) {
      _myCampaigns[myCampaignIndex] = updatedCampaign;
    }
  }

  Future<void> searchDonations({
    required List<String> categories,
    double? minAmount,
    double? maxAmount,
    bool exactAmount = false,
    int page = 1,
    int size = 20,
  }) async {
    _isSearching = true;
    _searchError = null;
    notifyListeners();
    try {
      final res = await _campaignApi.searchDonations(
        categories: categories,
        minAmount: minAmount,
        maxAmount: maxAmount,
        exactAmount: exactAmount,
        page: page,
        size: size,
      );
      final items = (res['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final mapped = items
          .map((m) => _parseCampaignFromApi(m as Map<String, dynamic>))
          .toList();
      // De-duplicate by id
      final seen = <String>{};
      _searchResults = mapped.where((c) => seen.add(c.id)).toList();
    } catch (e) {
      _searchError = e.toString();
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Generate a yearly donation receipt PDF for the current donor.
  Future<Map<String, dynamic>> generateDonationReceipt({required int year}) {
    return _campaignApi.generateDonationReceipt(year: year);
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return (v as num).toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
