import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/widgets/hub_screen_top_bar.dart';
import '../../../features/settings/widgets/settings_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/network_error_message.dart';
import '../../../core/widgets/ad_placement_section.dart';
import '../../../core/widgets/hub_mine_empty_state.dart';
import '../../../features/common/widgets/state_components.dart';
import '../../../core/widgets/debounced_tap.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/guest_browse_helpers.dart';
import '../../../core/utils/share_utils.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/models/chat_conversation.dart';
import 'donation_chat_screen.dart';
import '../../../core/compliance/ios_campaign_support.dart';
import '../models/donation_models.dart';
import '../providers/campaign_provider.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import '../../feed/mappers/social_listing_mapper.dart';
import '../../feed/models/social_listing_card_data.dart';
import '../../feed/widgets/social_feed_list.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';
import '../../../core/motion/create_stage_route.dart';
import '../../../core/motion/hero_stage.dart';
import '../../../core/motion/hub_atmosphere.dart';
import '../../../core/motion/hub_create_rail.dart';
import '../../../core/motion/hub_deck_bar.dart';
import '../../../core/motion/hub_stage_bus.dart';
import '../../../core/motion/soft_reveal.dart';
import '../../../core/navigation/route_observer.dart';
import 'create_campaign_screen.dart';
import '../../../core/motion/living_slide.dart';
import '../../../core/motion/stage_controller.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/widgets/app_toast.dart';
import '../../stage/living_slide_mapper.dart';
import '../widgets/donate_give_act.dart';

class DonationsScreen extends StatefulWidget {
  /// Optional tab to open (0 browse, 1 my campaigns, 2 requests, 3 history).
  final int initialTabIndex;
  final String? stageFocusId;

  const DonationsScreen({
    super.key,
    this.initialTabIndex = 0,
    this.stageFocusId,
  });

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  late TabController _tabController;
  int _currentIndex = 0;
  int _adFeedRefresh = 0;
  bool _didInitialLoad = false;
  final StageController _living = StageController();
  final DonateDraft _donateDraft = DonateDraft();
  List<LivingSlide> _livingSlides = const [];
  bool _openedStageFocus = false;
  String? _pendingFocus;

  @override
  void initState() {
    super.initState();
    _living.addListener(_onLivingChanged);
    HubStageBus.register(HubStageBus.donate, _openLinked);
    WidgetsBinding.instance.addObserver(this);
    final initialTab = widget.initialTabIndex.clamp(0, 3);
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialTab,
    );
    _currentIndex = initialTab;
    _tabController.addListener(_handleTabChange);

