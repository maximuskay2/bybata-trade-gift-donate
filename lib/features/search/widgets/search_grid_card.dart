import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/widgets/cached_media_image.dart';
import '../../../core/widgets/listing_media_view.dart';
import '../../../core/widgets/loading_states.dart';
import '../utils/search_item_view_data.dart';

/// Asymmetric search grid tile — 4:5 image, title, subtitle, module metric flag.
class SearchGridCard extends StatelessWidget {
  final SearchItemViewData item;
  final VoidCallback? onTap;

  const SearchGridCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? Color(0xFF1E1A28).withValues(alpha: 0.55)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final muted = scheme.onSurface.withValues(alpha: 0.52);
    final shimmerBase = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : scheme.surfaceContainerHighest;
    final shimmerHighlight = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : scheme.surfaceContainerHigh;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: _buildImage(
                  context,
                  shimmerBase: shimmerBase,
                  shimmerHighlight: shimmerHighlight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: -0.2,
                      color: scheme.onSurface,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle.trim().isEmpty
                        ? 'Tap to explore'
                        : item.subtitle.trim(),
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        item.metric.icon,
                        size: 14,
                        color: item.metric.color,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.metric.label,
                          style: TextStyle(
                            color: item.metric.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
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
    );
  }

  Widget _buildImage(
    BuildContext context, {
    required Color shimmerBase,
    required Color shimmerHighlight,
  }) {
    final placeholder = ShimmerLoading(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: ColoredBox(color: shimmerBase),
    );

    if (item.media.isVideo && item.media.videoKey != null) {
      return ListingMediaView(
        media: item.media.feedPreview,
        heroTag: 'search-grid-${item.id}',
        expand: true,
        fit: BoxFit.cover,
        feedMode: true,
        previewImageUrl: MediaResolver.peekCachedUrl(item.previewImageKey),
        showVideoPlayBadge: true,
        showPageIndicator: false,
      );
    }

    final key = item.previewImageKey;
    if (key != null && key.isNotEmpty) {
      return CachedMediaImage(
        mediaKey: key,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: placeholder,
        errorWidget: _imageFallback(context),
      );
    }

    return _imageFallback(context);
  }

  Widget _imageFallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final moduleColor = switch (item.moduleType) {
      'trade' => AppTheme.tradeColor,
      'gift' => AppTheme.giftColor,
      'campaign' => AppTheme.donationColor,
      'community' => AppTheme.communityColor,
      _ => scheme.primary,
    };

    return ColoredBox(
      color: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 36,
          color: moduleColor.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
