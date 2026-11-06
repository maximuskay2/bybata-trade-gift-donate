import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/compliance/ios_campaign_support.dart';
import '../../../core/karma/karma_membership_utils.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/share_utils.dart';
import '../../../core/widgets/cached_media_image.dart';
import '../../../core/widgets/debounced_tap.dart';
import '../../../core/widgets/listing_media_view.dart';
import '../../../features/settings/widgets/settings_ui.dart';
import '../models/social_listing_card_data.dart';

/// Unified social bento card for Trade / Gift / Donation browse feeds.
class SocialListingCard extends StatefulWidget {
  final SocialListingCardData data;
  final BentoTileSize density;
  final SocialFeedLayout layout;
  final VoidCallback? onCardTap;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onMessageTap;

  const SocialListingCard({
    super.key,
    required this.data,
    this.density = BentoTileSize.standard,
    this.layout = SocialFeedLayout.bento,
    this.onCardTap,
    this.onPrimaryAction,
    this.onMessageTap,
  });

  @override
  State<SocialListingCard> createState() => _SocialListingCardState();
}

class _SocialListingCardState extends State<SocialListingCard> {
  bool _liked = false;

  Color get _accent {
    switch (widget.data.module) {
      case SocialListingModule.trade:
        return AppTheme.tradeColor;
      case SocialListingModule.gift:
        return AppTheme.giftColor;
      case SocialListingModule.donation:
        return AppTheme.donationColor;
    }
  }

  String get _ctaLabel {
    switch (widget.data.module) {
      case SocialListingModule.trade:
        return 'Swap Offer';
      case SocialListingModule.gift:
        return 'Claim Free';
      case SocialListingModule.donation:
        return CampaignSupportCompliance.feedCtaLabel();
    }
  }

  void _share(BuildContext context) {
    final data = widget.data;
    switch (data.module) {
      case SocialListingModule.trade:
        ShareUtils.shareTrade(context, id: data.id, title: data.title);
      case SocialListingModule.gift:
        ShareUtils.shareGift(context, id: data.id, title: data.title);
      case SocialListingModule.donation:
        ShareUtils.shareCampaign(
          context,
          id: data.id,
          title: data.title,
          summary: data.description,
        );
    }
  }

  bool get _feedAutoplayVideo =>
      (widget.layout == SocialFeedLayout.instagram ||
          widget.layout == SocialFeedLayout.timeline) &&
      widget.data.media.isVideo;

  VoidCallback? get _cardNavTap => widget.onCardTap ?? widget.onPrimaryAction;

  VoidCallback? get _primaryNavTap =>
      widget.onPrimaryAction ?? widget.onCardTap;

  Widget _buildListingMedia({
    required SocialListingCardData data,
    required double aspectRatio,
  }) {
    final autoplay = _feedAutoplayVideo;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ListingMediaView(
        media: autoplay ? data.media : data.media.feedPreview,
        heroTag: 'social_${data.module.name}_${data.id}',
        fit: BoxFit.cover,
        expand: true,
        feedMode: true,
        previewImageUrl: data.previewImageUrl,
        showVideoPlayBadge: data.media.isVideo && !autoplay,
        onMediaTap: _cardNavTap ?? () {},
        autoplayVideo: autoplay,
        videoMuted: true,
        showVideoMuteControl: autoplay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.layout) {
      SocialFeedLayout.instagram => _buildInstagramLayout(context),
      SocialFeedLayout.timeline => _buildTimelineLayout(context),
      SocialFeedLayout.bento => _buildBentoLayout(context),
    };
  }