    // PRESERVED LOGIC: Initial data load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadAllData();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // PRESERVED LOGIC: Refresh on app resume
    if (state == AppLifecycleState.resumed) {
      _reloadAllData();
    }
  }

  void _reloadAllData({bool force = false}) {
    final campaignProvider = Provider.of<CampaignProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    campaignProvider.setCacheUserId(auth.currentUser?.id);
    final shouldForce = force || !_didInitialLoad;
    _didInitialLoad = true;

    campaignProvider.loadCampaigns(
      status: CampaignStatus.active,
      force: shouldForce,
    ).whenComplete(() {
      if (mounted) _maybeOpenStageFocus();
    });

    if (auth.isAuthenticated) {
      // Load account-specific tabs after browse feed so they cannot clear the
      // shared loading flag while campaigns are still in flight.
      Future.microtask(() {
        if (!mounted) return;
        final provider = Provider.of<CampaignProvider>(context, listen: false);
        provider.loadMyCampaigns(force: shouldForce);
        provider.loadDonationHistory(force: shouldForce);
      });
    }
  }

  void _handleTabChange() {
    if (_tabController.index != _currentIndex) {
      setState(() {
        _currentIndex = _tabController.index;
      });
      
      // PRESERVED LOGIC: Specific tab reload
      if (_tabController.index == 1) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (auth.isAuthenticated) {
          Provider.of<CampaignProvider>(context, listen: false).loadMyCampaigns();
        }
      }
    }
  }

  void _onLivingChanged() {
    if (mounted) setState(() {});
  }

  /// Back from hub: stage layers, then inner tab → browse tab, then pop route.
  void _handleHubBack() {
    if (_living.isOpen) {
      _living.back();
      return;
    }
    if (_tabController.index > 0) {
      _tabController.animateTo(0);
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    AppRoutes.navigateToHome(context);
  }

  bool get _canPopHub =>
      !_living.isOpen &&
      _tabController.index == 0 &&
      Navigator.canPop(context);

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
      HubStageBus.markCurrent(HubStageBus.donate, route.isCurrent);
    }
  }

  @override
  void didPush() => HubStageBus.markCurrent(HubStageBus.donate, true);

  @override
  void didPopNext() => HubStageBus.markCurrent(HubStageBus.donate, true);

  @override
  void didPushNext() => HubStageBus.markCurrent(HubStageBus.donate, false);

  @override
  void didPop() => HubStageBus.markCurrent(HubStageBus.donate, false);

  @override
  void dispose() {
    HubStageBus.markCurrent(HubStageBus.donate, false);
    HubStageBus.unregister(HubStageBus.donate, _openLinked);
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _living.removeListener(_onLivingChanged);
    _living.dispose();
    _donateDraft.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // --- PREMIUM UNIFORM 3D CANVAS CORES ---
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
          color: color ?? (isDark ? const Color(0xFF1E1A28).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.65)),
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
      canPop: _canPopHub,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleHubBack();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D0B12) : const Color(0xFFF8FAFF),
        extendBody: true,
        body: Stack(
          children: [
            HubAtmosphere(
              accent: AppTheme.donationColor,
              visible: !_living.isOpen,
            ),
            Column(
              children: [
                HubScreenTopBar(
                  title: 'Support Hub',
                  onBack: _handleHubBack,
                  trailingActions: [
                    HubTopBarIconButton(
                      icon: Icons.volunteer_activism_rounded,
                      onTap: () {
                        if (!guardHubTabForGuest(context, 3)) return;
                        _tabController.animateTo(3);
                      },
                      isDark: isDark,
                      iconColor: AppTheme.donationColor,
                    ),
                  ],
                ),
                _buildFluidTabSwitcher(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildAvailableDonationsTab(context),
                      GuestBrowseGate(
                        title: 'Sign in to view your campaigns',
                        message: 'Manage campaigns you created after you sign in.',
                        child: _buildMyDonationsTab(context),
                      ),
                      GuestBrowseGate(
                        title: 'Sign in to view requests',
                        message: 'Review donation requests from your account.',
                        child: _buildDonationRequestsTab(context),
                      ),
                      GuestBrowseGate(
                        title: 'Sign in to view donation history',
                        message: 'See your past donations after signing in.',
                        child: _buildDonationHistoryTab(context),
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
                  color: AppTheme.donationColor,
                  label: 'CREATE DONATION',
                  onTap: _openCreateCampaign,
                ),
              ),
            if (_living.isOpen && _livingSlides.isNotEmpty)
              Positioned.fill(child: _donateStage()),
          ],
        ),
      ),
    );
  }

  Widget _donateStage() {
    return LivingHeroStage(
      controller: _living,
      stageColor: AppTheme.donationColor,
      slides: _livingSlides,
      commitLabel: 'Give now',
      markIcon: Icons.favorite_rounded,
      numberTick: _donateDraft,
      numberText: () => _donateDraft.label,
      railBuilder: (slide) => DonateAmountRail(draft: _donateDraft),
      actBuilder: (slide) {
        final campaign = slide.source;
        if (campaign is! Campaign) return const SizedBox.shrink();
        return DonateGiveFields(campaign: campaign, draft: _donateDraft);
      },
      beforeBuilder: (slide) async {
        final campaign = slide.source;
        if (campaign is Campaign &&
            CampaignSupportCompliance.blocksInAppDonations) {
          CampaignSupportCompliance.handleSupportTap(
            context,
            campaign: campaign,
          );
          return false;
        }
        return !AppRoutes.requireSignIn(context);
      },
      onEdit: _editCampaignSlide,
      onCommit: _commitDonation,
    );
  }

  void _openCreateCampaign() {
    if (AppRoutes.requireSignIn(context)) return;
    GuardedNavigator.push(
      context,
      CreateStageRoute(
        color: AppTheme.donationColor,
        origin: stageCardOrigin(context),
        builder: (_) => const CreateCampaignScreen(),
      ),
    );
  }

  Widget _buildFluidTabSwitcher() {
    return SoftReveal(
      index: 0,
      travel: 10,
      child: HubDeckBar(
        controller: _tabController,
        accent: AppTheme.donationColor,
        activity: const [
          HubActivity('Requests', 2),
          HubActivity('History', 3),
        ],
        guard: (index) => guardHubTabForGuest(context, index),
      ),
    );
  }

  Widget _buildAvailableDonationsTab(BuildContext context) {
    return Consumer<CampaignProvider>(
      builder: (context, campaignProvider, child) {
        final campaigns = campaignProvider.campaigns
            .where((c) => c.status == CampaignStatus.active)
            .toList();
        if (campaignProvider.isLoadingCampaigns && campaigns.isEmpty) {
          return const BybataLoader();
        }

        final feedItems = campaigns.map(SocialListingMapper.fromCampaign).toList();

        return SocialFeedList(
          items: feedItems,
          layout: SocialFeedLayout.timeline,
          isLoading: campaignProvider.isLoadingCampaigns && campaigns.isEmpty,
          error: campaignProvider.error != null && campaigns.isEmpty
              ? campaignProvider.error
              : null,
          onRefresh: () async {
            if (mounted) setState(() => _adFeedRefresh++);
            await campaignProvider.loadCampaigns(
              status: CampaignStatus.active,
              force: true,
            );
          },
          header: [
            SoftReveal(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: _buildSectionHeader(
                  'Featured Donations',
                  Icons.star_rounded,
                  AppTheme.karmaColor,
                ),
              ),
            ),
            SoftReveal(
              index: 2,
              child: _build3DFeaturedCarousel(campaignProvider),
            ),
            const SizedBox(height: 16),
            SoftReveal(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AdPlacementSection(
                  key: ValueKey('campaign_ads_$_adFeedRefresh'),
                  placementKey: 'campaign_feed',
                  title: 'Sponsored Cause',
                  refreshToken: _adFeedRefresh,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SoftReveal(
              index: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSectionHeader(
                  'Active Campaigns (${campaigns.length})',
                  Icons.campaign_rounded,
                  AppTheme.donationColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          onCardTap: (item) {
            final campaign = item.raw?['campaign'] as Campaign?;
            if (campaign != null) _showCampaignDetails(campaign);
          },
          onPrimaryAction: (item) {
            final campaign = item.raw?['campaign'] as Campaign?;
            if (campaign != null) {
              CampaignSupportCompliance.handleSupportTap(
                context,
                campaign: campaign,
              );
            }
          },
          emptyAccent: AppTheme.donationColor,
          emptyIcon: Icons.volunteer_activism_outlined,
          emptyTitle: 'No active campaigns',
          emptySubtitle: 'Be the first to start a cause.',
        );
      },
    );
  }

  // --- TAB 2: MY DONATIONS ---
  Widget _buildMyDonationsTab(BuildContext context) {
    return Consumer<CampaignProvider>(
      builder: (context, campaignProvider, child) {
        final myCampaigns = campaignProvider.myCampaigns;
        if (campaignProvider.isLoadingMyCampaigns && myCampaigns.isEmpty) {
          return const BybataLoader();
        }

        if (myCampaigns.isEmpty && campaignProvider.error != null) {
          return ErrorState(
            title: NetworkErrorMessage.titleFrom(campaignProvider.error),
            message: NetworkErrorMessage.sanitize(campaignProvider.error),
            type: ErrorStateType.network,
            actionText: 'Try again',
            onRetry: () => campaignProvider.loadMyCampaigns(force: true),
          );
        }

        if (myCampaigns.isEmpty) {
          return HubMineEmptyState(
            accentColor: AppTheme.donationColor,
            icon: Icons.volunteer_activism_rounded,
            title: 'No campaigns yet',
            subtitle: 'Start a cause and collect BYC from supporters. Your campaigns live here.',
            buttonLabel: 'Start a campaign',
            hints: const [
              'Tell your story with photos & goals',
              'Track donors in real time',
            ],
            onCreate: () => _openCreateCampaign(),
          );
        }

        return RefreshIndicator(
          onRefresh: () => campaignProvider.loadMyCampaigns(force: true),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            physics: const BouncingScrollPhysics(),
            itemCount: myCampaigns.length + 1,
            itemBuilder: (context, index) {
              if (index == myCampaigns.length) {
                return HubMineCreateBar(
                  accentColor: AppTheme.donationColor,
                  label: 'Start another campaign',
                  onTap: () => _openCreateCampaign(),
                );
              }
              return _buildMyCampaignCard(myCampaigns[index]);
            },
          ),
        );
      },
    );
  }

  // --- TAB 3: REQUESTS ---
  Widget _buildDonationRequestsTab(BuildContext context) {
    return Consumer<CampaignProvider>(
      builder: (context, campaignProvider, child) {
        final urgent = campaignProvider.campaigns
            .where((c) => c.isUrgent && c.status == CampaignStatus.active)
            .toList();
        if (campaignProvider.isLoadingCampaigns &&
            campaignProvider.campaigns.isEmpty) {
          return const BybataLoader();
        }

        if (urgent.isEmpty) {
          return _buildEmptyState(
            'No urgent requests',
            'Everything is stable!',
            Icons.celebration_rounded,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          physics: const BouncingScrollPhysics(),
          itemCount: urgent.length,
          itemBuilder: (context, index) => _buildCampaignCard(urgent[index]),
        );
      },
    );
  }

  // --- TAB 4: HISTORY ---
  Widget _buildDonationHistoryTab(BuildContext context) {
    return Consumer<CampaignProvider>(
      builder: (context, campaignProvider, child) {
        if (campaignProvider.isLoadingHistory &&
            campaignProvider.donationHistory.isEmpty) {
          return const BybataLoader();
        }
        final history = campaignProvider.donationHistory;

        if (history.isEmpty) return _buildEmptyState('No donations yet', 'Support a cause today!', Icons.history_rounded);

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          physics: const BouncingScrollPhysics(),
          itemCount: history.length,
          itemBuilder: (context, index) => _buildHistoryCard(history[index]),
        );
      },
    );
  }

  // --- REUSABLE CARD WRAPPERS ---

  Widget _buildCampaignCard(Campaign campaign) {
    return Builder(
      builder: (cardContext) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _build3DContainer(
        child: DebouncedTap(
          onTap: () => _showCampaignDetails(
            campaign,
            origin: stageCardOrigin(cardContext),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildRaisedIcon(campaign.categoryIcon, campaign.categoryColor),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            campaign.title, 
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "by ${campaign.creator.name}",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (campaign.isUrgent) ...[
                      const SizedBox(width: 8),
                      _buildUrgentBadge(),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _build3DProgress(campaign),
              ),
              const SizedBox(height: 16),
              _buildCardFooter(campaign),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildMyCampaignCard(Campaign campaign) {
    final isDraft = campaign.status == CampaignStatus.draft;
    return Builder(
      builder: (cardContext) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _build3DContainer(
        child: DebouncedTap(
          onTap: () => _showCampaignDetails(
            campaign,
            origin: stageCardOrigin(cardContext),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildRaisedIcon(campaign.categoryIcon, campaign.categoryColor),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        campaign.title, 
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusPill(
                      campaign.status.name,
                      isDraft ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4) : AppTheme.successColor,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _build3DProgress(campaign),
              ),
              const SizedBox(height: 16),
              _buildMyCampaignFooter(campaign, isDraft),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _build3DProgress(Campaign campaign) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(campaign.formattedRaised, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            Text(
              "${(campaign.progressPercentage * 100).toInt()}%",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: AppTheme.successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: campaign.progressPercentage.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [campaign.categoryColor, campaign.categoryColor.withValues(alpha: 0.65)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Goal: ${campaign.formattedGoal}",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              campaign.timeRemainingText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: campaign.isUrgent ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardFooter(Campaign campaign) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
        border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _build3DActionButton(
              onTap: () => _donateToCampaign(campaign),
              label: CampaignSupportCompliance.hubDonateLabel(),
              color: AppTheme.donationColor,
            ),
          ),
          const SizedBox(width: 10),
          _buildCircleIconButton(Icons.share_rounded, () => _shareCampaign(campaign)),
          const SizedBox(width: 10),
          _buildCircleIconButton(Icons.chat_bubble_outline_rounded, () => _openCampaignChat(campaign)),
        ],
      ),
    );
  }

  Widget _buildMyCampaignFooter(Campaign campaign, bool isDraft) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
        border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _build3DActionButton(
              onTap: isDraft ? () => _activateCampaign(campaign) : () => AppRoutes.navigateToCampaignManagement(context, campaign),
              label: isDraft ? "Activate Cause" : "Manage Campaign",
              color: isDraft ? AppTheme.successColor : AppTheme.karmaColor,
              icon: isDraft ? Icons.rocket_launch_rounded : null,
            ),
          ),
          const SizedBox(width: 10),
          _buildCircleIconButton(Icons.share_rounded, () => _shareCampaign(campaign)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(dynamic donation) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _build3DContainer(
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildRaisedIcon(Icons.favorite_rounded, AppTheme.donationColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donation.campaign.title, 
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${donation.donatedAt.day}/${donation.donatedAt.month}/${donation.donatedAt.year}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${donation.amount} ${donation.currency}",
                    style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.successColor, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "+${donation.karmaAwarded} Karma",
                    style: TextStyle(fontSize: 11, color: AppTheme.karmaColor, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- PRESERVED DIALOG & REDIRECT INFRASTRUCTURE ---

  void _activateCampaign(Campaign campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Activate Campaign', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Once activated, "${campaign.title}" will be visible to everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
            child: const Text('Activate Now', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final campaignProvider = Provider.of<CampaignProvider>(context, listen: false);
      final success = await campaignProvider.updateCampaignStatus(campaign.id, CampaignStatus.active);
      if (success != null) {
        _showSnackBar('Campaign is now LIVE!');
        await campaignProvider.loadMyCampaigns();
      }
    }
  }

  void _donateToCampaign(Campaign campaign) {
    _openCampaignStage(campaign, give: true);
  }

  void _shareCampaign(Campaign campaign) {
    ShareUtils.shareCampaign(
      context,
      id: campaign.id.toString(),
      title: campaign.title,
    );
  }

  void _openCampaignChat(Campaign campaign) {
    if (AppRoutes.requireSignIn(context)) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser?.id == null) return;
    final existing = chatProvider.findConversationInCache(
      contextId: campaign.id,
      partnerId: campaign.creator.id,
    );
    GuardedNavigator.push(context, 
      MaterialPageRoute(
        builder: (context) => DonationChatScreen(
          campaign: campaign, 
          partnerId: campaign.creator.id, 
          partnerName: campaign.creator.name, 
          existingConversation: existing,
        ),
      ),
    );
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
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _build3DActionButton({
    required VoidCallback onTap,
    required String label,
    Color? color,
    IconData? icon,
  }) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: resolvedColor.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: resolvedColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
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
        icon: Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildUrgentBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2)),
        ),
        child: Text(
          "URGENT",
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      );

  Widget _buildStatusPill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withValues(alpha: 0.2)),
        ),
        child: Text(
          t.toUpperCase(),
          style: TextStyle(
            color: c,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

  Widget _buildSectionHeader(String t, IconData i, Color c) => Row(
        children: [
          Icon(i, color: c, size: 20),
          const SizedBox(width: 8),
          Text(
            t,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      );

  Widget _build3DFeaturedCarousel(CampaignProvider provider) {
    final featured = provider.campaigns.where((c) => c.status == CampaignStatus.active && c.isFeatured).toList();
    if (featured.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 200, 
      child: ListView.builder(
        scrollDirection: Axis.horizontal, 
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: featured.length, 
        itemBuilder: (context, index) => Container(
          width: 310, 
          margin: const EdgeInsets.only(right: 14), 
          child: _buildCampaignCard(featured[index]),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    String t,
    String d,
    IconData i, {
    bool showCreateButton = false,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                i,
                size: 56,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 16),
              Text(
                t,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                d,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              if (showCreateButton)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _build3DActionButton(
                    onTap: () => _openCreateCampaign(),
                    label: "Create Campaign",
                    color: AppTheme.primaryColor,
                  ),
                ),
            ],
          ),
        ),
      );

  void _showCampaignDetails(Campaign campaign, {Rect? origin}) {
    _openCampaignStage(campaign, give: false, origin: origin);
  }

  void _openCampaignStage(Campaign campaign, {required bool give, Rect? origin}) {
    if (give && CampaignSupportCompliance.blocksInAppDonations) {
      CampaignSupportCompliance.handleSupportTap(context, campaign: campaign);
      return;
    }
    final provider = context.read<CampaignProvider>();
    final mine = _tabController.index == 1;
    final list = mine ? provider.myCampaigns : provider.campaigns;
    final pool = list.any((item) => item.id == campaign.id)
        ? list
        : <Campaign>[campaign];
    final userId = context.read<AuthProvider>().currentUser?.id;
    final slides = pool
        .map(
          (item) => LivingSlideMapper.fromCampaign(
            item,
            currentUserId: userId,
          ),
        )
        .where((slide) => slide.id.isNotEmpty)
        .toList();
    if (slides.isEmpty) return;
    final index = slides.indexWhere((slide) => slide.id == campaign.id);
    final safe = index < 0 ? 0 : index;
    _donateDraft.clear();
    setState(() => _livingSlides = slides);
    _living.open(slides[safe].id, origin: origin);
    if (give && !slides[safe].isOwner) {
      if (AppRoutes.requireSignIn(context)) return;
      _living.openBuilder();
    }
  }

  Future<void> _maybeOpenStageFocus() async {
    final pending = _pendingFocus?.trim();
    final id = (pending != null && pending.isNotEmpty)
        ? pending
        : widget.stageFocusId?.trim();
    if (id == null || id.isEmpty || _openedStageFocus || !mounted) return;
    final campaigns = context.read<CampaignProvider>().campaigns;
    final match = campaigns.where((item) => item.id == id);
    if (match.isNotEmpty) {
      _openedStageFocus = true;
      _openCampaignStage(match.first, give: false);
      return;
    }
    _openedStageFocus = true;
    final campaign = await context.read<CampaignProvider>().getCampaign(id);
    if (!mounted || campaign == null) return;
    _openCampaignStage(campaign, give: false);
  }

  Future<StageCommitResult?> _commitDonation(LivingSlide slide) async {
    final campaign = slide.source is Campaign ? slide.source as Campaign : null;
    if (campaign == null) return null;
    if (CampaignSupportCompliance.blocksInAppDonations) {
      CampaignSupportCompliance.handleSupportTap(context, campaign: campaign);
      return null;
    }
    if (AppRoutes.requireSignIn(context)) return null;
    final amount = _donateDraft.amount;
    if (amount == null || amount <= 0) {
      HapticUtils.error();
      AppToast.show(context, 'Choose an amount');
      return null;
    }
    final balance = context.read<WalletProvider>().bycBalance;
    if (amount > balance) {
      HapticUtils.error();
      AppToast.show(context, 'Not enough BYC');
      return null;
    }
    final beforeRaised = campaign.raisedAmount;
    final provider = context.read<CampaignProvider>();
    final note = _donateDraft.note.text.trim();
    final donation = await provider.donateToCampaign(
      campaign.id,
      amount: amount,
      currency: 'BYC',
      isAnonymous: _donateDraft.anonymous,
      message: note.isEmpty ? null : note,
      rewardTierId: _donateDraft.tierId,
    );
    if (!mounted) return null;
    if (donation == null) {
      HapticUtils.error();
      AppToast.show(context, provider.error ?? 'Could not give');
      return null;
    }
    HapticUtils.heavy();
    final raised = donation.campaign.raisedAmount;
    final play = raised >= donation.campaign.goalAmount &&
        raised > beforeRaised &&
        GoalCheckSession.claim(campaign.id);
    _donateDraft.clear();
    return StageCommitResult(
      'Thank you · \$${raised.toStringAsFixed(0)} raised',
      playGoalCheck: play,
    );
  }

  Future<void> _editCampaignSlide(LivingSlide slide) async {
    final campaign = slide.source;
    if (campaign is! Campaign) return;
    if (AppRoutes.requireSignIn(context)) return;
    AppRoutes.navigateToEditCampaign(context, campaign);
  }
  void _showSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}