import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Core Imports
import '../../../core/widgets/search_bar_widget.dart';
import '../../../core/theme/borderless_input_decoration.dart';
import '../../../core/widgets/hub_screen_top_bar.dart';
import '../../../features/settings/widgets/settings_ui.dart';
import '../../../core/widgets/hub_mine_empty_state.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/navigation/main_navigation.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/guest_browse_helpers.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ad_placement_section.dart';
import '../../../core/config/env_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/models/listing_media.dart';
import '../../../core/widgets/cached_media_image.dart';
import '../../../core/widgets/debounced_tap.dart';
import '../../../core/widgets/listing_media_view.dart';
import '../../../core/utils/share_utils.dart';
import '../../../core/utils/network_error_message.dart';

// Trade Feature Imports
import '../providers/trade_backend_provider.dart';
import '../models/trade_models.dart' as trade_models;
import '../api/trade_api.dart';
import '../../wallet/services/wallet_service.dart';
import '../../wallet/screens/promotion_center_screen.dart';
import 'negotiation_screen.dart';
import 'existing_offer_negotiation_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

// Chat Feature Imports
import '../../feed/mappers/social_listing_mapper.dart';
import '../../feed/models/social_listing_card_data.dart';
import '../../feed/widgets/social_feed_list.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';
import '../../../core/motion/create_stage_route.dart';
import '../../../core/motion/hero_stage.dart';
import '../../../core/motion/hub_atmosphere.dart';
import '../../../core/motion/hub_create_rail.dart';
import '../../../core/motion/hub_deck_bar.dart';
import '../../../core/motion/hub_stage_bus.dart';
import '../../../core/motion/soft_reveal.dart';
import '../../../core/motion/living_slide.dart';
import '../../../core/motion/stage_controller.dart';
import '../../../core/navigation/route_observer.dart';
import 'create_trade_screen.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../stage/living_slide_mapper.dart';
import '../widgets/trade_offer_act.dart';
import 'trade_chat_screen.dart';

class TradeScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? highlightOfferId;
  final String? highlightTradeId;
  final String? stageFocusId;

  const TradeScreen({
    super.key,
    this.initialTabIndex = 0,
    this.highlightOfferId,
    this.highlightTradeId,
    this.stageFocusId,
  });

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  final Map<String, GlobalKey> _offerHighlightKeys = {};
  String? _activeHighlightOfferId;
  String? _activeHighlightTradeId;
  bool _highlightScrollAttempted = false;
  final StageController _living = StageController();
  final TradeOfferDraft _offerDraft = TradeOfferDraft();
  List<LivingSlide> _livingSlides = const [];
  bool _openedStageFocus = false;
  String? _pendingFocus;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSortOption = 'recent';
  List<String> _selectedFilters = [];
  List<String> _trustFilters = [];
  bool _showSmartMatches = true;

  // Real data from API
  List<Map<String, dynamic>> _availableTrades = [];
  List<Map<String, dynamic>> _myActiveTrades = [];
  List<Map<String, dynamic>> _draftTrades = [];
  List<Map<String, dynamic>> _ongoingOffers = [];
  List<Map<String, dynamic>> _completedTrades = [];
  bool _isLoading = true;
  bool _isMyLoading = false;
  bool _draftLoading = false;
  bool _offersLoading = false;
  bool _historyLoading = false;
  int _adFeedRefresh = 0;
  int _browsePage = 1;
  bool _browseHasMore = true;
  String? _browseLoadError;

  final List<String> _categories = [
    'All', 'Electronics', 'Books', 'Clothing', 'Home & Garden', 'Sports', 'Tools', 'Others',
  ];

  static const Set<String> _offersTabStatuses = {
    'pending',
    'accepted',
    'acceptedawaitingfinalization',
    'rejected',
    'withdrawn',
  };

  String _normalizeOfferStatus(dynamic status) {
    return (status ?? 'pending').toString().toLowerCase().replaceAll('_', '');
  }

  bool _isOfferVisibleInOffersTab(dynamic status) {
    return _offersTabStatuses.contains(_normalizeOfferStatus(status));
  }

  final List<SortOption> _sortOptions = [
    SortOption(value: 'recent', label: 'Most Recent', description: 'Newest trades first'),
    SortOption(value: 'smart_match', label: 'Smart Match', description: 'AI-powered recommendations'),
    SortOption(value: 'popular', label: 'Most Popular', description: 'Highest demand items'),
    SortOption(value: 'distance', label: 'Distance', description: 'Nearest to your location'),
    SortOption(value: 'trust_score', label: 'Trust Score', description: 'Highest trust traders first'),
    SortOption(value: 'karma_points', label: 'KARMA Points', description: 'Most KARMA points'),
  ];

  @override
  void initState() {
    super.initState();
    final initialIndex = (widget.initialTabIndex).clamp(0, 4);
    _tabController = TabController(length: 5, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      setState(() {}); 
      if (_tabController.index == 1 && _myActiveTrades.isEmpty && !_isMyLoading) {
        _loadMyActiveTrades();
      }
      if (_tabController.index == 2 && _draftTrades.isEmpty && !_draftLoading) {
        _loadDraftTrades();
      }
      if (_tabController.index == 3 && !_offersLoading) {
        _loadOngoingOffers();
      }
      if (_tabController.index == 4 && _completedTrades.isEmpty && !_historyLoading) {
        _loadTradeHistory();
      }
    });
    _living.addListener(_onLivingChanged);
    HubStageBus.register(HubStageBus.trade, _openLinked);
    _loadTradeData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyInitialTab());
  }

  void _onLivingChanged() {
    if (mounted) setState(() {});
  }

  void _openLinked(String id) {
    _pendingFocus = id;
    _openedStageFocus = false;
    _maybeOpenStageFocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
      HubStageBus.markCurrent(HubStageBus.trade, route.isCurrent);
    }
  }

  @override
  void didPush() => HubStageBus.markCurrent(HubStageBus.trade, true);

  @override
  void didPopNext() => HubStageBus.markCurrent(HubStageBus.trade, true);

  @override
  void didPushNext() => HubStageBus.markCurrent(HubStageBus.trade, false);

  @override
  void didPop() => HubStageBus.markCurrent(HubStageBus.trade, false);

  @override
  void dispose() {
    HubStageBus.markCurrent(HubStageBus.trade, false);
    HubStageBus.unregister(HubStageBus.trade, _openLinked);
    appRouteObserver.unsubscribe(this);
    _living.removeListener(_onLivingChanged);
    _living.dispose();
    _offerDraft.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  GlobalKey _keyForOffer(String offerId) {
    return _offerHighlightKeys.putIfAbsent(offerId, GlobalKey.new);
  }

  void _applyInitialTab() {
    final idx = widget.initialTabIndex.clamp(0, 4);
    if (idx == 0) return;
    if (idx == 3) {
      _loadOngoingOffers();
    } else if (idx == 1 && _myActiveTrades.isEmpty && !_isMyLoading) {
      _loadMyActiveTrades();
    } else if (idx == 2 && _draftTrades.isEmpty && !_draftLoading) {
      _loadDraftTrades();
    } else if (idx == 4 && _completedTrades.isEmpty && !_historyLoading) {
      _loadTradeHistory();
    }
  }

  void _maybeScrollToOfferHighlight() {
    if (_highlightScrollAttempted || _offersLoading) return;

    final offerId = widget.highlightOfferId?.trim();
    final tradeId = widget.highlightTradeId?.trim();
    if ((offerId == null || offerId.isEmpty) &&
        (tradeId == null || tradeId.isEmpty)) {
      return;
    }

    String? scrollTargetOfferId;
    if (offerId != null && offerId.isNotEmpty) {
      if (_ongoingOffers.any((o) => (o['id']?.toString() ?? '') == offerId)) {
        scrollTargetOfferId = offerId;
      }
    }
    if (scrollTargetOfferId == null && tradeId != null && tradeId.isNotEmpty) {
      for (final offer in _ongoingOffers) {
        if ((offer['tradeId']?.toString() ?? '') == tradeId) {
          scrollTargetOfferId = offer['id']?.toString();
          break;
        }
      }
    }

    if (scrollTargetOfferId == null || scrollTargetOfferId.isEmpty) {
      if (!_offersLoading) _highlightScrollAttempted = true;
      return;
    }

    _highlightScrollAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext =
          _offerHighlightKeys[scrollTargetOfferId]?.currentContext;
      if (targetContext == null) return;

      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        alignment: 0.12,
      );
      final matchedOffer = _ongoingOffers.firstWhere(
        (o) => (o['id']?.toString() ?? '') == scrollTargetOfferId,
        orElse: () => <String, dynamic>{},
      );
      setState(() {
        _activeHighlightOfferId = scrollTargetOfferId;
        _activeHighlightTradeId = matchedOffer['tradeId']?.toString();
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          _activeHighlightOfferId = null;
          _activeHighlightTradeId = null;
        });
      });
    });
  }

  Widget _wrapOfferHighlight({
    required String offerId,
    required String tradeId,
    required Widget child,
  }) {
    final highlighted = _activeHighlightOfferId == offerId ||
        (_activeHighlightOfferId == null &&
            _activeHighlightTradeId != null &&
            _activeHighlightTradeId == tradeId);
    return AnimatedContainer(
      key: _keyForOffer(offerId),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: highlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.tradeColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.tradeColor.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : null,
      child: child,
    );
  }

  Widget _build3DContainer({
    required Widget child,
    Color? color,
    double radius = 24,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: color != null ? const EdgeInsets.all(1.5) : null,
        decoration: BoxDecoration(
          color: color ?? (isDark ? const Color(0xFF1E1A28).withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.75)),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
            width: 1.2,
          ),
          boxShadow: isDark ? null : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 1),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: !_living.isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _living.back();
      },
      child: Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0B12) : AppColors.primaryTintSoft,
      body: Stack(
        children: [
          HubAtmosphere(
            accent: AppTheme.tradeColor,
            visible: !_living.isOpen,
          ),
          Column(
            children: [
              HubScreenTopBar(
                title: 'Trade Center',
                onBack: () => Navigator.of(context).pop(),
                trailingActions: [
                  HubTopBarIconButton(
                    icon: Icons.swap_horiz_rounded,
                    onTap: () {
                      if (!guardHubTabForGuest(context, 1)) return;
                      _tabController.animateTo(1);
                    },
                    isDark: isDark,
                    iconColor: AppTheme.tradeColor,
                  ),
                ],
              ),
              _buildFluidTabSwitcher(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildBrowseTradesTab(),
                    GuestBrowseGate(
                      title: 'Sign in to view your trades',
                      message: 'Create and manage your listings after you sign in.',
                      child: _buildMyTradesTab(),
                    ),
                    GuestBrowseGate(
                      title: 'Sign in to view drafts',
                      message: 'Save and publish trade drafts from your account.',
                      child: _buildDraftTab(),
                    ),
                    GuestBrowseGate(
                      title: 'Sign in to view offers',
                      message: 'Track negotiations and offers on your account.',
                      child: _buildTradeRequestsTab(),
                    ),
                    GuestBrowseGate(
                      title: 'Sign in to view history',
                      message: 'See completed trades after you sign in.',
                      child: _buildTradeHistoryTab(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_living.isOpen)
            Align(
              alignment: Alignment.centerRight,
              child: HubCreateRail(
                color: AppTheme.tradeColor,
                label: 'CREATE TRADE',
                onTap: _openCreateTrade,
              ),
            ),
          if (_living.isOpen && _livingSlides.isNotEmpty)
            Positioned.fill(child: _tradeStage()),
        ],
      ),
    ),
    );
  }

  Widget _tradeStage() {
    return LivingHeroStage(
      controller: _living,
      stageColor: AppTheme.tradeColor,
      slides: _livingSlides,
      commitLabel: 'Send offer',
      markIcon: Icons.swap_horiz_rounded,
      railIsFocus: true,
      numberTick: _offerDraft,
      numberText: () => _offerDraft.numberLabel,
      railBuilder: (slide) => TradeItemRail(
        targetId: slide.id,
        theirValue: slide.value ?? 0,
        draft: _offerDraft,
      ),
      actBuilder: (slide) => TradeOfferExtras(
        tradeId: slide.id,
        draft: _offerDraft,
      ),
      beforeBuilder: (slide) async => !AppRoutes.requireSignIn(context),
      onEdit: _editTradeSlide,
      onMessage: _messageTradeSlide,
      onCommit: _commitTradeOffer,
    );
  }

  void _openCreateTrade() {
    if (AppRoutes.requireSignIn(context)) return;
    GuardedNavigator.push(
      context,
      CreateStageRoute(
        color: AppTheme.tradeColor,
        origin: stageCardOrigin(context),
        builder: (_) => const CreateTradeScreen(),
      ),
    );
  }

  Widget _buildFluidTabSwitcher() {
    return SoftReveal(
      index: 0,
      travel: 10,
      child: HubDeckBar(
        controller: _tabController,
        accent: AppTheme.tradeColor,
        activity: const [
          HubActivity('Drafts', 2),
          HubActivity('Offers', 3),
          HubActivity('History', 4),
        ],
        guard: (index) => guardHubTabForGuest(context, index),
      ),
    );
  }

  Widget _buildBrowseTradesTab() {
    if (_isLoading) return const BybataLoader();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final filtered = _availableTrades.where((t) {
      final q = _searchQuery;
      final inCategory = trade_models.tradeMatchesBrowseCategory(
        t['category'],
        _selectedCategory,
      );
      final status = t['status']?.toString().toUpperCase() ?? 'OPEN';
      if (status != 'OPEN') return false;
      if (q.isEmpty) return inCategory;
      final title = t['title']?.toString().toLowerCase() ?? '';
      final desc = t['description']?.toString().toLowerCase() ?? '';
      return inCategory && (title.contains(q) || desc.contains(q));
    }).toList();

    final feedItems = filtered.map(SocialListingMapper.fromTradeMap).toList();

    return SocialFeedList(
      items: feedItems,
      layout: SocialFeedLayout.catalog,
      isLoading: _isLoading,
      hasMore: _browseHasMore,
      error: _browseLoadError,
      onRefresh: () => _loadTradeData(refresh: true),
      onLoadMore: _loadMoreBrowseTrades,
      header: [
        SoftReveal(
          index: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1826).withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppTheme.tradeColor.withValues(alpha: 0.08),
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: AppTheme.tradeColor.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: BorderlessInputDecoration.search(
                  hintText: 'Search trades',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white54 : AppTheme.tradeColor,
                  ),
                ),
              ),
            ),
          ),
        ),
        SoftReveal(
          index: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCategoryFilter(),
          ),
        ),
        const SizedBox(height: 16),
        SoftReveal(
          index: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AdPlacementSection(
              key: ValueKey('trade_ads_$_adFeedRefresh'),
              placementKey: 'trade_feed',
              title: 'Sponsored Exchange',
              refreshToken: _adFeedRefresh,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_showSmartMatches && _selectedSortOption == 'smart_match')
          SoftReveal(
            index: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSmartMatchBanner(),
            ),
          ),
      ],
      onCardTap: (item) => _openLivingTrades(filtered, item.id, mine: false),
      onPrimaryAction: (item) => _openLivingTrades(filtered, item.id, mine: false),
      emptyAccent: AppTheme.tradeColor,
      emptyIcon: Icons.swap_horiz_rounded,
      emptyTitle: 'No trades found',
      emptySubtitle: 'Try another category or check back later.',
    );
  }

  Widget _buildCategoryFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _categories.map((cat) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: _browseCategoryChip(cat, isDark),
        )).toList(),
      ),
    );
  }

  Widget _browseCategoryChip(String cat, bool isDark) {
    final selected = _selectedCategory == cat;
    final color = _browseChipColor(cat);
    final labelColor = selected
        ? Colors.white
        : (isDark ? Color.lerp(color, Colors.white, 0.55)! : color);
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategory = cat);
        _loadTradeData(refresh: true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color
              : color.withValues(alpha: isDark ? 0.28 : 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          cat,
          style: TextStyle(
            color: labelColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Color _browseChipColor(String cat) {
    return switch (cat) {
      'Electronics' => const Color(0xFF5C6BC0),
      'Books' => const Color(0xFF8D6E63),
      'Clothing' => const Color(0xFFEC407A),
      'Home & Garden' => const Color(0xFF26A69A),
      'Sports' => const Color(0xFF42A5F5),
      'Tools' => const Color(0xFFFB8C00),
      'Others' => AppColors.primaryMuted,
      _ => AppTheme.tradeColor,
    };
  }

  Widget _buildMyTradesTab() {
    if (_isMyLoading) return const BybataLoader();
    return RefreshIndicator(
      onRefresh: _loadMyActiveTrades,
      child: _myActiveTrades.isEmpty
          ? HubMineEmptyState(
              accentColor: AppTheme.tradeColor,
              icon: Icons.swap_horiz_rounded,
              title: 'No trades yet',
              subtitle: 'List something you want to swap. Your active listings show up here.',
              buttonLabel: 'Post a trade',
              hints: const [
                'Add photos for faster matches',
                'Set pickup or delivery preferences',
              ],
              onCreate: () => _openCreateTrade(),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                ..._myActiveTrades.map((t) => _buildTradeCard(t)),
                HubMineCreateBar(
                  accentColor: AppTheme.tradeColor,
                  label: 'Post another trade',
                  onTap: () => _openCreateTrade(),
                ),
              ],
            ),
    );
  }

  Widget _buildDraftTab() {
    if (_draftLoading) return const BybataLoader();
    return RefreshIndicator(
      onRefresh: _loadDraftTrades,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          if (_draftTrades.isEmpty)
            _buildEmptyState(
              "No Drafts",
              "Trades saved with BYC promo enabled appear here. Add funds and publish when ready.",
              Icons.drafts_rounded),
          if (_draftTrades.isNotEmpty)
            ..._draftTrades.map((t) => _buildDraftCard(t)),
        ],
      ),
    );
  }

  Widget _buildDraftCard(Map<String, dynamic> trade) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _build3DContainer(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_tradeHasMedia(trade))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 55,
                        height: 55,
                        child: _buildTradeListingThumb(trade),
                      ),
                    )
                  else
                    Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF15101F) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.image_not_supported_rounded, color: Colors.grey[400], size: 20),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trade['title'] ?? 'Untitled',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.2),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _mapCategory(trade['category']),
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _build3DActionButton(
                      onTap: () => _publishDraft(trade),
                      label: "Publish",
                      color: AppTheme.successColor,
                      icon: Icons.publish_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _build3DActionButton(
                      onTap: () => _openPromotionForDraft(trade),
                      label: "Create Ads",
                      color: AppTheme.primaryColor,
                      icon: Icons.campaign_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _build3DActionButton(
                      onTap: () => _editDraft(trade),
                      label: "Edit",
                      color: Colors.orange,
                      icon: Icons.edit_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _build3DActionButton(
                      onTap: () => _deleteDraft(trade['id']),
                      label: "Delete",
                      color: Theme.of(context).colorScheme.error,
                      textColor: Colors.white,
                      icon: Icons.delete_outline_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTradeRequestsTab() {
    if (_offersLoading) return const BybataLoader();
    if (_ongoingOffers.isEmpty) return _buildEmptyState("No Offers", "New barter requests appear here.", Icons.mail_outline_rounded);
    
    return RefreshIndicator(
      onRefresh: _loadOngoingOffers,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _ongoingOffers.length,
        itemBuilder: (context, index) {
          final offer = _ongoingOffers[index];
          final offerId = offer['id']?.toString() ?? 'offer-$index';
          return _wrapOfferHighlight(
            offerId: offerId,
            tradeId: offer['tradeId']?.toString() ?? '',
            child: _buildOfferCard(offer),
          );
        },
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final bool isReceived = offer['direction'] == 'received';
    final String status = (offer['status'] ?? 'pending').toString().toLowerCase().replaceAll('_', '');
    final bool isCashOffer = offer['amount'] != null && offer['amount'].toString().isNotEmpty;
    final (statusLabel, statusColor) = trade_models.getOfferStatusDisplayFromRaw(
      offer['status'],
      isReceived: isReceived,
      isCashOffer: isCashOffer,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _build3DContainer(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isReceived ? "Incoming Offer" : "Outgoing Offer",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.tradeColor,
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.copy_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                        onPressed: () => _copyOfferDetails(offer),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      _buildStatusBadge(statusLabel, statusColor),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text("Trade: ${offer['tradeTitle']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.1)),
              if (isCashOffer)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    "Offer: ${offer['amount']} BYC",
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              
              if (isReceived && status == 'pending') ...[
                 Row(
                  children: [
                    Expanded(child: _build3DActionButton(
                      onTap: () => _rejectOffer(offer['id'].toString()), 
                      label: "Decline", 
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      textColor: Theme.of(context).colorScheme.error,
                      icon: Icons.close_rounded,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _build3DActionButton(
                      onTap: () => _openExistingNegotiation(offer),
                      label: "Negotiate", 
                      color: AppTheme.primaryColor,
                      icon: Icons.forum_rounded,
                    )),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _build3DActionButton(
                      onTap: () => _acceptOffer(offer['id'].toString()), 
                      label: "Accept Offer", 
                      color: AppTheme.successColor,
                      icon: Icons.check_rounded,
                    )),
                  ],
                )
              ] else if (!isReceived && status == 'acceptedawaitingfinalization' && isCashOffer) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Owner accepted! Click Finalize to complete payment transfer.",
                          style: TextStyle(color: Colors.orange[700], fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _build3DActionButton(
                      onTap: () => _finalizeOffer(offer['id'].toString()), 
                      label: "Finalize Payment", 
                      color: AppTheme.successColor,
                      icon: Icons.check_circle_rounded,
                    )),
                  ],
                )
              ] else if (!isReceived && status == 'pending') ...[
                Row(
                  children: [
                    Expanded(child: _build3DActionButton(
                      onTap: () => _openExistingNegotiation(offer),
                      label: "View Negotiation",
                      color: AppTheme.primaryColor,
                      icon: Icons.chat_bubble_rounded,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _build3DActionButton(
                      onTap: () => _withdrawOffer(offer['id'].toString()),
                      label: "Withdraw",
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      textColor: Colors.orange,
                      icon: Icons.undo_rounded,
                    )),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: _build3DActionButton(
                      onTap: () => _openExistingNegotiation(offer),
                      label: "View Negotiation",
                      color: AppTheme.primaryColor,
                      icon: Icons.chat_bubble_outline_rounded,
                    )),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTradeHistoryTab() {
    if (_historyLoading && _completedTrades.isEmpty) {
      return const BybataLoader();
    }
    return RefreshIndicator(
      onRefresh: _loadTradeHistory,
      child: _completedTrades.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                _buildEmptyState(
                  'No Completed Trades Yet',
                  'Your finished trades will appear here.',
                  Icons.history_rounded,
                ),
              ],
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                ..._completedTrades.map((trade) => _buildTradeCard(trade)),
              ],
            ),
    );
  }

  Future<void> _openExistingNegotiation(Map<String, dynamic> offer) async {
    final tradeId = (offer['tradeId'] ?? '').toString();
    final offerId = ((offer['id'] ?? offer['offerId']) ?? '').toString();
    if (tradeId.isEmpty || offerId.isEmpty) {
      AppToast.show(context, 'Missing trade or offer ID.');
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BybataLoader(),
      );

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final me = auth.currentUser;
      if (me == null) {
        Navigator.pop(context);
        return;
      }

      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final tradeRes = await backend.getTrade(tradeId);
      if (tradeRes == null) {
        Navigator.pop(context);
        AppToast.show(context, 'Trade not found.');
        return;
      }

      final tradeJson = Map<String, dynamic>.from(
        (tradeRes['data'] is Map) ? tradeRes['data'] as Map : tradeRes as Map,
      );
      final targetTrade = _createTradeObjectFromApiResponse(tradeJson);

      Navigator.pop(context);
      if (!mounted) return;

      final isReceived = offer['direction'] == 'received';
      final initiatorUserId = isReceived
          ? (offer['bidderId'] ?? '').toString()
          : (offer['ownerId'] ?? tradeJson['owner']?['id'] ?? '').toString();
      final initiatorName = isReceived
          ? (offer['bidderName'] ?? 'User').toString()
          : (offer['ownerName'] ?? 'Owner').toString();

      trade_models.Trade? initialOfferedTrade;
      final offeredTradeMap = offer['offeredTrade'];
      if (offeredTradeMap is Map) {
        try {
          initialOfferedTrade = trade_models.Trade.fromJson(Map<String, dynamic>.from(offeredTradeMap));
        } catch (_) {
          try {
            initialOfferedTrade = _createTradeObjectFromApiResponse(Map<String, dynamic>.from(offeredTradeMap));
          } catch (_) {}
        }
      }

      await GuardedNavigator.push(context,
        MaterialPageRoute(
          builder: (_) => ExistingOfferNegotiationScreen(
            targetTrade: targetTrade,
            offerId: offerId,
            initiatorUserId: initiatorUserId,
            initiatorName: initiatorName,
            initialOfferedTrade: initialOfferedTrade,
            isReceived: isReceived,
          ),
        ),
      );
      _loadOngoingOffers();
    } catch (e) {
      Navigator.pop(context);
      AppToast.show(context, 'Failed to open negotiation: $e');
    }
  }

  void _navigateToTradeDetails(Map<String, dynamic> trade, {Rect? origin}) {
    final id = (trade['id'] ?? '').toString();
    if (id.isEmpty) return;
    final tab = _tabController.index;
    if (tab == 1) {
      _openLivingTrades(_myActiveTrades, id, mine: true, origin: origin);
      return;
    }
    if (tab == 4) {
      _openLivingTrades(_completedTrades, id, mine: true, origin: origin);
      return;
    }
    final inBrowse = _availableTrades.any((item) => item['id']?.toString() == id);
    _openLivingTrades(
      inBrowse ? _availableTrades : <Map<String, dynamic>>[trade],
      id,
      mine: trade['ownerFirstName']?.toString() == 'Me',
      origin: origin,
    );
  }

  void _openLivingTrades(
    List<Map<String, dynamic>> maps,
    String id, {
    required bool mine,
    Rect? origin,
  }) {
    final userId = context.read<AuthProvider>().currentUser?.id;
    final slides = maps
        .map(
          (item) => LivingSlideMapper.fromTradeMap(
            item,
            currentUserId: userId,
            treatAsMine: mine,
          ),
        )
        .where((slide) => slide.id.isNotEmpty)
        .toList();
    if (slides.isEmpty) return;
    final index = slides.indexWhere((slide) => slide.id == id);
    _offerDraft.clear();
    setState(() => _livingSlides = slides);
    _living.open(slides[index < 0 ? 0 : index].id, origin: origin);
  }

  Future<void> _maybeOpenStageFocus() async {
    final pending = _pendingFocus?.trim();
    final id = (pending != null && pending.isNotEmpty)
        ? pending
        : widget.stageFocusId?.trim();
    if (id == null || id.isEmpty || _openedStageFocus || !mounted) return;
    if (_availableTrades.any((item) => item['id']?.toString() == id)) {
      _openedStageFocus = true;
      _openLivingTrades(_availableTrades, id, mine: false);
      return;
    }
    if (_isLoading) return;
    _openedStageFocus = true;
    final raw = await context.read<TradeBackendProvider>().getTrade(id);
    if (!mounted || raw == null) return;
    _openLivingTrades([Map<String, dynamic>.from(raw)], id, mine: false);
  }

  Future<StageCommitResult?> _commitTradeOffer(LivingSlide slide) async {
    if (AppRoutes.requireSignIn(context)) return null;
    final backend = context.read<TradeBackendProvider>();
    final note = _offerDraft.message.text.trim();
    final isItem = _offerDraft.isItemOffer;

    if (isItem) {
      final offered = _offerDraft.offeredTradeId;
      if (offered == null || offered.isEmpty) {
        HapticUtils.error();
        AppToast.show(context, 'Pick one of your items');
        return null;
      }
    } else {
      final amount = double.tryParse(_offerDraft.amount.text.trim());
      if (amount == null || amount <= 0) {
        HapticUtils.error();
        AppToast.show(context, 'Enter a cash amount in BYC');
        return null;
      }
    }

    final uneven = isItem &&
        _offerDraft.mineValue != null &&
        _offerDraft.numberLabel.isNotEmpty &&
        _offerDraft.numberLabel != 'Even';
    final ok = await backend.createOffer(
      slide.id,
      offeredTradeId: isItem ? _offerDraft.offeredTradeId : null,
      amount: isItem ? null : _offerDraft.amount.text.trim(),
      message: note.isEmpty ? null : note,
    );
    if (!mounted) return null;
    if (!ok) {
      HapticUtils.error();
      AppToast.show(context, backend.error ?? 'Could not send the offer');
      return null;
    }
    HapticUtils.heavy();
    _offerDraft.clear();
    final offerId = backend.lastCreatedOfferId;
    if (offerId != null && (uneven || !isItem)) {
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (!mounted) return;
        _openExistingNegotiation({
          'id': offerId,
          'tradeId': slide.id,
          'direction': 'sent',
          'ownerId': slide.ownerId,
          'ownerName': slide.ownerName,
        });
      });
      if (uneven) {
        return const StageCommitResult('Offer sent · even it with PayPal');
      }
      return const StageCommitResult('Cash offer sent');
    }
    return const StageCommitResult('Offer sent');
  }

  Future<void> _editTradeSlide(LivingSlide slide) async {
    if (AppRoutes.requireSignIn(context)) return;
    final raw = await context.read<TradeBackendProvider>().getTrade(slide.id);
    if (!mounted || raw == null) {
      if (mounted) AppToast.show(context, 'Could not open this trade');
      return;
    }
    try {
      final trade = trade_models.Trade.fromJson(Map<String, dynamic>.from(raw));
      if (!mounted) return;
      AppRoutes.navigateToEditTrade(context, trade);
    } catch (_) {
      if (mounted) AppToast.show(context, 'Could not open this trade');
    }
  }

  Future<void> _messageTradeSlide(LivingSlide slide) async {
    if (AppRoutes.requireSignIn(context)) return;
    var partnerId = slide.ownerId;
    var partnerName = slide.ownerName;
    trade_models.Trade? trade;
    final raw = await context.read<TradeBackendProvider>().getTrade(slide.id);
    if (!mounted) return;
    if (raw != null) {
      try {
        trade = trade_models.Trade.fromJson(Map<String, dynamic>.from(raw));
        partnerId = trade.owner.id;
        partnerName = trade.owner.name;
      } catch (_) {}
    }
    if (partnerId.isEmpty) {
      AppToast.show(context, 'Could not open chat');
      return;
    }
    await GuardedNavigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TradeChatScreen(
          trade: trade,
          partnerId: partnerId,
          partnerName: partnerName.isEmpty ? 'Member' : partnerName,
        ),
      ),
    );
  }

  void _shareTrade(Map<String, dynamic> trade) {
    final id = (trade['id'] ?? '').toString();
    final title = (trade['title'] ?? 'Untitled').toString();
    if (id.isEmpty) return;
    ShareUtils.shareTrade(context, id: id, title: title);
  }

  Future<void> _acceptOffer(String offerId) async {
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final success = await backend.acceptOffer(offerId);
      if (success && mounted) {
        AppToast.success(context, 'Offer accepted!', title: 'Success');
        _loadOngoingOffers(); 
      } else {
        _showErrorSnackbar(backend.error ?? "Failed to accept");
      }
    } catch (e) {
      _showErrorSnackbar("Error: $e");
    }
  }

  Future<void> _finalizeOffer(String offerId) async {
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final success = await backend.finalizeOffer(offerId);
      if (success && mounted) {
        AppToast.success(context, 'Payment finalized — trade complete!', title: 'Success');
        _loadOngoingOffers();
        _loadTradeHistory();
      } else {
        _showErrorSnackbar(backend.error ?? "Failed to finalize");
      }
    } catch (e) {
      _showErrorSnackbar("Error: $e");
    }
  }

  Future<void> _rejectOffer(String offerId) async {
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final success = await backend.rejectOffer(offerId);
      if (success && mounted) {
        AppToast.warning(context, 'Offer declined');
        _loadOngoingOffers(); 
      } else {
        _showErrorSnackbar(backend.error ?? "Failed to reject");
      }
    } catch (e) {
      _showErrorSnackbar("Error: $e");
    }
  }

  void _copyOfferDetails(Map<String, dynamic> offer) {
    final (label, _) = trade_models.getOfferStatusDisplayFromRaw(
      offer['status'],
      isReceived: offer['direction'] == 'received',
      isCashOffer: offer['amount'] != null && offer['amount'].toString().isNotEmpty,
    );
    final lines = [
      'Trade: ${offer['tradeTitle'] ?? '—'}',
      'Status: $label',
      '${offer['direction'] == 'received' ? 'From' : 'To'}: ${offer['bidderName'] ?? offer['ownerName'] ?? '—'}',
      if (offer['amount'] != null && offer['amount'].toString().isNotEmpty)
        'Amount: ${offer['amount']} BYC',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) {
      AppToast.show(context, 'Copied to clipboard');
    }
  }

  Future<void> _withdrawOffer(String offerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Withdraw Offer', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Are you sure you want to withdraw this offer? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Withdraw', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final success = await backend.withdrawOffer(offerId);
      if (success && mounted) {
        AppToast.warning(context, 'Offer withdrawn');
        _loadOngoingOffers();
      } else {
        _showErrorSnackbar(backend.error ?? "Failed to withdraw");
      }
    } catch (e) {
      _showErrorSnackbar("Error: $e");
    }
  }

  Future<void> _loadTradeData({bool refresh = true}) async {
    if (refresh) {
      _browsePage = 1;
      _browseHasMore = true;
      if (mounted) {
        setState(() {
          _isLoading = true;
          _browseLoadError = null;
        });
      }
    }
    if (mounted) setState(() => _adFeedRefresh++);
    try {
      final tradeProvider = Provider.of<TradeBackendProvider>(context, listen: false);
      final res = await tradeProvider.listMyTrades(
        ownerId: '',
        status: 'OPEN',
        category: trade_models.browseChipToApiCategory(_selectedCategory),
        page: _browsePage,
        size: 20,
        forceRefresh: refresh,
      );
      if (!mounted) return;
      final batch = (res['items'] as List? ?? []).whereType<Map>().map((t) => Map<String, dynamic>.from(t)).toList();
      final total = (res['total'] as num?)?.toInt() ?? batch.length;
      setState(() {
        if (refresh) {
          _availableTrades = batch;
        } else {
          final seen = _availableTrades.map((e) => e['id']).toSet();
          for (final t in batch) {
            if (!seen.contains(t['id'])) _availableTrades.add(t);
          }
        }
        _browseHasMore = _browsePage * 20 < total;
        _isLoading = false;
        _browseLoadError = null;
      });
      _resolveImages(_availableTrades);
      await _maybeOpenStageFocus();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _browseLoadError = NetworkErrorMessage.forListingLoad(e);
        });
      }
      await _maybeOpenStageFocus();
    }
  }

  Future<void> _loadMoreBrowseTrades() async {
    if (!_browseHasMore || _isLoading) return;
    _browsePage += 1;
    await _loadTradeData(refresh: false);
  }

  Future<void> _loadMyActiveTrades() async {
    setState(() => _isMyLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final tradeProvider = Provider.of<TradeBackendProvider>(context, listen: false);
      if (auth.currentUser == null) return;
      
      final res = await tradeProvider.listMyTrades(ownerId: auth.currentUser!.id, status: 'OPEN', page: 1, size: 20);
      if (mounted) {
        setState(() {
          _myActiveTrades = (res['items'] as List? ?? []).map<Map<String, dynamic>>((t) => {
            'id': t['id'], 'title': t['title'], 'category': _mapCategory(t['category']),
            'time': 'Active',
            'mediaKeys': t['mediaKeys'],
            'mediaType': t['mediaType'],
            'videoKey': t['videoKey'],
            'thumbnailKey': t['thumbnailKey'],
            'imageUrl': null,
            'ownerFirstName': 'Me',
            'trustScore': 1.0,
          }).toList();
        });
      }
      _resolveImages(_myActiveTrades);
    } finally { if(mounted) setState(() => _isMyLoading = false); }
  }

  Future<void> _loadDraftTrades() async {
    setState(() => _draftLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final tradeProvider = Provider.of<TradeBackendProvider>(context, listen: false);
      if (auth.currentUser == null) {
        if (mounted) setState(() => _draftTrades = []);
        return;
      }

      final res = await tradeProvider.listMyTrades(
        ownerId: auth.currentUser!.id,
        status: 'DRAFT',
        page: 1,
        size: 20,
      );
      if (mounted) {
        setState(() {
          _draftTrades = (res['items'] as List? ?? []).map<Map<String, dynamic>>((t) => {
            'id': t['id'],
            'title': t['title'],
            'category': _mapCategory(t['category']),
            'mediaKeys': t['mediaKeys'],
            'mediaType': t['mediaType'],
            'videoKey': t['videoKey'],
            'thumbnailKey': t['thumbnailKey'],
            'imageUrl': null,
          }).toList();
        });
        _resolveImages(_draftTrades);
      }
    } finally {
      if (mounted) setState(() => _draftLoading = false);
    }
  }

  Future<void> _loadOngoingOffers() async {
    setState(() => _offersLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final me = auth.currentUser;
      if (me == null) {
         setState(() { _ongoingOffers = []; _offersLoading = false; });
         return;
      }

      final List<Map<String, dynamic>> aggregated = [];
      try {
        final res = await backend.listMyOffers(page: 1, size: 50);
        final items = (res['items'] as List?) ?? [];
        for (final raw in items) {
          if (raw is! Map) continue;
          final o = Map<String, dynamic>.from(raw);
          if (!_isOfferVisibleInOffersTab(o['status'])) continue;
          final trade = o['trade'] is Map ? Map<String, dynamic>.from(o['trade'] as Map) : null;
          final bidder = o['bidder'] is Map ? o['bidder'] as Map : null;
          final owner = trade?['owner'] is Map ? trade!['owner'] as Map : null;
          final direction = (o['direction'] ?? (o['bidderId']?.toString() == me.id ? 'sent' : 'received')).toString();
          aggregated.add({
            'id': o['id'] ?? o['offerId'],
            'tradeId': o['tradeId'] ?? trade?['id'],
            'tradeTitle': o['tradeTitle'] ?? trade?['title'] ?? 'Trade',
            'amount': o['amount'],
            'status': o['status'],
            'direction': direction,
            'bidderId': o['bidderId'],
            'bidderName': o['bidderName'] ??
                bidder?['profile']?['displayName'] ??
                bidder?['displayName'] ??
                'User',
            'ownerId': o['ownerId'] ?? trade?['ownerId'] ?? owner?['id'],
            'ownerName': o['ownerName'] ??
                owner?['profile']?['displayName'] ??
                owner?['displayName'] ??
                'Owner',
            'message': (o['message'] ?? '').toString(),
            'createdAt': o['createdAt'],
            'offeredTrade': o['offeredTrade'],
          });
        }
      } catch (_) {}

      aggregated.sort((a, b) {
        final aAt = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(0);
        final bAt = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(0);
        return bAt.compareTo(aAt);
      });

      if (mounted) {
        setState(() => _ongoingOffers = aggregated);
        _maybeScrollToOfferHighlight();
      }
    } finally { if(mounted) setState(() => _offersLoading = false); }
  }

  Future<void> _loadTradeHistory() async {
    setState(() => _historyLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final tradeProvider = Provider.of<TradeBackendProvider>(context, listen: false);
      if (auth.currentUser == null) {
        setState(() { _completedTrades = []; _historyLoading = false; });
        return;
      }
      
      final res = await tradeProvider.listMyTrades(ownerId: auth.currentUser!.id, status: 'CLOSED', page: 1, size: 20);
      if (mounted) {
        setState(() {
          _completedTrades = (res['items'] as List? ?? []).map<Map<String, dynamic>>((t) => {
             'id': t['id'], 'title': t['title'],
             'image': t['mediaKeys']?.isNotEmpty ?? false ? t['mediaKeys'][0] : null,
             'closedAt': t['closedAt'], 'acceptedOfferId': t['acceptedOfferId'],
             'category': _mapCategory(t['category'] ?? 'others'), 'mediaKeys': t['mediaKeys'],
          }).toList();
        });
        _resolveImages(_completedTrades);
      }
    } finally { if (mounted) setState(() => _historyLoading = false); }
  }

  bool _tradeHasMedia(Map<String, dynamic> trade) {
    final keys = trade['mediaKeys'];
    return (keys is List && keys.isNotEmpty) || (trade['videoKey']?.toString().isNotEmpty ?? false);
  }

  Future<void> _resolveImages(List<Map<String, dynamic>> listToUpdate) async {
    MediaResolver.seedUrlsFromListingMaps(listToUpdate);
    for (var t in listToUpdate) {
      final preview = t['previewImageUrl'] ?? t['thumbnailUrl'];
      if (preview != null && preview.toString().isNotEmpty) {
        if (mounted) setState(() => t['imageUrl'] = preview);
        continue;
      }
      if (t['videoKey']?.toString().isNotEmpty ?? false) continue;
      if (t['mediaKeys'] != null && (t['mediaKeys'] as List).isNotEmpty) {
        try {
          final key = t['mediaKeys'][0]?.toString();
          final resolved = await MediaResolver.resolveUrl(key);
          if (mounted) setState(() => t['imageUrl'] = resolved);
        } catch (_) {}
      }
    }
  }

  Widget _buildTradeCard(Map<String, dynamic> trade) {
    return Builder(
      builder: (cardContext) {
        final origin = stageCardOrigin(cardContext);
        return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _build3DContainer(
        child: DebouncedTap(
          onTap: () => _navigateToTradeDetails(trade, origin: origin),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildTradeListingThumb(trade),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trade['title'] ?? 'Untitled', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                          const SizedBox(height: 2),
                          Text(
                            "by ${trade['ownerFirstName'] ?? 'User'}",
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(trade['category'] ?? 'General', Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
              _buildCardFooter(trade),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildTradeListingThumb(Map<String, dynamic> trade) {
    final media = ListingMediaFields.fromJson(trade);
    if (media.hasMedia) {
      return ListingMediaThumb(media: media, size: 55);
    }
    return _build3DImageThumb(trade['imageUrl'] as String?);
  }

  Widget _build3DImageThumb(String? url) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 55, height: 55,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: url != null
            ? CachedMediaImage(
                mediaKey: url,
                directUrl: url.startsWith('http') ? url : null,
                fit: BoxFit.cover,
                optimizedForFeed: true,
                width: 55,
                height: 55,
                errorWidget: const Icon(Icons.image_outlined, color: Colors.grey, size: 20),
              )
            : const Icon(Icons.image_outlined, color: Colors.grey, size: 20),
      ),
    );
  }

  Widget _buildCardFooter(Map<String, dynamic> trade) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = (trade['historyRole'] as String?) ?? '';
    final histStatus = (trade['historyStatus'] as String?) ?? '';
    final isHistory = role.isNotEmpty || histStatus.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
        border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03))),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, size: 14, color: scheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 6),
          Text(trade['time'] ?? 'Active', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
          if (isHistory) ...[
            const SizedBox(width: 10),
            _buildHistoryBadges(role, histStatus),
          ],
          const Spacer(),
          GestureDetector(
            onTap: () => _shareTrade(trade),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.share_outlined, size: 18, color: scheme.primary),
            ),
          ),
          DebouncedTap(
            onTap: () => _navigateToTradeDetails(trade, origin: stageCardOrigin(context)),
            child: Row(
              children: [
                Text("View", style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w900, fontSize: 13)),
                Icon(Icons.chevron_right_rounded, color: scheme.primary, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryBadges(String role, String status) {
    final scheme = Theme.of(context).colorScheme;
    Color rColor = scheme.primary; String rLabel = 'Participant';
    if (role == 'OWNER') { rColor = scheme.primary; rLabel = 'Owner'; }
    else if (role == 'BIDDER') { rColor = AppTheme.karmaColor; rLabel = 'Bidder'; }
    else if (role == 'OWNER_BIDDER') { rColor = AppTheme.successColor; rLabel = 'Owner & Bidder'; }

    Color sColor = AppTheme.successColor; String sLabel = 'Completed';
    if (status == 'CANCELLED') { sColor = scheme.error; sLabel = 'Cancelled'; }

    return Row(
      children: [
        _buildStatusBadge(rLabel, rColor),
        const SizedBox(width: 4),
        _buildStatusBadge(sLabel, sColor),
      ],
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Text(text.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  Widget _build3DActionButton({
    required VoidCallback onTap,
    required String label,
    Color? color,
    Color? textColor,
    IconData? icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedColor = color ?? scheme.primary;
    final resolvedTextColor = textColor ?? Colors.white;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: color == Colors.transparent ? null : [
          BoxShadow(color: resolvedColor.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: resolvedColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap, 
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14), 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                if (icon != null) ...[
                  Icon(icon, color: resolvedTextColor, size: 18),
                  const SizedBox(width: 6),
                ],
                Text(label, style: TextStyle(color: resolvedTextColor, fontWeight: FontWeight.w900, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String t, String d, IconData i) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(i, size: 56, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
              const SizedBox(height: 16),
              Text(t, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface, letterSpacing: -0.2)),
              const SizedBox(height: 4),
              Text(d, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
  
  Widget _buildSmartMatchBanner() {
    return _build3DContainer(
      color: AppTheme.primaryColor.withValues(alpha: 0.08),
      radius: 16,
      child: ListTile(
        leading: Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryColor),
        title: const Text("Smart Match Enabled", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: -0.1)),
        subtitle: const Text("Recommendations based on your profile mapping choices", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ),
    );
  }

  void _publishDraft(Map<String, dynamic> trade) async {
    final tradeId = trade['id']?.toString() ?? '';
    if (tradeId.isEmpty) return;
    final enableBYCPromotion = trade['enableBYCPromotion'] == true;

    try {
      if (enableBYCPromotion) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final walletService = WalletService();
        if (auth.currentUser != null && !walletService.isInitialized) {
          await walletService.initializeWallet(auth.currentUser!.id);
        }
        final boostOk = await walletService.tryPurchaseDefaultBoostForTrade(tradeId, trade['title']?.toString() ?? 'Trade');
        if (!boostOk && mounted) {
          final msg = walletService.error ?? 'Insufficient funds';
          final choice = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cannot Publish Yet'),
              content: Text(
                '$msg\n\n'
                'You have two options:\n'
                '1. Add funds and create ads in Promotion Center\n'
                '2. Edit this trade and turn off BYC Promo to publish without ads',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, 'edit'), child: const Text('Edit & Disable Promo')),
                TextButton(onPressed: () => Navigator.pop(ctx, 'promo'), child: const Text('Go to Promotion Center')),
                TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
              ],
            ),
          );
          if (choice == 'edit') _editDraft(trade);
          else if (choice == 'promo') GuardedNavigator.push(context, MaterialPageRoute(builder: (_) => const MainNavigation(initialScreen: 'wallet')));
          return;
        }
      }

      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final success = await backend.publishDraft(tradeId);
      if (success && mounted) {
        AppToast.success(context, "Draft published! Trade is now live.");
        _loadDraftTrades();
        _loadMyActiveTrades();
      } else {
        _showErrorSnackbar(backend.error ?? "Failed to publish");
      }
    } catch (e) {
      _showErrorSnackbar("Error: $e");
    }
  }

  void _openPromotionForDraft(Map<String, dynamic> trade) {
    GuardedNavigator.push(context, 
      MaterialPageRoute(builder: (_) => const PromotionCenterScreen(initialType: 'trade')),
    );
  }

  void _editDraft(Map<String, dynamic> trade) {
    try {
      final t = trade_models.Trade.fromJson(Map<String, dynamic>.from(trade));
      AppRoutes.navigateToEditTrade(context, t);
    } catch (_) {
      _showErrorSnackbar("Could not open edit");
    }
  }

  Future<void> _deleteDraft(String tradeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Draft"),
        content: const Text("Are you sure you want to delete this draft? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final success = await backend.deleteTrade(tradeId);
      if (success && mounted) {
        AppToast.show(context, "Draft deleted.");
        _loadDraftTrades();
      } else {
        _showErrorSnackbar(backend.error ?? "Failed to delete");
      }
    } catch (e) {
      _showErrorSnackbar("Error: $e");
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
  
  trade_models.Trade _createTradeObjectFromApiResponse(Map<String, dynamic> apiResponse) {
    return trade_models.Trade.fromJson(apiResponse);
  }

  void _showErrorSnackbar(String m) => AppToast.error(context, m);
  String _extractOwnerFirstName(Map? o, Map? p) => p?['firstName']?.toString() ?? o?['name']?.toString().split(' ').first ?? "User";
  String _extractOwnerName(Map? o, Map? p) => p?['displayName']?.toString() ?? o?['name']?.toString() ?? "User";
  String _mapCategory(dynamic c) => trade_models.tradeCategoryDisplayName(c);

  List<String> _parseImages(dynamic images) => images == null ? [] : (images is List ? images.map((i) => i.toString()).toList() : []);
  trade_models.TradeCategory _parseCategory(dynamic c) => trade_models.TradeCategory.others;
  double _parseRating(dynamic r) => r == null ? 4.0 : (r is num ? r.toDouble() : double.tryParse(r.toString()) ?? 4.0);
  DateTime _parseDate(dynamic d) => d == null ? DateTime.now() : (d is DateTime ? d : DateTime.tryParse(d.toString()) ?? DateTime.now());
  trade_models.TradeStatus _parseStatus(dynamic s) => trade_models.TradeStatus.active;
  trade_models.ItemCondition _parseCondition(dynamic c) => trade_models.ItemCondition.good;
}