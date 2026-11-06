import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cached_media_image.dart';
import '../../../features/donations/models/donation_models.dart';
import '../../../features/donations/providers/campaign_provider.dart';
import 'discovery_slider_section.dart';
import 'home_v2_tokens.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Horizontal rail of active campaigns with inline progress rings.
///
/// Pulls from [CampaignProvider.campaigns] (active ones). On first paint the
/// provider is kicked with [CampaignProvider.loadCampaigns] so the rail can
/// populate without depending on upstream callers having loaded it.
class ActiveCampaignsRail extends StatefulWidget {
  const ActiveCampaignsRail({super.key});

  @override
  State<ActiveCampaignsRail> createState() => _ActiveCampaignsRailState();
}

class _ActiveCampaignsRailState extends State<ActiveCampaignsRail> {
  bool _kicked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_kicked && mounted) {
        _kicked = true;
        context
            .read<CampaignProvider>()
            .loadCampaigns(status: CampaignStatus.active);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CampaignProvider>(
      builder: (context, p, _) {
        final items = p.campaigns.take(10).toList();
        if (items.isEmpty) return const SizedBox.shrink();

        return DiscoverySliderSection(
          title: 'Active campaigns',
          railHeight: HomeV2Tokens.kCampaignRailHeight,
          trailing: TextButton(
            onPressed: () => GuardedNavigator.pushNamed(context, '/donations'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('See all'),
          ),
          rail: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: HomeV2Tokens.kHorizontalPad,
            ),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: HomeV2Tokens.kRailItemGap),
            itemBuilder: (context, i) => _CampaignTile(campaign: items[i]),
          ),
        );
      },
    );
  }
}

class _CampaignTile extends StatelessWidget {
  final Campaign campaign;
  const _CampaignTile({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = campaign.images.isNotEmpty ? campaign.images.first : null;
    final progress = campaign.progressPercentage;

    return SizedBox(
      width: HomeV2Tokens.kCampaignRailWidth,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(HomeV2Tokens.kCardRadius),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(HomeV2Tokens.kCardRadius),
          onTap: () {
            GuardedNavigator.pushNamed(context,
              '/campaign-details',
              arguments: {'id': campaign.id},
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HomeV2Tokens.kCardRadius),
              border:
                  Border.all(color: scheme.outline.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(HomeV2Tokens.kCardRadius),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (cover != null)
                          CachedMediaImage(
                            mediaKey: cover,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              color: AppTheme.donationColor
                                  .withValues(alpha: 0.15),
                              child: Icon(
                                Icons.volunteer_activism_rounded,
                                color: AppTheme.donationColor,
                                size: 32,
                              ),
                            ),
                          )
                        else
                          Container(
                            color: AppTheme.donationColor
                                .withValues(alpha: 0.15),
                            child: Icon(
                              Icons.volunteer_activism_rounded,
                              color: AppTheme.donationColor,
                              size: 32,
                            ),
                          ),
                        if (campaign.isUrgent)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'URGENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor:
                              AppTheme.donationColor.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.donationColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            campaign.formattedRaised,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.donationColor,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface.withValues(alpha: 0.6),
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
}
