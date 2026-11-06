import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/env_config.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/signup_location_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/network_error_message.dart';
import '../../feed/mappers/social_listing_mapper.dart';
import '../../feed/models/social_listing_card_data.dart';
import '../../search/services/search_api_service.dart';
import 'ask_understanding.dart';
import 'assistant_guidance.dart';
import 'bento_layout_adapter.dart';
import 'conversational_analytics.dart';
import 'conversational_ranker.dart';
import 'intent_apply_gate.dart';
import 'intent_module.dart';

/// Loads proximity-ranked trades, gifts, and campaigns for the conversational home.
class ConversationalFeedProvider extends ChangeNotifier {
  ConversationalFeedProvider({required this.isAuthed});

  final bool isAuthed;

  SearchApiService? _searchApi;
  int _requestGeneration = 0;
  static const int _pageSize = 20;

  List<RankedFeedItem> items = const [];
  List<RankedFeedItem> donationHeroes = const [];
  List<RankedFeedItem> tradeGiftItems = const [];

  bool isLoading = false;
  String? error;
  String? activeQuery;
  double? radiusKmUsed;
  bool liquidityExhausted = false;

  /// Optional AI / rules interpret summary shown above the bento grid.
  String? aiSummaryLine;
  bool intentPending = false;
  bool intentApplied = false;
  double intentConfidence = 0;
  List<String> intentCategories = const [];
  String? selectedCategory;
  bool showModuleHints = false;

  /// What to do and where to go. Rules guidance shows at once; model
  /// guidance replaces it when the intent call returns in time.
  AssistantGuidance? assistant;

  /// Earlier questions in this conversation. The latest question lives in
  /// [activeQuery] and the fields above.
  final List<ConversationTurn> history = [];

  /// User asked to see listings even though the guidance hid them.
  bool _forceListings = false;

  /// How the latest question was read: item, hub, overview, or other.
  AskUnderstanding? _ask;

  /// On-device guidance for the latest question, before any found-items reply.
  AssistantGuidance? _rulesGuidance;

  bool get showListings => _forceListings || (assistant?.showListings ?? true);

  /// Hub answers already link the newest listings, so no extra button.
  bool get canShowListingsAnyway =>
      !showListings && !(_ask?.wantsLatestPicks ?? false);

  bool get loadingPicks =>
      isLoading && !_forceListings && (_ask?.wantsLatestPicks ?? false);

  /// Starts a new turn. The previous answer stays in [history].
  Future<void> ask(String query) {
    _archiveCurrent();
    return search(query);
  }

  void _archiveCurrent() {
    final query = activeQuery?.trim() ?? '';
    if (query.isEmpty) return;
    if (history.length >= 12) history.removeAt(0);
    history.add(
      ConversationTurn(
        query: query,
        assistant: assistant,
        listings: items.map((item) => item.data).toList(),
        showListings: showListings,
        summaryLine: aiSummaryLine,
      ),
    );
  }

  Future<void> showListingsAnyway() async {
    final q = activeQuery;
    if (q == null || q.isEmpty) return;
    _forceListings = true;
    await search(q, skipAi: true);
  }

  String intentCohort = 'rules';
  String? _searchPlace;
  int? _lastIntentElapsedMs;
  bool _lastIntentCached = false;

  bool _keywordSettled = false;
  bool _intentFetchSettled = true;
  IntentModule? _resultModule;
  int? _intentLayoutGeneration;
  _StagedIntent? _stagedIntent;

  bool verifiedOnly = false;
  bool endingSoonOnly = false;
  bool within5KmOnly = false;
  int _page = 1;
  bool hasMore = false;
  int _totalCount = 0;

  int get totalCount => _totalCount;

  String get summaryLine {
    if (isLoading) return 'Searching near you…';
    if (error != null) return error!;
    if (items.isEmpty) {
      return activeQuery == null || activeQuery!.isEmpty
          ? 'Nothing nearby yet'
          : 'No matches for “$activeQuery”';
    }
    final radius = radiusKmUsed != null
        ? ' within ${radiusKmUsed!.toStringAsFixed(0)} km'
        : '';
    if (activeQuery != null && activeQuery!.isNotEmpty) {
      return '$totalCount matches for “$activeQuery”$radius';
    }
    return '$totalCount listings near you$radius';
  }

