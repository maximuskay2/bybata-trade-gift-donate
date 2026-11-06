import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/karma/karma_membership_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/borderless_input_decoration.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../models/karma_models.dart';
import '../services/karma_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

/// Top KARMA earners — simple ranked list.
class KarmaLeaderboardScreen extends StatefulWidget {
  const KarmaLeaderboardScreen({super.key});

  @override
  State<KarmaLeaderboardScreen> createState() => _KarmaLeaderboardScreenState();
}

class _KarmaLeaderboardScreenState extends State<KarmaLeaderboardScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _period = 'all_time'; // all_time | this_week | this_month

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KarmaService>().refreshLeaderboard();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LeaderboardEntry> _sortedEntries(List<LeaderboardEntry> entries) {
    var list = List<LeaderboardEntry>.from(entries);
    switch (_period) {
      case 'this_week':
        list.sort((a, b) => b.thisWeekPoints.compareTo(a.thisWeekPoints));
      case 'this_month':
      case 'all_time':
        list.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((e) => e.userName.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Leaderboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<KarmaService>().refreshLeaderboard(),
          ),
        ],
      ),
      body: Consumer<KarmaService>(
        builder: (context, karma, _) {
          if (karma.isLoading && karma.leaderboard.isEmpty) {
            return const BybataLoader();
          }

          if (karma.error != null && karma.leaderboard.isEmpty) {
            return _errorState(scheme, karma);
          }

          final entries = _sortedEntries(karma.leaderboard);
          final top3 = entries.take(3).toList();

          return RefreshIndicator(
            onRefresh: () => karma.refreshLeaderboard(),
            color: AppTheme.primaryColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: BorderlessInputDecoration.search(
                    hintText: 'Search members',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 12),
                _periodChips(scheme),
                if (top3.isNotEmpty && _searchQuery.isEmpty) ...[
                  const SizedBox(height: 16),
                  _podiumCard(scheme, top3),
                ],
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  _emptyState(scheme)
                else
                  ...entries.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _rankTile(
                            scheme,
                            e.value,
                            e.key + 1,
                            _period,
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

  Widget _periodChips(ColorScheme scheme) {
    const options = [
      ('all_time', 'All time'),
      ('this_week', 'This week'),
      ('this_month', 'This month'),
    ];
    return Row(
      children: options.map((o) {
        final selected = _period == o.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: o.$1 != 'this_month' ? 8 : 0,
            ),
            child: FilterChip(
              label: Text(o.$2, textAlign: TextAlign.center),
              selected: selected,
              onSelected: (_) => setState(() => _period = o.$1),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AppTheme.primaryColor
                    : scheme.onSurface.withValues(alpha: 0.7),
              ),
              selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              backgroundColor: scheme.surfaceContainerHighest,
              side: BorderSide.none,
              padding: EdgeInsets.zero,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _podiumCard(ColorScheme scheme, List<LeaderboardEntry> top3) {
    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (top3.length > 1) Expanded(child: _podiumSlot(top3[1], 2, scheme)),
            Expanded(child: _podiumSlot(top3[0], 1, scheme, tall: true)),
            if (top3.length > 2) Expanded(child: _podiumSlot(top3[2], 3, scheme)),
          ],
        ),
      ),
    );
  }

  Widget _podiumSlot(LeaderboardEntry entry, int rank, ColorScheme scheme,
      {bool tall = false}) {
    final color = _rankColor(rank);
    final pts = _period == 'this_week'
        ? entry.thisWeekPoints
        : entry.totalPoints;

    return Column(
      children: [
        Icon(
          rank == 1 ? Icons.emoji_events_rounded : Icons.military_tech_rounded,
          color: color,
          size: rank == 1 ? 28 : 22,
        ),
        const SizedBox(height: 6),
        CircleAvatar(
          radius: tall ? 28 : 22,
          backgroundColor: entry.level.color.withValues(alpha: 0.15),
          child: Text(entry.level.emoji, style: TextStyle(fontSize: tall ? 22 : 18)),
        ),
        const SizedBox(height: 6),
        Text(
          entry.userName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        Text(
          '$pts',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: tall ? 8 : 0),
      ],
    );
  }

  Widget _rankTile(
    ColorScheme scheme,
    LeaderboardEntry entry,
    int rank,
    String period,
  ) {
    final isYou = entry.isCurrentUser;
    final pts =
        period == 'this_week' ? entry.thisWeekPoints : entry.totalPoints;
    final trustLabel = membershipLabelForTier(
      _trustTierKey(entry.trustLevel),
    );

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: isYou
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _rankBadge(rank),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 22,
                backgroundColor: entry.level.color.withValues(alpha: 0.12),
                child: Text(entry.level.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.userName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: scheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isYou) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'You',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${entry.level.name} · $trustLabel',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$pts',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isYou ? AppTheme.primaryColor : scheme.onSurface,
                    ),
                  ),
                  Text(
                    period == 'this_week' ? 'this week' : 'points',
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rankBadge(int rank) {
    final color = _rankColor(rank);
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: rank <= 3
          ? Icon(
              rank == 1
                  ? Icons.emoji_events_rounded
                  : Icons.military_tech_rounded,
              color: color,
              size: 18,
            )
          : Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
            ),
    );
  }

  String _trustTierKey(TrustLevel level) {
    switch (level) {
      case TrustLevel.ambassador:
        return 'LEGEND';
      case TrustLevel.premium:
        return 'GOLD';
      case TrustLevel.trusted:
        return 'SILVER';
      case TrustLevel.basic:
        return 'BRONZE';
      case TrustLevel.unverified:
        return 'NEWCOMER';
    }
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return AppColors.primaryMuted;
      case 3:
        return Colors.brown;
      default:
        return AppTheme.primaryColor;
    }
  }

  Widget _emptyState(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(
            Icons.leaderboard_outlined,
            size: 48,
            color: scheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty ? 'No members found' : 'Leaderboard is empty',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(ColorScheme scheme, KarmaService karma) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              'Could not load leaderboard',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => karma.refreshLeaderboard(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
