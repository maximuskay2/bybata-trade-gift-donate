import 'package:flutter/material.dart';

import '../../../feed/models/social_listing_card_data.dart';
import '../conversational_card_actions.dart';
import '../conversational_feed_provider.dart';
import '../conversational_ranker.dart';
import '../conversational_unread_enricher.dart';
import 'donation_hero_tile.dart';
import '../../../feed/widgets/social_listing_card.dart';

/// Masonry-style bento grid for conversational home results.
class BentoResultsGrid extends StatelessWidget {
  final ConversationalFeedProvider feed;
  final ScrollController? scrollController;
  final VoidCallback? onLoadMore;
  final bool enrichUnread;

  const BentoResultsGrid({
    super.key,
    required this.feed,
    this.scrollController,
    this.onLoadMore,
    this.enrichUnread = false,
  });

  List<RankedFeedItem> _maybeEnrich(
    BuildContext context,
    List<RankedFeedItem> items,
  ) {
    if (!enrichUnread) return items;
    return ConversationalUnreadEnricher.enrich(context, items);
  }

  @override
  Widget build(BuildContext context) {
    final items = _maybeEnrich(context, feed.items);
    final heroes = _maybeEnrich(context, feed.donationHeroes);

    if (items.isEmpty && heroes.isEmpty && !feed.isLoading) {
      return _EmptyFeedState(
        hasQuery:
            feed.activeQuery != null && feed.activeQuery!.trim().isNotEmpty,
        liquidityExhausted: feed.liquidityExhausted,
        onExpandRadius: feed.liquidityExhausted
            ? feed.expandSearchRadius
            : null,
      );
    }

    final isIdle = feed.activeQuery == null || feed.activeQuery!.isEmpty;
    final heroIds = isIdle ? heroes.map((e) => e.data.id).toSet() : <String>{};

    final left = <Widget>[];
    final right = <Widget>[];
    var leftH = 0.0;
    var rightH = 0.0;

    for (final ranked in items) {
      if (isIdle &&
          ranked.data.module == SocialListingModule.donation &&
          heroIds.contains(ranked.data.id) &&
          ranked.size == BentoTileSize.hero) {
        continue;
      }
      final tile = _BentoTile(
        ranked: ranked,
        onOpen: () {
          feed.trackIntentEvent(
            'ai_intent_slot_tap',
            module: ranked.data.module.name,
            size: ranked.size.name,
          );
          ConversationalCardActions.openDetail(context, ranked.data);
        },
        onPrimary: () {
          feed.trackIntentEvent(
            'ai_intent_conversion',
            module: ranked.data.module.name,
            kind: ranked.data.module == SocialListingModule.trade
                ? 'offer'
                : ranked.data.module == SocialListingModule.gift
                ? 'claim'
                : 'donation',
          );
          ConversationalCardActions.primaryAction(context, ranked.data);
        },
        onMessage: ranked.data.module != SocialListingModule.donation
            ? () => ConversationalCardActions.messageOwner(context, ranked.data)
            : null,
      );
      final h = _estimateHeight(ranked);
      final padded = Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: tile,
      );
      if (leftH <= rightH) {
        left.add(padded);
        leftH += h + 14;
      } else {
        right.add(padded);
        rightH += h + 14;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heroes.isNotEmpty && feed.activeQuery == null) ...[
          const _SectionHeader(title: 'Community fundraisers near you'),
          const SizedBox(height: 10),
          ...heroes.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DonationHeroTile(
                data: e.data,
                onTap: () =>
                    ConversationalCardActions.openDetail(context, e.data),
                onSupport: () =>
                    ConversationalCardActions.primaryAction(context, e.data),
              ),
            ),
          ),
        ],
        if (feed.tradeGiftItems.isNotEmpty ||
            feed.activeQuery != null ||
            left.isNotEmpty ||
            right.isNotEmpty) ...[
          if (isIdle && (left.isNotEmpty || right.isNotEmpty))
            const _SectionHeader(title: 'Trades & gifts near you'),
          if (left.isNotEmpty || right.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: left)),
                const SizedBox(width: 12),
                Expanded(child: Column(children: right)),
              ],
            ),
          ],
        ],
        if (feed.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else if (feed.hasMore && onLoadMore != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: OutlinedButton(
              onPressed: onLoadMore,
              child: const Text('Load more'),
            ),
          ),
      ],
    );
  }

  double _estimateHeight(RankedFeedItem ranked) {
    switch (ranked.size) {
      case BentoTileSize.hero:
        return 360;
      case BentoTileSize.compact:
        return 220;
      case BentoTileSize.standard:
        return 320;
    }
  }
}

class _BentoTile extends StatelessWidget {
  final RankedFeedItem ranked;
  final VoidCallback onOpen;
  final VoidCallback onPrimary;
  final VoidCallback? onMessage;

  const _BentoTile({
    required this.ranked,
    required this.onOpen,
    required this.onPrimary,
    this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final data = ranked.data.copyWith(bentoSize: ranked.size);

    if (data.module == SocialListingModule.donation &&
        ranked.size == BentoTileSize.hero) {
      return DonationHeroTile(data: data, onTap: onOpen, onSupport: onPrimary);
    }

    return SocialListingCard(
      data: data,
      density: ranked.size,
      onCardTap: onOpen,
      onPrimaryAction: onPrimary,
      onMessageTap: onMessage,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  final bool hasQuery;
  final bool liquidityExhausted;
  final VoidCallback? onExpandRadius;

  const _EmptyFeedState({
    required this.hasQuery,
    required this.liquidityExhausted,
    this.onExpandRadius,
  });

  @override
  Widget build(BuildContext context) {
    // A search with no results is answered by the assistant reply above.
    if (hasQuery) {
      if (!liquidityExhausted || onExpandRadius == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton.icon(
            onPressed: onExpandRadius,
            icon: const Icon(Icons.travel_explore_rounded, size: 18),
            label: const Text('Look further away'),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.explore_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Nothing nearby yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search or expand your area.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (liquidityExhausted && onExpandRadius != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onExpandRadius,
              child: const Text('Show wider area'),
            ),
          ],
        ],
      ),
    );
  }
}
