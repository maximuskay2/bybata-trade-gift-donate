import 'package:flutter/material.dart';

import '../../../core/utils/listing_video_handoff.dart';
import '../../../core/utils/media_file_cache.dart';
import '../../../core/utils/network_error_message.dart';
import '../../../core/widgets/bybata_loading_indicator.dart';
import '../models/social_listing_card_data.dart';
import 'social_listing_card.dart';

/// Vertical social feed list with pull-to-refresh and infinite scroll.
class SocialFeedList extends StatefulWidget {
  final List<SocialListingCardData> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onLoadMore;
  final List<Widget> header;
  final void Function(SocialListingCardData item)? onCardTap;
  final void Function(SocialListingCardData item)? onPrimaryAction;
  final Color emptyAccent;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final SocialFeedLayout layout;

  const SocialFeedList({
    super.key,
    required this.items,
    this.isLoading = false,
    this.hasMore = false,
    this.error,
    this.onRefresh,
    this.onLoadMore,
    this.header = const [],
    this.onCardTap,
    this.onPrimaryAction,
    this.emptyAccent = Colors.grey,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Nothing here yet',
    this.emptySubtitle = 'Check back soon for new listings.',
    this.layout = SocialFeedLayout.bento,
  });

  @override
  State<SocialFeedList> createState() => _SocialFeedListState();
}

class _SocialFeedListState extends State<SocialFeedList> {
  final ScrollController _scrollController = ScrollController();
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _prefetchInitialWindow();
  }

  @override
  void didUpdateWidget(covariant SocialFeedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _prefetchInitialWindow();
    }
  }

  void _prefetchInitialWindow() {
    ListingVideoPrefetch.prefetchItemWindow(
      items: widget.items,
      anchorIndex: 0,
      ahead: 8,
      behind: 1,
    );
    ListingVideoPrefetch.prefetchFeedImages(
      widget.items.map((e) => e.previewImageUrl ?? e.media.previewImageKey ?? ''),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    ListingVideoPrefetch.prefetchForScroll(
      scrollOffset: _scrollController.offset,
      lastScrollOffset: _lastScrollOffset,
      items: widget.items,
      ahead: 8,
      behind: 2,
    );
    _lastScrollOffset = _scrollController.offset;

    if (!widget.hasMore || widget.isLoading || widget.onLoadMore == null) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      widget.onLoadMore!();
    }
  }

  void _prepareVideoHandoff(SocialListingCardData item) {
    if (!item.media.isVideo) return;
    final videoKey = item.media.videoKey?.trim();
    if (videoKey == null || videoKey.isEmpty) return;
    ListingVideoHandoff.prepareDetailNavigation(videoKey);
  }

  @override
  Widget build(BuildContext context) {
    final child = CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        ...widget.header.map((w) => SliverToBoxAdapter(child: w)),
        if (widget.error != null && widget.items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _ErrorRetry(
              message: widget.error!,
              onRetry: widget.onRefresh,
            ),
          )
        else if (widget.items.isEmpty && widget.isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: BybataLoadingIndicator()),
          )
        else if (widget.items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.emptyIcon, size: 48, color: widget.emptyAccent),
                    const SizedBox(height: 12),
                    Text(
                      widget.emptyTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.emptySubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: widget.layout == SocialFeedLayout.instagram
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= widget.items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: BybataLoadingIndicator(
                          size: BybataLoadingSize.compact,
                        ),
                      ),
                    );
                  }
                  final item = widget.items[index];
                  return SocialListingCard(
                    key: ValueKey(
                      '${item.id}_${item.media.previewImageKey}_${item.media.videoKey}',
                    ),
                    data: item,
                    layout: widget.layout,
                    onCardTap: widget.onCardTap != null
                        ? () {
                            _prepareVideoHandoff(item);
                            widget.onCardTap!(item);
                          }
                        : null,
                    onPrimaryAction: widget.onPrimaryAction != null
                        ? () {
                            _prepareVideoHandoff(item);
                            widget.onPrimaryAction!(item);
                          }
                        : null,
                  );
                },
                childCount: widget.items.length + (widget.hasMore ? 1 : 0),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );

    if (widget.onRefresh != null) {
      return RefreshIndicator(onRefresh: widget.onRefresh!, child: child);
    }
    return child;
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final Future<void> Function()? onRetry;

  const _ErrorRetry({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 48, color: scheme.error),
          const SizedBox(height: 12),
          Text(
            NetworkErrorMessage.sanitize(message),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => onRetry!(),
              child: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}
