import 'package:flutter/material.dart';

import 'home_v2_tokens.dart';

/// Compact header + fixed-height rail wrapper for home discovery sliders.
///
/// [stacked] uses [HomeV2Tokens.kSliderGap] between consecutive sections.
/// When false, uses [HomeV2Tokens.kDiscoveryLeadGap] before the first block.
class DiscoverySliderSection extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final double railHeight;
  final Widget rail;
  final bool stacked;
  final Widget? belowTitle;

  const DiscoverySliderSection({
    super.key,
    required this.title,
    required this.railHeight,
    required this.rail,
    this.trailing,
    this.stacked = true,
    this.belowTitle,
  });

  @override
  Widget build(BuildContext context) {
    final topGap = stacked
        ? HomeV2Tokens.kSliderGap
        : HomeV2Tokens.kDiscoveryLeadGap;

    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeV2Tokens.kHorizontalPad,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          if (belowTitle != null) ...[
            SizedBox(height: HomeV2Tokens.kRailHeaderGap),
            belowTitle!,
          ],
          SizedBox(
            height: belowTitle == null
                ? HomeV2Tokens.kRailHeaderGap
                : HomeV2Tokens.kSliderToRailGap,
          ),
          SizedBox(height: railHeight, child: rail),
          const SizedBox(height: HomeV2Tokens.kSliderSectionTailGap),
        ],
      ),
    );
  }
}
