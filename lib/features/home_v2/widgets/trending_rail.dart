import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/feed_item.dart';
import '../../../providers/feed_provider.dart';
import 'discovery_slider_section.dart';
import 'feed_card.dart';
import 'home_v2_tokens.dart';

/// Horizontal rail showing items that are trending in the user's area.
///
/// Backend does not yet expose a dedicated `trending=true` flag, so for V2
/// we sort the in-memory FeedProvider items by recency and take the top 8.
/// TODO(home_v2): replace with a dedicated /v1/feed/trending endpoint once
/// available.
class TrendingRail extends StatelessWidget {
  const TrendingRail({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, feed, _) {
        final items = _pickTrending(feed.feedItems);
        if (items.isEmpty) return const SizedBox.shrink();

        return DiscoverySliderSection(
          title: 'Trending in your community',
          railHeight: HomeV2Tokens.kListingCardHeight,
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          rail: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: HomeV2Tokens.kHorizontalPad,
            ),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: HomeV2Tokens.kRailItemGap),
            itemBuilder: (context, i) => FeedCard(
              item: items[i],
              fixedWidth: HomeV2Tokens.kListingCardWidth,
            ),
          ),
        );
      },
    );
  }

  List<FeedItem> _pickTrending(List<FeedItem> source) {
    final copy = List<FeedItem>.from(source);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy.take(8).toList();
  }
}
