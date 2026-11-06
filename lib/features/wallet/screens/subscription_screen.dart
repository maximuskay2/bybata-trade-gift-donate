import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/karma/karma_membership_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../karma/navigation/karma_navigator.dart';
import 'package:bybata/core/providers/auth_provider.dart';
import '../../karma/screens/karma_screen.dart';
import '../../karma/services/karma_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Membership status earned through KARMA — not a paid store subscription.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  KarmaMembershipInfo? _membership;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final karma = Provider.of<KarmaService>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId =
          auth.currentUser?.id ?? karma.currentUserKarma?.userId;
      if (userId != null) {
        await karma.refresh(userId);
      }
      final raw = await karma.fetchKarmaAccountFromApi();
      if (!mounted) return;
      if (raw != null) {
        setState(() {
          _membership = KarmaMembershipInfo.fromKarmaJson(raw);
          _loading = false;
        });
      } else {
        final points = karma.currentUserKarma?.totalPoints ?? 0;
        setState(() {
          _membership = KarmaMembershipInfo.fromTier('NEWCOMER', points);
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membership'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      backgroundColor: scheme.surface,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  const BybataLoader(),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.error, fontSize: 13),
                      ),
                    ),
                  _buildCurrentPlanCard(context, scheme),
                  const SizedBox(height: 20),
                  _buildProgressCard(scheme),
                  const SizedBox(height: 20),
                  _buildBenefitsCard(scheme),
                  const SizedBox(height: 20),
                  _buildActionsCard(context, scheme),
                ],
              ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(BuildContext context, ColorScheme scheme) {
    final m = _membership ?? KarmaMembershipInfo.fromTier('NEWCOMER', 0);
    final style = tierStyle(m.tier);

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: style.$1.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(style.$2, color: style.$1, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current membership',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.planName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (m.isPremium)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Premium benefits active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              m.isPremium
                  ? 'You unlocked Premium through community KARMA. Keep earning points to maintain your tier.'
                  : 'Earn KARMA by trading, gifting, and helping the community. Gold tier (5,000+ points) unlocks Premium benefits.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: scheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(ColorScheme scheme) {
    final m = _membership!;
    if (m.nextTierLabel == null || m.pointsToNextTier <= 0) {
      return const SizedBox.shrink();
    }

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next tier: ${m.nextTierLabel}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${m.pointsToNextTier} more KARMA points to reach ${m.nextTierLabel}',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsCard(ColorScheme scheme) {
    final m = _membership!;
    const allBenefits = [
      ('Premium Trade Filters', Icons.filter_list, 100),
      ('Gift Scheduling', Icons.schedule, 150),
      ('Exclusive Communities', Icons.group, 200),
      ('Higher Trading Limits', Icons.trending_up, 250),
      ('Priority Support', Icons.support_agent, 600),
    ];

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Member benefits',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...allBenefits.map((b) {
              final unlocked = m.unlockedFeatures.contains(b.$1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                      color: unlocked ? Colors.green : scheme.onSurface.withValues(alpha: 0.35),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.$1,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: unlocked
                                  ? scheme.onSurface
                                  : scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          Text(
                            '${b.$3}+ KARMA',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, ColorScheme scheme) {
    final m = _membership!;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => KarmaNavigator.toTrustLevel(context),
            icon: const Icon(Icons.verified_user_rounded, size: 20),
            label: Text(m.isPremium ? 'View trust level' : 'Boost membership'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              GuardedNavigator.push(context,
                MaterialPageRoute(builder: (_) => const KarmaScreen()),
              );
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: const Text('View KARMA & earn points'),
          ),
        ),
      ],
    );
  }
}
