import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/listing_delete_helper.dart';
import '../../../core/utils/share_utils.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/widgets/hub_mine_empty_state.dart';
import '../../../core/widgets/hub_screen_top_bar.dart';
import '../models/donation_models.dart';
import '../providers/campaign_provider.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

class MyCampaignsScreen extends StatefulWidget {
  const MyCampaignsScreen({super.key});

  @override
  State<MyCampaignsScreen> createState() => _MyCampaignsScreenState();
}

class _MyCampaignsScreenState extends State<MyCampaignsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  static const _tabLabels = ['Active', 'Done', 'Drafts'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging &&
          _tabController.index != _currentTabIndex) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CampaignProvider>().loadMyCampaigns(force: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D0B12) : const Color(0xFFF8FAFF),
      body: Column(
        children: [
          HubScreenTopBar(
            title: 'My Donations',
            onBack: () => Navigator.of(context).pop(),
            trailingActions: [
              HubTopBarIconButton(
                icon: Icons.add_rounded,
                onTap: () => AppRoutes.navigateToCreateCampaign(context),
                isDark: isDark,
                iconColor: AppTheme.donationColor,
              ),
            ],
          ),
          Expanded(
            child: Consumer<CampaignProvider>(
              builder: (context, provider, _) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Text(
                        'Track and manage the campaigns you created',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: _buildStatsOverview(provider),
                    ),
                    _buildFluidTabSwitcher(isDark),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildActiveCampaignsTab(provider),
                          _buildCompletedCampaignsTab(provider),
                          _buildDraftsTab(provider),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluidTabSwitcher(bool isDark) {
    final divisor = _tabLabels.length > 1 ? _tabLabels.length - 1 : 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      height: 52,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment(
              -1.0 + (_currentTabIndex * (2.0 / divisor)),
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / _tabLabels.length,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1A28) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(
              _tabLabels.length,
              (index) => Expanded(
                child: GestureDetector(
                  onTap: () => _tabController.animateTo(index),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      _tabLabels[index],
                      style: TextStyle(
                        color: _currentTabIndex == index
                            ? (isDark ? Colors.white : const Color(0xFF1C1921))
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.45),
                        fontWeight: _currentTabIndex == index
                            ? FontWeight.w900
                            : FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview(CampaignProvider provider) {
    final campaigns = provider.myCampaigns;
    final active =
        campaigns.where((c) => c.status == CampaignStatus.active).length;
    final completed =
        campaigns.where((c) => c.status == CampaignStatus.completed).length;
    final drafts =
        campaigns.where((c) => c.status == CampaignStatus.draft).length;
    final totalRaised =
        campaigns.fold<double>(0, (sum, c) => sum + c.raisedAmount);
    final totalSupporters =
        campaigns.fold<int>(0, (sum, c) => sum + c.supportersCount);

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    label: 'Active',
                    value: '$active',
                    icon: Icons.trending_up_rounded,
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatTile(
                    label: 'Done',
                    value: '$completed',
                    icon: Icons.check_circle_rounded,
                    color: AppTheme.donationColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatTile(
                    label: 'Drafts',
                    value: '$drafts',
                    icon: Icons.drafts_rounded,
                    color: AppTheme.karmaColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    label: 'Total raised',
                    value: '${totalRaised.toStringAsFixed(0)} BYC',
                    icon: Icons.volunteer_activism_rounded,
                    color: AppTheme.successColor,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatTile(
                    label: 'Supporters',
                    value: '$totalSupporters',
                    icon: Icons.people_rounded,
                    color: AppTheme.primaryColor,
                    compact: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool compact = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: compact ? 18 : 20, color: color),
          SizedBox(height: compact ? 6 : 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 15 : 18,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCampaignsTab(CampaignProvider provider) {
    final campaigns = provider.myCampaigns
        .where((c) => c.status == CampaignStatus.active)
        .toList();

    if (provider.isLoading && campaigns.isEmpty) {
      return const BybataLoader();
    }

    if (campaigns.isEmpty) {
      return HubMineEmptyState(
        accentColor: AppTheme.donationColor,
        icon: Icons.volunteer_activism_rounded,
        title: 'No active campaigns',
        subtitle: 'Start a cause and invite your community to support it.',
        buttonLabel: 'Create campaign',
        onCreate: () => AppRoutes.navigateToCreateCampaign(context),
        hints: const [
          'Share your story with photos or video',
          'Set a clear goal and deadline',
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadMyCampaigns(force: true),
      color: AppTheme.donationColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: campaigns.length + 1,
        itemBuilder: (context, index) {
          if (index == campaigns.length) {
            return HubMineCreateBar(
              accentColor: AppTheme.donationColor,
              label: 'Create another campaign',
              onTap: () => AppRoutes.navigateToCreateCampaign(context),
            );
          }
          return _buildCampaignCard(
            campaigns[index],
            isDraft: false,
            isActive: true,
          );
        },
      ),
    );
  }

  Widget _buildCompletedCampaignsTab(CampaignProvider provider) {
    final campaigns = provider.myCampaigns
        .where((c) => c.status == CampaignStatus.completed)
        .toList();

    if (provider.isLoading && campaigns.isEmpty) {
      return const BybataLoader();
    }

    if (campaigns.isEmpty) {
      return HubMineEmptyState(
        accentColor: AppTheme.donationColor,
        icon: Icons.check_circle_outline_rounded,
        title: 'No completed campaigns yet',
        subtitle: 'Finished campaigns will appear here for your records.',
        buttonLabel: 'Browse causes',
        onCreate: () => Navigator.of(context).pop(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: campaigns.length,
      itemBuilder: (context, index) => _buildCampaignCard(
        campaigns[index],
        isDraft: false,
        isActive: false,
      ),
    );
  }

  Widget _buildDraftsTab(CampaignProvider provider) {
    final drafts = provider.myCampaigns
        .where((c) => c.status == CampaignStatus.draft)
        .toList();

    if (provider.isLoading && drafts.isEmpty) {
      return const BybataLoader();
    }

    if (drafts.isEmpty) {
      return HubMineEmptyState(
        accentColor: AppTheme.karmaColor,
        icon: Icons.drafts_rounded,
        title: 'No drafts saved',
        subtitle: 'Save a campaign as a draft and finish it when you are ready.',
        buttonLabel: 'Start a draft',
        onCreate: () => AppRoutes.navigateToCreateCampaign(context),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: drafts.length,
      itemBuilder: (context, index) => _buildCampaignCard(
        drafts[index],
        isDraft: true,
        isActive: false,
      ),
    );
  }

  Widget _build3DContainer({required Widget child, double radius = 22}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1A28).withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            width: 1.2,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildCampaignCard(
    Campaign campaign, {
    required bool isDraft,
    required bool isActive,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = isDraft
        ? AppTheme.karmaColor
        : isActive
            ? AppTheme.successColor
            : AppTheme.donationColor;
    final statusLabel = isDraft
        ? 'DRAFT'
        : isActive
            ? 'ACTIVE'
            : 'DONE';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _build3DContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildCategoryIcon(campaign.categoryIcon, campaign.categoryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          campaign.categoryLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: campaign.categoryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusPill(statusLabel, statusColor),
                ],
              ),
            ),
            if (!isDraft) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildProgressSection(campaign, isDark),
              ),
              const SizedBox(height: 14),
            ],
            _buildCardFooter(campaign, isDraft: isDraft, isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(IconData icon, Color color) {
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

  Widget _buildStatusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildProgressSection(Campaign campaign, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              campaign.formattedRaised,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            Text(
              '${(campaign.progressPercentage * 100).toInt()}%',
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
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: campaign.progressPercentage.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    campaign.categoryColor,
                    campaign.categoryColor.withValues(alpha: 0.65),
                  ],
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
              'Goal: ${campaign.formattedGoal}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
            Text(
              '${campaign.supportersCount} supporters',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardFooter(
    Campaign campaign, {
    required bool isDraft,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.01),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              label: isDraft ? 'Continue editing' : 'Manage',
              color: isDraft ? AppTheme.karmaColor : AppTheme.donationColor,
              onTap: isDraft
                  ? () => AppRoutes.navigateToCreateCampaign(context)
                  : () => AppRoutes.navigateToCampaignManagement(context, campaign),
            ),
          ),
          const SizedBox(width: 10),
          _buildCircleIconButton(
            Icons.share_rounded,
            () => _shareCampaign(campaign),
          ),
          if (ListingDeleteRules.canDeleteCampaign(campaign)) ...[
            const SizedBox(width: 10),
            _buildCircleIconButton(
              Icons.delete_outline_rounded,
              () => _deleteCampaign(campaign),
              isDestructive: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleIconButton(
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final color = isDestructive ? scheme.error : scheme.onSurface;

    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          size: 18,
          color: color.withValues(alpha: isDestructive ? 0.85 : 0.6),
        ),
      ),
    );
  }

  void _shareCampaign(Campaign campaign) {
    ShareUtils.shareCampaign(
      context,
      id: campaign.id.toString(),
      title: campaign.title,
    );
  }

  Future<void> _deleteCampaign(Campaign campaign) async {
    final confirmed = await confirmDeleteListing(
      context,
      title: campaign.title,
      itemLabel: 'campaign',
      blockedReason: ListingDeleteRules.campaignDeleteBlockedReason(campaign),
    );
    if (!confirmed || !mounted) return;

    final provider = context.read<CampaignProvider>();
    final success = await provider.deleteCampaign(campaign.id);
    if (!mounted) return;

    if (success) {
      showDeleteListingResult(
        context,
        success: true,
        message: 'Campaign deleted',
      );
    } else {
      showDeleteListingResult(
        context,
        success: false,
        message: provider.error ?? 'Failed to delete campaign',
      );
    }
  }
}
