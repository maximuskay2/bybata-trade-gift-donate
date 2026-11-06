import 'package:flutter/material.dart';

import '../../widgets/home_v2_tokens.dart';

/// Shimmer placeholders while the conversational feed loads.
class BentoCardSkeletonGrid extends StatelessWidget {
  final int count;

  const BentoCardSkeletonGrid({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white12 : Colors.black12;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: List.generate(
              (count / 2).ceil(),
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _block(base, height: i.isEven ? 280 : 220),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: List.generate(
              count ~/ 2,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _block(base, height: i.isEven ? 220 : 280),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _block(Color color, {required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(HomeV2Tokens.kCardRadius),
      ),
    );
  }
}