  Future<void> initialize() async {
    await _ensureApi();
    await loadIdleFeed();
  }

  Future<void> refresh() async {
    final q = activeQuery;
    if (q == null || q.isEmpty) {
      await loadIdleFeed();
    } else {
      await search(q, moduleBias: null);
    }
  }

  Future<void> loadIdleFeed() async {
    await _ensureApi();
    final gen = ++_requestGeneration;
    isLoading = true;
    error = null;
    activeQuery = null;
    _page = 1;
    notifyListeners();

    try {
      final geo = await _resolveGeo();
      final api = _searchApi!;

      final results = await Future.wait([
        isAuthed
            ? api.listTradesWithCascadingLiquidity(geo: geo, page: 1, size: 8)
            : api.listTradesPublicWithCascadingLiquidity(
                geo: geo,
                page: 1,
                size: 8,
              ),
        isAuthed
            ? api.listGiftsWithCascadingLiquidity(geo: geo, page: 1, size: 8)
            : api.listGiftsPublicWithCascadingLiquidity(
                geo: geo,
                page: 1,
                size: 8,
              ),
        isAuthed
            ? api.listCampaignsWithCascadingLiquidity(
                geo: geo,
                page: 1,
                size: 6,
              )
            : api.listCampaignsPublicWithCascadingLiquidity(
                geo: geo,
                page: 1,
                size: 6,
              ),
      ]);

      if (gen != _requestGeneration) return;

      final mapped = <SocialListingCardData>[];
      for (final cascade in results) {
        mapped.addAll(_mapPayload(cascade.payload));
      }

      radiusKmUsed = results
          .map((r) => r.radiusKmUsed)
          .whereType<double>()
          .fold<double?>(
            null,
            (prev, v) => prev == null ? v : (v > prev ? v : prev),
          );
      liquidityExhausted = results.every((r) => r.liquidityExhausted);

      _applyRanked(mapped, query: null);
      hasMore = mapped.length >= 8;
      _totalCount = mapped.length;
      isLoading = false;
      error = null;
      notifyListeners();
    } catch (e) {
      if (gen != _requestGeneration) return;
      isLoading = false;
      error = NetworkErrorMessage.forSearchLoad(e);
      items = const [];
      donationHeroes = const [];
      tradeGiftItems = const [];
      notifyListeners();
    }
  }

