import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/widgets/hub_screen_top_bar.dart';
import '../../../features/settings/widgets/settings_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/network_error_message.dart';
import '../../../core/widgets/ad_placement_section.dart';
import '../../../core/widgets/hub_mine_empty_state.dart';
import '../../../core/widgets/debounced_tap.dart';
import '../../../core/navigation/route_observer.dart';
import '../../../core/utils/listing_video_handoff.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/guest_browse_helpers.dart';
import '../models/gift_models.dart' as gift_models;
import '../providers/gift_provider.dart';
import '../providers/gift_provider.dart' show GiftClaim;
import '../../chat/providers/chat_provider.dart';
import '../../chat/models/chat_conversation.dart';
import '../../../core/constants/app_constants.dart';
import 'gift_request_chat_screen.dart';
import 'my_gifts_screen.dart';
import 'gift_details_loader.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../trade/models/trade_models.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import '../../feed/mappers/social_listing_mapper.dart';
import '../../feed/models/social_listing_card_data.dart';
import '../../feed/widgets/social_feed_list.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class GiftingScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? highlightRequestId;
  final String? highlightGiftId;

  const GiftingScreen({
    super.key,
    this.initialTabIndex = 0,
    this.highlightRequestId,
    this.highlightGiftId,
  });

  @override
  State<GiftingScreen> createState() => _GiftingScreenState();
}

