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
import 'donation_history_screen.dart';
import '../../../core/compliance/ios_campaign_support.dart';
import '../models/donation_models.dart';
import '../providers/campaign_provider.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import '../../feed/mappers/social_listing_mapper.dart';
import '../../feed/models/social_listing_card_data.dart';
import '../../feed/widgets/social_feed_list.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class DonationsScreen extends StatefulWidget {
  /// Optional tab to open (0 browse, 1 my campaigns, 2 requests, 3 history).
  final int initialTabIndex;

  const DonationsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  int _currentIndex = 0;
  int _adFeedRefresh = 0;
  bool _didInitialLoad = false;

  @override
  void initState() {
    super.initState();
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
    );

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

  /// Back from hub: inner tab → browse tab, then pop route, else home.
  void _handleHubBack() {
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
      _tabController.index == 0 && Navigator.canPop(context);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            Column(
              children: [
                HubScreenTopBar(
                  title: 'Support Hub',
                  onBack: _handleHubBack,
                  trailingActions: [
                    HubTopBarIconButton(
                      icon: Icons.volunteer_activism_rounded,
                      onTap: () {
                        if (AppRoutes.requireSignIn(context)) return;
                        GuardedNavigator.push(context, 
                          MaterialPageRoute(
                            builder: (_) => const DonationHistoryScreen(),
                          ),
                        );
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
            Align(
              alignment: Alignment.centerRight,
              child: _buildRightMiddleCreateDonationButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightMiddleCreateDonationButton() {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => AppRoutes.navigateToCreateCampaign(context),
      child: Container(
        height: 130,
        width: 48,
        decoration: BoxDecoration(
          color: AppTheme.donationColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.donationColor.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(-4, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
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
                    'CREATE DONATION',
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
    List<String> labels = ["Browse", "My Donations", "Requests", "History"];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 15),
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
            alignment: Alignment(-1.0 + (_currentIndex * (2.0 / (labels.length - 1))), 0),
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
                child: Center(
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: _currentIndex == index
                          ? (isDark ? Colors.white : const Color(0xFF1C1921))
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                      fontWeight: _currentIndex == index ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: -0.1,
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

  // --- TAB 1: BROWSE ---
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _buildSectionHeader(
                'Featured Donations',
                Icons.star_rounded,
                AppTheme.karmaColor,
              ),
            ),
            _build3DFeaturedCarousel(campaignProvider),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AdPlacementSection(
                key: ValueKey('campaign_ads_$_adFeedRefresh'),
                placementKey: 'campaign_feed',
                title: 'Sponsored Cause',
                refreshToken: _adFeedRefresh,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSectionHeader(
                'Active Campaigns (${campaigns.length})',
                Icons.campaign_rounded,
                AppTheme.donationColor,
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
            onCreate: () => AppRoutes.navigateToCreateCampaign(context),
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
                  onTap: () => AppRoutes.navigateToCreateCampaign(context),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _build3DContainer(
        child: DebouncedTap(
          onTap: () => _showCampaignDetails(campaign),
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
    );
  }

  Widget _buildMyCampaignCard(Campaign campaign) {
    final isDraft = campaign.status == CampaignStatus.draft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _build3DContainer(
        child: DebouncedTap(
          onTap: () => _showCampaignDetails(campaign),
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
    CampaignSupportCompliance.handleSupportTap(
      context,
      campaign: campaign,
    );
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
                    onTap: () => AppRoutes.navigateToCreateCampaign(context),
                    label: "Create Campaign",
                    color: AppTheme.primaryColor,
                  ),
                ),
            ],
          ),
        ),
      );

  void _showCampaignDetails(Campaign campaign) => AppRoutes.navigateToCampaignDetails(context, campaign);
  void _showSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}