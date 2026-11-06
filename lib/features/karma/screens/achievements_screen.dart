import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../models/karma_models.dart';
import '../navigation/karma_navigator.dart';
import '../services/karma_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

/// Achievements — progress overview and unlockable badges.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  AchievementCategory? _categoryFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final karma = context.read<KarmaService>();
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? karma.currentUserKarma?.userId;
    if (userId != null) {
      await karma.refresh(userId);
    }
  }

  List<Achievement> _filtered(List<Achievement> all) {
    if (_categoryFilter == null) return all;
    return all.where((a) => a.category == _categoryFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Achievements'),
        elevation: 0,
      ),
      body: Consumer<KarmaService>(
        builder: (context, karma, _) {
          final user = karma.currentUserKarma;
          final achievements = karma.availableAchievements;

          if (karma.isLoading && achievements.isEmpty) {
            return const BybataLoader();
          }

          if (user == null || achievements.isEmpty) {
            return Center(
              child: Text(
                'No achievements yet',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            );
          }

          final unlocked = achievements.where((a) => a.isUnlocked).toList();
          final locked = achievements.where((a) => !a.isUnlocked).toList();
          final filteredUnlocked = _filtered(unlocked);
          final filteredLocked = _filtered(locked);

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.primaryColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _progressCard(scheme, achievements, unlocked),
                const SizedBox(height: 16),
                _categoryChips(scheme),
                const SizedBox(height: 20),
                if (filteredUnlocked.isNotEmpty) ...[
                  _sectionHeader(scheme, 'Unlocked', filteredUnlocked.length,
                      AppTheme.successColor),
                  const SizedBox(height: 10),
                  ...filteredUnlocked.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _achievementTile(context, scheme, a, user, true),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (filteredLocked.isNotEmpty) ...[
                  _sectionHeader(
                    scheme,
                    'In progress',
                    filteredLocked.length,
                    scheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 10),
                  ...filteredLocked.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _achievementTile(context, scheme, a, user, false),
                    ),
                  ),
                ],
                if (filteredUnlocked.isEmpty && filteredLocked.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(
                        'No achievements in this category',
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _progressCard(
    ColorScheme scheme,
    List<Achievement> all,
    List<Achievement> unlocked,
  ) {
    final total = all.length;
    final progress = total > 0 ? unlocked.length / total : 0.0;
    final points = unlocked.fold<int>(0, (s, a) => s + a.pointsReward);

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
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.emoji_events_outlined,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${unlocked.length} of $total',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        'achievements unlocked',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+$points',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.karmaColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).round()}% complete',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChips(ColorScheme scheme) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: _categoryFilter == null,
              onSelected: (_) => setState(() => _categoryFilter = null),
              selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              backgroundColor: scheme.surfaceContainerHighest,
              side: BorderSide.none,
            ),
          ),
          ...AchievementCategory.values.map((cat) {
            final selected = _categoryFilter == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_categoryLabel(cat)),
                selected: selected,
                onSelected: (_) => setState(() => _categoryFilter = cat),
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                backgroundColor: scheme.surfaceContainerHighest,
                side: BorderSide.none,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionHeader(
    ColorScheme scheme,
    String title,
    int count,
    Color accent,
  ) {
    return Row(
      children: [
        Icon(
          title == 'Unlocked' ? Icons.check_circle_outline : Icons.lock_outline,
          size: 20,
          color: accent,
        ),
        const SizedBox(width: 8),
        Text(
          '$title ($count)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _achievementTile(
    BuildContext context,
    ColorScheme scheme,
    Achievement achievement,
    UserKarma user,
    bool unlocked,
  ) {
    final progress = _progressFor(achievement, user).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => KarmaNavigator.toAchievementDetail(
          context,
          achievement: achievement,
        ),
        borderRadius: BorderRadius.circular(16),
        child: ByBataGlassContainer(
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (unlocked
                            ? achievement.rarityColor
                            : scheme.onSurface)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: unlocked
                        ? Text(
                            achievement.iconUrl,
                            style: const TextStyle(fontSize: 22),
                          )
                        : Icon(
                            Icons.lock_outline_rounded,
                            color: scheme.onSurface.withValues(alpha: 0.35),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              achievement.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: achievement.rarityColor
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              achievement.rarity,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: achievement.rarityColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (!unlocked && progress > 0) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: scheme.surfaceContainerHighest,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(progress * 100).round()}% complete',
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                      if (unlocked && achievement.pointsReward > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '+${achievement.pointsReward} KARMA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.karmaColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _progressFor(Achievement achievement, UserKarma user) {
    if (achievement.isUnlocked) return 1;
    switch (achievement.requiredActivity) {
      case 'completeTrade':
        return (user.activityCounts[KarmaActivity.completeTrade] ?? 0) /
            achievement.requiredValue;
      case 'helpCommunity':
        return (user.activityCounts[KarmaActivity.helpCommunity] ?? 0) /
            achievement.requiredValue;
      case 'shareContent':
        return (user.activityCounts[KarmaActivity.shareContent] ?? 0) /
            achievement.requiredValue;
      case 'mentorUser':
        return (user.activityCounts[KarmaActivity.mentorUser] ?? 0) /
            achievement.requiredValue;
      case 'getVerified':
        return (user.activityCounts[KarmaActivity.getVerified] ?? 0) /
            achievement.requiredValue;
      case 'milestone':
        return user.totalPoints / achievement.requiredValue;
      default:
        return 0;
    }
  }

  String _categoryLabel(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.trading:
        return 'Trading';
      case AchievementCategory.community:
        return 'Community';
      case AchievementCategory.helping:
        return 'Helping';
      case AchievementCategory.verification:
        return 'Verify';
      case AchievementCategory.social:
        return 'Social';
      case AchievementCategory.milestone:
        return 'Milestone';
      case AchievementCategory.special:
        return 'Special';
    }
  }
}
