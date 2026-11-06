import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/borderless_input_decoration.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../models/karma_models.dart';
import '../navigation/karma_navigator.dart';
import '../services/karma_service.dart';

/// KARMA transaction history with search and filters.
class KarmaHistoryScreen extends StatefulWidget {
  const KarmaHistoryScreen({super.key});

  @override
  State<KarmaHistoryScreen> createState() => _KarmaHistoryScreenState();
}

class _KarmaHistoryScreenState extends State<KarmaHistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  KarmaActivity? _activityFilter;
  _DateFilter _dateFilter = _DateFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _activityFilter != null || _dateFilter != _DateFilter.all;

  List<KarmaTransaction> _filter(List<KarmaTransaction> txs) {
    var list = List<KarmaTransaction>.from(txs);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (t) =>
                t.description.toLowerCase().contains(q) ||
                t.activity.name.toLowerCase().contains(q),
          )
          .toList();
    }

    if (_activityFilter != null) {
      list = list.where((t) => t.activity == _activityFilter).toList();
    }

    if (_dateFilter != _DateFilter.all) {
      final now = DateTime.now();
      DateTime? start;
      DateTime? end;

      switch (_dateFilter) {
        case _DateFilter.today:
          start = DateTime(now.year, now.month, now.day);
        case _DateFilter.week:
          start = now.subtract(Duration(days: now.weekday - 1));
          start = DateTime(start.year, start.month, start.day);
        case _DateFilter.month:
          start = DateTime(now.year, now.month, 1);
        case _DateFilter.lastMonth:
          start = DateTime(now.year, now.month - 1, 1);
          end = DateTime(now.year, now.month, 1);
        case _DateFilter.all:
          break;
      }

      list = list.where((t) {
        if (start != null && t.timestamp.isBefore(start)) return false;
        if (end != null && !t.timestamp.isBefore(end)) return false;
        return true;
      }).toList();
    }

    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Future<void> _refresh() async {
    final karma = context.read<KarmaService>();
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? karma.currentUserKarma?.userId;
    if (userId != null) {
      await karma.refresh(userId);
    }
  }

  void _clearFilters() {
    setState(() {
      _activityFilter = null;
      _dateFilter = _DateFilter.all;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('KARMA history'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _hasFilters,
              child: const Icon(Icons.tune_rounded),
            ),
            onPressed: () => _showFilters(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: BorderlessInputDecoration.search(
                hintText: 'Search activity',
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
          ),
          if (_hasFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (_activityFilter != null)
                          Chip(
                            label: Text(_activityFilter!.name),
                            onDeleted: () =>
                                setState(() => _activityFilter = null),
                          ),
                        if (_dateFilter != _DateFilter.all)
                          Chip(
                            label: Text(_dateFilter.label),
                            onDeleted: () =>
                                setState(() => _dateFilter = _DateFilter.all),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Consumer<KarmaService>(
              builder: (context, karma, _) {
                final all = karma.getUserKarmaHistory();
                final filtered = _filter(all);

                if (all.isEmpty) {
                  return _emptyState(scheme, noData: true);
                }

                if (filtered.isEmpty) {
                  return _emptyState(scheme, noData: false);
                }

                final earned = filtered.fold<int>(
                  0,
                  (s, t) => s + t.pointsEarned,
                );

                return RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppTheme.primaryColor,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      ByBataGlassContainer(
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${filtered.length} activities',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                              Text(
                                '+$earned KARMA',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.karmaColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...filtered.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _transactionTile(context, scheme, t),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => KarmaNavigator.toEarnKarma(context),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Earn more KARMA'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionTile(
    BuildContext context,
    ColorScheme scheme,
    KarmaTransaction tx,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => KarmaNavigator.showTransactionDetails(
          context,
          transaction: tx,
        ),
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
                    color: tx.activity.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    tx.activity.icon,
                    color: tx.activity.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.activity.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tx.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatWhen(tx.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+${tx.pointsEarned}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ColorScheme scheme, {required bool noData}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              noData ? Icons.history_rounded : Icons.search_off_rounded,
              size: 48,
              color: scheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              noData ? 'No history yet' : 'No matches',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              noData
                  ? 'Your KARMA activities will show up here'
                  : 'Try different search or filters',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (!noData) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _clearFilters,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFilters(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              24 + MediaQuery.paddingOf(ctx).bottom,
            ),
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
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Activity',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _activityFilter == null,
                      onSelected: (_) =>
                          setSheetState(() => _activityFilter = null),
                    ),
                    ...KarmaActivity.values.map(
                      (a) => FilterChip(
                        label: Text(a.name),
                        selected: _activityFilter == a,
                        onSelected: (_) =>
                            setSheetState(() => _activityFilter = a),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'When',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _DateFilter.values.map((d) {
                    return FilterChip(
                      label: Text(d.label),
                      selected: _dateFilter == d,
                      onSelected: (_) => setSheetState(() => _dateFilter = d),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _clearFilters();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear all'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatWhen(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

enum _DateFilter {
  all('All time'),
  today('Today'),
  week('This week'),
  month('This month'),
  lastMonth('Last month');

  final String label;
  const _DateFilter(this.label);
}
