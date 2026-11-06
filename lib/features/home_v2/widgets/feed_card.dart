import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/models/listing_media.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cached_media_image.dart';
import '../../../core/widgets/listing_media_view.dart';
import '../../../models/feed_item.dart';
import '../../../models/intent_types.dart';
import 'home_v2_tokens.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// 3D Glassmorphism portrait listing card used across the home and browse
/// sliders (Near-You, Trending, Active Campaigns).
///
/// Layout (per design brief):
///   1. Full-bleed background image (BoxFit.cover) inside a 28px rounded
///      [ClipRRect] with a soft ambient shadow.
///   2. Top-right 36dp circular frosted-glass action button
///      ([Icons.north_east_rounded]) that triggers the detail screen.
///   3. Bottom ~35% frosted info slab using [BackdropFilter] (sigma 12)
///      plus a transparent → black87/white50 gradient. Inside the slab
///      we render a 5-star rating (or "NEW LISTING" when unrated), the
///      item title at FontWeight.w900, and a "Category • Location"
///      subtitle.
///
/// The widget keeps its previous public API (`item`, `onTap`,
/// `fixedWidth`) so existing call sites in [TrendingRail],
/// [NearYouSection] and [ActiveCampaignsRail] keep working without
/// changes apart from sizing.
class FeedCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback? onTap;
  final double? fixedWidth;

  const FeedCard({
    super.key,
    required this.item,
    this.onTap,
    this.fixedWidth,
  });

  bool get _isCompact =>
      fixedWidth != null && fixedWidth! <= HomeV2Tokens.kListingCardWidth + 4;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(HomeV2Tokens.kListingCardRadius);
    final effectiveTap = onTap ?? () => _defaultTap(context);
    final compact = _isCompact;

    final card = Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          // Soft ambient shadow per spec: spread -2, blur 20, 8% black.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: effectiveTap,
          borderRadius: radius,
          child: AspectRatio(
            aspectRatio: HomeV2Tokens.kListingCardAspect,
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _backgroundImage(context),
                  // Bottom ~35% frosted info slab.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _GlassInfoSlab(
                      item: item,
                      isDark: isDark,
                      compact: compact,
                    ),
                  ),
                  // Decorative only — outer InkWell owns the tap so we never
                  // fire open-detail twice from nested InkWells.
                  Positioned(
                    top: compact ? 8 : 12,
                    right: compact ? 8 : 12,
                    child: IgnorePointer(
                      child: _GlassCircleButton(
                        icon: Icons.north_east_rounded,
                        isDark: isDark,
                        compact: compact,
                        onTap: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (fixedWidth != null) {
      return SizedBox(width: fixedWidth, child: card);
    }
    return card;
  }

  Widget _backgroundImage(BuildContext context) {
    final meta = item.metadata;
    if (meta != null) {
      final listingMedia = ListingMediaFields.fromJson(meta);
      if (listingMedia.isVideo) {
        return ListingMediaView(
          media: listingMedia,
          heroTag: 'feed-${item.id}',
          fit: BoxFit.cover,
          expand: true,
          showPageIndicator: false,
          feedMode: true,
          autoplayVideo: false,
          showVideoPlayBadge: true,
        );
      }
    }
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return CachedMediaImage(
        mediaKey: item.imageUrl,
        fit: BoxFit.cover,
        errorWidget: _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final base = isDark
        ? scheme.surface
        : const Color(0xFFEDE7F6);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base,
            HomeV2Tokens.kBrandPurple.withValues(alpha: isDark ? 0.35 : 0.18),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _moduleIcon(item.sourceType),
          size: _isCompact ? 36 : 48,
          color: HomeV2Tokens.kBrandPurple
              .withValues(alpha: isDark ? 0.7 : 0.5),
        ),
      ),
    );
  }

  void _defaultTap(BuildContext context) {
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

  static IconData _moduleIcon(FeedSourceType t) {
    switch (t) {
      case FeedSourceType.trade:
        return Icons.swap_horiz_rounded;
      case FeedSourceType.gift:
        return Icons.card_giftcard_rounded;
      case FeedSourceType.campaign:
        return Icons.volunteer_activism_rounded;
      case FeedSourceType.post:
        return Icons.forum_rounded;
    }
  }
}

/// The bottom 35% frosted glass info slab.
class _GlassInfoSlab extends StatelessWidget {
  final FeedItem item;
  final bool isDark;
  final bool compact;

