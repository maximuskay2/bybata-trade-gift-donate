import 'dart:ui';
import 'package:flutter/material.dart';

/// A non-AppBar custom header for screens that want full control of the top
/// bar contents but still need a correct top safe-area for the notch.
///
/// The frosted-glass background bleeds all the way to the physical top edge
/// (y=0) while the [child] is pushed down by `MediaQuery.padding.top` + a
/// configurable spacer so the back button / title / actions sit safely below
/// the notch.
///
/// Status-bar icon colours are handled globally by the app-level
/// `AnnotatedRegion` in `main.dart`, and re-enforced here by placing the
/// header inside its own `AnnotatedRegion` so any full-screen modals rendered
/// under it still get the right contrast.
///
/// Usage:
/// ```dart
/// Stack(
///   children: [
///     AmbientOrbs(),
///     ScrollContent(),
///     Positioned(
///       top: 0, left: 0, right: 0,
///       child: GlassHeader(
///         child: Row(children: [BackBtn(), Title(), Spacer(), Actions()]),
///       ),
///     ),
///   ],
/// )
/// ```
class GlassHeader extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double verticalSpacing;
  final EdgeInsets horizontalPadding;
  final Color? tintColor;

  const GlassHeader({
    super.key,
    required this.child,
    this.blurSigma = 18,
    this.verticalSpacing = 12,
    this.horizontalPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.of(context).padding.top;
    final tint = tintColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.55));

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          color: tint,
          padding: EdgeInsets.only(
            top: topInset + verticalSpacing,
            bottom: verticalSpacing,
            left: horizontalPadding.left,
            right: horizontalPadding.right,
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                color: isDark ? Colors.white : Colors.black87,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
