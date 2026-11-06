import 'package:flutter/foundation.dart';
import '../core/utils/listing_category_parser.dart';
import '../models/feed_item.dart';
import '../models/intent_types.dart';
import '../core/api/api_client.dart';
import '../core/utils/network_utils.dart';

/// Unified feed backed by the PUBLIC browse endpoints.
///
/// WHY: `/v1/feed/home` is both JWT-gated and feature-flag gated
/// (`ENABLE_UNIFIED_FEED`, off in production), so it returns 403 for every
/// caller — logged-in or not — producing the "you don't have permission to
/// perform this action" error users were seeing on the Discover tab and
/// the Home screen's Near-you section. The public browse endpoints
/// (`/v1/public/browse/{trades,gifts,campaigns}`) are open to all and
/// return the same content we need, so we aggregate them client-side.
class FeedProvider with ChangeNotifier {
  final ApiClient _apiClient;

  FeedProvider(this._apiClient);

  static const int _pageSize = 20;

  List<FeedItem> _feedItems = [];
  List<FeedItem> _recentItems = [];
  bool _isLoading = false;
  bool _isLoadingRecent = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;

  // Filters
  IntentType? _intentTypeFilter;
  IntentSubType? _intentSubTypeFilter;

  List<FeedItem> get feedItems => _feedItems;
  List<FeedItem> get recentItems => _recentItems;
  bool get isLoading => _isLoading;
  bool get isLoadingRecent => _isLoadingRecent;
  String? get error => _error;
  bool get hasMore => _hasMore;
  IntentType? get intentTypeFilter => _intentTypeFilter;
  IntentSubType? get intentSubTypeFilter => _intentSubTypeFilter;

