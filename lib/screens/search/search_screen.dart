import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/borderless_input_decoration.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bybata_loading_indicator.dart';
import '../../core/api/api_client.dart';
import '../../core/config/env_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/providers/auth_provider.dart';
import '../../features/search/services/search_api_service.dart';
import '../../features/search/widgets/ecosystem_seeding_portal.dart';
import '../../features/feed/mappers/social_listing_mapper.dart';
import '../../features/feed/models/social_listing_card_data.dart';
import '../../features/feed/widgets/social_listing_card.dart';
import '../../features/search/utils/search_item_view_data.dart';
import '../../core/utils/media_file_cache.dart';
import '../../features/trade/models/trade_models.dart' as trade_models;
import '../../features/donations/models/donation_models.dart' as donation_models;
import '../../features/community/screens/community_hub_screen.dart';
import '../../features/profile/screens/user_profile_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/utils/network_error_message.dart';
import '../../core/widgets/ad_placement_section.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/location_service.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

enum _SearchSortOption {
  newest('Newest first'),
  oldest('Oldest first'),
  titleAsc('Title A–Z'),
  titleDesc('Title Z–A');

  const _SearchSortOption(this.label);
  final String label;
}

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialCategory;

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialCategory,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  static const int _discoveryPageSize = 40;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _recentSearches = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _rawResults = [];
  List<Map<String, dynamic>> _searchSuggestions = [];
  _SearchSortOption _sortOption = _SearchSortOption.newest;
  String? _locationFilter;
  Position? _nearbyPosition;
  static const double _nearbyRadiusKm = 50;
  bool _isLoading = false;
  bool _isLoadingSuggestions = false;
  String? _errorMessage;
  int _totalResults = 0;
  int _currentPage = 1;
  bool _hasMore = false;
  bool _liquidityExhausted = false;
  Timer? _debounceTimer;
  SearchApiService? _searchApiService;
  final ScrollController _resultsScrollController = ScrollController();
  double _lastResultsScrollOffset = 0;
  
  final List<String> _categories = ['All', 'Trades', 'Gifts', 'Donations', 'Communities', 'Users'];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _isLoading = true;

    final initialQuery = widget.initialQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
      _searchQuery = initialQuery;
    }
    if (widget.initialCategory != null &&
        _categories.contains(widget.initialCategory)) {
      _selectedCategory = widget.initialCategory!;
    }

    _initializeApiService();
    _loadRecentSearches();
    _searchController.addListener(_onSearchChanged);
    
    _fadeController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _fadeController.forward();
    _resultsScrollController.addListener(_onResultsScroll);
  }

  void _onResultsScroll() {
    ListingVideoPrefetch.prefetchForScroll(
      scrollOffset: _resultsScrollController.offset,
      lastScrollOffset: _lastResultsScrollOffset,
      items: _searchResults,
      estimatedItemExtent: 340,
    );
    _lastResultsScrollOffset = _resultsScrollController.offset;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _resultsScrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Widget _build3DContainer({required Widget child, double radius = 24, EdgeInsets? padding}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark 
                ? Color(0xFF1E1A28).withValues(alpha: 0.65) 
                : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildRecessedInput({required TextEditingController controller, required FocusNode focusNode, required String hint}) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15101F) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface),
        decoration: BorderlessInputDecoration.search(
          hintText: hint,
          prefixIcon: Icon(
            Icons.search_rounded,
            color: scheme.onSurface.withValues(alpha: 0.4),
            size: 22,
          ),
          suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _searchResults = [];
                    _rawResults = [];
                    _searchSuggestions = [];
                  });
                  if (_selectedCategory == 'All') {
                    _loadAllItems();
                  } else {
                    _loadCategoryItems(category: _selectedCategory);
                  }
                },
              )
            : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onSubmitted: (value) => _performSearch(value),
      ),
    );
  }

  Widget _buildTactileChip(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor 
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected 
                ? Colors.transparent 
                : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  bool get _isAuthed {
    if (!mounted) return false;
    return Provider.of<AuthProvider>(context, listen: false).isAuthenticated;
  }

  bool get _hasActiveFilters =>
      (_locationFilter?.trim().isNotEmpty ?? false) ||
      _sortOption != _SearchSortOption.newest;

  String? get _locationQuery {
    final v = _locationFilter?.trim();
    return (v != null && v.isNotEmpty) ? v : null;
  }

  ListingGeoQuery? get _listingGeo {
    if (_nearbyPosition != null) {
      return ListingGeoQuery(
        lat: _nearbyPosition!.latitude,
        lng: _nearbyPosition!.longitude,
        radiusKm: _nearbyRadiusKm,
        locationLabel: _locationQuery,
      );
    }
    if (_locationQuery != null) {
      return ListingGeoQuery(locationLabel: _locationQuery);
    }
    return null;
  }

  void _commitResults({
    required List<Map<String, dynamic>> items,
    required int apiTotal,
    required bool apiHasMore,
    required bool loadMore,
    required int page,
  }) {
    if (!mounted) return;
    if (!loadMore) {
      _rawResults = List<Map<String, dynamic>>.from(items);
      _currentPage = page;
    } else {
      _rawResults = [..._rawResults, ...items];
      _currentPage = page;
    }
    final display = _filterAndSortResults(_rawResults);
    setState(() {
      _searchResults = display;
      _totalResults = _hasActiveFilters ? display.length : apiTotal;
      _hasMore = _hasActiveFilters ? false : apiHasMore;
      _isLoading = false;
      _errorMessage = null;
      if (display.isNotEmpty) _liquidityExhausted = false;
    });
    SearchItemViewData.warmPreviewMedia(display);
    if (!loadMore) {
      _lastResultsScrollOffset = 0;
      if (_resultsScrollController.hasClients) {
        _resultsScrollController.jumpTo(0);
      }
      ListingVideoPrefetch.prefetchItemWindow(
        items: display,
        anchorIndex: 0,
        ahead: 2,
        behind: 0,
      );
    }
  }

  Future<CascadingLiquidityResult> _fetchTradesCascade({
    required bool useAuthed,
    required int page,
    required int size,
    ListingGeoQuery? geo,
  }) {
    final useCascade = geo?.lat != null && geo?.lng != null;
    if (!useCascade) {
      return (useAuthed
              ? _searchApiService!.listTrades(page: page, size: size, geo: geo)
              : _searchApiService!.listTradesPublic(page: page, size: size, geo: geo))
          .then(
        (payload) => CascadingLiquidityResult(
          payload: payload,
          radiusKmUsed: geo?.radiusKm,
          liquidityExhausted: false,
        ),
      );
    }
    return useAuthed
        ? _searchApiService!.listTradesWithCascadingLiquidity(
            geo: geo, page: page, size: size)
        : _searchApiService!.listTradesPublicWithCascadingLiquidity(
            geo: geo, page: page, size: size);
  }

  Future<CascadingLiquidityResult> _fetchGiftsCascade({
    required bool useAuthed,
    required int page,
    required int size,
    ListingGeoQuery? geo,
  }) {
    final useCascade = geo?.lat != null && geo?.lng != null;
    if (!useCascade) {
      return (useAuthed
              ? _searchApiService!.listGifts(page: page, size: size, geo: geo)
              : _searchApiService!.listGiftsPublic(page: page, size: size, geo: geo))
          .then(
        (payload) => CascadingLiquidityResult(
          payload: payload,
          radiusKmUsed: geo?.radiusKm,
          liquidityExhausted: false,
        ),
      );
    }
    return useAuthed
        ? _searchApiService!.listGiftsWithCascadingLiquidity(
            geo: geo, page: page, size: size)
        : _searchApiService!.listGiftsPublicWithCascadingLiquidity(
            geo: geo, page: page, size: size);
  }

  Future<CascadingLiquidityResult> _fetchCampaignsCascade({
    required bool useAuthed,
    required int page,
    required int size,
    ListingGeoQuery? geo,
  }) {
    final useCascade = geo?.lat != null && geo?.lng != null;
    if (!useCascade) {
      return (useAuthed
              ? _searchApiService!.listCampaigns(page: page, size: size, geo: geo)
              : _searchApiService!.listCampaignsPublic(page: page, size: size, geo: geo))
          .then(
        (payload) => CascadingLiquidityResult(
          payload: payload,
          radiusKmUsed: geo?.radiusKm,
          liquidityExhausted: false,
        ),
      );
    }
    return useAuthed
        ? _searchApiService!.listCampaignsWithCascadingLiquidity(
            geo: geo, page: page, size: size)
        : _searchApiService!.listCampaignsPublicWithCascadingLiquidity(
            geo: geo, page: page, size: size);
  }

  void _reloadCurrentQuery() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _performSearch(query);
    } else if (_selectedCategory == 'All') {
      _loadAllItems();
    } else {
      _loadCategoryItems(category: _selectedCategory);
    }
  }

  Future<void> _onRefresh() async {
    if (_searchApiService == null) return;
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      await _performSearch(query);
    } else if (_selectedCategory == 'All') {
      await _loadAllItems();
    } else {
      await _loadCategoryItems(category: _selectedCategory);
    }
  }

  List<Map<String, dynamic>> _filterAndSortResults(List<Map<String, dynamic>> items) {
    var list = List<Map<String, dynamic>>.from(items);
    // Location filtering is handled server-side when [_listingGeo] is set.
    // Only apply a local text fallback for manual city entry without GPS.
    if (_nearbyPosition == null) {
      final loc = _locationQuery;
      if (loc != null) {
        final tokens = loc
            .split(RegExp(r'[,|/]+'))
            .expand((part) => part.trim().toLowerCase().split(RegExp(r'\s+')))
            .where((t) => t.length >= 3)
            .toList();
        list = list.where((item) {
          final type = _normalizeResultType(item['type']?.toString() ?? '');
          if (type == 'user') return true;
          final itemLoc = (item['location'] ?? '').toString().toLowerCase();
          if (itemLoc.isEmpty) return false;
          return tokens.any((t) => itemLoc.contains(t));
        }).toList();
      }
    }

    list.sort((a, b) {
      if (_nearbyPosition != null) {
        final da = (a['distanceMeters'] as num?)?.toDouble() ?? double.infinity;
        final db = (b['distanceMeters'] as num?)?.toDouble() ?? double.infinity;
        if (da != db) return da.compareTo(db);
      }
      switch (_sortOption) {
        case _SearchSortOption.oldest:
          return _compareByDate(a, b, ascending: true);
        case _SearchSortOption.titleAsc:
          return _compareByTitle(a, b, ascending: true);
        case _SearchSortOption.titleDesc:
          return _compareByTitle(a, b, ascending: false);
        case _SearchSortOption.newest:
          return _compareByDate(a, b, ascending: false);
      }
    });
    return list;
  }

  int _compareByDate(Map<String, dynamic> a, Map<String, dynamic> b, {required bool ascending}) {
    final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return ascending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
  }

  int _compareByTitle(Map<String, dynamic> a, Map<String, dynamic> b, {required bool ascending}) {
    final typeA = a['type']?.toString() ?? '';
    final typeB = b['type']?.toString() ?? '';
    final titleA = _getResultTitle(a, typeA).toLowerCase();
    final titleB = _getResultTitle(b, typeB).toLowerCase();
    return ascending ? titleA.compareTo(titleB) : titleB.compareTo(titleA);
  }

  Future<void> _initializeApiService() async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final secureStorage = const FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, secureStorage);
      _searchApiService = SearchApiService(apiClient);
      if (!mounted) return;
      final query = _searchController.text.trim();
      if (query.length >= 2) {
        _performSearch(query);
      } else if (_selectedCategory == 'All' && query.isEmpty) {
        _loadAllItems();
      }
    } catch (e) {
      setState(() { _errorMessage = NetworkErrorMessage.forSearchLoad(e); });
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recent = prefs.getStringList('recent_searches') ?? [];
      setState(() { _recentSearches = recent; });
    } catch (e) {}
  }

  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_searches', _recentSearches);
    } catch (e) {}
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.length >= 2 && _searchApiService != null) {
        _loadSearchSuggestions(query);
        _performSearch(query);
      } else if (_selectedCategory == 'All' && query.isEmpty) {
        _loadAllItems();
      } else if (query.isEmpty) {
        _loadCategoryItems(category: _selectedCategory);
      } else {
        setState(() {
          _searchSuggestions = [];
          _searchResults = [];
          _totalResults = 0;
          _hasMore = false;
          _searchQuery = query;
        });
      }
    });
  }

  Future<void> _loadAllItems({bool loadMore = false}) async {
    if (_searchApiService == null) return;
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
        _searchQuery = '';
      });
    } else {
      setState(() { _isLoading = true; });
    }

    try {
      final page = loadMore ? _currentPage + 1 : 1;
      final size = _discoveryPageSize;
      final useAuthed = _isAuthed;
      final geo = _listingGeo;
      final cascadeResults = await Future.wait([
        _fetchTradesCascade(useAuthed: useAuthed, page: page, size: size, geo: geo),
        _fetchGiftsCascade(useAuthed: useAuthed, page: page, size: size, geo: geo),
        _fetchCampaignsCascade(useAuthed: useAuthed, page: page, size: size, geo: geo),
      ]);

      final responses = cascadeResults.map((r) => r.payload).toList();
      final exhausted = cascadeResults.every((r) => r.liquidityExhausted);

      final trades = (responses[0]['items'] as List? ?? [])
          .map((item) => {...item as Map<String, dynamic>, 'type': 'trade'})
          .toList();
      final gifts = (responses[1]['items'] as List? ?? [])
          .map((item) => {...item as Map<String, dynamic>, 'type': 'gift'})
          .toList();
      final campaigns = (responses[2]['items'] as List? ?? [])
          .map((item) => {...item as Map<String, dynamic>, 'type': 'campaign'})
          .toList();

      final combined = [...trades, ...gifts, ...campaigns];

      final tradesTotal = (responses[0]['total'] as num?)?.toInt() ?? 0;
      final giftsTotal = (responses[1]['total'] as num?)?.toInt() ?? 0;
      final campaignsTotal = (responses[2]['total'] as num?)?.toInt() ?? 0;
      final total = tradesTotal + giftsTotal + campaignsTotal;
      final hasMore = tradesTotal > page * size ||
          giftsTotal > page * size ||
          campaignsTotal > page * size;

      _commitResults(
        items: combined,
        apiTotal: total,
        apiHasMore: hasMore,
        loadMore: loadMore,
        page: page,
      );
      if (mounted) {
        setState(() => _liquidityExhausted = exhausted && combined.isEmpty);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = NetworkErrorMessage.forSearchLoad(e);
        if (!loadMore) {
          _searchResults = [];
          _rawResults = [];
          _totalResults = 0;
          _hasMore = false;
        }
      });
    }
  }

  Future<void> _loadCategoryItems({required String category, bool loadMore = false}) async {
    if (_searchApiService == null) return;
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
        _searchQuery = '';
      });
    } else {
      setState(() { _isLoading = true; });
    }

    try {
      final page = loadMore ? _currentPage + 1 : 1;
      final size = _discoveryPageSize;
      final lower = category.toLowerCase();
      final useAuthed = _isAuthed;
      final geo = _listingGeo;
      Map<String, dynamic> response;
      bool liquidityExhausted = false;

      switch (lower) {
        case 'trades': {
          final cascade = await _fetchTradesCascade(
            useAuthed: useAuthed,
            page: page,
            size: size,
            geo: geo,
          );
          response = cascade.payload;
          liquidityExhausted = cascade.liquidityExhausted;
          break;
        }
        case 'gifts': {
          final cascade = await _fetchGiftsCascade(
            useAuthed: useAuthed,
            page: page,
            size: size,
            geo: geo,
          );
          response = cascade.payload;
          liquidityExhausted = cascade.liquidityExhausted;
          break;
        }
        case 'donations': {
          final cascade = await _fetchCampaignsCascade(
            useAuthed: useAuthed,
            page: page,
            size: size,
            geo: geo,
          );
          response = cascade.payload;
          liquidityExhausted = cascade.liquidityExhausted;
          break;
        }
        case 'communities':
          response = useAuthed
              ? await _searchApiService!.listCommunities(page: page, size: size)
              : await _searchApiService!.listCommunitiesPublic(page: page, size: size);
          break;
        case 'users':
          if (!useAuthed) {
            response = const {'items': [], 'total': 0, 'totalPages': 0};
          } else {
            response = await _searchApiService!.listUsers(page: page, size: size);
          }
          break;
        default:
          response = useAuthed
              ? await _searchApiService!.search(
                  query: '',
                  type: _apiTypeForCategory(category),
                  page: page,
                  size: size,
                )
              : const {'items': [], 'total': 0, 'totalPages': 0};
      }

      final items = (response['items'] as List? ?? [])
          .map((item) => {
                ...item as Map<String, dynamic>,
                'type': _itemTypeForCategory(category),
              })
          .toList();

      final totalPages = (response['totalPages'] as num?)?.toInt();
      final total = (response['total'] as num?)?.toInt() ?? items.length;
      final hasMore = totalPages != null ? page < totalPages : total > page * size;

      _commitResults(
        items: items,
        apiTotal: total,
        apiHasMore: hasMore,
        loadMore: loadMore,
        page: page,
      );
      if (mounted) {
        final showSeeding = liquidityExhausted &&
            items.isEmpty &&
            (lower == 'trades' || lower == 'gifts');
        setState(() => _liquidityExhausted = showSeeding);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = NetworkErrorMessage.forSearchLoad(e);
        if (!loadMore) {
          _searchResults = [];
          _rawResults = [];
          _totalResults = 0;
          _hasMore = false;
        }
      });
    }
  }

  Future<void> _loadSearchSuggestions(String query) async {
    if (_searchApiService == null) return;
    if (!_isAuthed) {
      if (mounted) setState(() { _searchSuggestions = []; _isLoadingSuggestions = false; });
      return;
    }
    setState(() { _isLoadingSuggestions = true; });
    try {
      final response = await _searchApiService!.getSearchSuggestions(
        query: query,
        type: _selectedCategory == 'All' ? null : _apiTypeForCategory(_selectedCategory),
      );
      final suggestions = (response['suggestions'] as List? ?? []).map((s) => {'text': s['text'] ?? '', 'type': s['type'] ?? ''}).toList();
      if (mounted) setState(() { _searchSuggestions = suggestions; _isLoadingSuggestions = false; });
    } catch (e) {
      if (mounted) setState(() { _searchSuggestions = []; _isLoadingSuggestions = false; });
    }
  }

  Future<void> _performSearch(String query, {bool loadMore = false}) async {
    if (_searchApiService == null) return;
    if (query.trim().isEmpty) {
      if (_selectedCategory == 'All') {
        return _loadAllItems(loadMore: loadMore);
      }
      return _loadCategoryItems(category: _selectedCategory, loadMore: loadMore);
    }
    if (!loadMore) setState(() { _isLoading = true; _errorMessage = null; _currentPage = 1; _searchQuery = query; });
    else setState(() { _isLoading = true; });

    try {
      final page = loadMore ? _currentPage + 1 : 1;
      final size = _discoveryPageSize;
      final useAuthed = _isAuthed;
      final geo = _listingGeo;
      Map<String, dynamic> response;
      if (_selectedCategory == 'All') {
        if (useAuthed) {
          response = await _searchApiService!.search(query: query, page: page, size: size);
        } else {
          final responses = await Future.wait([
            _searchApiService!.listTradesPublic(query: query, page: page, size: size, geo: geo),
            _searchApiService!.listGiftsPublic(query: query, page: page, size: size, geo: geo),
            _searchApiService!.listCampaignsPublic(query: query, page: page, size: size, geo: geo),
          ]);
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
          final hasMore = tradesTotal > page * size ||
              giftsTotal > page * size ||
              campaignsTotal > page * size;
          response = {
            'items': merged,
            'total': total,
            'totalPages': hasMore ? page + 1 : page,
          };
        }
      } else {
        final type = _selectedCategory.toLowerCase();
        if (useAuthed) {
          switch (type) {
            case 'trades':
              response = await _searchApiService!.searchTrades(
                query: query,
                location: _locationQuery,
                geo: geo,
                page: page,
                size: size,
              );
              break;
            case 'gifts':
              response = await _searchApiService!.searchGifts(
                query: query,
                location: _locationQuery,
                geo: geo,
                page: page,
                size: size,
              );
              break;
            case 'donations':
              response = await _searchApiService!.searchCampaigns(
                query: query,
                location: _locationQuery,
                geo: geo,
                page: page,
                size: size,
              );
              break;
            case 'communities':
              response = await _searchApiService!.searchCommunities(query: query, page: page, size: size);
              break;
            case 'users':
              response = await _searchApiService!.searchUsers(
                    query: query,
                    location: _locationQuery,
                    page: page,
                    size: size,
                  ) ??
                  {};
              break;
            default: response = await _searchApiService!.search(
              query: query,
              type: _apiTypeForCategory(_selectedCategory),
              page: page,
              size: size,
            );
          }
        } else {
          switch (type) {
            case 'trades': response = await _searchApiService!.listTradesPublic(query: query, page: page, size: size, geo: geo); break;
            case 'gifts': response = await _searchApiService!.listGiftsPublic(query: query, page: page, size: size, geo: geo); break;
            case 'donations': response = await _searchApiService!.listCampaignsPublic(query: query, page: page, size: size, geo: geo); break;
            case 'communities': response = await _searchApiService!.listCommunitiesPublic(query: query, page: page, size: size); break;
            case 'users': response = const {'items': [], 'total': 0, 'totalPages': 0}; break;
            default: response = const {'items': [], 'total': 0, 'totalPages': 0};
          }
        }
      }
      final items = (response['items'] as List? ?? [])
          .map((item) => {
                ...item as Map<String, dynamic>,
                'type': _normalizeResultType(
                  item['type'] ?? _itemTypeForCategory(_selectedCategory),
                ),
              })
          .toList();
      if (mounted) {
        final total = (response['total'] as num?)?.toInt() ?? items.length;
        final totalPages = (response['totalPages'] as num?)?.toInt() ?? 0;
        final hasMore = totalPages > page;
        _commitResults(
          items: items,
          apiTotal: total,
          apiHasMore: hasMore,
          loadMore: loadMore,
          page: page,
        );
        if (!_recentSearches.contains(query)) {
          _recentSearches.insert(0, query);
          if (_recentSearches.length > 10) _recentSearches.removeLast();
          _saveRecentSearches();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = NetworkErrorMessage.forSearchLoad(e);
          if (!loadMore) {
            _searchResults = [];
            _rawResults = [];
            _totalResults = 0;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0B12) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Search Engine',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _build3DSearchHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppTheme.primaryColor,
                  child: SingleChildScrollView(
                    controller: _resultsScrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: AdPlacementSection(
                          placementKey: 'search_feed',
                          title: 'Sponsored Deals',
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildErrorMessage(),
                        ),
                      
                      if (_searchQuery.isNotEmpty) ...[
                        if (_isLoadingSuggestions && _searchSuggestions.isEmpty)
                          const Center(child: Padding(padding: EdgeInsets.all(20), child: BybataLoadingIndicator(size: BybataLoadingSize.compact)))
                        else if (_searchSuggestions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: _buildSearchSuggestions(),
                          ),

                        if (_isLoading && _searchResults.isEmpty)
                          const Center(child: Padding(padding: EdgeInsets.all(20), child: BybataLoadingIndicator(size: BybataLoadingSize.compact)))
                        else
                          _buildSearchResultsList(),
                      ] else ...[
                        if (_isLoading && _searchResults.isEmpty)
                          const Center(child: Padding(padding: EdgeInsets.all(20), child: BybataLoadingIndicator(size: BybataLoadingSize.compact)))
                        else
                          _buildSearchResultsList(),
                      ],
                      if (_searchQuery.isEmpty && _searchResults.isEmpty && _recentSearches.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildRecentSearches(),
                        ),
                    ],
                  ),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3DSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildRecessedInput(
                  controller: _searchController, 
                  focusNode: _searchFocus, 
                  hint: "Search Bybata to trade, gift or fund..."
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showFilterSheet,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: _hasActiveFilters
                            ? AppTheme.primaryColor
                            : AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: _hasActiveFilters ? Colors.white : AppTheme.primaryColor,
                        size: 22,
                      ),
                    ),
                    if (_hasActiveFilters)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppTheme.karmaColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            child: Row(
              children: _categories.map((c) => _buildTactileChip(c, _selectedCategory == c, () {
                setState(() => _selectedCategory = c);
                final query = _searchController.text.trim();
                if (query.isNotEmpty) {
                  _performSearch(query);
                } else if (c == 'All') {
                  _loadAllItems();
                } else {
                  _loadCategoryItems(category: c);
                }
              })).toList(),
            ),
          ),
          if (_hasActiveFilters) _buildActiveFilterChips(),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList() {
    if (_searchResults.isEmpty) return _buildEmptyState();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Found $_totalResults results',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        ..._searchResults.map((result) {
          final card = SocialListingMapper.fromSearchItemMap(result);
          if (card == null) return const SizedBox.shrink();
          final type = result['type']?.toString() ?? 'all';
          return SocialListingCard(
            key: ValueKey(
              '${card.id}_${card.media.previewImageKey}_${card.media.videoKey}',
            ),
            data: card,
            layout: SocialFeedLayout.instagram,
            onCardTap: () => _openResult(result, type),
            onPrimaryAction: () {
              if (AppRoutes.requireSignIn(context)) return;
              _openResult(result, type);
            },
          );
        }),
        if (_hasMore && !_hasActiveFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Center(
              child: OutlinedButton(
                onPressed: () {
                  final query = _searchController.text.trim();
                  if (query.isNotEmpty) {
                    _performSearch(query, loadMore: true);
                  } else if (_selectedCategory == 'All') {
                    _loadAllItems(loadMore: true);
                  } else {
                    _loadCategoryItems(category: _selectedCategory, loadMore: true);
                  }
                },
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: const Text('Load More Items', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    if (_liquidityExhausted && _listingGeo?.lat != null) {
      return const EcosystemSeedingPortal();
    }
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          const Text(
            "No listings detected", 
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)
          ),
          const SizedBox(height: 4),
          Text(
            "Try rephrasing your intent query",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    final isOffline = NetworkErrorMessage.messageIndicatesOffline(_errorMessage);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isOffline ? Icons.cloud_off_outlined : Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    var draftSort = _sortOption;
    final locationController = TextEditingController(text: _locationFilter ?? '');
    var draftUseNearby = _nearbyPosition != null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final bottomInset = MediaQuery.paddingOf(ctx).bottom;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final hasDraftChanges =
                draftSort != _sortOption ||
                draftUseNearby != (_nearbyPosition != null) ||
                locationController.text.trim() != (_locationFilter?.trim() ?? '');

            Future<void> applyNearby() async {
              setState(() => _sortOption = draftSort);
              Navigator.pop(ctx);
              await _applyMyLocationFilter();
            }

            void applyManual() {
              final text = locationController.text.trim();
              setState(() {
                _sortOption = draftSort;
                _locationFilter = text.isEmpty ? null : text;
                _nearbyPosition = null;
              });
              if (_rawResults.isNotEmpty) {
                _commitResults(
                  items: _rawResults,
                  apiTotal: _rawResults.length,
                  apiHasMore: false,
                  loadMore: false,
                  page: _currentPage,
                );
              } else {
                _reloadCurrentQuery();
              }
              Navigator.pop(ctx);
            }

            return Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(ctx).size.height * 0.12),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.82,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.96),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      border: Border(
                        top: BorderSide(color: scheme.outline.withValues(alpha: 0.08)),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.onSurface.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.primaryColor.withValues(alpha: 0.18),
                                            AppTheme.karmaColor.withValues(alpha: 0.12),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(Icons.tune_rounded, color: AppTheme.primaryColor, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Refine results',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.5,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                          Text(
                                            'Sort and narrow by what\'s near you',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: scheme.onSurface.withValues(alpha: 0.55),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      icon: Icon(Icons.close_rounded, color: scheme.onSurface.withValues(alpha: 0.5)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                _filterSectionLabel(scheme, Icons.sort_rounded, 'Sort by'),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _SearchSortOption.values.map((option) {
                                    final selected = draftSort == option;
                                    return FilterChip(
                                      label: Text(option.label),
                                      selected: selected,
                                      showCheckmark: false,
                                      onSelected: (_) => setSheetState(() => draftSort = option),
                                      labelStyle: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: selected ? Colors.white : scheme.onSurface.withValues(alpha: 0.75),
                                      ),
                                      selectedColor: AppTheme.primaryColor,
                                      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                      side: BorderSide(
                                        color: selected
                                            ? Colors.transparent
                                            : scheme.outline.withValues(alpha: 0.12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 24),
                                _filterSectionLabel(scheme, Icons.near_me_rounded, 'Location'),
                                const SizedBox(height: 10),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: applyNearby,
                                    borderRadius: BorderRadius.circular(18),
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppTheme.primaryColor.withValues(alpha: 0.14),
                                            AppTheme.karmaColor.withValues(alpha: 0.08),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: draftUseNearby || _nearbyPosition != null
                                              ? AppTheme.primaryColor.withValues(alpha: 0.45)
                                              : AppTheme.primaryColor.withValues(alpha: 0.18),
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(Icons.my_location_rounded, color: AppTheme.primaryColor, size: 20),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Near me',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                    color: scheme.onSurface,
                                                  ),
                                                ),
                                                Text(
                                                  'Trades, gifts & campaigns within 50 km',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: scheme.onSurface.withValues(alpha: 0.55),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 14,
                                            color: scheme.onSurface.withValues(alpha: 0.35),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Or search a city / area',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface.withValues(alpha: 0.45),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: locationController,
                                  onChanged: (_) => setSheetState(() {
                                    draftUseNearby = false;
                                  }),
                                  textCapitalization: TextCapitalization.words,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                  decoration: BorderlessInputDecoration.search(
                                    hintText: 'e.g. Lagos, Abuja, Ikeja…',
                                    prefixIcon: Icon(
                                      Icons.place_outlined,
                                      color: scheme.onSurface.withValues(alpha: 0.45),
                                    ),
                                    suffixIcon: locationController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.close_rounded, size: 18),
                                            onPressed: () {
                                              locationController.clear();
                                              setSheetState(() => draftUseNearby = false);
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                                if (_hasActiveFilters) ...[
                                  const SizedBox(height: 20),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.primaryColor),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _activeFiltersSummary(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: scheme.onSurface.withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 12),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            border: Border(
                              top: BorderSide(color: scheme.outline.withValues(alpha: 0.08)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _hasActiveFilters || hasDraftChanges
                                      ? () {
                                          _clearAllFilters();
                                          Navigator.pop(ctx);
                                        }
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton(
                                  onPressed: applyManual,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Text(
                                    'Apply filters',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    locationController.dispose();
  }

  Widget _filterSectionLabel(ColorScheme scheme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }

  String _activeFiltersSummary() {
    final parts = <String>[];
    if (_sortOption != _SearchSortOption.newest) parts.add(_sortOption.label);
    if (_nearbyPosition != null) {
      parts.add('Within 50 km');
    } else if (_locationQuery != null) {
      parts.add(_locationQuery!);
    }
    return parts.isEmpty ? 'No filters active' : parts.join(' · ');
  }

  Widget _buildActiveFilterChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_sortOption != _SearchSortOption.newest)
            InputChip(
              label: Text(_sortOption.label),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              onDeleted: () {
                setState(() => _sortOption = _SearchSortOption.newest);
                if (_rawResults.isNotEmpty) {
                  _commitResults(
                    items: _rawResults,
                    apiTotal: _rawResults.length,
                    apiHasMore: false,
                    loadMore: false,
                    page: _currentPage,
                  );
                } else {
                  _reloadCurrentQuery();
                }
              },
            ),
          if (_locationQuery != null)
            InputChip(
              avatar: Icon(
                _nearbyPosition != null ? Icons.near_me_rounded : Icons.place_outlined,
                size: 16,
                color: AppTheme.primaryColor,
              ),
              label: Text(_nearbyPosition != null ? 'Near me · 50 km' : _locationQuery!),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              onDeleted: () {
                setState(() {
                  _locationFilter = null;
                  _nearbyPosition = null;
                });
                _reloadCurrentQuery();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _applyMyLocationFilter() async {
    try {
      final status = await LocationService.instance.ensureForFunction(context);
      final granted = status == LocationPermission.always ||
          status == LocationPermission.whileInUse;
      if (!granted) return;

      final position = await LocationService.instance.getCurrentPosition(forceRefresh: true);
      if (position == null) {
        if (!mounted) return;
        AppToast.show(context, 'Could not detect your location. Enter a city manually.');
        return;
      }

      final label = await LocationService.instance.resolvePlacemark(position) ??
          await LocationService.instance.getCachedPlacemark();
      if (!mounted) return;
      if (label == null || label.isEmpty) {
        AppToast.show(context, 'Could not detect your area. Enter a city manually.');
        return;
      }
      setState(() {
        _nearbyPosition = position;
        _locationFilter = label;
      });
      _reloadCurrentQuery();
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, 'Location unavailable. Enter a city manually.');
    }
  }

  void _clearAllFilters() {
    setState(() {
      _sortOption = _SearchSortOption.newest;
      _locationFilter = null;
      _nearbyPosition = null;
    });
    _reloadCurrentQuery();
  }

  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Recent intents", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.4)),
        const SizedBox(height: 12),
        ..._recentSearches.map((s) => ListTile(
          leading: const Icon(Icons.history_rounded), 
          title: Text(s, style: const TextStyle(fontWeight: FontWeight.w600)), 
          onTap: () { _searchController.text = s; _performSearch(s); },
          trailing: IconButton(
            icon: const Icon(Icons.close_rounded, size: 18), 
            onPressed: () => setState(() { _recentSearches.remove(s); _saveRecentSearches(); })
          ),
        )),
      ],
    );
  }

  Widget _buildSearchSuggestions() {
    return _build3DContainer(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: _searchSuggestions.map((s) => ListTile(
          leading: Icon(_getCategoryIcon(s['type'])), 
          title: Text(s['text'], style: const TextStyle(fontWeight: FontWeight.w600)), 
          onTap: () { _searchController.text = s['text']; _performSearch(s['text']); }
        )).toList()
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'trade': case 'trades': return Icons.swap_horiz_rounded;
      case 'gift': case 'gifts': return Icons.card_giftcard_rounded;
      case 'campaign': case 'campaigns': case 'donation': case 'donations': return Icons.volunteer_activism_rounded;
      case 'community': case 'communities': return Icons.groups_rounded;
      case 'user': case 'users': return Icons.person_rounded;
      default: return Icons.search_rounded;
    }
  }

  String _getResultTitle(Map<String, dynamic> result, String type) {
    if (type == 'user') {
      final username = result['profile']?['username'] ?? result['username'];
      if (username != null && username.toString().isNotEmpty) {
        final s = username.toString();
        return s.startsWith('@') ? s : '@$s';
      }
      return result['profile']?['displayName'] ?? result['displayName'] ?? result['email'] ?? 'User';
    }
    return result['title'] ?? result['name'] ?? 'Item';
  }

  void _openResult(Map<String, dynamic> result, String type) {
    final normalizedType = _normalizeResultType(type);
    final id = result['id'];
    if (id == null) return;
    if (normalizedType == 'trade') _navigateToTradeDetails(result);
    else if (normalizedType == 'gift') _navigateToGiftDetails(result);
    else if (normalizedType == 'campaign') _navigateToCampaignDetails(result);
    else if (normalizedType == 'community') {
      if (AppRoutes.requireSignIn(context)) return;
      GuardedNavigator.push(context, MaterialPageRoute(builder: (_) => CommunityHubScreen(communityId: id, communityName: result['name'])));
    } else if (normalizedType == 'user') {
      if (AppRoutes.requireSignIn(context)) return;
      GuardedNavigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: id)));
    }
  }

  void _navigateToTradeDetails(Map<String, dynamic> result) {
    final id = result['id']?.toString();
    if (id != null && id.isNotEmpty) {
      AppRoutes.navigateToTradeDetailsById(context, id);
      return;
    }
    try {
      final owner = result['owner'] as Map<String, dynamic>? ?? {};
      final profile = owner['profile'] as Map<String, dynamic>? ?? {};
      
      final trade = trade_models.Trade(
        id: result['id'] ?? '',
        title: result['title'] ?? 'Trade',
        description: result['description'] ?? '',
        images: _parseImages(result['mediaKeys']),
        category: _parseTradeCategory(result['category']),
        owner: trade_models.TradeUser(
          id: owner['id'] ?? '', 
          name: profile['displayName'] ?? 'Unknown', 
          username: '@user', 
          rating: 0, 
          completedTrades: 0, 
          joinedDate: DateTime.now(), 
          isVerified: false
        ),
        status: _parseTradeStatus(result['status']),
        createdAt: DateTime.now(), 
        condition: trade_models.ItemCondition.good, 
        estimatedValue: 0, 
        interestedItems: const [], 
        location: '', 
        tags: const [], 
        viewCount: 0, 
        favoriteCount: 0, 
        isNegotiable: true, 
        allowPickup: true
      );
      AppRoutes.navigateToTradeDetails(context, trade);
    } catch (_) {}
  }

  void _navigateToGiftDetails(Map<String, dynamic> result) {
    final id = result['id']?.toString();
    if (id != null && id.isNotEmpty) {
      AppRoutes.navigateToGiftDetailsById(context, id);
      return;
    }
    GuardedNavigator.pushNamed(context,
      AppConstants.giftDetailsRoute,
      arguments: result,
    );
  }

  void _navigateToCampaignDetails(Map<String, dynamic> result) {
    final id = result['id']?.toString();
    if (id != null && id.isNotEmpty) {
      AppRoutes.navigateToCampaignDetailsById(context, id);
      return;
    }
    final campaign = donation_models.Campaign(
      id: result['id'] ?? '',
      title: result['title'] ?? '',
      story: result['description'] ?? '',
      goalAmount: 0, 
      raisedAmount: 0, 
      status: donation_models.CampaignStatus.active, 
      category: donation_models.CampaignCategory.other, 
      priority: donation_models.CampaignPriority.normal,
      creator: donation_models.DonationUser(
        id: 'u', 
        name: 'User', 
        trustLevel: 0, 
        karmaPoints: 0, 
        campaignsCreated: 0, 
        donationsMade: 0, 
        totalRaised: 0, 
        totalDonated: 0, 
        location: ''
      ),
      createdAt: DateTime.now(), 
      deadline: DateTime.now(), 
      images: const [], 
      videoUrl: null, 
      rewardTiers: const [], 
      updates: const [], 
      donations: const [], 
      location: '', 
      tags: const [], 
      supportersCount: 0, 
      viewsCount: 0, 
      sharesCount: 0, 
      isFeatured: false, 
      isUrgent: false, 
      isLocal: false, 
      beneficiaryInfo: null
    );
    AppRoutes.navigateToCampaignDetails(context, campaign);
  }

  List<String> _parseImages(dynamic keys) => (keys is List) ? keys.map((e) => e.toString()).toList() : [];
  
  trade_models.TradeCategory _parseTradeCategory(dynamic c) {
    final searchStr = c?.toString().toUpperCase() ?? '';
    return trade_models.TradeCategory.values.firstWhere(
      (e) => e.toString().toUpperCase().contains(searchStr), 
      orElse: () => trade_models.TradeCategory.others
    );
  }
  
  trade_models.TradeStatus _parseTradeStatus(dynamic s) {
    final searchStr = s?.toString().toUpperCase() ?? '';
    return trade_models.TradeStatus.values.firstWhere(
      (e) => e.toString().toUpperCase().contains(searchStr), 
      orElse: () => trade_models.TradeStatus.active
    );
  }
  
  String _apiTypeForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'trades': return 'trades';
      case 'gifts': return 'gifts';
      case 'donations': return 'campaigns';
      case 'communities': return 'communities';
      case 'users': return 'users';
      default: return category.toLowerCase();
    }
  }

  String _itemTypeForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'trades': return 'trade';
      case 'gifts': return 'gift';
      case 'donations': return 'campaign';
      case 'communities': return 'community';
      case 'users': return 'user';
      default: return category.toLowerCase();
    }
  }

  String _normalizeResultType(String type) {
    switch (type.toLowerCase()) {
      case 'trades': return 'trade';
      case 'gifts': return 'gift';
      case 'campaigns':
      case 'donations': return 'campaign';
      case 'communities': return 'community';
      case 'users': return 'user';
      default: return type.toLowerCase();
    }
  }
}