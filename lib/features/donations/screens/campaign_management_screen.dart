import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/widgets/hub_screen_top_bar.dart';
import '../models/donation_models.dart';
import '../api/campaign_api.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/utils/listing_delete_helper.dart';
import '../../../core/utils/share_utils.dart';
import '../providers/campaign_provider.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/theme/app_theme.dart';

class CampaignManagementScreen extends StatefulWidget {
  final Campaign campaign;

  const CampaignManagementScreen({super.key, required this.campaign});

  @override
  State<CampaignManagementScreen> createState() =>
      _CampaignManagementScreenState();
}

class _CampaignManagementScreenState extends State<CampaignManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Campaign _campaign;
  List<RewardTier> _rewardTiers = [];
  bool _loadingTiers = false;
  Map<String, dynamic>? _analytics;
  bool _loadingAnalytics = false;
  List<Map<String, dynamic>> _updates = [];
  bool _loadingUpdates = false;
  bool _loadingCampaign = true;
  String? _loadError;
  CampaignStatus _currentStatus = CampaignStatus.active;
  int _currentTabIndex = 0;

  static const _tabLabels = [
    'Stats',
    'Rewards',
    'Updates',
    'Fans',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _campaign = widget.campaign;
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging &&
          _tabController.index != _currentTabIndex) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
    _currentStatus = widget.campaign.status;
    _refreshAll();
  }

  CampaignApi _api() =>
      CampaignApi(context.read<CampaignProvider>().apiClient);

  Future<void> _refreshAll() async {
    await _loadCampaign();
    if (!mounted || _loadError != null) return;
    await Future.wait([
      _loadRewardTiers(),
      _loadAnalytics(),
      _loadUpdates(),
    ]);
  }

  Future<void> _loadCampaign() async {
    setState(() {
      _loadingCampaign = true;
      _loadError = null;
    });
    try {
      final data = await _api().getCampaign(widget.campaign.id);
      if (!mounted) return;
      setState(() {
        _campaign = Campaign.fromJson(data);
        _currentStatus = _campaign.status;
        _loadingCampaign = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load campaign details';
        _loadingCampaign = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: Navigator.canPop(context),
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0D0B12) : const Color(0xFFF8FAFF),
        body: Column(
          children: [
            HubScreenTopBar(
              title: 'Manage Campaign',
              onBack: () => Navigator.maybePop(context),
              trailingActions: [
                HubTopBarIconButton(
                  icon: Icons.share_rounded,
                  onTap: _shareCampaign,
                  isDark: isDark,
                  iconColor: AppTheme.donationColor,
                ),
                const SizedBox(width: 8),
                _buildTopBarMenu(isDark),
              ],
            ),
            Expanded(
              child: _loadingCampaign
                  ? const Center(child: BybataLoader())
                  : _loadError != null
                      ? _buildLoadError()
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                              child: _buildOverviewCard(),
                            ),
                            _buildFluidTabSwitcher(isDark),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _refreshAll,
                                color: AppTheme.donationColor,
                                child: TabBarView(
                                  controller: _tabController,
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  children: [
                                    _buildAnalyticsTab(),
                                    _buildRewardsTab(),
                                    _buildUpdatesTab(),
                                    _buildSupportersTab(),
                                    _buildSettingsTab(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              _loadError ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _refreshAll,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBarMenu(bool isDark) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz_rounded,
        color: isDark ? Colors.white : Colors.black87,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        switch (value) {
          case 'create':
            AppRoutes.navigateToCreateCampaign(context);
          case 'edit':
            _editCampaign();
          case 'pause':
            _pauseCampaign();
          case 'promote':
            _promoteCampaign();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'create',
          child: ListTile(
            leading: Icon(Icons.add_circle_outline_rounded),
            title: Text('New campaign'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_rounded),
            title: Text('Edit campaign'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const PopupMenuItem(
          value: 'pause',
          child: ListTile(
            leading: Icon(Icons.pause_circle_outline_rounded),
            title: Text('Pause campaign'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const PopupMenuItem(
          value: 'promote',
          child: ListTile(
            leading: Icon(Icons.rocket_launch_rounded),
            title: Text('Promote campaign'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Widget _build3DContainer({
    required Widget child,
    double radius = 22,
  }) {
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

  Widget _buildFluidTabSwitcher(bool isDark) {
    final divisor = _tabLabels.length > 1 ? _tabLabels.length - 1 : 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
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
            children: List.generate(
              _tabLabels.length,
              (index) => Expanded(
                child: GestureDetector(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _tabController.animateTo(index);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      _tabLabels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                        fontSize: 10,
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

  Widget _buildOverviewCard() {
    final campaign = _campaign;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _currentStatus == CampaignStatus.active;

    return _build3DContainer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildCategoryIcon(campaign.categoryIcon, campaign.categoryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        campaign.categoryLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: campaign.categoryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusPill(
                  _currentStatus.name,
                  isActive ? AppTheme.successColor : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewMetric(
                    label: 'Raised',
                    value: campaign.formattedRaised,
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildOverviewMetric(
                    label: 'Supporters',
                    value: '${campaign.supportersCount}',
                    color: AppTheme.donationColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildOverviewMetric(
                    label: 'Goal',
                    value: campaign.formattedGoal,
                    color: AppTheme.karmaColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildProgressBar(campaign, isDark),
            const SizedBox(height: 10),
            Text(
              campaign.timeRemainingText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: campaign.isUrgent
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
              ),
            ),
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
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildOverviewMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(Campaign campaign, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(campaign.progressPercentage * 100).toInt()}% funded',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            Text(
              campaign.formattedGoal,
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
        const SizedBox(height: 8),
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
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    final donorCount = (_analytics?['donorCount'] as num?)?.toInt() ??
        _campaign.supportersCount;
    final totalDonations = (_analytics?['totalDonations'] as num?)?.toInt() ??
        _campaign.donations.length;
    final totalAmount = _parseAmount(
      _analytics?['totalAmount'] ?? _analytics?['currentAmount'],
      fallback: _campaign.raisedAmount,
    );
    final goalAmount = _parseAmount(
      _analytics?['goalAmount'],
      fallback: _campaign.goalAmount,
    );
    final avgDonation =
        totalDonations > 0 ? totalAmount / totalDonations : 0.0;
    final progressPct = goalAmount > 0
        ? ((totalAmount / goalAmount) * 100).clamp(0, 100)
        : 0.0;
    final recent = (_analytics?['recent'] as List?) ?? const [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loadingAnalytics) const LinearProgressIndicator(),
          Row(
            children: [
              _buildAnalyticCard(
                'Raised',
                '${totalAmount.toStringAsFixed(0)} BYC',
                Icons.volunteer_activism_rounded,
                AppTheme.successColor,
                '${progressPct.toStringAsFixed(0)}% of goal',
              ),
              const SizedBox(width: 12),
              _buildAnalyticCard(
                'Supporters',
                '$donorCount',
                Icons.people_alt_rounded,
                AppTheme.donationColor,
                '$totalDonations donations',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildAnalyticCard(
                'Avg. Donation',
                avgDonation > 0
                    ? '${avgDonation.toStringAsFixed(0)} BYC'
                    : '0 BYC',
                Icons.attach_money,
                Colors.orange,
                'Per donation',
              ),
              const SizedBox(width: 12),
              _buildAnalyticCard(
                'Views',
                '${_campaign.viewsCount}',
                Icons.visibility,
                AppColors.primary,
                'Campaign reach',
              ),
            ],
          ),
          const SizedBox(height: 20),
          ShadowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Recent Donations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ActionShadowCard(
                      onTap: _viewDetailedAnalytics,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      color: AppColors.primary,
                      child: const Text(
                        'View Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (recent.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 40, color: Colors.grey[500]),
                        const SizedBox(height: 8),
                        Text(
                          'No donations yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...recent.take(8).map((raw) {
                    final d = Map<String, dynamic>.from(raw as Map);
                    final donor = (d['donor'] as Map?) ?? {};
                    final profile = (donor['profile'] as Map?) ?? {};
                    final name = d['isAnonymous'] == true
                        ? 'Anonymous'
                        : (profile['displayName']?.toString() ?? 'Supporter');
                    final amount = _parseAmount(d['amount']);
                    final when = DateTime.tryParse(
                          d['createdAt']?.toString() ?? '',
                        ) ??
                        DateTime.now();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                AppTheme.donationColor.withValues(alpha: 0.12),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _formatDate(when),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${amount.toStringAsFixed(0)} BYC',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _parseAmount(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  Widget _buildRewardsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reward Tiers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              OutlinedButton.icon(
                onPressed: _showCreateTierDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Tier'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingTiers) const LinearProgressIndicator(),
          Expanded(
            child: _rewardTiers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.card_giftcard,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        const Text('No reward tiers'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _rewardTiers.length,
                    itemBuilder: (context, index) {
                      final tier = _rewardTiers[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ShadowCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${tier.minimumDonation.toStringAsFixed(0)} BYC',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (tier.limitedQuantity != null)
                                    Text(
                                      '(${(tier.limitedQuantity! - tier.claimedCount)} left of ${tier.limitedQuantity})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  const Spacer(),
                                  Text(
                                    tier.status.name.toUpperCase(),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _editTier(tier),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteTier(tier),
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tier.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tier.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRewardTiers() async {
    try {
      setState(() => _loadingTiers = true);
      final items = await _api().getRewardTiers(_campaign.id);
      final tiers = items
          .map(
            (m) => RewardTier(
              id: (m['id'] ?? '').toString(),
              campaignId: _campaign.id,
              title: (m['title'] ?? '').toString(),
              description: (m['description'] ?? '').toString(),
              minimumDonation: (m['minimumDonation'] is num
                  ? (m['minimumDonation'] as num).toDouble()
                  : double.tryParse('${m['minimumDonation']}') ?? 0.0),
              limitedQuantity: m['limitedQuantity'] as int?,
              claimedCount: (m['claimedCount'] as int?) ?? 0,
              status: _parseRewardTierStatus(m['status']?.toString()),
              includes: const [],
              isPhysical: false,
            ),
          )
          .toList();
      if (mounted) setState(() => _rewardTiers = tiers);
    } catch (_) {
      if (mounted) AppToast.error(context, 'Failed to load reward tiers');
    } finally {
      if (mounted) setState(() => _loadingTiers = false);
    }
  }

  RewardTierStatus _parseRewardTierStatus(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'SOLD_OUT':
        return RewardTierStatus.soldOut;
      case 'CLAIMED':
        return RewardTierStatus.claimed;
      default:
        return RewardTierStatus.available;
    }
  }

  String _updateTypeLabel(String type) {
    switch (type) {
      case 'MILESTONE':
        return 'Milestone update';
      case 'IMAGE':
        return 'Photo update';
      case 'VIDEO':
        return 'Video update';
      default:
        return 'Campaign update';
    }
  }

  IconData _updateTypeIcon(String type) {
    switch (type) {
      case 'MILESTONE':
        return Icons.flag_rounded;
      case 'IMAGE':
        return Icons.image_rounded;
      case 'VIDEO':
        return Icons.videocam_rounded;
      default:
        return Icons.update;
    }
  }

  void _showCreateTierDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final minCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Reward Tier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: minCtrl,
                decoration: const InputDecoration(
                  labelText: 'Minimum Donation (BYC)',
                  border: OutlineInputBorder(),
                  prefixText: 'BYC ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Limited Quantity (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final minStr = minCtrl.text.trim();
              if (title.isEmpty || minStr.isEmpty) return;
              final min = double.tryParse(minStr) ?? 0;
              final qty = int.tryParse(qtyCtrl.text.trim());
              try {
                await _api().createRewardTier(
                  _campaign.id,
                  title: title,
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  minimumDonation: min,
                  limitedQuantity: qty,
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  AppToast.success(context, 'Reward tier added');
                  _loadRewardTiers();
                }
              } catch (e) {
                AppToast.error(context, 'Failed to add tier');
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAnalytics() async {
    try {
      setState(() => _loadingAnalytics = true);
      final data = await _api().getCampaignAnalytics(_campaign.id);
      if (mounted) setState(() => _analytics = data);
    } catch (_) {
      if (mounted) setState(() => _analytics = null);
    } finally {
      if (mounted) setState(() => _loadingAnalytics = false);
    }
  }

  Future<void> _loadUpdates() async {
    try {
      setState(() => _loadingUpdates = true);
      final items = await _api().getCampaignUpdates(_campaign.id);
      if (mounted) setState(() => _updates = items);
    } catch (_) {
      if (mounted) setState(() => _updates = []);
    } finally {
      if (mounted) setState(() => _loadingUpdates = false);
    }
  }

  void _editTier(RewardTier tier) {
    final titleCtrl = TextEditingController(text: tier.title);
    final descCtrl = TextEditingController(text: tier.description);
    final minCtrl = TextEditingController(
      text: tier.minimumDonation.toStringAsFixed(0),
    );
    final qtyCtrl = TextEditingController(
      text: tier.limitedQuantity?.toString() ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Reward Tier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: minCtrl,
                decoration: const InputDecoration(
                  labelText: 'Minimum Donation (BYC)',
                  border: OutlineInputBorder(),
                  prefixText: 'BYC ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Limited Quantity (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final minStr = minCtrl.text.trim();
              if (title.isEmpty || minStr.isEmpty) return;
              final min = double.tryParse(minStr) ?? tier.minimumDonation;
              final qty = int.tryParse(qtyCtrl.text.trim());
              try {
                await _api().updateRewardTier(
                  _campaign.id,
                  tier.id,
                  title: title,
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  minimumDonation: min,
                  limitedQuantity: qty,
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  AppToast.success(context, 'Reward tier updated');
                  _loadRewardTiers();
                }
              } catch (e) {
                AppToast.error(context, 'Failed to update tier');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteTier(RewardTier tier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reward Tier'),
        content: const Text(
          'Are you sure you want to delete this tier? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api().deleteRewardTier(_campaign.id, tier.id);
      AppToast.success(context, 'Reward tier deleted');
      _loadRewardTiers();
    } catch (e) {
      AppToast.error(context, 'Failed to delete tier');
    }
  }

  Widget _buildAnalyticCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Expanded(
      child: ShadowCard(
        shadowIntensity: ShadowIntensity.light,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatesTab() {
    return Column(
      children: [
        // Add Update Button
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ActionShadowCard(
              onTap: _addUpdate,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: _campaign.categoryColor,
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text(
                      'Add Update',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Updates List
        Expanded(
          child: _loadingUpdates
              ? const BybataLoader()
              : _updates.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 48),
                        Icon(Icons.update, size: 56, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Center(
                          child: Text(
                            'No updates yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Share progress with your supporters',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _updates.length,
                      itemBuilder: (context, index) {
                        final update =
                            Map<String, dynamic>.from(_updates[index]);
                        final content =
                            update['content']?.toString().trim() ?? '';
                        final type =
                            update['type']?.toString().toUpperCase() ?? 'TEXT';
                        final title = content.isNotEmpty
                            ? (content.length > 48
                                ? '${content.substring(0, 48)}…'
                                : content)
                            : _updateTypeLabel(type);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ShadowCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _updateTypeIcon(type),
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        type,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (content.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    content,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 12,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      (() {
                                        final raw =
                                            update['createdAt']?.toString() ??
                                                '';
                                        final dt = DateTime.tryParse(raw);
                                        if (dt == null) {
                                          return raw.isEmpty ? 'Unknown' : raw;
                                        }
                                        return _formatDate(dt);
                                      })(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSupportersTab() {
    final supporters = _campaign.donations
        .where((d) => d.status == DonationStatus.completed)
        .toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                '${supporters.isNotEmpty ? supporters.length : _campaign.supportersCount} Supporters',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ActionShadowCard(
                onTap: supporters.isEmpty ? null : _exportSupporters,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                color: AppColors.primary,
                child: Text(
                  'Export',
                  style: TextStyle(
                    color: supporters.isEmpty ? Colors.grey : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: supporters.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 48),
                    Icon(Icons.people_outline,
                        size: 56, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'No supporters yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Share your campaign to get your first donation',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: supporters.length,
                  itemBuilder: (context, index) {
                    final donation = supporters[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ShadowCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.donationColor
                                  .withValues(alpha: 0.12),
                              child: Text(
                                donation.donorName.isNotEmpty
                                    ? donation.donorName[0].toUpperCase()
                                    : '?',
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    donation.donorName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _timeAgo(donation.donatedAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (donation.message != null &&
                                      donation.message!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      donation.message!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              '${donation.amount.toStringAsFixed(0)} BYC',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campaign Status
          ShadowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Campaign Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ActionShadowCard(
                        onTap: _currentStatus == CampaignStatus.active
                            ? null
                            : _activateCampaign,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: _currentStatus == CampaignStatus.active
                            ? Colors.green
                            : null,
                        child: Center(
                          child: Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _currentStatus == CampaignStatus.active
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ActionShadowCard(
                        onTap: _currentStatus == CampaignStatus.paused
                            ? null
                            : _pauseCampaign,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: _currentStatus == CampaignStatus.paused
                            ? Colors.orange
                            : null,
                        child: Center(
                          child: Text(
                            'Paused',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _currentStatus == CampaignStatus.paused
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Campaign Settings
          ShadowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Campaign Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildSettingItem(
                  'Quick Edit Details',
                  'Update title and story',
                  Icons.edit,
                  _quickEditDetails,
                ),
                _buildSettingItem(
                  'Manage Reward Tiers',
                  'Add, edit, or remove reward tiers',
                  Icons.card_giftcard,
                  _manageRewards,
                ),
                _buildSettingItem(
                  'Update Goal Amount',
                  'Change your funding goal',
                  Icons.flag,
                  _updateGoal,
                ),
                _buildSettingItem(
                  'Extend Deadline',
                  'Add more time to your campaign',
                  Icons.schedule,
                  _extendDeadline,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Promotion Tools
          ShadowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Promotion Tools',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildSettingItem(
                  'Share Campaign',
                  'Share on social media and messaging apps',
                  Icons.share,
                  _shareCampaign,
                ),
                _buildSettingItem(
                  'Create Embed Code',
                  'Embed on your website or blog',
                  Icons.code,
                  _createEmbedCode,
                ),
                _buildSettingItem(
                  'Download Media Kit',
                  'Graphics and promotional materials',
                  Icons.download,
                  _downloadMediaKit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Danger Zone
          ShadowCard(
            color: Colors.red.withValues(alpha: 0.05),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingItem(
                  'Cancel Campaign',
                  'Permanently cancel this campaign',
                  Icons.cancel,
                  _cancelCampaign,
                  textColor: Colors.red,
                ),
                if (ListingDeleteRules.canDeleteCampaign(_campaign))
                  _buildSettingItem(
                    'Delete Campaign',
                    'Permanently delete this campaign',
                    Icons.delete_forever,
                    _deleteCampaign,
                    textColor: Colors.red,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ActionShadowCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (textColor ?? Colors.grey).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: textColor ?? Colors.grey[700], size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // Analytics Actions
  void _viewDetailedAnalytics() {
    if (_analytics == null) {
      AppToast.show(context, 'Analytics not available yet');
      return;
    }
    final donorCount = (_analytics!['donorCount'] ?? _campaign.supportersCount).toString();
    final totalDonations = (_analytics!['totalDonations'] ?? _campaign.donations.length).toString();
    final totalAmount = _parseAmount(
      _analytics!['totalAmount'] ?? _analytics!['currentAmount'],
      fallback: _campaign.raisedAmount,
    ).toStringAsFixed(0);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Campaign Analytics'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _analyticsDetailRow('Goal', '${_campaign.formattedGoal}'),
              _analyticsDetailRow('Raised', '$totalAmount BYC'),
              _analyticsDetailRow('Supporters', donorCount),
              _analyticsDetailRow('Donations', totalDonations),
              _analyticsDetailRow('Views', '${_campaign.viewsCount}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _analyticsDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // Update Actions
  void _addUpdate() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post Update'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Share progress with your supporters…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final content = controller.text.trim();
              if (content.isEmpty) return;
              try {
                await _api().postCampaignUpdate(
                  _campaign.id,
                  type: 'TEXT',
                  content: content,
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  AppToast.success(context, 'Update posted');
                  _loadUpdates();
                }
              } catch (_) {
                AppToast.error(context, 'Failed to post update');
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  // Supporter Actions
  Future<void> _exportSupporters() async {
    final supporters = _campaign.donations
        .where((d) => d.status == DonationStatus.completed)
        .toList();
    if (supporters.isEmpty) {
      AppToast.show(context, 'No supporters to export');
      return;
    }
    final buffer = StringBuffer('Supporter,Amount (BYC),Date,Message\n');
    for (final d in supporters) {
      final message = (d.message ?? '').replaceAll(',', ' ');
      buffer.writeln(
        '${d.donorName},${d.amount.toStringAsFixed(0)},${d.donatedAt.toIso8601String()},$message',
      );
    }
    await Share.share(
      buffer.toString(),
      subject: '${_campaign.title} supporters',
    );
  }

  // Campaign Actions
  void _editCampaign() {
    AppRoutes.navigateToEditCampaign(context, _campaign);
  }

  void _pauseCampaign() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pause Campaign'),
        content: const Text(
          'Are you sure you want to pause this campaign? You can reactivate it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateCampaignStatus('PAUSED');
            },
            child: const Text('Pause'),
          ),
        ],
      ),
    );
  }

  void _promoteCampaign() {
    _shareCampaign();
  }

  Future<void> _activateCampaign() async {
    await _updateCampaignStatus('ACTIVE');
  }

  void _manageRewards() {
    _tabController.animateTo(1);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inMinutes} minutes ago';
    }
  }

  String _timeAgo(DateTime dt) => _formatDate(dt);

  void _updateGoal() {
    showDialog(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController(
          text: _campaign.goalAmount.toStringAsFixed(0),
        );
        return AlertDialog(
          title: const Text('Update Goal Amount'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter new goal amount (BYC)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final v = double.tryParse(ctrl.text);
                if (v == null || v <= 0) {
                  Navigator.pop(context);
                  AppToast.error(context, 'Invalid amount');
                  return;
                }
                try {
                  await _api().updateCampaign(_campaign.id, goalAmount: v);
                  if (!mounted) return;
                  Navigator.pop(context);
                  AppToast.success(context, 'Goal updated');
                  await _loadCampaign();
                } catch (_) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  AppToast.error(context, 'Failed to update goal');
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _extendDeadline() {
    showDatePicker(
      context: context,
      initialDate: _campaign.deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    ).then((date) async {
      if (date == null) return;
      try {
        await _api().updateCampaign(_campaign.id, endsAt: date);
        if (!mounted) return;
        AppToast.success(context, 'Deadline extended');
        await _loadCampaign();
      } catch (_) {
        if (!mounted) return;
        AppToast.error(context, 'Failed to extend deadline');
      }
    });
  }

  void _shareCampaign() {
    ShareUtils.shareCampaign(
      context,
      id: _campaign.id.toString(),
      title: _campaign.title,
    );
  }

  void _createEmbedCode() {
    ShareUtils.shareCampaign(
      context,
      id: _campaign.id,
      title: _campaign.title,
    );
  }

  void _downloadMediaKit() {
    _shareCampaign();
  }

  void _cancelCampaign() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Campaign'),
        content: const Text(
          'Are you sure you want to cancel this campaign? This action cannot be undone and all supporters will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateCampaignStatus('CANCELLED');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Campaign'),
          ),
        ],
      ),
    );
  }

  void _deleteCampaign() async {
    final campaign = _campaign;
    final confirmed = await confirmDeleteListing(
      context,
      title: campaign.title,
      itemLabel: 'campaign',
      blockedReason: ListingDeleteRules.campaignDeleteBlockedReason(campaign),
    );
    if (!confirmed || !mounted) return;

    final provider = Provider.of<CampaignProvider>(context, listen: false);
    final success = await provider.deleteCampaign(campaign.id);
    if (!mounted) return;
    if (success) {
      showDeleteListingResult(context, success: true, message: 'Campaign deleted');
      Navigator.pop(context);
    } else {
      showDeleteListingResult(
        context,
        success: false,
        message: provider.error ?? 'Failed to delete campaign',
      );
    }
  }

  Future<void> _updateCampaignStatus(String status) async {
    try {
      await _api().updateCampaignStatus(_campaign.id, status);
      if (!mounted) return;
      setState(() => _currentStatus = _mapStatus(status));
      AppToast.success(context, 'Status updated');
      await _loadCampaign();
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to update status');
    }
  }

  CampaignStatus _mapStatus(String s) {
    switch (s.toUpperCase()) {
      case 'ACTIVE':
        return CampaignStatus.active;
      case 'PAUSED':
        return CampaignStatus.paused;
      case 'COMPLETED':
        return CampaignStatus.completed;
      case 'CANCELLED':
        return CampaignStatus.cancelled;
      default:
        return _currentStatus;
    }
  }

  void _quickEditDetails() {
    final titleCtrl = TextEditingController(text: _campaign.title);
    final storyCtrl = TextEditingController(text: _campaign.story);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Edit Details'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Title'),
                controller: titleCtrl,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(labelText: 'Story'),
                controller: storyCtrl,
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _api().updateCampaign(
                  _campaign.id,
                  title: titleCtrl.text.trim(),
                  description: storyCtrl.text.trim(),
                );
                if (!mounted) return;
                Navigator.pop(context);
                AppToast.success(context, 'Details updated');
                await _loadCampaign();
              } catch (_) {
                if (!mounted) return;
                Navigator.pop(context);
                AppToast.error(context, 'Failed to update details');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
