import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cached_media_image.dart';
import '../../../feed/models/social_listing_card_data.dart';
import 'glass_surface.dart';

/// Compact listing rows shown while the user types on conversational home.
class ConversationalItemSuggestionList extends StatelessWidget {
  final List<SocialListingCardData> items;
  final bool isLoading;
  final String query;
  final void Function(SocialListingCardData item) onItemTap;
  final VoidCallback? onSeeAllTap;
  final bool showHeader;

  const ConversationalItemSuggestionList({
    super.key,
    required this.items,
    required this.isLoading,
    required this.query,
    required this.onItemTap,
    this.onSeeAllTap,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!isLoading && items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isLoading ? 'Finding matches…' : 'Matches for “$query”',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                if (!isLoading && items.isNotEmpty && onSeeAllTap != null)
                  TextButton(
                    onPressed: onSeeAllTap,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(44, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('See all'),
                  ),
              ],
            ),
          ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassSurface(
                onTap: () => onItemTap(item),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    _ItemThumbnail(item: item),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.58),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: scheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  static String _subtitle(SocialListingCardData item) {
    final parts = <String>[_moduleLabel(item.module)];
    final progress = item.progressLabel;
    if (item.module == SocialListingModule.donation &&
        progress != null &&
        progress.isNotEmpty) {
      parts.add(progress);
    }
    if (item.distanceLabel != null && item.distanceLabel!.isNotEmpty) {
      parts.add(item.distanceLabel!);
    }
    return parts.join(' · ');
  }

  static String _moduleLabel(SocialListingModule module) {
    switch (module) {
      case SocialListingModule.trade:
        return 'Trade';
      case SocialListingModule.gift:
        return 'Gift';
      case SocialListingModule.donation:
        return 'Fundraiser';
    }
  }
}

class _ItemThumbnail extends StatelessWidget {
  final SocialListingCardData item;

  const _ItemThumbnail({required this.item});

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    final imageKey = item.media.previewImageKey;
    final directUrl = item.previewImageUrl?.trim();
    final hasImage =
        (imageKey != null && imageKey.isNotEmpty) ||
        (directUrl != null && directUrl.isNotEmpty);

    if (!hasImage) {
      return _ModuleDot(module: item.module);
    }

    final scheme = Theme.of(context).colorScheme;
    final placeholderColor = scheme.surfaceContainerHighest;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedMediaImage(
              mediaKey: imageKey,
              directUrl: directUrl,
              fit: BoxFit.cover,
              width: _size,
              height: _size,
              optimizedForFeed: true,
              placeholder: ColoredBox(color: placeholderColor),
              errorWidget: _ModuleDot(module: item.module),
            ),
            if (item.media.isVideo)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.28),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModuleDot extends StatelessWidget {
  final SocialListingModule module;
  const _ModuleDot({required this.module});

  @override
  Widget build(BuildContext context) {
    final color = switch (module) {
      SocialListingModule.trade => AppTheme.tradeColor,
      SocialListingModule.gift => AppTheme.giftColor,
      SocialListingModule.donation => AppTheme.donationColor,
    };
    final icon = switch (module) {
      SocialListingModule.trade => Icons.swap_horiz_rounded,
      SocialListingModule.gift => Icons.card_giftcard_rounded,
      SocialListingModule.donation => Icons.favorite_rounded,
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