  Future<void> search(
    String query, {
    IntentModule? moduleBias,
    bool loadMore = false,
    bool skipAi = false,
    bool widenRadius = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      await loadIdleFeed();
      return;
    }

    await _ensureApi();
    final gen = ++_requestGeneration;
    final ask = AskUnderstanding.parse(trimmed);
    final searchText = ask.item ?? trimmed;
    if (!loadMore) {
      _ask = ask;
      isLoading = true;
      error = null;
      activeQuery = trimmed;
      _page = 1;
      if (!widenRadius) {
        radiusKmUsed = null;
        liquidityExhausted = false;
      }
      _keywordSettled = false;
      _stagedIntent = null;
      _intentLayoutGeneration = null;
      intentPending = !skipAi;
      _intentFetchSettled = skipAi;
      if (!skipAi) _resultModule = null;
      intentApplied = false;
      if (!skipAi) {
        aiSummaryLine = null;
        intentCategories = const [];
        selectedCategory = null;
        showModuleHints = false;
        intentConfidence = 0;
        assistant = AssistantRules.guide(trimmed);
        _rulesGuidance = assistant;
        _forceListings = false;
      } else if (moduleBias != null) {
        showModuleHints = false;
      }
      notifyListeners();
    } else {
      isLoading = true;
      notifyListeners();
    }

    if (!loadMore && !_forceListings && ask.wantsLatestPicks) {
      await _answerWithLatest(ask, gen);
      return;
    }

    try {
      final geo = await _resolveGeo();
      final page = loadMore ? _page + 1 : 1;
      final api = _searchApi!;
      Map<String, dynamic> response;

      if (!loadMore && !skipAi) {
        unawaited(_fetchIntent(trimmed, gen, widenRadius: widenRadius));
      } else if (!loadMore) {
        intentPending = false;
      }

      if (isAuthed) {
        response = await api.search(
          query: searchText,
          page: page,
          size: _pageSize,
        );
      } else {
        final responses = await Future.wait([
          api.listTradesPublic(
            query: searchText,
            geo: geo,
            page: page,
            size: _pageSize,
          ),
          api.listGiftsPublic(
            query: searchText,
            geo: geo,
            page: page,
            size: _pageSize,
          ),
          api.listCampaignsPublic(
            query: searchText,
            geo: geo,
            page: page,
            size: _pageSize,
          ),
        ]);
        response = _mergePublicResponses(responses, page);
      }

      if (gen != _requestGeneration) return;

      final batch = _mapPayload(response);
      final total = (response['total'] as num?)?.toInt() ?? batch.length;
      final totalPages = (response['totalPages'] as num?)?.toInt() ?? 1;
      hasMore = page < totalPages;

      if (_intentLayoutGeneration != gen) {
        if (loadMore && items.isNotEmpty) {
          final existingIds = items
              .map((e) => '${e.data.module.name}_${e.data.id}')
              .toSet();
          final merged = [
            ...items.map((e) => e.data),
            ...batch.where(
              (b) => !existingIds.contains('${b.module.name}_${b.id}'),
            ),
          ];
          _applyRanked(merged, query: searchText, moduleBias: moduleBias);
        } else {
          _applyRanked(batch, query: searchText, moduleBias: moduleBias);
        }
        _totalCount = total;
        _maybeDescribeFound();
      }

      _page = page;
      _keywordSettled = true;
      isLoading = false;
      error = null;
      notifyListeners();
      _maybeApplyStaged(gen);
      if (_maybeEncourageEmpty()) notifyListeners();
    } catch (e) {
      if (gen != _requestGeneration) return;
      isLoading = false;
      error = NetworkErrorMessage.forSearchLoad(e);
      if (!loadMore) {
        items = const [];
        donationHeroes = const [];
        tradeGiftItems = const [];
      }
      _keywordSettled = true;
      notifyListeners();
      _maybeApplyStaged(gen);
    }
  }

  /// A finished search with no gifts, trades, or campaigns gets a create
  /// suggestion that matches the query. Answers that already open a create
  /// screen, or that hid listings on purpose, stay as they are.
  bool _maybeEncourageEmpty() {
    if (!_keywordSettled ||
        !_intentFetchSettled ||
        isLoading ||
        error != null) {
      return false;
    }
    final query = activeQuery?.trim() ?? '';
    if (query.length < 2) return false;
    if (items.isNotEmpty || donationHeroes.isNotEmpty) return false;
    final current = assistant;
    if (current != null &&
        (current.encouragesCreate || !current.showListings)) {
      return false;
    }
    assistant = AssistantRules.forEmptyResults(
      query,
      prefer: _resultModule,
      item: _ask?.item,
    );
    unawaited(_attachAvailable(_requestGeneration));
    return true;
  }

  /// Nothing matched: link one trade, gift and campaign that are open now.
  Future<void> _attachAvailable(int gen) async {
    final found = await Future.wait([
      _latest(SocialListingModule.trade, 1),
      _latest(SocialListingModule.gift, 1),
      _latest(SocialListingModule.donation, 1),
    ]);
    if (gen != _requestGeneration) return;
    final picks = found.expand((list) => list).toList();
    final current = assistant;
    if (picks.isEmpty || current == null || current.picks.isNotEmpty) return;
    assistant = current.copyWith(picks: picks);
    notifyListeners();
  }

  /// "i need a car" with results: say how many and where, unless the model
  /// already answered or the guidance hid listings on purpose.
  void _maybeDescribeFound() {
    final item = _ask?.item;
    if (item == null || items.isEmpty) return;
    final current = assistant;
    if (current != null && (current.fromAi || !current.showListings)) return;
    assistant = AssistantRules.forFound(
      item,
      items.map((e) => e.data).toList(),
      base: _rulesGuidance,
    );
  }

