import 'package:flutter/material.dart';

import '../constants/listing_media_constants.dart';

/// User-facing upload tips for trades, gifts, and donation campaigns.
class ListingMediaUploadGuidance extends StatelessWidget {
  final Color accentColor;
  final int maxPhotos;
  final String? moduleLabel;

  const ListingMediaUploadGuidance({
    super.key,
    required this.accentColor,
    this.maxPhotos = ListingMediaConstants.maxPhotosPerListing,
    this.moduleLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tips = ListingMediaConstants.uploadGuidance(maxPhotos: maxPhotos);
    final surface = isDark
        ? accentColor.withValues(alpha: 0.08)
        : accentColor.withValues(alpha: 0.06);
    final border = accentColor.withValues(alpha: isDark ? 0.22 : 0.18);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  moduleLabel == null
                      ? 'Photo & video guidelines'
                      : 'Photo & video guidelines for your $moduleLabel',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tips.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
