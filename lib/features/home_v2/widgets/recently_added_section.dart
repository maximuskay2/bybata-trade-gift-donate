import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cached_media_image.dart';
import '../../../models/feed_item.dart';
import '../../../models/intent_types.dart';
import '../../../providers/feed_provider.dart';
import 'home_v2_tokens.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Vertical "Recently Added" list — image left, details right (reference layout).
///
/// Pulls merged trade / gift / campaign items from [FeedProvider.recentItems],
/// sorted newest-first regardless of Near-you chip filters.
class RecentlyAddedSection extends StatefulWidget {
  const RecentlyAddedSection({super.key});

  @override
  State<RecentlyAddedSection> createState() => _RecentlyAddedSectionState();
}

class _RecentlyAddedSectionState extends State<RecentlyAddedSection> {
  bool _kicked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_kicked && mounted) {
        _kicked = true;
        final feed = context.read<FeedProvider>();
        if (feed.recentItems.isEmpty) {
          feed.loadRecentlyAdded();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, feed, _) {
        if (feed.isLoadingRecent && feed.recentItems.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: HomeV2Tokens.kSliderGap),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (feed.recentItems.isEmpty) return const SizedBox.shrink();

        final scheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.only(top: HomeV2Tokens.kSliderGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HomeV2Tokens.kHorizontalPad,
                ),
                child: Row(
                  children: [
                    Text(
                      'Recently Added',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            color: scheme.onSurface.withValues(alpha: 0.85),
                          ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          GuardedNavigator.pushNamed(context, '/search'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        'See All',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: HomeV2Tokens.kRailHeaderGap),
              ...feed.recentItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(
                    left: HomeV2Tokens.kHorizontalPad,
                    right: HomeV2Tokens.kHorizontalPad,
                    bottom: 12,
                  ),
                  child: RecentlyAddedListTile(item: item),
                ),
              ),
              const SizedBox(height: HomeV2Tokens.kSliderSectionTailGap),
            ],
          ),
        );
      },
    );
  }
}

class RecentlyAddedListTile extends StatelessWidget {
  final FeedItem item;

  const RecentlyAddedListTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final module = _moduleMeta(item.sourceType);

    return Material(
      color: scheme.surface,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(HomeV2Tokens.kCardRadius),
      child: InkWell(
        onTap: () => _openItem(context),
        borderRadius: BorderRadius.circular(HomeV2Tokens.kCardRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HomeV2Tokens.kCardRadius),
            border: Border.all(
              color: scheme.outline.withValues(alpha: isDark ? 0.12 : 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumbnail(
                  item: item,
                  badgeLabel: module.label,
                  badgeColor: module.color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            module.icon,
                            size: 16,
                            color: scheme.onSurface.withValues(alpha: 0.55),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _prettifyCategory(item.category) ?? module.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface.withValues(alpha: 0.75),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (AppRoutes.requireSignIn(context)) return;
                            },
                            icon: Icon(
                              Icons.favorite_border_rounded,
                              size: 20,
                              color: scheme.onSurface.withValues(alpha: 0.45),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _priceLine(item),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _locationLine(item),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurface.withValues(alpha: 0.55),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openItem(BuildContext context) {
    // Browse home is public — open detail routes without a sign-in gate.
    switch (item.sourceType) {
      case FeedSourceType.trade:
        GuardedNavigator.pushNamed(context,
          '/trade-details',
          arguments: {'id': item.id},
        );
        break;
      case FeedSourceType.gift:
        GuardedNavigator.pushNamed(context,
          '/gift-details',
          arguments: {'id': item.id},
        );
        break;
      case FeedSourceType.campaign:
        GuardedNavigator.pushNamed(context,
          '/campaign-details',
          arguments: {'id': item.id},
        );
        break;
      case FeedSourceType.post:
        GuardedNavigator.pushNamed(context,
          '/request-details',
          arguments: {'id': item.id},
        );
        break;
    }
  }
}

class _Thumbnail extends StatelessWidget {
  final FeedItem item;
  final String badgeLabel;
  final Color badgeColor;

  const _Thumbnail({
    required this.item,
    required this.badgeLabel,
    required this.badgeColor,
  });

  static const double _size = 92;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              CachedMediaImage(
                mediaKey: item.imageUrl,
                fit: BoxFit.cover,
                errorWidget: _placeholder(scheme),
              )
            else
              _placeholder(scheme),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 5),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: badgeColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      badgeLabel.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
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

  Widget _placeholder(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_outlined,
        color: scheme.onSurface.withValues(alpha: 0.25),
        size: 28,
      ),
    );
  }
}

class _ModuleMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _ModuleMeta(this.label, this.icon, this.color);
}

_ModuleMeta _moduleMeta(FeedSourceType type) {
  switch (type) {
    case FeedSourceType.trade:
      return _ModuleMeta('Trade', Icons.swap_horiz_rounded, AppTheme.tradeColor);
    case FeedSourceType.gift:
      return _ModuleMeta('Gift', Icons.card_giftcard_rounded, AppTheme.giftColor);
    case FeedSourceType.campaign:
      return _ModuleMeta(
        'Donate',
        Icons.volunteer_activism_rounded,
        AppTheme.donationColor,
      );
    case FeedSourceType.post:
      return _ModuleMeta('Request', Icons.forum_rounded, AppTheme.primaryColor);
  }
}

String? _prettifyCategory(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.toUpperCase() != raw) return raw;
  return raw
      .split(RegExp(r'[_\s]+'))
      .where((s) => s.isNotEmpty)
      .map((s) => s[0].toUpperCase() + s.substring(1).toLowerCase())
      .join(' ');
}

String _priceLine(FeedItem item) {
  final md = item.metadata ?? {};
  switch (item.sourceType) {
    case FeedSourceType.trade:
      final value = md['value'] ?? md['askingPrice'] ?? md['price'];
      if (value != null) return '${_formatAmount(value)} BYC';
      return 'Open to offers';
    case FeedSourceType.gift:
      return 'Free';
    case FeedSourceType.campaign:
      final goal = md['goalAmount'] ?? md['targetAmount'];
      if (goal != null) return '${_formatAmount(goal)} BYC goal';
      return 'Fundraiser';
    case FeedSourceType.post:
      return 'Community request';
  }
}

String _formatAmount(Object value) {
  if (value is num) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(0);
  }
  return value.toString();
}

String _locationLine(FeedItem item) {
  final loc = item.location?.trim();
  final added = timeago.format(item.createdAt);
  if (loc != null && loc.isNotEmpty) {
    return '$loc · $added';
  }
  return 'Added $added';
}
