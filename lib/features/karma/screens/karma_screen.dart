import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/karma/karma_membership_utils.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../models/karma_models.dart';
import '../navigation/karma_navigator.dart';
import '../services/karma_api_service.dart';
import '../services/karma_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';

/// Main KARMA hub — points, tier, shortcuts, and recent activity.
class KarmaScreen extends StatefulWidget {
  const KarmaScreen({super.key});

  @override
  State<KarmaScreen> createState() => _KarmaScreenState();
}

class _KarmaScreenState extends State<KarmaScreen> {
  KarmaMembershipInfo? _membership;
  bool _membershipLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await _refresh();
  }

  Future<void> _refresh() async {
    final karma = context.read<KarmaService>();
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? karma.currentUserKarma?.userId ?? 'me';
    await karma.refresh(userId);
    final raw = await karma.fetchKarmaAccountFromApi();
    if (!mounted) return;
    final points = karma.currentUserKarma?.totalPoints ??
        (raw?['currentPoints'] as num?)?.toInt() ??
        0;
    setState(() {
      _membership = raw != null
          ? KarmaMembershipInfo.fromKarmaJson(raw)
          : KarmaMembershipInfo.fromTier('NEWCOMER', points);
      _membershipLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('KARMA'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'About KARMA',
            onPressed: () => KarmaNavigator.showKarmaInfoDialog(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'stats':
                  KarmaNavigator.toKarmaStats(context);
                case 'settings':
                  KarmaNavigator.toKarmaSettings(context);
                case 'reset':
                  _showResetDialog(context);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'stats',
                child: ListTile(
                  leading: Icon(Icons.analytics_outlined),
                  title: Text('Statistics'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (Theme.of(ctx).brightness == Brightness.light)
                const PopupMenuItem(
                  value: 'reset',
                  child: ListTile(
                    leading: Icon(Icons.refresh, color: Colors.red),
                    title: Text('Reset KARMA', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Consumer<KarmaService>(
        builder: (context, karma, _) {
          if (karma.isLoading && karma.currentUserKarma == null) {
            return const BybataLoader();
          }

          if (karma.error != null && karma.currentUserKarma == null) {
            return _buildErrorState(context, karma);
          }

          final user = karma.currentUserKarma;
          if (user == null) {
            return Center(
              child: Text(
                'No KARMA data yet',
                style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
              ),
            );
          }

          final m = _membership ??
              KarmaMembershipInfo.fromTier('NEWCOMER', user.totalPoints);

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.primaryColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _buildHeroCard(context, user, m, scheme),
                const SizedBox(height: 16),
                _buildStatsRow(context, user, m, scheme),
                const SizedBox(height: 16),
                _buildShortcuts(context, scheme),
                const SizedBox(height: 16),
                _WithdrawToWalletCard(currentPoints: user.totalPoints),
                const SizedBox(height: 16),
                _buildRecentActivity(context, user, scheme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, KarmaService karma) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              'Could not load KARMA',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              karma.error ?? 'Check your connection',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _refresh,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    UserKarma user,
    KarmaMembershipInfo m,
    ColorScheme scheme,
  ) {
    final style = tierStyle(m.tier);
    final progress = karmaTierProgress(user.totalPoints);
    final rank = user.rank;
    final rankText = rank > 0 && rank < 999999 ? '#$rank' : '—';

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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.karmaColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.karmaColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user.totalPoints}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        'KARMA points',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_membershipLoaded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: style.$1.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.$2, size: 16, color: style.$1),
                        const SizedBox(width: 4),
                        Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: style.$1,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (m.nextTierLabel != null) ...[
              const SizedBox(height: 18),
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
                    '${m.pointsToNextTier} pts · Rank $rankText',
                    style: TextStyle(
                      fontSize: 11,
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
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: style.$1,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _miniStat(
                  scheme,
                  Icons.local_fire_department_outlined,
                  '${user.currentStreak.currentStreak}d',
                  'Streak',
                ),
                _miniStat(
                  scheme,
                  Icons.trending_up_rounded,
                  '${user.stats.thisWeekPoints}',
                  'This week',
                ),
                _miniStat(
                  scheme,
                  Icons.calendar_month_outlined,
                  '${user.stats.thisMonthPoints}',
                  'This month',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(
    ColorScheme scheme,
    IconData icon,
    String value,
    String label,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: scheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    UserKarma user,
    KarmaMembershipInfo m,
    ColorScheme scheme,
  ) {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            scheme,
            icon: Icons.verified_user_outlined,
            label: 'Trust',
            value: m.label,
            onTap: () => KarmaNavigator.toTrustLevel(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(
            scheme,
            icon: Icons.emoji_events_outlined,
            label: 'Achievements',
            value: '${user.achievements.length}',
            onTap: () => KarmaNavigator.toAchievements(context),
          ),
        ),
      ],
    );
  }

  Widget _statTile(
    ColorScheme scheme, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ByBataGlassContainer(
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 26),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortcuts(BuildContext context, ColorScheme scheme) {
    final items = [
      (
        Icons.add_circle_outline_rounded,
        'Earn KARMA',
        AppTheme.successColor,
        () => KarmaNavigator.toEarnKarma(context),
      ),
      (
        Icons.leaderboard_rounded,
        'Leaderboard',
        AppTheme.karmaColor,
        () => KarmaNavigator.toLeaderboard(context),
      ),
      (
        Icons.history_rounded,
        'History',
        AppTheme.primaryColor,
        () => KarmaNavigator.toKarmaHistory(context),
      ),
      (
        Icons.military_tech_outlined,
        'Achievements',
        Colors.amber,
        () => KarmaNavigator.toAchievements(context),
      ),
    ];

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shortcuts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _shortcutBtn(context, scheme, items[0])),
                const SizedBox(width: 10),
                Expanded(child: _shortcutBtn(context, scheme, items[1])),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _shortcutBtn(context, scheme, items[2])),
                const SizedBox(width: 10),
                Expanded(child: _shortcutBtn(context, scheme, items[3])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shortcutBtn(
    BuildContext context,
    ColorScheme scheme,
    (IconData, String, Color, VoidCallback) item,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.$4,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(item.$1, color: item.$3, size: 26),
              const SizedBox(height: 6),
              Text(
                item.$2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(
    BuildContext context,
    UserKarma user,
    ColorScheme scheme,
  ) {
    final items = user.recentActivity.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () => KarmaNavigator.toKarmaHistory(context),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (items.isEmpty)
          ByBataGlassContainer(
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 40,
                      color: scheme.onSurface.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No activity yet',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trade, gift, or verify to earn KARMA',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ByBataGlassContainer(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: scheme.outline.withValues(alpha: 0.15),
                    ),
                  _activityRow(context, items[i], scheme),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _activityRow(
    BuildContext context,
    KarmaTransaction tx,
    ColorScheme scheme,
  ) {
    return InkWell(
      onTap: () => KarmaNavigator.showTransactionDetails(
        context,
        transaction: tx,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tx.activity.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tx.activity.icon, color: tx.activity.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.activity.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    tx.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '+${tx.pointsEarned}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.successColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset KARMA?'),
        content: const Text(
          'This resets points, level, achievements, and history. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              KarmaService().resetUserKarma();
              AppToast.show(context, 'KARMA profile reset');
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

/// Convert KARMA points to BYC in wallet.
class _WithdrawToWalletCard extends StatefulWidget {
  final int currentPoints;

  const _WithdrawToWalletCard({required this.currentPoints});

  @override
  State<_WithdrawToWalletCard> createState() => _WithdrawToWalletCardState();
}

class _WithdrawToWalletCardState extends State<_WithdrawToWalletCard> {
  KarmaWithdrawSettings? _settings;
  bool _loading = true;
  bool _withdrawing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = KarmaApiService(ApiClient(baseUrl, const FlutterSecureStorage()));
      final settings = await api.getWithdrawSettings();
      if (mounted) {
        setState(() {
          _settings = settings;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load withdraw settings';
          _loading = false;
        });
      }
    }
  }

  Future<void> _withdraw() async {
    if (_settings == null ||
        widget.currentPoints < _settings!.minThreshold) {
      return;
    }
    final points = _settings!.minThreshold;
    final byc = _settings!.karmaToByc(points);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw KARMA'),
        content: Text(
          'Convert $points KARMA to ${byc.toStringAsFixed(4)} BYC?\n\n'
          'Rate: ${_settings!.karmaToBycRate} KARMA = 1 BYC',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _withdrawing = true;
      _error = null;
    });

    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = KarmaApiService(ApiClient(baseUrl, const FlutterSecureStorage()));
      final result = await api.withdrawToWallet(points);
      if (!mounted) return;
      AppToast.success(
        context,
        '${result.bycAmount.toStringAsFixed(4)} BYC moved to your wallet',
        title: 'Withdrawal complete',
      );
      final auth = context.read<AuthProvider>();
      final uid = auth.currentUser?.id ?? 'me';
      await context.read<KarmaService>().refresh(uid);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Withdraw failed');
        AppToast.error(context, 'Withdraw failed: $e');
      }
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return ByBataGlassContainer(
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.all(28),
          child: const BybataLoader(),
        ),
      );
    }

    final min = _settings?.minThreshold ?? 0;
    final canWithdraw =
        _settings != null && widget.currentPoints >= min;
    final needed = min - widget.currentPoints;

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppTheme.successColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'Withdraw to wallet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            if (_settings != null) ...[
              const SizedBox(height: 8),
              Text(
                'Min $min KARMA → ${_settings!.karmaToByc(min).toStringAsFixed(2)} BYC',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(fontSize: 12, color: scheme.error)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canWithdraw && !_withdrawing ? _withdraw : null,
                icon: _withdrawing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  canWithdraw
                      ? 'Withdraw $min KARMA'
                      : needed > 0
                          ? '$needed more KARMA needed'
                          : 'Withdraw unavailable',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