  /// Hub questions ("i want to donate", "what else can i do") get a reply
  /// with the newest listings as links instead of a keyword search.
  Future<void> _answerWithLatest(AskUnderstanding ask, int gen) async {
    intentPending = false;
    _intentFetchSettled = true;
    _keywordSettled = true;
    items = const [];
    donationHeroes = const [];
    tradeGiftItems = const [];
    hasMore = false;
    _totalCount = 0;
    assistant = AssistantRules.forHub(ask);
    notifyListeners();

    final picks = await _latestPicks(ask);
    if (gen != _requestGeneration) return;
    isLoading = false;
    assistant = AssistantRules.forHub(ask, picks: picks);
    notifyListeners();
  }

  Future<List<SocialListingCardData>> _latestPicks(AskUnderstanding ask) async {
    if (ask.kind == AskKind.overview) {
      final one = await Future.wait([
        _latest(SocialListingModule.gift, 1),
        _latest(SocialListingModule.trade, 1),
        _latest(SocialListingModule.donation, 1),
      ]);
      return one.expand((list) => list).toList();
    }
    switch (ask.hub) {
      case IntentModule.donation:
        return _latest(SocialListingModule.donation, 3);
      case IntentModule.gift:
        return _latest(SocialListingModule.gift, 3);
      default:
        return _latest(SocialListingModule.trade, 3);
    }
  }