  const _GlassInfoSlab({
    required this.item,
    required this.isDark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final rating = item.author.averageRating;
    final hasRating = rating != null && rating > 0;
    final accent = _moduleAccent(item.sourceType);
    // Match the parent card radius on the bottom corners. The top
    // corners stay sharp because the slab sits flush against the
    // image edge — clipping the parent already takes care of the
    // outer rounding.
    final slabRadius = BorderRadius.only(
      bottomLeft: Radius.circular(HomeV2Tokens.kListingCardRadius),
      bottomRight: Radius.circular(HomeV2Tokens.kListingCardRadius),
    );

    return ClipRRect(
      borderRadius: slabRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 20),
          decoration: BoxDecoration(
            // Dark scrim over the photo — theme onSurface was black on
            // light mode, which vanished on the blurred image backdrop.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.4, 1.0],
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.88),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.2),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ModuleChip(
                    label: _moduleLabel(item.sourceType),
                    color: accent,
                    compact: compact,
                  ),
                  const Spacer(),
                  if (hasRating)
                    _StarRow(rating: rating, compact: compact)
                  else
                    _NewListingChip(accent: accent, compact: compact),
                ],
              ),
              SizedBox(height: compact ? 6 : 8),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: compact ? 14 : 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.15,
                  shadows: const [
                    Shadow(
                      color: Color(0x99000000),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: compact ? 3 : 5),
              Text(
                _buildSubtitle(),
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.88),
                  shadows: const [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _moduleAccent(FeedSourceType type) {
    switch (type) {
      case FeedSourceType.trade:
        return AppTheme.tradeColor;
      case FeedSourceType.gift:
        return AppTheme.giftColor;
      case FeedSourceType.campaign:
        return AppTheme.donationColor;
      case FeedSourceType.post:
        return AppTheme.primaryColor;
    }
  }

  /// Compose "Category • Location". Falls back gracefully when one or
  /// both are missing — we never want to show a stray bullet.
  String _buildSubtitle() {
    final parts = <String>[];
    final cat = _prettifyCategory(item.category);
    if (cat != null && cat.isNotEmpty) parts.add(cat);
    final loc = item.location;
    if (loc != null && loc.trim().isNotEmpty) parts.add(loc.trim());
    if (parts.isEmpty) {
      // Last-ditch fallback so the row never collapses to empty space.
      return _moduleLabel(item.sourceType);
    }
    return parts.join(' • ');
  }

  /// Backend ships category as enum-like SCREAMING_SNAKE for trades
  /// and gifts (e.g. "HOME_GOODS"). Title-case it for display.
  String? _prettifyCategory(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.toUpperCase() != raw) return raw; // already a free-form label
    return raw
        .split(RegExp(r'[_\s]+'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1).toLowerCase())
        .join(' ');
  }

  String _moduleLabel(FeedSourceType t) {
    switch (t) {
      case FeedSourceType.trade:
        return 'Trade';
      case FeedSourceType.gift:
        return 'Gift';
      case FeedSourceType.campaign:
        return 'Donate';
      case FeedSourceType.post:
        return 'Request';
    }
  }
}

/// Module type pill — Trade / Gift / Donate with a saturated accent fill.
class _ModuleChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const _ModuleChip({
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: compact ? 8 : 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Compact "new" badge when the listing has no rating yet.
class _NewListingChip extends StatelessWidget {
  final Color accent;
  final bool compact;

  const _NewListingChip({required this.accent, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.85)),
      ),
      child: Text(
        'NEW',
        style: TextStyle(
          fontSize: compact ? 8 : 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Row of 5 amber star icons, partially filled to match [rating].
class _StarRow extends StatelessWidget {
  final double rating;
  final bool compact;
  const _StarRow({required this.rating, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final clamped = rating.clamp(0.0, 5.0);
    final starSize = compact ? 13.0 : 16.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final delta = clamped - i;
        IconData icon;
        if (delta >= 1.0) {
          icon = Icons.star_rounded;
        } else if (delta >= 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(
          icon,
          color: Colors.amber.shade300,
          size: starSize,
          shadows: const [
            Shadow(color: Color(0x99000000), blurRadius: 4),
          ],
        );
      }),
    );
  }
}

/// Top-right 36dp frosted circular button. The [BackdropFilter] gives
/// it the same glass aesthetic as the bottom info slab.
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final bool compact;
  final VoidCallback onTap;

  const _GlassCircleButton({
    required this.icon,
    required this.isDark,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 36.0;
    final iconSize = compact ? 15.0 : 18.0;
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: (isDark ? Colors.white : Colors.black)
              .withValues(alpha: isDark ? 0.18 : 0.22),
          shape: CircleBorder(
            side: BorderSide(
              color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.6),
              width: 1,
            ),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: iconSize,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pivot chip used by NearYouSection. Exposed here to keep styling tokens
/// adjacent to the card they visually pair with.
class FeedPivotChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color tint;
  final VoidCallback onTap;

  const FeedPivotChip({
    super.key,
    required this.label,
    required this.selected,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? tint : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper mapping from Near-You chip state to FeedProvider filter.
IntentSubType? subTypeForLabel(String label) {
  switch (label) {
    case 'Trade':
      return IntentSubType.trade;
    case 'Gift':
      return IntentSubType.give;
    case 'Donate':
      return IntentSubType.helpCampaign;
    default:
      return null; // All
  }
}
