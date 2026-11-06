import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/theme_provider.dart';

/// Frosted glass container — sigma 12, theme-aware onyx / translucent white.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider?>();
    final isGlass = themeProvider?.isGlassTheme ?? false;
    final scheme = Theme.of(context).colorScheme;

    final fill = isDark || isGlass
        ? const Color(0xFF121018).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.78);
    final border = isDark || isGlass
        ? Colors.white.withValues(alpha: 0.12)
        : scheme.onSurface.withValues(alpha: 0.08);

    final content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: borderRadius,
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: content,
      ),
    );
  }
}