  Future<List<SocialListingCardData>> _latest(
    SocialListingModule module,
    int count,
  ) async {
    final api = _searchApi!;
    try {
      final Map<String, dynamic> response;
      final String type;
      switch (module) {
        case SocialListingModule.trade:
          response = await api.listTradesPublic(size: count);
          type = 'trade';
        case SocialListingModule.gift:
          response = await api.listGiftsPublic(size: count);
          type = 'gift';
        case SocialListingModule.donation:
          response = await api.listCampaignsPublic(size: count);
          type = 'campaign';
      }
      final raw = (response['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => {...Map<String, dynamic>.from(item), 'type': type})
          .toList();
      return _mapPayload({'items': raw}).take(count).toList();
    } catch (_) {
      return const [];
    }
  }

  IntentModule? _moduleFromInterpret(Object? raw) {
    if (raw is! Map) return null;
    final layout = raw['layout'];
    final primary = layout is Map ? layout['primary']?.toString() : null;
    final fromPrimary = _hubModule(primary);
    if (fromPrimary != null) return fromPrimary;
    final modules = raw['modules'];
    if (modules is! List) return null;
    for (final module in modules) {
      final hub = _hubModule(module?.toString());
      if (hub != null) return hub;
    }
    return null;
  }

  IntentModule? _hubModule(String? wire) {
    switch (wire) {
      case 'gift':
        return IntentModule.gift;
      case 'trade':
        return IntentModule.trade;
      case 'campaign':
        return IntentModule.donation;
      default:
        return null;
    }
  }

  Future<void> loadMore() async {
    final q = activeQuery;
    if (intentApplied || q == null || q.isEmpty || !hasMore || isLoading) {
      return;
    }
    await search(q, loadMore: true);
  }

  Future<void> expandSearchRadius() async {
    ConversationalAnalytics.radiusExpanded(radiusKm: 500);
    radiusKmUsed = 500;
    liquidityExhausted = false;
    final q = activeQuery;
    if (q == null || q.isEmpty) {
      await refresh();
      return;
    }
    await search(q, widenRadius: true);
  }

  void setVerifiedOnly(bool value) {
    verifiedOnly = value;
    _reapplyFilters();
  }

  void setEndingSoonOnly(bool value) {
    endingSoonOnly = value;
    _reapplyFilters();
  }

  void setWithin5KmOnly(bool value) {
    within5KmOnly = value;
    _reapplyFilters();
  }

  Future<void> refineCategory(String category) async {
    final query = activeQuery;
    if (query == null || query.isEmpty) return;
    await _ensureApi();
    final gen = ++_requestGeneration;
    selectedCategory = category;
    _stagedIntent = null;
    _keywordSettled = true;
    intentPending = true;
    isLoading = true;
    notifyListeners();
    try {
      final geo = await _resolveGeo();
      final payload = await _searchApi!.searchIntent(
        query: query,
        geo: geo,
        categories: [category],
        skipAi: true,
      );
      if (gen != _requestGeneration) return;
      if (payload == null) {
        intentPending = false;
        isLoading = false;
        _intentFetchSettled = true;
        _maybeEncourageEmpty();
        ConversationalAnalytics.aiIntentFallback(reason: 'refine_failed');
        notifyListeners();
        return;
      }
      _applyIntentPayload(payload);
      _resultModule =
          _moduleFromInterpret(payload['interpret']) ?? _resultModule;
      _intentLayoutGeneration = gen;
      intentApplied = true;
      intentPending = false;
      isLoading = false;
      _intentFetchSettled = true;
      _maybeEncourageEmpty();
      notifyListeners();
    } catch (_) {
      if (gen != _requestGeneration) return;
      intentPending = false;
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearIntent() async {
    ConversationalAnalytics.aiIntentCleared();
    _postIntentEvent('ai_intent_cleared');
    aiSummaryLine = null;
    intentApplied = false;
    intentPending = false;
    intentConfidence = 0;
    intentCategories = const [];
    selectedCategory = null;
    showModuleHints = false;
    assistant = null;
    _ask = null;
    _rulesGuidance = null;
    _forceListings = false;
    _stagedIntent = null;
    history.clear();
    await loadIdleFeed();
  }

  Future<void> _fetchIntent(
    String query,
    int gen, {
    bool widenRadius = false,
  }) async {
    if (!await FeatureFlags.enableAiSearch) {
      if (gen != _requestGeneration) return;
      intentPending = false;
      _intentFetchSettled = true;
      _maybeEncourageEmpty();
      notifyListeners();
      return;
    }
    final started = DateTime.now();
    try {
      final api = _searchApi;
      if (api == null) {
        intentPending = false;
        _intentFetchSettled = true;
        _maybeEncourageEmpty();
        notifyListeners();
        return;
      }
      final geo = await _resolveGeo();
      final payload = await api
          .searchIntent(query: query, geo: geo, widenRadius: widenRadius)
          .timeout(const Duration(milliseconds: IntentApplyGate.cutoffMs));
      if (gen != _requestGeneration) return;
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      if (payload == null) {
        intentPending = false;
        _intentFetchSettled = true;
        showModuleHints = true;
        ConversationalAnalytics.aiIntentFallback(reason: 'error');
        _postIntentEvent('ai_intent_fallback', reason: 'error');
        _maybeEncourageEmpty();
        notifyListeners();
        return;
      }
      _resultModule =
          _moduleFromInterpret(payload['interpret']) ?? _resultModule;
      _stagedIntent = _StagedIntent(
        payload: payload,
        elapsedMs: elapsed,
        generation: gen,
      );
      _intentFetchSettled = true;
      _maybeApplyStaged(gen);
      if (_maybeEncourageEmpty()) notifyListeners();
    } catch (_) {
      if (gen != _requestGeneration) return;
      intentPending = false;
      _intentFetchSettled = true;
      showModuleHints = true;
      ConversationalAnalytics.aiIntentFallback(reason: 'error');
      _postIntentEvent('ai_intent_fallback', reason: 'error');
      _maybeEncourageEmpty();
      notifyListeners();
    }
  }

  void _maybeApplyStaged(int gen) {
    if (gen != _requestGeneration || !_keywordSettled) return;
    final staged = _stagedIntent;
    if (staged == null || staged.generation != gen) {
      if (intentPending && _intentFetchSettled) {
        intentPending = false;
        _maybeEncourageEmpty();
        notifyListeners();
      }
      return;
    }

    final interpret = staged.payload['interpret'];
    final confidence = interpret is Map
        ? (interpret['confidence'] as num?)?.toDouble() ?? 0
        : 0.0;
    if (interpret is Map && interpret['cohort'] == 'ai') {
      intentCohort = 'ai';
    } else if (interpret is Map) {
      intentCohort = 'rules';
    }
    _lastIntentElapsedMs = staged.elapsedMs;
    _lastIntentCached = interpret is Map && interpret['cached'] == true;
    final modelGuidance = interpret is Map
        ? AssistantGuidance.fromJson(interpret['assistant'])
        : null;
    if (modelGuidance != null) assistant = modelGuidance;
    _resultModule = _moduleFromInterpret(interpret) ?? _resultModule;
    final apply = IntentApplyGate.shouldApply(
      flagEnabled: true,
      requestGeneration: staged.generation,
      currentGeneration: _requestGeneration,
      elapsedMs: staged.elapsedMs,
      confidence: confidence,
    );
    if (!apply) {
      intentPending = false;
      intentApplied = false;
      aiSummaryLine = null;
      showModuleHints = true;
      final reason = staged.elapsedMs > IntentApplyGate.cutoffMs
          ? 'late'
          : 'low_confidence';
      ConversationalAnalytics.aiIntentFallback(reason: reason);
      _postIntentEvent('ai_intent_fallback', reason: reason);
      _maybeEncourageEmpty();
      notifyListeners();
      return;
    }

    _applyIntentPayload(staged.payload);
    _maybeDescribeFound();
    _intentLayoutGeneration = gen;
    intentPending = false;
    intentApplied = true;
    showModuleHints = false;
    error = null;
    isLoading = false;
    ConversationalAnalytics.aiIntentShown(
      label: aiSummaryLine ?? '',
      confidence: intentConfidence,
      results: items.length,
    );
    _postIntentEvent(
      'ai_intent_shown',
      latencyMs: _lastIntentElapsedMs,
      cached: _lastIntentCached,
    );
    _maybeEncourageEmpty();
    notifyListeners();
  }

  void _applyIntentPayload(Map<String, dynamic> payload) {
    final interpret = payload['interpret'] is Map
        ? Map<String, dynamic>.from(payload['interpret'] as Map)
        : <String, dynamic>{};
    final results = payload['results'];
    final grouped = <String, List<SocialListingCardData>>{};
    if (results is Map) {
      for (final key in ['gift', 'trade', 'campaign']) {
        final raw = results[key];
        grouped[key] = raw is List ? _mapPayload({'items': raw}) : const [];
      }
    }
    if (interpret['verifiedOnly'] == true) {
      verifiedOnly = true;
      for (final key in grouped.keys.toList()) {
        grouped[key] = grouped[key]!
            .where(
              (item) =>
                  item.module != SocialListingModule.donation ||
                  item.isVerified,
            )
            .toList();
      }
    }

    final ranked = BentoLayoutAdapter.adapt(
      interpret: interpret,
      grouped: grouped,
    );
    items = ranked;
    donationHeroes = ranked
        .where(
          (e) =>
              e.data.module == SocialListingModule.donation &&
              e.size == BentoTileSize.hero,
        )
        .toList();
    tradeGiftItems = ranked
        .where((e) => e.data.module != SocialListingModule.donation)
        .toList();

    final label = interpret['intentLabel']?.toString().trim();
    final hint = interpret['locationHint']?.toString();
    intentConfidence = (interpret['confidence'] as num?)?.toDouble() ?? 0;
    intentCategories =
        (interpret['categories'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    final near = hint == 'near me' || hint == 'around campus';
    final place = _searchPlace;
    aiSummaryLine = label == null || label.isEmpty
        ? null
        : near && place != null
        ? 'Showing: $label near $place'
        : near
        ? 'Showing: $label near you'
        : 'Showing: $label';
    final radius = payload['radiusKm'];
    if (radius is num) radiusKmUsed = radius.toDouble();
    liquidityExhausted = payload['liquidityExhausted'] == true;
    hasMore = false;
    if (interpret['cohort'] == 'ai') intentCohort = 'ai';
    _totalCount = ranked.length;
  }

  void trackIntentEvent(
    String event, {
    String? module,
    String? size,
    String? kind,
    String? reason,
    int? latencyMs,
    bool cached = false,
  }) {
    if (activeQuery == null || activeQuery!.isEmpty) return;
    _postIntentEvent(
      event,
      module: module,
      size: size,
      kind: kind,
      reason: reason,
      latencyMs: latencyMs,
      cached: cached,
    );
  }

  void _postIntentEvent(
    String event, {
    String? module,
    String? size,
    String? kind,
    String? reason,
    int? latencyMs,
    bool cached = false,
  }) {
    final api = _searchApi;
    if (api == null) return;
    unawaited(
      api.trackIntentEvent(
        event: event,
        cohort: intentCohort,
        module: module,
        size: size,
        kind: kind,
        reason: reason,
        latencyMs: latencyMs,
        cached: cached,
      ),
    );
  }

  void _reapplyFilters() {
    final base = items.map((e) => e.data).toList();
    _applyRanked(base, query: activeQuery);
    notifyListeners();
  }

  void _applyRanked(
    List<SocialListingCardData> mapped, {
    String? query,
    IntentModule? moduleBias,
  }) {
    var list = mapped;
    if (verifiedOnly) {
      list = list
          .where(
            (e) => e.module != SocialListingModule.donation || e.isVerified,
          )
          .toList();
    }
    if (endingSoonOnly) {
      list = list.where((e) {
        if (e.module != SocialListingModule.donation) return true;
        final progress = e.progress;
        return progress != null && progress < 0.35;
      }).toList();
    }
    if (within5KmOnly) {
      list = list.where((e) {
        final raw = e.raw;
        final d = raw?['distanceKm'];
        if (d is num) return d <= 5;
        return true;
      }).toList();
    }

    final ranked = ConversationalRanker.rankAndSize(
      items: list,
      query: query,
      moduleBias: moduleBias,
      verifiedOnly: verifiedOnly,
    );

    items = ranked;
    donationHeroes = ranked
        .where(
          (e) =>
              e.data.module == SocialListingModule.donation &&
              e.size == BentoTileSize.hero,
        )
        .toList();
    tradeGiftItems = ranked
        .where((e) => e.data.module != SocialListingModule.donation)
        .toList();
  }

  Future<void> _ensureApi() async {
    if (_searchApi != null) return;
    final baseUrl = await EnvConfig.getBaseUrl();
    _searchApi = SearchApiService(
      ApiClient(baseUrl, const FlutterSecureStorage()),
    );
  }

  Future<ListingGeoQuery?> _resolveGeo() async {
    final place = await SignupLocationService.resolveForAuth();
    _searchPlace = _cityFrom(place);
    final pos = await LocationService.instance.getCachedPositionOnly();
    if (pos != null) {
      return ListingGeoQuery(
        lat: pos.latitude,
        lng: pos.longitude,
        radiusKm: radiusKmUsed ?? 50,
        locationLabel: place,
      );
    }
    if (place != null) {
      return ListingGeoQuery(locationLabel: place);
    }
    return null;
  }

  String? _cityFrom(String? place) {
    final first = place?.split(',').first.trim();
    if (first == null || first.length < 2) return null;
    return first;
  }

  List<SocialListingCardData> _mapPayload(Map<String, dynamic> payload) {
    final rawItems = payload['items'];
    if (rawItems is! List) return const [];
    final out = <SocialListingCardData>[];
    for (final item in rawItems) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final card = SocialListingMapper.fromSearchItemMap(map);
      if (card != null) out.add(card);
    }
    return out;
  }

  Map<String, dynamic> _mergePublicResponses(
    List<Map<String, dynamic>> responses,
    int page,
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
    final merged = [...trades, ...gifts, ...campaigns];
    final tradesTotal = (responses[0]['total'] as num?)?.toInt() ?? 0;
    final giftsTotal = (responses[1]['total'] as num?)?.toInt() ?? 0;
    final campaignsTotal = (responses[2]['total'] as num?)?.toInt() ?? 0;
    final total = tradesTotal + giftsTotal + campaignsTotal;
    final size = _pageSize;
    final hasMore =
        tradesTotal > page * size ||
        giftsTotal > page * size ||
        campaignsTotal > page * size;
    return {
      'items': merged,
      'total': total,
      'totalPages': hasMore ? page + 1 : page,
    };
  }
}

/// One finished question in the home conversation.
class ConversationTurn {
  final String query;
  final AssistantGuidance? assistant;
  final List<SocialListingCardData> listings;
  final bool showListings;
  final String? summaryLine;

  const ConversationTurn({
    required this.query,
    required this.assistant,
    required this.listings,
    required this.showListings,
    required this.summaryLine,
  });
}

class _StagedIntent {
  final Map<String, dynamic> payload;
  final int elapsedMs;
  final int generation;

  _StagedIntent({
    required this.payload,
    required this.elapsedMs,
    required this.generation,
  });
}
