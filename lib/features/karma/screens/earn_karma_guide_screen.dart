import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/karma/karma_membership_utils.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../community/navigation/community_routes.dart';
import '../../referrals/services/referral_api_service.dart';
import '../../referrals/widgets/referral_share_card.dart';
import '../../settings/screens/settings_security_screen.dart';
import '../navigation/karma_navigator.dart';
import '../services/karma_api_service.dart';
import '../services/karma_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Production earn guide — loads live methods, points, and completion from the API.
class EarnKarmaGuideScreen extends StatefulWidget {
  const EarnKarmaGuideScreen({super.key});

  @override
  State<EarnKarmaGuideScreen> createState() => _EarnKarmaGuideScreenState();
}

class _EarnKarmaGuideScreenState extends State<EarnKarmaGuideScreen> {
  String _selectedCategory = 'All';
  bool _isLoading = false;
  bool _isGuideLoading = true;
  String? _guideError;
  KarmaMembershipInfo? _membership;
  int _points = 0;
  KarmaEarnGuide? _guide;
  ReferralStats? _referralStats;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _refreshKarma(),
      _loadEarnGuide(),
      _loadReferralStats(),
    ]);
  }

  Future<void> _refreshKarma() async {
    final karma = context.read<KarmaService>();
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? karma.currentUserKarma?.userId;
    if (userId != null) {
      await karma.refresh(userId);
    }
    final raw = await karma.fetchKarmaAccountFromApi();
    if (!mounted) return;
    setState(() {
      _points = karma.currentUserKarma?.totalPoints ??
          (raw?['currentPoints'] as num?)?.toInt() ??
          0;
      _membership = raw != null
          ? KarmaMembershipInfo.fromKarmaJson(raw)
          : KarmaMembershipInfo.fromTier('NEWCOMER', _points);
    });
  }

  Future<void> _loadEarnGuide() async {
    setState(() {
      _isGuideLoading = true;
      _guideError = null;
    });
    try {
      final karma = context.read<KarmaService>();
      if (karma.apiService == null) {
        throw Exception('API not ready');
      }
      final guide = await karma.apiService!.getEarnGuide();
      if (!mounted) return;
      setState(() {
        _guide = guide;
        if (!guide.categories.contains(_selectedCategory)) {
          _selectedCategory = 'All';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _guideError = 'Could not load earn guide');
    } finally {
      if (mounted) setState(() => _isGuideLoading = false);
    }
  }

  Future<void> _loadReferralStats() async {
    try {
      final service = await ReferralApiService.create();
      final stats = await service.getMyReferralStats();
      if (!mounted) return;
      setState(() => _referralStats = stats);
    } catch (_) {
      // Referral sheet will show a retry state if needed.
    }
  }

  List<EarnGuideMethod> get _filteredMethods {
    final methods = _guide?.methods ?? const <EarnGuideMethod>[];
    if (_selectedCategory == 'All') return methods;
    return methods.where((m) => m.category == _selectedCategory).toList();
  }

  List<String> get _categories =>
      _guide?.categories ?? const ['All', 'Trading', 'Social', 'Referrals', 'Verification', 'Events'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final karma = context.watch<KarmaService>();
    final m = _membership ?? KarmaMembershipInfo.fromTier('NEWCOMER', _points);
    final tierStylePair = tierStyle(m.tier);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Earn KARMA'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshAll,
            color: AppTheme.primaryColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _buildHeroCard(scheme, m, tierStylePair),
                const SizedBox(height: 20),
                _buildCategoryChips(scheme),
                const SizedBox(height: 16),
                if (_isGuideLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: const BybataLoader(),
                  )
                else if (_guideError != null)
                  _buildGuideError(scheme)
                else ...[
                  Text(
                    '${_filteredMethods.length} ways to earn',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._filteredMethods.map(
                    (method) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildMethodTile(context, scheme, method),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _buildTipsCard(scheme),
                const SizedBox(height: 16),
                _buildProgressCard(context, scheme, karma),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => KarmaNavigator.toTrustLevel(context),
                    icon: const Icon(Icons.verified_user_outlined, size: 20),
                    label: const Text('View trust level'),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const BybataLoader(),
            ),
        ],
      ),
    );
  }

  Widget _buildGuideError(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: scheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            _guideError!,
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _loadEarnGuide, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    ColorScheme scheme,
    KarmaMembershipInfo m,
    (Color, IconData) style,
  ) {
    final progress = karmaTierProgress(_points);
    final streak = _guide?.stats.streak ?? 0;

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.karmaColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.karmaColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_points KARMA',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        '${m.label} · ${m.isPremium ? "Premium" : "Member"}',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (streak > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.local_fire_department_rounded, size: 18, color: AppTheme.karmaColor),
                  const SizedBox(width: 6),
                  Text(
                    '$streak day streak',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.karmaColor,
                    ),
                  ),
                ],
              ),
            ],
            if (m.nextTierLabel != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Next: ${m.nextTierLabel}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    '${m.pointsToNextTier} pts',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: style.$1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(ColorScheme scheme) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final selected = _selectedCategory == cat;
          return FilterChip(
            label: Text(cat),
            selected: selected,
            onSelected: (_) => setState(() => _selectedCategory = cat),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? AppTheme.primaryColor
                  : scheme.onSurface.withValues(alpha: 0.7),
            ),
            selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            backgroundColor: scheme.surfaceContainerHighest,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }

  Widget _buildMethodTile(
    BuildContext context,
    ColorScheme scheme,
    EarnGuideMethod method,
  ) {
    final done = method.isCompleted && !method.canClaim;
    final showGo = method.canClaim || (!done && method.isRecurring) || !method.isCompleted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMethodSheet(context, method),
        borderRadius: BorderRadius.circular(16),
        child: ByBataGlassContainer(
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: done
                        ? AppTheme.successColor.withValues(alpha: 0.12)
                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : _iconForKey(method.iconKey),
                    color: done ? AppTheme.successColor : AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: scheme.onSurface,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        method.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (method.isRecurring) ...[
                        const SizedBox(height: 4),
                        Text(
                          method.canClaim ? 'Ready to claim' : 'Repeatable',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: method.canClaim
                                ? AppTheme.successColor
                                : AppTheme.karmaColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (method.points > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.karmaColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${method.points}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.karmaColor,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (showGo)
                      TextButton(
                        onPressed: () => _handleAction(context, method),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(method.canClaim ? 'Claim' : 'Go'),
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

  Widget _buildTipsCard(ColorScheme scheme) {
    final tips = _guide?.tips ??
        const [
          'Verify your account first — it unlocks the most rewards.',
          'Daily actions and streaks add up quickly.',
          'Referrals give some of the biggest single boosts.',
        ];

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tips_and_updates_outlined, color: AppTheme.primaryColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Quick tips',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tips.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 6, color: AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: scheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    ColorScheme scheme,
    KarmaService karma,
  ) {
    final user = karma.currentUserKarma;
    final monthPts = user?.stats.thisMonthPoints ?? 0;
    final activities = user?.stats.totalTransactions ?? 0;
    final rank = user?.rank ?? 0;
    final rankText = rank > 0 && rank < 999999 ? '#$rank' : '—';
    final nextPts = user?.pointsToNextLevel ?? 0;
    final guideStats = _guide?.stats;

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This month',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _statCell(scheme, _formatNumber(monthPts), 'Earned', Icons.stars_rounded),
                _statCell(
                  scheme,
                  guideStats != null
                      ? '${guideStats.completedOneTime}/${guideStats.totalOneTime}'
                      : '$activities',
                  guideStats != null ? 'Milestones' : 'Activities',
                  Icons.check_circle_outline_rounded,
                ),
                _statCell(scheme, rankText, 'Rank', Icons.leaderboard_outlined),
              ],
            ),
            if (nextPts > 0) ...[
              const SizedBox(height: 14),
              Text(
                '$nextPts points to your next level',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCell(ColorScheme scheme, String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _showMethodSheet(BuildContext context, EarnGuideMethod method) {
    final scheme = Theme.of(context).colorScheme;
    final done = method.isCompleted && !method.canClaim;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.paddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _iconForKey(method.iconKey),
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (method.points > 0)
                        Text(
                          '+${method.points} KARMA',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.karmaColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              method.description,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            if (method.isRecurring) ...[
              const SizedBox(height: 12),
              Text(
                method.canClaim
                    ? 'Your daily reward is ready to claim.'
                    : 'You can earn this reward more than once.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.karmaColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: done
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _handleAction(context, method);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  done
                      ? 'Completed'
                      : method.canClaim
                          ? 'Claim now'
                          : method.actionLabel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, EarnGuideMethod method) async {
    if (method.canClaim && method.claimActionType != null) {
      await _earnFromApi(context, method, method.claimActionType!);
      return;
    }

    switch (method.route) {
      case 'create_trade':
        AppRoutes.navigateToCreateTrade(context);
      case 'browse_trades':
        GuardedNavigator.pushNamed(context, AppConstants.tradeRoute);
      case 'refer_friend':
        await _showReferralSheet(context);
      case 'verification':
        AppRoutes.navigateToVerification(context);
      case 'settings_security':
        GuardedNavigator.push(context,
          MaterialPageRoute(builder: (_) => const SettingsSecurityScreen()),
        );
      case 'community_discover':
        CommunityRoutes.navigateToDiscover(context);
      case 'create_gift':
        AppRoutes.navigateToCreateGift(context);
      case 'browse_donations':
        GuardedNavigator.pushNamed(context, AppConstants.donationsRoute);
      case 'leaderboard':
        KarmaNavigator.toLeaderboard(context);
      case 'achievements':
        KarmaNavigator.toAchievements(context);
      default:
        _snack(context, 'Action not available', success: false);
    }
  }

  Future<void> _earnFromApi(
    BuildContext context,
    EarnGuideMethod method,
    String actionType,
  ) async {
    setState(() => _isLoading = true);

    try {
      final karma = context.read<KarmaService>();
      if (karma.apiService == null) {
        throw Exception('API not ready');
      }

      final response = await karma.apiService!.earnFromAction(
        actionType,
        metadata: {
          'source': 'earn_guide',
          'methodId': method.id,
        },
      );

      final userId = karma.currentUserKarma?.userId ?? '';
      if (userId.isNotEmpty) await karma.refresh(userId);
      await _refreshAll();

      if (!context.mounted) return;
      _snack(
        context,
        '+${response.pointsEarned} KARMA · Total ${response.totalPoints}',
        success: true,
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString().contains('already claimed')
          ? 'Already claimed today — come back tomorrow'
          : 'Could not claim KARMA right now';
      _snack(context, msg, success: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showReferralSheet(BuildContext context) async {
    ReferralStats? stats = _referralStats;
    if (stats == null || stats.referralCode.isEmpty) {
      setState(() => _isLoading = true);
      try {
        final service = await ReferralApiService.create();
        stats = await service.getMyReferralStats();
        if (mounted) setState(() => _referralStats = stats);
      } catch (_) {
        if (context.mounted) {
          _snack(context, 'Could not load referral code', success: false);
        }
        return;
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    if (!context.mounted || stats == null || stats.referralCode.isEmpty) {
      if (context.mounted) {
        _snack(context, 'Referral code unavailable', success: false);
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: SingleChildScrollView(
          child: ReferralShareCard(stats: stats!),
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg, {bool success = false}) {
    AppToast.success(context, msg);
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  IconData _iconForKey(String key) {
    switch (key) {
      case 'swap_horiz':
        return Icons.swap_horiz_rounded;
      case 'bar_chart':
        return Icons.bar_chart_rounded;
      case 'person_add':
        return Icons.person_add_alt_1_rounded;
      case 'verified_user':
        return Icons.verified_user_outlined;
      case 'security':
        return Icons.security_rounded;
      case 'forum':
        return Icons.forum_outlined;
      case 'lightbulb':
        return Icons.lightbulb_outline_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_outlined;
      case 'emoji_events':
        return Icons.emoji_events_outlined;
      case 'military_tech':
        return Icons.military_tech_outlined;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'volunteer_activism':
        return Icons.volunteer_activism_rounded;
      default:
        return Icons.stars_rounded;
    }
  }
}
