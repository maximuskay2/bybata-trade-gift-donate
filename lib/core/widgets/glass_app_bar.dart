import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A frosted-glass `AppBar` that plays nicely with `extendBodyBehindAppBar:
/// true`.
///
/// Features:
///   * Transparent scaffold-level background so our ambient orbs bleed through.
///   * `BackdropFilter` blur clipped behind the AppBar so glass touches the
///     very top physical edge of the device.
///   * Explicit [SystemUiOverlayStyle] that auto-inverts to the current theme
///     brightness so the native time / battery / signal icons always contrast
///     against whatever glass tint is drawn underneath them.
///   * Native AppBar still computes top-notch safe area for its title/actions,
///     so the back button + title sit safely below the notch while the glass
///     background bleeds to the top edge.
///
/// Use via:
/// ```dart
/// Scaffold(
///   extendBodyBehindAppBar: true,
///   appBar: GlassAppBar(title: Text('Chat')),
/// )
/// ```
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final double blurSigma;
  final double height;

  /// Optional tint poured over the glass. Alpha kept low so blur still reads.
  /// Defaults to a theme-aware soft tint.
  final Color? tintColor;

  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.blurSigma = 18,
    this.height = kToolbarHeight,
    this.tintColor,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
          );
    final tint = tintColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.55));

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: AppBar(
          title: title,
          leading: leading,
          actions: actions,
          centerTitle: centerTitle,
          backgroundColor: tint,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: overlayStyle,
          iconTheme: IconThemeData(
            color: isDark ? Colors.white : Colors.black87,
          ),
          titleTextStyle: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