  Widget _buildTimelineLayout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.data;
    final distance = data.distanceLabel?.trim() ?? '';
    final moduleLabel = _timelineModuleLabel(data.module);
    final valueToken = _timelineValueToken(data);
    final description = data.description.trim().isNotEmpty
        ? data.description.trim()
        : data.title;
    final cardBg = isDark
        ? const Color(0xFF1C1C22)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.65);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.outlineVariant.withValues(alpha: 0.35);
    final onCardTap = _cardNavTap;
    final autoplay = _feedAutoplayVideo;

    return Semantics(
      label: '$moduleLabel: ${data.title}${distance.isNotEmpty ? ', $distance' : ''}',
      button: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    _ownerAvatar(context, radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  data.ownerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              if (data.isVerified) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.verified_rounded,
                                  size: 14,
                                  color: scheme.primary,
                                ),
                              ],
                            ],
                          ),
                          if (distance.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 13,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      distance,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ListingMediaView(
                          media: autoplay ? data.media : data.media.feedPreview,
                          heroTag: 'social_${data.module.name}_${data.id}',
                          fit: BoxFit.cover,
                          expand: true,
                          feedMode: true,
                          previewImageUrl: data.previewImageUrl,
                          showVideoPlayBadge: data.media.isVideo && !autoplay,
                          onMediaTap: onCardTap ?? () {},
                          autoplayVideo: autoplay,
                          videoMuted: true,
                          showVideoMuteControl: autoplay,
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: _TimelineFrostedBadge(
                            label: moduleLabel,
                            accent: _accent,
                          ),
                        ),
                        if (valueToken != null)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: _TimelineFrostedBadge(
                              label: valueToken.label,
                              accent: valueToken.accent,
                              urgent: valueToken.urgent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              DebouncedTap(
                onTap: onCardTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                            color: scheme.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                      if (data.module == SocialListingModule.donation &&
                          data.progress != null) ...[
                        const SizedBox(height: 10),
                        _DonationProgressBlock(
                          progress: data.progress!,
                          label: data.progressLabel,
                          accent: _accent,
                          scheme: scheme,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: cardBorder,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                child: Row(
                  children: [
                    _timelineEngagementAction(
                      icon: _liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _liked
                          ? Colors.redAccent
                          : scheme.onSurface.withValues(alpha: 0.55),
                      count: _liked ? 1 : 0,
                      label: 'Like listing',
                      onTap: () => setState(() => _liked = !_liked),
                    ),
                    _timelineMessageAction(scheme),
                    _timelineEngagementAction(
                      icon: Icons.share_outlined,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                      label: 'Share listing',
                      onTap: () => _share(context),
                    ),
                    const Spacer(),
                    Semantics(
                      button: true,
                      label: _ctaLabel,
                      child: FilledButton(
                        onPressed: _primaryNavTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(44, 38),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: Text(
                          _ctaLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timelineModuleLabel(SocialListingModule module) {
    return switch (module) {
      SocialListingModule.trade => '🔄 Barter',
      SocialListingModule.gift => '🎁 Gift',
      SocialListingModule.donation => '💚 Donation',
    };
  }

  ({String label, Color accent, bool urgent})? _timelineValueToken(
    SocialListingCardData data,
  ) {
    final meta = _ListingMeta.from(data);
    switch (data.module) {
      case SocialListingModule.gift:
        for (final chip in meta.chips) {
          if (chip.label.toLowerCase().contains('karma')) {
            return (label: '⭐ ${chip.label}', accent: AppTheme.giftColor, urgent: false);
          }
        }
        final tier = data.karmaTier;
        if (tier != null && tier.isNotEmpty) {
          return (
            label: '⭐ ${membershipLabelForTier(tier)}',
            accent: AppTheme.giftColor,
            urgent: false,
          );
        }
        return null;
      case SocialListingModule.donation:
        for (final chip in meta.chips) {
          if (chip.label.toLowerCase() == 'urgent') {
            return (label: 'Urgent', accent: Colors.orangeAccent, urgent: true);
          }
        }
        if (data.progress != null) {
          final pct = (data.progress! * 100).clamp(0, 100).round();
          return (
            label: '$pct% funded',
            accent: AppTheme.donationColor,
            urgent: false,
          );
        }
        return null;
      case SocialListingModule.trade:
        if (meta.categoryLabel != null) {
          return (
            label: meta.categoryLabel!,
            accent: AppTheme.tradeColor,
            urgent: false,
          );
        }
        return null;
    }
  }

  Widget _timelineEngagementAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
    int count = 0,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _timelineMessageAction(ColorScheme scheme) {
    final onTap = widget.onMessageTap ?? widget.onCardTap ?? () {};
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _timelineEngagementAction(
          icon: Icons.mode_comment_outlined,
          color: scheme.onSurface.withValues(alpha: 0.55),
          label: _messageTooltip ?? 'Comment',
          onTap: onTap,
        ),
        if (widget.data.hasUnreadMessages)
          Positioned(
            right: 4,
            top: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInstagramLayout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = widget.data;
    final tier = data.karmaTier;
    final tierVisual = tier != null ? tierStyle(tier) : null;
    final moduleLabel = switch (data.module) {
      SocialListingModule.trade => 'Trade',
      SocialListingModule.gift => 'Gift',
      SocialListingModule.donation => 'Campaign',
    };
    final distance = data.distanceLabel ?? '';
    final semanticLabel =
        '$moduleLabel: ${data.title}${distance.isNotEmpty ? ', $distance' : ''}';

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Row(
              children: [
                _ownerAvatar(context, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              data.ownerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          if (data.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified_rounded,
                              size: 14,
                              color: scheme.primary,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        [
                          moduleLabel,
                          if (tierVisual != null && tier != null)
                            membershipLabelForTier(tier),
                          if (data.distanceLabel != null) data.distanceLabel!,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onCardTap,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ),
          ),
          _buildListingMedia(data: data, aspectRatio: 4 / 5),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
            child: Row(
              children: [
                _iconAction(
                  icon: _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _liked ? Colors.redAccent : scheme.onSurface,
                  label: 'Like listing',
                  onTap: () => setState(() => _liked = !_liked),
                ),
                _messageAction(scheme, iconColor: scheme.onSurface),
                _iconAction(
                  icon: Icons.share_outlined,
                  color: scheme.onSurface,
                  label: 'Share listing',
                  onTap: () => _share(context),
                ),
                const Spacer(),
                Semantics(
                  button: true,
                  label: _ctaLabel,
                  child: FilledButton(
                    onPressed: widget.onPrimaryAction ?? widget.onCardTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(44, 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      _ctaLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          DebouncedTap(
            onTap: widget.onCardTap,
            child: _InstagramCaptionPanel(data: data, accent: _accent),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoLayout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.data;
    final density = widget.density;
    final tier = data.karmaTier;
    final tierVisual = tier != null ? tierStyle(tier) : null;
    final compact = density == BentoTileSize.compact;
    final mediaAspect = compact ? 1.0 : 4 / 5;
    final moduleLabel = switch (data.module) {
      SocialListingModule.trade => 'Trade',
      SocialListingModule.gift => 'Gift',
      SocialListingModule.donation => 'Campaign',
    };
    final distance = data.distanceLabel ?? '';
    final semanticLabel =
        '$moduleLabel: ${data.title}${distance.isNotEmpty ? ', $distance' : ''}';

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Padding(
      padding: EdgeInsets.only(bottom: compact ? 12 : 20),
      child: Material(
        color: scheme.surface,
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SettingsUi.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  children: [
                    _ownerAvatar(context, radius: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.ownerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (tierVisual != null && tier != null)
                            Row(
                              children: [
                                Icon(tierVisual.$2, size: 12, color: tierVisual.$1),
                                const SizedBox(width: 4),
                                Text(
                                  membershipLabelForTier(tier),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: tierVisual.$1,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (data.distanceLabel != null)
                      Text(
                        data.distanceLabel!,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              _buildListingMedia(data: data, aspectRatio: mediaAspect),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    _iconAction(
                      icon: _liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _liked ? Colors.redAccent : scheme.onSurfaceVariant,
                      label: 'Like listing',
                      onTap: () => setState(() => _liked = !_liked),
                    ),
                    _messageAction(scheme),
                    _iconAction(
                      icon: Icons.share_outlined,
                      color: scheme.onSurfaceVariant,
                      label: 'Share listing',
                      onTap: () => _share(context),
                    ),
                    const Spacer(),
                    Semantics(
                      button: true,
                      label: _ctaLabel,
                      child: FilledButton(
                        onPressed: _primaryNavTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          visualDensity: VisualDensity.standard,
                        ),
                        child: Text(
                          _ctaLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DebouncedTap(
                onTap: widget.onCardTap,
                child: _ListingDetailsPanel(
                  data: data,
                  accent: _accent,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownerAvatar(BuildContext context, {required double radius}) {
    final data = widget.data;
    return DebouncedTap(
      onTap: data.ownerId.isEmpty
          ? null
          : () {
              if (AppRoutes.requireSignIn(context)) return;
              AppRoutes.navigateToProfile(
                context,
                userId: data.ownerId,
              );
            },
      behavior: HitTestBehavior.opaque,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: _accent.withValues(alpha: 0.15),
        child: data.ownerAvatarKey != null && data.ownerAvatarKey!.isNotEmpty
            ? ClipOval(
                child: CachedMediaImage(
                  mediaKey: data.ownerAvatarKey,
                  directUrl: data.ownerAvatarUrl,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  optimizedForFeed: true,
                ),
              )
            : Text(
                data.ownerName.isNotEmpty
                    ? data.ownerName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  String? get _messageTooltip {
    if (widget.data.hasUnreadMessages) return 'Unread messages';
    return widget.onMessageTap != null ? 'Message owner' : null;
  }

  Widget _messageAction(ColorScheme scheme, {Color? iconColor}) {
    final onTap = widget.onMessageTap ?? widget.onCardTap ?? () {};
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _iconAction(
          icon: Icons.mode_comment_outlined,
          color: iconColor ?? scheme.onSurfaceVariant,
          label: _messageTooltip,
          onTap: onTap,
        ),
        if (widget.data.hasUnreadMessages)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? label,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        icon: Icon(icon, size: 22, color: color),
        tooltip: label,
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}

/// Frosted overlay badge for timeline feed media corners.
class _TimelineFrostedBadge extends StatelessWidget {
  final String label;
  final Color accent;
  final bool urgent;

  const _TimelineFrostedBadge({
    required this.label,
    required this.accent,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = urgent
        ? Colors.orangeAccent.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.42);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Instagram-style caption block — username + title, optional progress.
class _InstagramCaptionPanel extends StatelessWidget {
  final SocialListingCardData data;
  final Color accent;

  const _InstagramCaptionPanel({
    required this.data,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final description = data.description.trim();
    final caption = description.isNotEmpty ? description : data.title;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: scheme.onSurface,
              ),
              children: [
                TextSpan(
                  text: '${data.ownerName} ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: caption),
              ],
            ),
          ),
          if (data.module == SocialListingModule.donation &&
              data.progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: data.progress!.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: accent.withValues(alpha: 0.15),
                color: accent,
              ),
            ),
            if (data.progressLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                data.progressLabel!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Rich details block under feed card media — title, chips, progress, comments.
class _ListingDetailsPanel extends StatelessWidget {
  final SocialListingCardData data;
  final Color accent;
  final bool isDark;

  const _ListingDetailsPanel({
    required this.data,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = _ListingMeta.from(data);
    final panelBg = isDark
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : accent.withValues(alpha: 0.04);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ModuleBadge(module: data.module, accent: accent),
                if (meta.categoryLabel != null) ...[
                  const SizedBox(width: 6),
                  Flexible(child: _MetaChip(
                    icon: Icons.category_outlined,
                    label: meta.categoryLabel!,
                    accent: scheme.onSurfaceVariant,
                  )),
                ],
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                height: 1.25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: scheme.onSurface,
              ),
            ),
            if (data.description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                data.description.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
            if (meta.chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: meta.chips.map((c) => _MetaChip(
                  icon: c.icon,
                  label: c.label,
                  accent: accent,
                )).toList(),
              ),
            ],
            if (data.module == SocialListingModule.donation &&
                data.progress != null) ...[
              const SizedBox(height: 12),
              _DonationProgressBlock(
                progress: data.progress!,
                label: data.progressLabel,
                accent: accent,
                scheme: scheme,
              ),
            ],
            if (data.latestCommentPreview != null) ...[
              const SizedBox(height: 10),
              _CommentPreview(text: data.latestCommentPreview!, accent: accent),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModuleBadge extends StatelessWidget {
  final SocialListingModule module;
  final Color accent;

  const _ModuleBadge({required this.module, required this.accent});

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (module) {
      SocialListingModule.trade => ('Trade', Icons.swap_horiz_rounded),
      SocialListingModule.gift => ('Free Gift', Icons.volunteer_activism_rounded),
      SocialListingModule.donation => ('Campaign', Icons.favorite_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent.withValues(alpha: 0.85)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accent.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonationProgressBlock extends StatelessWidget {
  final double progress;
  final String? label;
  final Color accent;
  final ColorScheme scheme;

  const _DonationProgressBlock({
    required this.progress,
    required this.label,
    required this.accent,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0, 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$pct% funded',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            const Spacer(),
            if (label != null)
              Flexible(
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
            color: accent,
          ),
        ),
      ],
    );
  }
}

class _CommentPreview extends StatelessWidget {
  final String text;
  final Color accent;

  const _CommentPreview({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 14, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: scheme.onSurface.withValues(alpha: 0.78),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChipData {
  final IconData icon;
  final String label;
  const _MetaChipData(this.icon, this.label);
}

class _ListingMeta {
  final String? categoryLabel;
  final List<_MetaChipData> chips;

  const _ListingMeta({this.categoryLabel, this.chips = const []});

  static _ListingMeta from(SocialListingCardData data) {
    final raw = data.raw ?? {};
    final chips = <_MetaChipData>[];

    if (data.distanceLabel != null && data.distanceLabel!.trim().isNotEmpty) {
      final loc = data.distanceLabel!.trim();
      final isKm = loc.toLowerCase().contains('km');
      chips.add(_MetaChipData(
        isKm ? Icons.near_me_outlined : Icons.location_on_outlined,
        loc,
      ));
    }

    String? category;
    switch (data.module) {
      case SocialListingModule.trade:
        category = _formatLabel(raw['category']?.toString());
        final condition = raw['condition']?.toString();
        if (condition != null && condition.isNotEmpty) {
          chips.add(_MetaChipData(Icons.verified_outlined, _formatLabel(condition)!));
        }
        if (raw['isNegotiable'] == true) {
          chips.add(const _MetaChipData(Icons.handshake_outlined, 'Negotiable'));
        }
      case SocialListingModule.gift:
        final giftRaw = raw['gift'];
        if (giftRaw != null) {
          try {
            final dynamic g = giftRaw;
            category = _formatLabel(g.category?.name ?? g.type?.name);
            final karma = g.karmaReward;
            if (karma is int && karma > 0) {
              chips.add(_MetaChipData(Icons.stars_rounded, '+$karma Karma'));
            }
          } catch (_) {}
        }
        category ??= _formatLabel(raw['category']?.toString() ?? raw['type']?.toString());
      case SocialListingModule.donation:
        final campRaw = raw['campaign'];
        if (campRaw != null) {
          try {
            final dynamic c = campRaw;
            category = _formatLabel(c.category?.name ?? c.categoryLabel);
            if (c.isUrgent == true) {
              chips.add(const _MetaChipData(Icons.priority_high_rounded, 'Urgent'));
            }
          } catch (_) {}
        }
        category ??= _formatLabel(raw['category']?.toString());
    }

    return _ListingMeta(categoryLabel: category, chips: chips);
  }

  static String? _formatLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return raw
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'(?=[A-Z])'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
