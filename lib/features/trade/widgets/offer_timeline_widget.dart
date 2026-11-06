import 'package:flutter/material.dart';
import '../../../core/theme/theme_extensions.dart';
import '../models/trade_models.dart' as trade_models;

/// Visual timeline component showing the history of all proposals and counter-proposals
class OfferTimelineWidget extends StatelessWidget {
  final List<trade_models.TradeOffer> timeline;
  final Function(trade_models.TradeOffer)? onCounterOfferTap;

  const OfferTimelineWidget({
    super.key,
    required this.timeline,
    this.onCounterOfferTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    if (timeline.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.surfaceCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Offer history',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.primaryText,
                ),
              ),
            ],
          ),
            const SizedBox(height: 16),
            ...timeline.asMap().entries.map((entry) {
              final index = entry.key;
              final offer = entry.value;
              final isLast = index == timeline.length - 1;
              
              return _buildTimelineItem(
                context,
                offer,
                primaryColor,
                isLast,
                offer.timelineDepth,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    trade_models.TradeOffer offer,
    Color primaryColor,
    bool isLast,
    int depth,
  ) {
    final isCounterOffer = offer.isCounterOffer;
    final offerDepth = depth.clamp(0, 4);
    final indent = offerDepth * 20.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isCounterOffer ? Colors.orange : primaryColor;
    final cardFill = isCounterOffer
        ? accent.withValues(alpha: isDark ? 0.12 : 0.08)
        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50);
    final borderColor = accent.withValues(alpha: 0.35);

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line
          Column(
            children: [
              Container(width: 2, height: 20, color: accent),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: context.tertiaryText.withValues(alpha: 0.35),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Offer content
          Expanded(
            child: GestureDetector(
              onTap: isCounterOffer && onCounterOfferTap != null
                  ? () => onCounterOfferTap!(offer)
                  : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCounterOffer ? Icons.swap_horiz : Icons.handshake_outlined,
                          size: 16,
                          color: accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCounterOffer ? 'Counter-Offer' : 'Original Offer',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                              Text(
                                'From ${offer.offerer.name}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.tertiaryText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: offer.statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            offer.statusText,
                            style: TextStyle(
                              fontSize: 10,
                              color: offer.statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (offer.isOwnerCounter) ...[
                      if (offer.requestedTrade != null)
                        _termsRow(
                          context,
                          icon: Icons.inventory_2_outlined,
                          label: 'Wants item',
                          value: offer.requestedTrade!.title,
                        ),
                      if (offer.requestedAmount != null &&
                          offer.requestedAmount!.trim().isNotEmpty)
                        _termsRow(
                          context,
                          icon: Icons.payments_outlined,
                          label: 'Wants cash',
                          value: '${offer.requestedAmount} BYC',
                          valueColor: Colors.green.shade700,
                        ),
                      _termsRow(
                        context,
                        icon: Icons.storefront_outlined,
                        label: 'For your listing',
                        value: offer.targetTrade.title,
                      ),
                    ] else if (offer.isItemOffer && offer.offeredTrade != null) ...[
                      _termsRow(
                        context,
                        icon: offer.offeredTrade!.categoryIcon,
                        label: 'Offers item',
                        value: offer.offeredTrade!.title,
                      ),
                    ] else if (offer.isCashOffer) ...[
                      _termsRow(
                        context,
                        icon: Icons.payments_outlined,
                        label: 'Cash offer',
                        value: '${offer.amount} BYC',
                        valueColor: Colors.green.shade700,
                      ),
                    ],
                    if (offer.message.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        offer.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.secondaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      offer.timeAgo,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.tertiaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _termsRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: context.secondaryText),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: context.secondaryText),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? context.primaryText,
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

