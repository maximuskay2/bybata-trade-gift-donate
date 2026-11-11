import 'package:flutter/material.dart';

/// Soft gradient + floating blobs behind hub chrome.
/// Pure presentation — place as the first child of a [Stack]; never owns logic.
class HubAtmosphere extends StatelessWidget {
  final Color accent;
  final bool visible;

  const HubAtmosphere({
    super.key,
    required this.accent,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).scaffoldBackgroundColor;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(
                    accent.withValues(alpha: isDark ? 0.22 : 0.12),
                    base,
                  ),
                  base,
                ],
              ),
            ),
          ),
          Positioned(
            top: -48,
            right: -36,
            child: _Blob(
              size: 200,
              color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
            ),
          ),
          Positioned(
            top: 180,
            left: -70,
            child: _Blob(
              size: 160,
              color: accent.withValues(alpha: isDark ? 0.10 : 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