class _GiftingScreenState extends State<GiftingScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  int _selectedTab = 0;
  bool _requestsDataLoaded = false;
  bool _historyDataLoaded = false;
  gift_models.KarmaLevel? _selectedKarmaLevel; 
  bool _showExpiringSoon = false; 
  bool _showChainGifts = false; 
  bool _showSurpriseGifts = false; 
  Timer? _countdownTimer; 
  final Map<String, int> _remainingSeconds = {}; 
  int _adFeedRefresh = 0;
  final Map<String, GlobalKey> _requestHighlightKeys = {};
  final Map<String, GlobalKey> _giftGroupHighlightKeys = {};
  String? _activeHighlightRequestId;
  String? _activeHighlightGiftId;
  bool _highlightScrollAttempted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index;
      });
      if (_tabController.index == 2 && !_requestsDataLoaded) {
        _requestsDataLoaded = true;
        final giftProvider = Provider.of<GiftProvider>(context, listen: false);
        giftProvider.loadGiftRequests(
          force: false,
          status: gift_models.GiftRequestStatus.pending,
        );
        giftProvider.loadGiftHistory(force: false);
      }
    });
    _startCountdownTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _applyInitialTab();
    });
  }

  GlobalKey _keyForRequest(String requestId) {
    return _requestHighlightKeys.putIfAbsent(requestId, GlobalKey.new);
  }

  GlobalKey _keyForGiftGroup(String giftId) {
    return _giftGroupHighlightKeys.putIfAbsent(giftId, GlobalKey.new);
  }

  void _maybeScrollToHighlight(
    List<gift_models.GiftRequest> requests,
    bool isLoading,
  ) {
    if (_highlightScrollAttempted || isLoading) return;

    final requestId = widget.highlightRequestId?.trim();
    final giftId = widget.highlightGiftId?.trim();
    if ((requestId == null || requestId.isEmpty) &&
        (giftId == null || giftId.isEmpty)) {
      return;
    }

    String? scrollTargetRequestId;
    String? scrollTargetGiftId;

    if (requestId != null && requestId.isNotEmpty) {
      if (requests.any((r) => r.id == requestId)) {
        scrollTargetRequestId = requestId;
      } else if (giftId != null && giftId.isNotEmpty) {
        scrollTargetGiftId = giftId;
      }
    } else if (giftId != null && giftId.isNotEmpty) {
      if (requests.any((r) => r.giftId == giftId)) {
        scrollTargetGiftId = giftId;
      }
    }

    if (scrollTargetRequestId == null && scrollTargetGiftId == null) {
      if (!isLoading) _highlightScrollAttempted = true;
      return;
    }

    _highlightScrollAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = scrollTargetRequestId != null
          ? _requestHighlightKeys[scrollTargetRequestId]?.currentContext
          : _giftGroupHighlightKeys[scrollTargetGiftId]?.currentContext;
      if (targetContext == null) return;

      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        alignment: 0.12,
      );
      setState(() {
        _activeHighlightRequestId = scrollTargetRequestId;
        _activeHighlightGiftId = scrollTargetGiftId;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          _activeHighlightRequestId = null;
          _activeHighlightGiftId = null;
        });
      });
    });
  }

  Widget _wrapRequestHighlight(String requestId, Widget child) {
    final highlighted = _activeHighlightRequestId == requestId;
    return AnimatedContainer(
      key: _keyForRequest(requestId),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: EdgeInsets.only(bottom: highlighted ? 6 : 0),
      padding: highlighted ? const EdgeInsets.all(8) : EdgeInsets.zero,
      decoration: highlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.1),
            )
          : null,
      child: child,
    );
  }

  Widget _wrapGiftGroupHighlight(String giftId, Widget child) {
    final highlighted =
        _activeHighlightGiftId == giftId && _activeHighlightRequestId == null;
    return AnimatedContainer(
      key: _keyForGiftGroup(giftId),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: highlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : null,
      child: child,
    );
  }

  void _applyInitialTab() {
    final idx = widget.initialTabIndex.clamp(0, 3);
    if (idx == 0) return;
    _tabController.animateTo(idx);
    if (idx == 2) {
      _requestsDataLoaded = true;
      Provider.of<GiftProvider>(context, listen: false).loadGiftRequests(
        force: true,
        status: gift_models.GiftRequestStatus.pending,
      );
    } else if (idx == 3) {
      _historyDataLoaded = true;
      Provider.of<GiftProvider>(context, listen: false).loadGiftHistory(force: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _tabController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    ListingVideoHandoff.onDetailRouteClosed();
    _loadInitialData(force: true);
    if (_tabController.index == 2) {
      final giftProvider = Provider.of<GiftProvider>(context, listen: false);
      giftProvider.loadGiftRequests(force: true, status: gift_models.GiftRequestStatus.pending);
      giftProvider.loadGiftHistory(force: true);
    }
  }

  void _loadInitialData({bool force = false}) {
    final giftProvider = Provider.of<GiftProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    giftProvider.setExcludedUserId(auth.currentUser?.id);
    final args = ModalRoute.of(context)?.settings.arguments;
    final routeRefresh = args is Map && args['refresh'] == true;
    final createdGiftId =
        args is Map ? args['createdGiftId']?.toString() : null;
    final shouldForce = force || routeRefresh;
    giftProvider.loadGifts(force: shouldForce);
    if (auth.isAuthenticated) {
      giftProvider.loadMyGifts(force: shouldForce);
      if (shouldForce) {
        giftProvider.loadGiftHistory(force: true, size: 50);
      }
    }
    if (createdGiftId != null && createdGiftId.isNotEmpty) {
      giftProvider.refreshGiftById(createdGiftId);
    }
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
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0B12) : const Color(0xFFF8FAFF),
      extendBody: true,
      body: Stack(
        children: [
          Column(
            children: [
              HubScreenTopBar(
                title: 'Gifting Hub',
                onBack: () => Navigator.of(context).pop(),
                trailingActions: [
                  HubTopBarIconButton(
                    icon: Icons.card_giftcard_rounded,
                    onTap: () {
                      if (AppRoutes.requireSignIn(context)) return;
                      GuardedNavigator.push(context, 
                        MaterialPageRoute(
                          builder: (_) => const MyGiftsScreen(),
                        ),
                      );
                    },
                    isDark: isDark,
                    iconColor: AppTheme.giftColor,
                  ),
                ],
              ),
              _buildFluidTabSwitcher(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildAvailableGiftsTab(context),
                    GuestBrowseGate(
                      title: 'Sign in to view your gifts',
                      message: 'Manage gifts you have posted after you sign in.',
                      child: _buildMyGiftsTab(context),
                    ),
                    GuestBrowseGate(
                      title: 'Sign in to view requests',
                      message: 'Approve or track gift requests from your account.',
                      child: _buildGiftRequestsTab(context),
                    ),
                    GuestBrowseGate(
                      title: 'Sign in to view gift history',
                      message: 'See gifts you gave or received after signing in.',
                      child: _buildGiftHistoryTab(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _buildRightMiddleCreateGiftButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildRightMiddleCreateGiftButton() {
    return GestureDetector(
      onTap: () => AppRoutes.navigateToCreateGift(context),
      child: Container(
        height: 130,
        width: 48,
        decoration: BoxDecoration(
          color: AppTheme.giftColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.giftColor.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(-4, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(height: 8),
            RotatedBox(
              quarterTurns: 3,
              child: SizedBox(
                width: 85,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'CREATE GIFT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFluidTabSwitcher() {
    List<String> labels = ["Available", "My Gifts", "Requests", "History"];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 15),
      height: 54,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment(-1.0 + (_tabController.index * (2.0 / (labels.length - 1))), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / labels.length,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1A28) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(labels.length, (index) => Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!guardHubTabForGuest(context, index)) return;
                  _tabController.animateTo(index);
                },
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        color: _tabController.index == index
                            ? (isDark ? Colors.white : const Color(0xFF1C1921))
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                        fontWeight: _tabController.index == index ? FontWeight.w900 : FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableGiftsTab(BuildContext context) {
    return Consumer<GiftProvider>(
      builder: (context, giftProvider, child) {
        final allGifts = giftProvider.gifts;
        final feedItems = allGifts.map(SocialListingMapper.fromGift).toList();

        return SocialFeedList(
          items: feedItems,
          layout: SocialFeedLayout.timeline,
          isLoading: giftProvider.isLoading && allGifts.isEmpty,
          error: giftProvider.giftsError != null && allGifts.isEmpty
              ? giftProvider.giftsError
              : null,
          onRefresh: () async {
            if (mounted) setState(() => _adFeedRefresh++);
            await giftProvider.loadGifts(force: true);
          },
          header: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildQuickFilters(context),
            ),
            const SizedBox(height: 16),
            if (_showSurpriseGifts)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildSurpriseGiftsSection(context)),
            if (_showChainGifts)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildGiftChainsSection(context)),
            if (_showExpiringSoon)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildExpiringSoonSection(context)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSectionHeader(
                'Featured Gifts',
                Icons.local_fire_department_rounded,
                AppTheme.karmaColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildFeaturedGifts(context),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AdPlacementSection(
                key: ValueKey('gift_ads_$_adFeedRefresh'),
                placementKey: 'gift_feed',
                refreshToken: _adFeedRefresh,
                title: 'Sponsored Giveaway',
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSectionHeader(
                'All Gifts (${allGifts.length})',
                Icons.grid_view_rounded,
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          onCardTap: (item) {
            final gift = item.raw?['gift'] as gift_models.Gift?;
            if (gift != null) _showGiftDetails(gift);
          },
          onPrimaryAction: (item) {
            if (AppRoutes.requireSignIn(context)) return;
            final gift = item.raw?['gift'] as gift_models.Gift?;
            if (gift != null) _showGiftDetails(gift);
          },
          emptyAccent: AppTheme.giftColor,
          emptyIcon: Icons.card_giftcard_outlined,
          emptyTitle: 'No gifts found',
          emptySubtitle: 'No gifts available at the moment.',
        );
      },
    );
  }

  Widget _buildMyGiftsTab(BuildContext context) {
    return Consumer<GiftProvider>(
      builder: (context, giftProvider, child) {
        if (giftProvider.isLoading) {
          return const BybataLoader();
        }
        if (giftProvider.myGiftsError != null) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _buildErrorRetry(() => giftProvider.loadMyGifts(), giftProvider.myGiftsError!),
            ],
          );
        }
        if (giftProvider.myGifts.isEmpty) {
          return HubMineEmptyState(
            accentColor: AppTheme.giftColor,
            icon: Icons.card_giftcard_rounded,
            title: 'No gifts yet',
            subtitle: 'Share something kind with your community. Gifts you create appear here.',
            buttonLabel: 'Give a gift',
            hints: const [
              'Random, targeted, or chain gifts',
              'Earn karma when others claim',
            ],
            onCreate: () => AppRoutes.navigateToCreateGift(context),
          );
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(
                  'My Active Gifts',
                  Icons.inventory_2_rounded,
                  AppTheme.giftColor,
                ),
                TextButton(
                  onPressed: () => AppRoutes.navigateToMyGifts(context),
                  child: const Text('Manage All', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            ...giftProvider.myGifts.take(3).map((gift) => _buildRealGiftCard(gift)),
            HubMineCreateBar(
              accentColor: AppTheme.giftColor,
              label: 'Give another gift',
              onTap: () => AppRoutes.navigateToCreateGift(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGiftRequestsTab(BuildContext context) {
    return Consumer<GiftProvider>(
      builder: (context, giftProvider, child) {
        if (giftProvider.giftRequests.isEmpty && !giftProvider.isLoading && !_requestsDataLoaded) {
          _requestsDataLoaded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            giftProvider.loadGiftRequests(status: gift_models.GiftRequestStatus.pending);
          });
        }
        final requests = giftProvider.giftRequests.where((r) => r.status == gift_models.GiftRequestStatus.pending).toList();
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final currentUserId = auth.currentUser?.id;
        final incomingByGift = <String, List<gift_models.GiftRequest>>{};
        final outgoing = <gift_models.GiftRequest>[];
        for (final r in requests) {
          if (r.gift.giver.id == currentUserId) {
            incomingByGift.putIfAbsent(r.giftId, () => []).add(r);
          } else {
            outgoing.add(r);
          }
        }

        _maybeScrollToHighlight(requests, giftProvider.isLoading);
        
        return RefreshIndicator(
          onRefresh: () async {
            await giftProvider.loadGiftRequests(force: true, status: gift_models.GiftRequestStatus.pending);
            await giftProvider.loadGiftHistory(force: true);
          },
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            children: [
              _buildSectionHeader(
                'Recent Requests',
                Icons.mark_email_unread_rounded,
                Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 4),
              Text(
                'See who requested each of your gifts',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (giftProvider.isLoading)
                const BybataLoader()
              else if (giftProvider.requestsError != null)
                _buildErrorRetry(() => giftProvider.loadGiftRequests(force: true), giftProvider.requestsError!)
              else if (requests.isEmpty)
                _buildEmptyState('Inbox is Empty', 'New requests will appear here.', Icons.inbox_rounded)
              else ...[
                if (incomingByGift.isNotEmpty) ...[
                  ...incomingByGift.entries.map((e) => _buildRequestGroupByGift(e.key, e.value)),
                  const SizedBox(height: 16),
                ],
                if (outgoing.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Your Outgoing Requests',
                    Icons.send_rounded,
                    Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  ...outgoing.map(
                    (r) => _wrapRequestHighlight(
                      r.id,
                      _buildRequestCard(r, giftTitle: r.gift.title),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGiftHistoryTab(BuildContext context) {
    return Consumer<GiftProvider>(
      builder: (context, giftProvider, child) {
        if (giftProvider.giftHistory.isEmpty && !giftProvider.isLoading && !_historyDataLoaded) {
          _historyDataLoaded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => giftProvider.loadGiftHistory());
        }
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(
                  'Activity Log',
                  Icons.history_edu_rounded,
                  Theme.of(context).colorScheme.tertiary,
                ),
                TextButton(onPressed: () => AppRoutes.navigateToGiftHistory(context), child: const Text("View All", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 12),
            if (giftProvider.isLoading)
              const BybataLoader()
            else if (giftProvider.historyError != null)
              _buildErrorRetry(() => giftProvider.loadGiftHistory(force: true), giftProvider.historyError!)
            else if (giftProvider.giftHistory.isEmpty)
              _buildEmptyState('No Activity', 'Your history is currently empty.', Icons.history_rounded)
            else
              ...giftProvider.giftHistory.take(10).map((claim) => _buildRealHistoryCard(claim)),
          ],
        );
      },
    );
  }

  Widget _buildRealGiftCard(gift_models.Gift gift) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _build3DContainer(
        child: DebouncedTap(
          onTap: () => _showGiftDetails(gift),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildRaisedIcon(gift.category.icon, gift.category.color),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(gift.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                          const SizedBox(height: 2),
                          Text(
                            "by ${gift.giver.name}",
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppTheme.successColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.15))),
                      child: Text("+${gift.karmaReward} ✨", style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                  border: Border(top: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03))),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 4),
                    Text(gift.location ?? "Nearby", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const Spacer(),
                    Text("View Details", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 13)),
                    Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.primary, size: 16),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestGroupByGift(String giftId, List<gift_models.GiftRequest> requests) {
    if (requests.isEmpty) return const SizedBox.shrink();
    final gift = requests.first.gift;
    return _wrapGiftGroupHighlight(
      giftId,
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _build3DContainer(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildRaisedIcon(gift.category.icon, gift.category.color),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(gift.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('${requests.length} incoming request${requests.length > 1 ? 's' : ''}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildCircleIconButton(Icons.info_outline_rounded, () => _showGiftDetails(gift)),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                ...requests.map((request) => _wrapRequestHighlight(
                  request.id,
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _openRequesterProfile(request.requester),
                              child: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                radius: 18,
                                child: Text(
                                  (request.requester.name.isNotEmpty ? request.requester.name[0] : '?').toUpperCase(),
                                  style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _openRequesterProfile(request.requester),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(request.requester.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                    if (request.message != null && request.message!.isNotEmpty)
                                      Text(request.message!, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text(request.timeAgo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _build3DActionButton(
                              onTap: () => _startGiftChat(request, request.requester.id, request.requester.name),
                              label: 'Chat',
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                              textColor: Theme.of(context).colorScheme.onSurface,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: _build3DActionButton(
                              onTap: () => _approveRequest(request),
                              label: 'Approve',
                              color: AppTheme.successColor,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: _build3DActionButton(
                              onTap: () => _declineRequest(request),
                              label: 'Decline',
                              color: Theme.of(context).colorScheme.error,
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRequesterProfile(gift_models.GiftUser requester) {
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: requester.id,
          user: TradeUser(
            id: requester.id, name: requester.name, username: requester.username,
            avatar: requester.profileImageUrl, rating: requester.rating,
            completedTrades: requester.completedGifts, joinedDate: requester.joinedDate,
            isVerified: requester.isVerified, karmaPoints: requester.karmaPoints, trustBadges: const [],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(gift_models.GiftRequest request, {String? giftTitle}) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isOwner = request.gift.giver.id == auth.currentUser?.id;
    final partnerId = isOwner ? request.requester.id : request.gift.giver.id;
    final partnerName = isOwner ? request.requester.name : request.gift.giver.name;

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
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                    child: Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isOwner ? request.requester.name : "Request Sent", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        Text(giftTitle ?? "Gift", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusPill(request.status.name),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _build3DActionButton(
                    onTap: () => _startGiftChat(request, partnerId, partnerName),
                    label: "Chat",
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                    textColor: Theme.of(context).colorScheme.onSurface,
                  )),
                  if (isOwner) ...[
                    const SizedBox(width: 10),
                    Expanded(child: _build3DActionButton(
                      onTap: () => _approveRequest(request),
                      label: "Approve",
                      color: AppTheme.successColor,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _build3DActionButton(
                      onTap: () => _declineRequest(request),
                      label: "Decline",
                      color: Theme.of(context).colorScheme.error,
                    )),
                  ]
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealHistoryCard(GiftClaim claim) {
    final userId = context.read<AuthProvider>().currentUser?.id ?? '';
    final isReceived = userId.isNotEmpty && claim.isReceivedBy(userId);
    final subtitle = isReceived ? 'From ${claim.gift.giver.name}' : 'Claimed by ${claim.gift.claimedBy?.name ?? 'someone'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _build3DContainer(
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(isReceived ? Icons.card_giftcard_rounded : Icons.volunteer_activism_rounded, color: isReceived ? AppTheme.giftColor : Colors.green, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(claim.gift.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('+${claim.karmaAwarded} ✨', style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w900, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(isReceived ? 'Received' : 'Given', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w700)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showGiftDetails(gift_models.Gift gift) async {
    final result = await GuardedNavigator.pushNamed(context, AppConstants.giftDetailsRoute, arguments: _giftToLegacyMap(gift));
    if (result is Map && result['showRequests'] == true) {
      context.read<GiftProvider>().loadGiftRequests(force: true, status: gift_models.GiftRequestStatus.pending);
      if (mounted) _tabController.animateTo(2);
    }
  }

  Future<void> _approveRequest(gift_models.GiftRequest request) async {
    final ok = await context.read<GiftProvider>().approveGiftRequest(request.id);
    if (!ok || !mounted) return;
    _showApprovalSuccessDialog(request);
  }

  Future<void> _declineRequest(gift_models.GiftRequest request) async {
    final ok = await context.read<GiftProvider>().declineGiftRequest(request.id);
    if (!ok || !mounted) return;
    AppToast.show(context, 'Request declined');
  }

  void _showApprovalSuccessDialog(gift_models.GiftRequest request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ApprovalSuccessDialog(
        requesterName: request.requester.name,
        onOpenChat: () {
          Navigator.pop(context);
          _startGiftChat(request, request.requester.id, request.requester.name);
        },
        onDone: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _startGiftChat(gift_models.GiftRequest request, String partnerId, String partnerName) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser?.id == null) return;
    
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final existing = chatProvider.findConversationInCache(
      contextId: request.giftId,
      partnerId: partnerId,
    );
    
    if (mounted) {
      GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => GiftRequestChatScreen(
        request: request, partnerId: partnerId, partnerName: partnerName, existingConversation: existing,
      )));
    }
  }

  Widget _buildRaisedIcon(IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15101F) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.1), offset: const Offset(0, 4), blurRadius: 10),
        ],
      ),
      child: Icon(icon, color: color, size: 20),
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
                  Icon(icon, color: resolvedTextColor, size: 16),
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

  Widget _buildCircleIconButton(IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
        shape: BoxShape.circle,
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }

  Widget _buildQuickFilters(BuildContext context) {
    return Row(
      children: [
        _filterChip("Mystery", Icons.auto_awesome_rounded, _showSurpriseGifts, (v) => setState(() => _showSurpriseGifts = v)),
        const SizedBox(width: 6),
        _filterChip("Chains", Icons.link_rounded, _showChainGifts, (v) => setState(() => _showChainGifts = v)),
        const SizedBox(width: 6),
        _filterChip("Expiring", Icons.timer_outlined, _showExpiringSoon, (v) => setState(() => _showExpiringSoon = v)),
      ],
    );
  }

  Widget _filterChip(String label, IconData icon, bool active, Function(bool) onToggle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(icon, size: 16, color: active ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
      selected: active,
      onSelected: onToggle,
      selectedColor: AppTheme.giftColor,
      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
      labelStyle: TextStyle(color: active ? Colors.white : Theme.of(context).colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide.none),
      showCheckmark: false,
    );
  }

  Widget _buildStatusPill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
        child: Text(text.toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.w900)),
      );

  Widget _buildErrorRetry(VoidCallback onRetry, String error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                NetworkErrorMessage.titleFrom(error),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                NetworkErrorMessage.sanitize(error),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmptyState(String title, String desc, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface, letterSpacing: -0.2)),
            const SizedBox(height: 4),
            Text(desc, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
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

  void _showSnackBar(String m) => AppToast.show(context, m);
  Map<String, dynamic> _giftToLegacyMap(gift_models.Gift gift) => {
    'id': gift.id, 'title': gift.title, 'description': gift.description, 'giver': gift.giver.name, 'giverId': gift.giver.id,
    'karma': gift.karmaReward, 'category': gift.category.name, 'color': gift.category.color, 'icon': gift.category.icon,
    'mediaKeys': gift.imageUrls,
    'mediaType': gift.mediaType,
    'videoKey': gift.videoKey,
    'thumbnailKey': gift.thumbnailKey,
  };

  void _startCountdownTimer() {}
  Widget _buildSurpriseGiftsSection(BuildContext context) => const SizedBox.shrink();
  Widget _buildGiftChainsSection(BuildContext context) => const SizedBox.shrink();
  Widget _buildExpiringSoonSection(BuildContext context) => const SizedBox.shrink();
  Widget _buildFeaturedGifts(BuildContext context) => const SizedBox.shrink();
}

class _ApprovalSuccessDialog extends StatefulWidget {
  final String requesterName;
  final VoidCallback onOpenChat;
  final VoidCallback onDone;

  const _ApprovalSuccessDialog({
    required this.requesterName,
    required this.onOpenChat,
    required this.onDone,
  });

  @override
  State<_ApprovalSuccessDialog> createState() => _ApprovalSuccessDialogState();
}

class _ApprovalSuccessDialogState extends State<_ApprovalSuccessDialog>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _thanksOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.elasticOut),
    );
    _thanksOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _controller!.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1A28) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller!,
              builder: (context, child) {
                return Opacity(
                  opacity: _thanksOpacity.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.celebration_rounded,
                            size: 52,
                            color: AppTheme.successColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Thanks!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: AppTheme.successColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Request approved',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Continue the chat with ${widget.requesterName} to arrange pickup coordination logistics.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onDone,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Done', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: widget.onOpenChat,
                    icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                    label: const Text('Open Chat', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}