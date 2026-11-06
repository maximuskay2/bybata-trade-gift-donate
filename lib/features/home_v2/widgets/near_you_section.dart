import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/feed_provider.dart';
import 'discovery_slider_section.dart';
import 'feed_card.dart';
import 'home_v2_tokens.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

/// Near you — a horizontal, auto-advancing carousel of feed items.
///
/// Why horizontal: the previous vertical SliverList pushed the rails below
/// the fold so users had to scroll a long way to see Trending and Active
/// Campaigns. A horizontal carousel keeps the section to a single screen
/// row regardless of how many items are loaded, restoring the intended
/// vertical rhythm of Home / Browse Home.
///
/// Behavior:
///   * Horizontal ListView with the same card spacing as Trending.
///   * Auto-advances by one card every 1s using `Curves.easeOut` whenever
///     the user is NOT touching the screen.
///   * Touch pauses auto-advance immediately; it resumes ~2s after the
///     last pointer event (so a quick swipe still gets quiet time).
///   * Loops back to index 0 at the end (continuous discovery).
///   * Calls `feed.loadMore()` when the user reaches the last 3 cards.
class NearYouSection {
  NearYouSection._();

  static const _chipLabels = ['All', 'Trade', 'Gift', 'Donate'];

  static List<Widget> buildSlivers(
    BuildContext context, {
    required bool isAuthed,
  }) {
    return const [
      SliverToBoxAdapter(child: _NearYouBlock()),
    ];
  }
}

/// Near-you header, filters, and carousel in one block — avoids extra sliver
/// spacing and keeps the gap to the next slider minimal.
class _NearYouBlock extends StatelessWidget {
  const _NearYouBlock();

  @override
  Widget build(BuildContext context) {
    final carouselHeight = HomeV2Tokens.kListingCardHeight;

    return DiscoverySliderSection(
      stacked: false,
      title: 'Near you',
      railHeight: carouselHeight,
      trailing: Consumer<FeedProvider>(
        builder: (context, p, _) => TextButton(
          onPressed: p.isLoading ? null : () => p.refresh(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('Refresh'),
        ),
      ),
      belowTitle: const Padding(
        padding: EdgeInsets.symmetric(horizontal: HomeV2Tokens.kHorizontalPad),
        child: _ChipsRow(),
      ),
      rail: const _FeedCarousel(),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  const _ChipsRow();

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, feed, _) {
        final current = feed.intentSubTypeFilter;
        // Full-width segmented control. Each label gets equal horizontal
        // share via [Expanded], so the four buttons fill the row from
        // edge to edge regardless of screen width — no horizontal
        // scrolling, no leftover dead space.
        final children = <Widget>[];
        for (var i = 0; i < NearYouSection._chipLabels.length; i++) {
          final label = NearYouSection._chipLabels[i];
          final sub = subTypeForLabel(label);
          final selected = sub == current;
          final tint = _tintFor(label);
          children.add(Expanded(
            child: _NearYouSegment(
              label: label,
              icon: _iconFor(label),
              selected: selected,
              tint: tint,
              onTap: () {
                if (sub == null) {
                  feed.clearFilters();
                } else {
                  feed.setIntentSubTypeFilter(sub);
                }
              },
            ),
          ));
          if (i != NearYouSection._chipLabels.length - 1) {
            children.add(const SizedBox(width: 8));
          }
        }
        return SizedBox(
          height: 40,
          child: Row(children: children),
        );
      },
    );
  }