  /// Load feed with optional filters.
  Future<void> loadFeed({
    bool refresh = false,
    IntentType? intentType,
    IntentSubType? intentSubType,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _feedItems = [];
      _hasMore = true;
    }

    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Decide which public endpoints to hit based on the active filter.
      // When no subtype filter is set we fan out to all three to produce a
      // merged "Near you" style feed.
      final sources = _sourcesFor(intentSubType);
      final batches = await Future.wait(
        sources.map((s) => _fetchSource(s, _currentPage)),
      );

      final newItems = <FeedItem>[];
      var anyHasMore = false;
      for (final batch in batches) {
        newItems.addAll(batch.items);
        if (batch.hasMore) anyHasMore = true;
      }

      // Newest first — the backend sorts each list by createdAt desc but
      // once we merge across sources we must re-sort to preserve ordering.
      newItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (refresh) {
        _feedItems = newItems;
      } else {
        _feedItems.addAll(newItems);
      }

      _hasMore = anyHasMore;
      _currentPage += 1;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = NetworkUtils.getErrorMessage(e);
      debugPrint('[FeedProvider] Error loading feed: $_error');
      notifyListeners();
    }
  }

  // Apply filter
  void setIntentTypeFilter(IntentType? intentType) {
    _intentTypeFilter = intentType;
    _intentSubTypeFilter = null; // Clear subtype when setting type
    loadFeed(refresh: true, intentType: intentType);
  }

  void setIntentSubTypeFilter(IntentSubType? intentSubType) {
    _intentSubTypeFilter = intentSubType;
    _intentTypeFilter = null; // Clear type when setting subtype
    loadFeed(refresh: true, intentSubType: intentSubType);
  }

  void clearFilters() {
    _intentTypeFilter = null;
    _intentSubTypeFilter = null;
    loadFeed(refresh: true);
  }

  Future<void> loadMore() async {
    await loadFeed(
      intentType: _intentTypeFilter,
      intentSubType: _intentSubTypeFilter,
    );
  }

  Future<void> refresh() async {
    await Future.wait([
      loadFeed(
        refresh: true,
        intentType: _intentTypeFilter,
        intentSubType: _intentSubTypeFilter,
      ),
      loadRecentlyAdded(),
    ]);
  }

  /// Merged trade + gift + campaign listings, newest first (ignores Near-you filters).
  Future<void> loadRecentlyAdded() async {
    if (_isLoadingRecent) return;

    _isLoadingRecent = true;
    notifyListeners();

    try {
      const sources = [
        FeedSourceType.trade,
        FeedSourceType.gift,
        FeedSourceType.campaign,
      ];
      final batches = await Future.wait(
        sources.map((s) => _fetchSource(s, 1)),
      );

      final merged = <FeedItem>[];
      for (final batch in batches) {
        merged.addAll(batch.items);
      }
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _recentItems = merged.take(12).toList();
    } catch (e) {
      debugPrint('[FeedProvider] loadRecentlyAdded failed: $e');
    } finally {
      _isLoadingRecent = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Source selection + fetching
  // ---------------------------------------------------------------------

  List<FeedSourceType> _sourcesFor(IntentSubType? sub) {
    switch (sub) {
      case IntentSubType.trade:
        return [FeedSourceType.trade];
      case IntentSubType.give:
      case IntentSubType.request:
        return [FeedSourceType.gift];
      case IntentSubType.helpCampaign:
        return [FeedSourceType.campaign];
      case IntentSubType.none:
      case null:
        return [
          FeedSourceType.trade,
          FeedSourceType.gift,
          FeedSourceType.campaign,
        ];
    }
  }

  Future<_Batch> _fetchSource(FeedSourceType source, int page) async {
    final path = switch (source) {
      FeedSourceType.trade => '/v1/public/browse/trades',
      FeedSourceType.gift => '/v1/public/browse/gifts',
      FeedSourceType.campaign => '/v1/public/browse/campaigns',
      FeedSourceType.post => '/v1/public/browse/trades', // unused fallback
    };

    try {
      final resp = await _apiClient.get(
        path,
        queryParameters: {'page': '$page', 'size': '$_pageSize'},
      );
      final data = resp.data;
      if (data is! Map) return const _Batch(items: [], hasMore: false);
      final map = Map<String, dynamic>.from(data);
      final rawItems = (map['items'] as List?) ?? const [];
      final total = (map['total'] as num?)?.toInt() ?? rawItems.length;
      final items = rawItems
          .whereType<Map>()
          .map((e) => _mapItem(source, Map<String, dynamic>.from(e)))
          .whereType<FeedItem>()
          .toList();
      final hasMore = page * _pageSize < total;
      return _Batch(items: items, hasMore: hasMore);
    } catch (e) {
      // Don't let one failing source nuke the entire feed — return empty
      // and keep the rest of the batches in play. The top-level catch
      // still surfaces errors when ALL sources fail.
      debugPrint('[FeedProvider] $source fetch failed: $e');
      return const _Batch(items: [], hasMore: false);
    }
  }

  FeedItem? _mapItem(FeedSourceType source, Map<String, dynamic> raw) {
    try {
      switch (source) {
        case FeedSourceType.trade:
          return _mapTrade(raw);
        case FeedSourceType.gift:
          return _mapGift(raw);
        case FeedSourceType.campaign:
          return _mapCampaign(raw);
        case FeedSourceType.post:
          return null;
      }
    } catch (e) {
      debugPrint('[FeedProvider] map $source failed: $e');
      return null;
    }
  }

  FeedItem _mapTrade(Map<String, dynamic> t) {
    final owner = (t['owner'] as Map?) ?? const {};
    final profile = (owner['profile'] as Map?) ?? const {};
    return FeedItem(
      id: t['id']?.toString() ?? '',
      sourceType: FeedSourceType.trade,
      intentType: IntentType.offer,
      intentSubType: IntentSubType.trade,
      title: (t['title'] as String?) ?? 'Untitled trade',
      summary: (t['description'] as String?) ?? '',
      imageUrl: _firstMediaKey(t),
      location: t['location'] as String?,
      category: _readCategory(t),
      createdAt: _parseDate(t['createdAt']),
      author: FeedItemAuthor(
        id: owner['id']?.toString() ?? '',
        name: (profile['displayName'] as String?) ?? 'Member',
        avatar: profile['avatarKey'] as String?,
        averageRating: _readRating(t),
      ),
      status: (t['status'] as String?) ?? 'OPEN',
      metadata: t,
    );
  }

  FeedItem _mapGift(Map<String, dynamic> g) {
    final giver = (g['giver'] as Map?) ?? const {};
    final profile = (giver['profile'] as Map?) ?? const {};
    return FeedItem(
      id: g['id']?.toString() ?? '',
      sourceType: FeedSourceType.gift,
      intentType: IntentType.offer,
      intentSubType: IntentSubType.give,
      title: (g['title'] as String?) ?? 'Gift',
      summary: (g['description'] as String?) ?? '',
      imageUrl: _firstMediaKey(g),
      location: g['location'] as String?,
      category: _readCategory(g),
      createdAt: _parseDate(g['createdAt']),
      author: FeedItemAuthor(
        id: giver['id']?.toString() ?? '',
        name: (profile['displayName'] as String?) ?? 'Member',
        avatar: profile['avatarKey'] as String?,
        averageRating: _readRating(g),
      ),
      status: (g['status'] as String?) ?? 'AVAILABLE',
      metadata: g,
    );
  }

  FeedItem _mapCampaign(Map<String, dynamic> c) {
    final creator = (c['creator'] as Map?) ?? (c['founder'] as Map?) ?? (c['owner'] as Map?) ?? const {};
    final profile = (creator['profile'] as Map?) ?? const {};
    return FeedItem(
      id: c['id']?.toString() ?? '',
      sourceType: FeedSourceType.campaign,
      intentType: IntentType.ask,
      intentSubType: IntentSubType.helpCampaign,
      title: (c['title'] as String?) ?? 'Campaign',
      summary: (c['story'] as String?) ?? (c['description'] as String?) ?? '',
      // Prefer the first usable entry in `mediaKeys` (the same source
      // the campaign detail screen resolves from), and only fall back
      // to `thumbnailKey` if the campaign has no media uploaded at
      // all. The reverse priority caused sliders to silently render
      // placeholders whenever a thumbnail object was missing from
      // storage even though the original cover photo existed.
      imageUrl: _campaignImageKey(c),
      location: c['location'] as String?,
      category: _readCategory(c),
      createdAt: _parseDate(c['createdAt']),
      author: FeedItemAuthor(
        id: creator['id']?.toString() ?? '',
        name: (profile['displayName'] as String?) ?? 'Campaign',
        avatar: profile['avatarKey'] as String?,
        averageRating: _readRating(c),
      ),
      status: (c['status'] as String?) ?? 'ACTIVE',
      metadata: c,
    );
  }

  /// Pick the best image key for a campaign listing.
  ///
  /// Detail screens resolve campaign covers from `mediaKeys` and that
  /// flow is known to work, while `thumbnailKey` is frequently set to a
  /// derived key whose object never made it to storage (so the resolver
  /// 404s and the card silently falls back to the placeholder). To keep
  /// the slider visually in sync with the detail screen, we prefer the
  /// first non-empty entry in `mediaKeys` and only use `thumbnailKey`
  /// when the campaign has no media uploaded at all.
  String? _campaignImageKey(Map<String, dynamic> c) {
    final fromMedia = _firstMediaKey(c);
    if (fromMedia != null && fromMedia.isNotEmpty) return fromMedia;
    final thumb = c['thumbnailKey'];
    if (thumb is String && thumb.trim().isNotEmpty) return thumb;
    return null;
  }

  /// Pull the category off a raw Prisma entity. Trades/gifts use enum
  /// strings (e.g. `OTHERS`, `ELECTRONICS`), campaigns use a free-form
  /// string. We surface them verbatim and let the UI prettify them.
  String? _readCategory(Map<String, dynamic> raw) {
    final v = raw['category'] ?? raw['type'] ?? raw['sourceType'];
    if (v == null) return null;
    if (v is String && v.isNotEmpty) {
      final normalized = ListingCategoryParser.normalizeModuleLabel(v);
      if (normalized != 'unknown') return normalized;
      return v;
    }
    return v.toString();
  }

  /// Pull the precomputed owner rating that
  /// `PublicBrowseController.enrichWithOwnerRating` splices onto each
  /// listing. Falls back to null when the backend hasn't been deployed
  /// yet so the card just hides the stars instead of showing zeros.
  double? _readRating(Map<String, dynamic> raw) {
    final v = raw['ownerAverageRating'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Extract the first usable storage key from a record. The backend
  /// (see Prisma `Trade.mediaKeys`, `Gift.mediaKeys`, `Campaign.mediaKeys`)
  /// stores S3 keys as a `String[]`. `CachedMediaImage` accepts these
  /// keys and resolves them through `MediaResolver` to signed URLs, so
  /// we just need to surface the first non-empty entry. We fall back to
  /// a few alternative shapes in case any source ever inlines a URL.
  String? _firstMediaKey(Map<String, dynamic> raw) {
    // Preferred: mediaKeys: String[]
    final mk = raw['mediaKeys'];
    if (mk is List) {
      for (final v in mk) {
        if (v is String && v.isNotEmpty) return v;
        if (v is Map) {
          final key = v['key'] ?? v['url'] ?? v['mediaKey'];
          if (key is String && key.isNotEmpty) return key;
        }
      }
    }
    // Singular fallbacks used by some endpoints / older shapes.
    final single = raw['mediaKey'] ?? raw['imageKey'] ?? raw['imageUrl'];
    if (single is String && single.isNotEmpty) return single;
    return null;
  }

  DateTime _parseDate(Object? v) {
    if (v is String) {
      return DateTime.tryParse(v) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

class _Batch {
  final List<FeedItem> items;
  final bool hasMore;
  const _Batch({required this.items, required this.hasMore});
}
