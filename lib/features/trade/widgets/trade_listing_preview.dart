import 'package:flutter/material.dart';

import '../../../core/widgets/listing_media_view.dart';
import '../models/trade_models.dart' as trade_models;

/// Shared trade card/list preview (photos + video posters).
class TradeListingPreview extends StatelessWidget {
  final trade_models.Trade trade;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const TradeListingPreview({
    super.key,
    required this.trade,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    final media = trade.listingMedia;
    if (!media.hasMedia) {
      return _placeholder(context);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: ListingMediaThumb(
          media: media,
          width: width,
          height: height,
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
      ),
    );
  }
}
