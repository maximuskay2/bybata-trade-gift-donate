import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart' show AppConstants;
import '../../../core/navigation/app_routes.dart';
import '../../../core/utils/listing_delete_helper.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/network_error_message.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/widgets/hub_screen_top_bar.dart';
import '../../common/widgets/state_components.dart';
import '../../settings/widgets/settings_ui.dart';
import '../models/gift_models.dart';
import '../providers/gift_provider.dart';
import 'gift_details_loader.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class MyGiftsScreen extends StatefulWidget {
  const MyGiftsScreen({super.key});

  @override
  State<MyGiftsScreen> createState() => _MyGiftsScreenState();
}

class _MyGiftsScreenState extends State<MyGiftsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshJourney());
  }

  Future<void> _refreshJourney() async {
    final gp = context.read<GiftProvider>();
    if (mounted) setState(() => _initialLoadDone = false);

    await Future.wait([
      gp.loadMyGifts(page: 1, size: 100, force: true),
      gp.loadGiftHistory(page: 1, size: 100, force: true),
    ]);

    if (mounted) {
      unawaited(gp.loadUserAnalytics());
      setState(() => _initialLoadDone = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GiftProvider>();
    final userId = context.watch<AuthProvider>().currentUser?.id ?? '';
    final given = gp.myGifts;
    final received =
        userId.isEmpty ? <GiftClaim>[] : gp.receivedGiftsFor(userId);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SettingsUi.pageBackground(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HubScreenTopBar(
            title: 'My Gifts',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshJourney,
              color: AppTheme.primaryColor,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Text(
                        'Track gifts you have given and received',
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _buildStatsSection(gp, userId, given.length, received.length),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: _buildTabSwitcher(context),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildGiftsGivenTab(gp, given),
                        _buildGiftsReceivedTab(gp, received),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
    GiftProvider gp,
    String userId,
    int givenCount,
    int receivedCount,
  ) {
    if (gp.error != null && gp.error!.contains('Too many requests')) {
      return const SizedBox.shrink();
    }

    final analytics = gp.userAnalytics;
    final totalGiven = analytics?.totalGiftsGiven ?? givenCount;
    final totalReceived = analytics?.totalGiftsReceived ?? receivedCount;
    final karma = analytics?.totalKarmaEarned ??
        gp.receivedGiftsFor(userId).fold<int>(0, (sum, c) => sum + c.karmaAwarded);

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(SettingsUi.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    context,
                    label: 'Given',
                    value: '$totalGiven',
                    icon: Icons.volunteer_activism_rounded,
                    color: AppTheme.giftColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatTile(
                    context,
                    label: 'Received',
                    value: '$totalReceived',
                    icon: Icons.card_giftcard_rounded,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatTile(
                    context,
                    label: 'Karma',
                    value: '$karma',
                    icon: Icons.star_rounded,
                    color: AppTheme.karmaColor,
                  ),
                ),
              ],
            ),
            if (analytics != null && analytics.categoryBreakdown.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile(
                      context,
                      label: 'Avg rating',
                      value: analytics.averageRating.toStringAsFixed(1),
                      icon: Icons.star_outline_rounded,
                      color: AppColors.warning,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatTile(
                      context,
                      label: 'Top category',
                      value: analytics.categoryBreakdown.entries.first.key.name,
                      icon: Icons.category_outlined,
                      color: AppTheme.communityColor,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(
    BuildContext context, {
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
              fontSize: compact ? 16 : 20,
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

  Widget _buildTabSwitcher(BuildContext context) {
    const labels = ['Given', 'Received'];
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment(_currentTabIndex == 0 ? -1.0 : 1.0, 0),
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(labels.length, (index) {
              final selected = _currentTabIndex == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _currentTabIndex = index);
                    _tabController.animateTo(index);
                  },
                  child: Center(
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftsGivenTab(GiftProvider gp, List<Gift> items) {
    if (!_initialLoadDone || (gp.isLoading && items.isEmpty)) {
      return const BybataLoader();
    }
    if (gp.myGiftsError != null && items.isEmpty) {
      return _buildErrorState(gp.myGiftsError!, _refreshJourney);
    }

    if (items.isEmpty) {
      return _buildEmptyState(
        'No gifts given yet',
        'Create a gift from the Gifting Hub',
        Icons.volunteer_activism_outlined,
        onAction: () => GuardedNavigator.pushNamed(context, AppConstants.giftingRoute),
        actionLabel: 'Go to Gifting Hub',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildGivenGiftCard(items[index]),
    );
  }

  Widget _buildGiftsReceivedTab(GiftProvider gp, List<GiftClaim> items) {
    if (!_initialLoadDone || (gp.isLoading && items.isEmpty)) {
      return const BybataLoader();
    }
    if (gp.historyError != null && items.isEmpty) {
      return _buildErrorState(gp.historyError!, _refreshJourney);
    }

    if (items.isEmpty) {
      return _buildEmptyState(
        'No gifts received yet',
        'Browse available gifts to claim',
        Icons.card_giftcard_outlined,
        onAction: () => GuardedNavigator.pushNamed(context, AppConstants.giftingRoute),
        actionLabel: 'Browse gifts',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildReceivedGiftCard(items[index]),
    );
  }

  void _openGiftDetails(String giftId) {
    GuardedNavigator.push(context,
      MaterialPageRoute(builder: (_) => GiftDetailsLoader(giftId: giftId)),
    );
  }

  Future<void> _deleteGift(Gift gift) async {
    final confirmed = await confirmDeleteListing(
      context,
      title: gift.title,
      itemLabel: 'gift',
      blockedReason: ListingDeleteRules.giftDeleteBlockedReason(gift),
    );
    if (!confirmed || !mounted) return;

    final provider = context.read<GiftProvider>();
    final success = await provider.deleteGift(gift.id);
    if (!mounted) return;
    if (success) {
      showDeleteListingResult(context, success: true, message: 'Gift deleted');
      await _refreshJourney();
    } else {
      showDeleteListingResult(
        context,
        success: false,
        message: provider.error ?? 'Failed to delete gift',
      );
    }
  }

  Widget _buildGivenGiftCard(Gift gift) {
    final scheme = Theme.of(context).colorScheme;
    final statusStr = _mapStatusLabel(gift.status);
    final statusColor = _getStatusColor(statusStr);
    final claimedBy = gift.claimedBy?.name;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openGiftDetails(gift.id),
        borderRadius: BorderRadius.circular(SettingsUi.cardRadius),
        child: ByBataGlassContainer(
          borderRadius: BorderRadius.circular(SettingsUi.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _leadingIcon(Icons.card_giftcard_rounded, AppTheme.giftColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gift.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            claimedBy != null
                                ? 'Claimed by $claimedBy'
                                : 'Posted by you',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusChip(statusStr, statusColor),
                    if (ListingDeleteRules.canDeleteGift(gift))
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        color: Colors.red,
                        tooltip: 'Delete gift',
                        onPressed: () => _deleteGift(gift),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                        size: 22,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _metaChip(Icons.visibility_outlined, '${gift.viewCount} views'),
                    _metaChip(
                      Icons.inbox_outlined,
                      '${gift.currentClaims}/${gift.maxClaims} claims',
                    ),
                    _metaChip(
                      Icons.star_rounded,
                      '+${gift.karmaReward} karma',
                      color: AppTheme.karmaColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceivedGiftCard(GiftClaim claim) {
    final scheme = Theme.of(context).colorScheme;
    final dateLabel =
        '${claim.claimedAt.day}/${claim.claimedAt.month}/${claim.claimedAt.year}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openGiftDetails(claim.giftId),
        borderRadius: BorderRadius.circular(SettingsUi.cardRadius),
        child: ByBataGlassContainer(
          borderRadius: BorderRadius.circular(SettingsUi.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _leadingIcon(Icons.redeem_rounded, AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        claim.gift.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'From ${claim.gift.giver.name} · $dateLabel',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => AppRoutes.navigateToGiftHistory(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('View full history'),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.karmaColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+${claim.karmaAwarded} KARMA',
                        style: const TextStyle(
                          color: AppTheme.karmaColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leadingIcon(IconData icon, Color color) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text, {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: tint),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: tint,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, Future<void> Function() onRetry) {
    return ErrorState(
      title: NetworkErrorMessage.titleFrom(message),
      message: NetworkErrorMessage.sanitize(message),
      type: ErrorStateType.network,
      actionText: 'Try again',
      onRetry: () => onRetry(),
    );
  }

  String _mapStatusLabel(GiftStatus status) {
    switch (status) {
      case GiftStatus.active:
        return 'Active';
      case GiftStatus.pending:
        return 'Pending';
      case GiftStatus.claimed:
        return 'Claimed';
      case GiftStatus.completed:
        return 'Completed';
      case GiftStatus.expired:
        return 'Expired';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return AppTheme.successColor;
      case 'Pending':
        return AppColors.warning;
      case 'Claimed':
      case 'Completed':
        return AppTheme.primaryColor;
      case 'Expired':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }
}