  Color _tintFor(String label) {
    switch (label) {
      case 'Trade':
        return AppTheme.tradeColor;
      case 'Gift':
        return AppTheme.giftColor;
      case 'Donate':
        return AppTheme.donationColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _iconFor(String label) {
    switch (label) {
      case 'Trade':
        return Icons.swap_horiz_rounded;
      case 'Gift':
        return Icons.card_giftcard_rounded;
      case 'Donate':
        return Icons.volunteer_activism_rounded;
      default:
        return Icons.apps_rounded;
    }
  }
}

/// Full-width segmented button used by the Near-You filter row.
///
/// Visual treatment:
///   * Selected: tint → tint.darker linear gradient, white label, soft
///     coloured glow shadow, 1px translucent inner border for crispness.
///   * Unselected: theme `surfaceContainerHighest` fill, dim onSurface
///     label, hairline outline, no shadow.
///   * Animates the swap with [AnimatedContainer] so taps feel springy
///     instead of snapping. Tappable surface is the entire button.
class _NearYouSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color tint;
  final VoidCallback onTap;

  const _NearYouSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(14);
    final fg = selected
        ? Colors.white
        : scheme.onSurface.withValues(alpha: 0.78);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: selected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tint,
                  Color.alphaBlend(
                    Colors.black.withValues(alpha: 0.18),
                    tint,
                  ),
                ],
              )
            : null,
        color: selected ? null : scheme.surfaceContainerHighest,
        border: Border.all(
          color: selected
              ? Colors.white.withValues(alpha: isDark ? 0.18 : 0.35)
              : scheme.outline.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: tint.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          splashColor: tint.withValues(alpha: 0.18),
          highlightColor: tint.withValues(alpha: 0.08),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedCarousel extends StatefulWidget {
  const _FeedCarousel();

  @override
  State<_FeedCarousel> createState() => _FeedCarouselState();
}

class _FeedCarouselState extends State<_FeedCarousel> {
  static const Duration _tick = Duration(milliseconds: 4500);
  static const Duration _animDuration = Duration(milliseconds: 650);
  static const Duration _resumeDelay = Duration(seconds: 2);

  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  bool _bootstrapped = false;
  bool _isTouching = false;
  DateTime _lastTouch = DateTime.fromMillisecondsSinceEpoch(0);

  double get _cardStride =>
      HomeV2Tokens.kListingCardWidth + HomeV2Tokens.kRailItemGap;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _bootstrapped) return;
      _bootstrapped = true;
      context.read<FeedProvider>().loadFeed(refresh: true);
      _startTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) => _maybeAdvance());
  }

  void _maybeAdvance() {
    if (!mounted || _isTouching) return;
    if (DateTime.now().difference(_lastTouch) < _resumeDelay) return;
    if (!_scrollController.hasClients) return;
    final items = context.read<FeedProvider>().feedItems;
    if (items.length < 2) return;

    final stride = _cardStride;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final nextOffset = _scrollController.offset + stride;
    final target = nextOffset > maxOffset ? 0.0 : nextOffset;

    _scrollController.animateTo(
      target,
      duration: _animDuration,
      curve: Curves.easeOut,
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final feed = context.read<FeedProvider>();
    final items = feed.feedItems;
    if (items.isEmpty) return;

    final index = (_scrollController.offset / _cardStride).round();
    if (index >= items.length - 3 && !feed.isLoading && feed.hasMore) {
      feed.loadMore();
    }
  }

  void _onPointerDown(PointerDownEvent _) {
    _isTouching = true;
    _lastTouch = DateTime.now();
  }

  void _onPointerUp(PointerUpEvent _) {
    _isTouching = false;
    _lastTouch = DateTime.now();
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _isTouching = false;
    _lastTouch = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, feed, _) {
        // Fixed compact card width so Near-you matches Trending rails.
        final cardWidth = HomeV2Tokens.kListingCardWidth;
        final carouselHeight = HomeV2Tokens.kListingCardHeight;

        if (feed.isLoading && feed.feedItems.isEmpty) {
          return SizedBox(
            height: carouselHeight,
            child: const BybataLoader(),
          );
        }

        if (feed.error != null && feed.feedItems.isEmpty) {
          final dimOnSurface = Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.5);
          return SizedBox(
            height: carouselHeight,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 40, color: dimOnSurface),
                  const SizedBox(height: 10),
                  Text(
                    feed.error ?? 'Could not load feed',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => feed.refresh(),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }

        if (feed.feedItems.isEmpty) {
          return SizedBox(
            height: carouselHeight,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: _EmptyState(),
            ),
          );
        }

        return Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: SizedBox(
            height: carouselHeight,
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: HomeV2Tokens.kHorizontalPad,
              ),
              physics: const BouncingScrollPhysics(
                decelerationRate: ScrollDecelerationRate.fast,
              ),
              itemCount: feed.feedItems.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: HomeV2Tokens.kRailItemGap),
              itemBuilder: (context, i) => FeedCard(
                item: feed.feedItems[i],
                fixedWidth: cardWidth,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dim = scheme.onSurface.withValues(alpha: 0.5);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.explore_outlined, size: 48, color: dim),
        const SizedBox(height: 12),
        Text(
          'Nothing nearby yet',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Be the first to share — post a trade, gift or campaign.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => AppRoutes.navigateToCreateTrade(context),
          icon: const Icon(Icons.add),
          label: const Text('Post'),
        ),
      ],
    );
  }
}
