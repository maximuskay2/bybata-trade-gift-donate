import 'package:flutter/material.dart';

import '../../../../core/compliance/ios_campaign_support.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/listing_media_view.dart';
import '../../../feed/models/social_listing_card_data.dart';
import '../../widgets/home_v2_tokens.dart';
import 'glass_surface.dart';

/// Large hero tile for verified local fundraisers in the conversational feed.
class DonationHeroTile extends StatelessWidget {
  final SocialListingCardData data;
  final VoidCallback? onTap;
  final VoidCallback? onSupport;

  const DonationHeroTile({
    super.key,
    required this.data,
    this.onTap,
    this.onSupport,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = (data.progress ?? 0).clamp(0.0, 1.0);
    final accent = AppTheme.donationColor;

    return GlassSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HomeV2Tokens.kCardRadius),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(HomeV2Tokens.kCardRadius),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ListingMediaView(
                    media: data.media.feedPreview,
                    heroTag: 'donation_hero_${data.id}',
                    fit: BoxFit.cover,
                    expand: true,
                    feedMode: true,
                    previewImageUrl: data.previewImageUrl,
                    showVideoPlayBadge: false,
                    autoplayVideo: false,
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Row(
                      children: [
                        if (data.isVerified)
                          _badge(
                            icon: Icons.verified_rounded,
                            label: 'Verified',
                            color: Colors.white,
                            bg: accent,
                          ),
                        if (data.distanceLabel != null) ...[
                          const SizedBox(width: 8),
                          _badge(
                            icon: Icons.near_me_rounded,
                            label: data.distanceLabel!,
                            color: Colors.white,
                            bg: Colors.black.withValues(alpha: 0.45),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                    height: 1.15,
                  ),
                ),
                if (data.progressLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    data.progressLabel!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    color: accent,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onSupport ?? onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      CampaignSupportCompliance.feedCtaLabel(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
