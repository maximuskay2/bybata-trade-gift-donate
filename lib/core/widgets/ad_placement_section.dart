import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/donations/screens/campaign_details_loader.dart';
import '../../features/gifting/screens/gift_details_loader.dart';
import '../../features/trade/screens/trade_details_loader.dart';
import '../models/ad_item.dart';
import '../services/ads_service.dart';
import '../theme/app_theme.dart';
import '../utils/media_utils.dart';
import '../widgets/app_toast.dart';
import 'bybata_glass_container.dart';
import 'cached_media_image.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class AdPlacementSection extends StatefulWidget {
  final String placementKey;
  final String? title;
  /// Bump to refetch ads (e.g. after pull-to-refresh on parent screen).
  final int refreshToken;

  const AdPlacementSection({
    super.key,
    required this.placementKey,
    this.title,
    this.refreshToken = 0,
  });

  @override
  State<AdPlacementSection> createState() => _AdPlacementSectionState();
}

class _AdPlacementSectionState extends State<AdPlacementSection> {
  late Future<List<AdItem>> _future;
  final AdsService _service = AdsService();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(AdPlacementSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placementKey != widget.placementKey ||
        oldWidget.refreshToken != widget.refreshToken) {
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<List<AdItem>> _load() async {
    final ads = await _service.fetchPlacementAds(widget.placementKey);
    for (final ad in ads) {
      _service.trackView(ad);
    }
    return ads;
  }

  Future<void> _onAdTap(AdItem ad) async {
    await _service.trackClick(ad);

    if (ad.isBoost && ad.hasListingReference) {
      if (!mounted) return;
      _openBoostedListing(ad.referenceType!, ad.referenceId!);
      return;
    }

    final normalized = ad.destinationUrl?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      var uri = Uri.tryParse(normalized);
      if (uri == null && !normalized.toLowerCase().startsWith('http')) {
        uri = Uri.tryParse('https://$normalized');
      }
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      if (mounted) {
        AppToast.show(context, 'Could not open this link', type: ToastType.error);
      }
      return;
    }

    if (!mounted) return;
    _showDetailSheet(ad);
  }

  void _openBoostedListing(String referenceType, String referenceId) {
    final type = referenceType.toLowerCase();
    Widget screen;
    if (type == 'trade') {
      screen = TradeDetailsLoader(tradeId: referenceId);
    } else if (type == 'gift') {
      screen = GiftDetailsLoader(giftId: referenceId);
    } else if (type == 'campaign' || type == 'donation') {
      screen = CampaignDetailsLoader(campaignId: referenceId);
    } else {
      _showDetailSheet(AdItem(
        id: referenceId,
        kind: 'boost',
        title: 'Listing',
        referenceType: referenceType,
        referenceId: referenceId,
      ));
      return;
    }
    GuardedNavigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showDetailSheet(AdItem ad) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).padding.bottom + 16),
          child: ByBataGlassContainer(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Sponsored',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ad.title,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (ad.description != null && ad.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    ad.description!,
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.75),
                        ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<AdItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          debugPrint(
            'AdPlacementSection(${widget.placementKey}) load error: ${snapshot.error}',
          );
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final ads = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(Icons.campaign_outlined, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      widget.title!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: ads.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _AdCard(
                  ad: ads[index],
                  scheme: scheme,
                  onTap: () => _onAdTap(ads[index]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AdCard extends StatelessWidget {
  final AdItem ad;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _AdCard({
    required this.ad,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasLink = ad.destinationUrl != null && ad.destinationUrl!.trim().isNotEmpty;
    return SizedBox(
      width: 240,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: ByBataGlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _AdMedia(ad: ad),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ad.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ad.description ?? 'Sponsored',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.7),
                            ),
                      ),
                      if (hasLink) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.open_in_new_rounded, size: 12, color: AppTheme.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to visit',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
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

class _AdMedia extends StatelessWidget {
  final AdItem ad;
  const _AdMedia({required this.ad});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const size = 90.0;

    Widget placeholder() => Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.campaign, color: scheme.onSurface.withValues(alpha: 0.6)),
        );

    if (ad.isVideo) {
      return Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: size,
              width: size,
              child: _AdImageContent(ad: ad, placeholder: placeholder()),
            ),
          ),
          Icon(
            Icons.play_circle_fill_rounded,
            color: AppTheme.primaryColor.withValues(alpha: 0.92),
            size: 28,
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: size,
        width: size,
        child: _AdImageContent(ad: ad, placeholder: placeholder()),
      ),
    );
  }
}

class _AdImageContent extends StatelessWidget {
  final AdItem ad;
  final Widget placeholder;

  const _AdImageContent({required this.ad, required this.placeholder});

  @override
  Widget build(BuildContext context) {
    final thumb = ad.thumbnailUrl?.trim();
    if (thumb != null &&
        thumb.isNotEmpty &&
        (thumb.startsWith('http://') || thumb.startsWith('https://'))) {
      if (!MediaResolver.isDecodableImageUrl(thumb)) {
        return placeholder;
      }
      return CachedMediaImage(
        mediaKey: thumb,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        placeholder: placeholder,
        errorWidget: placeholder,
      );
    }

    final key = ad.primaryMediaKey;
    if (key == null) return placeholder;

    return CachedMediaImage(
      mediaKey: key,
      width: 90,
      height: 90,
      fit: BoxFit.cover,
      placeholder: placeholder,
      errorWidget: placeholder,
    );
  }
}
