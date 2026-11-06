import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Frosted glass card used on trade/gift detail headers.
class DetailsGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const DetailsGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shell = Theme.of(context).colorScheme.surface;
    final glassFill = isDark
        ? shell.withValues(alpha: 0.72)
        : shell.withValues(alpha: 0.9);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.85);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: glassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Circular frosted icon button for detail screen app bars.
class DetailsGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Widget? child;

  const DetailsGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassFill = isDark
        ? scheme.surface.withValues(alpha: 0.65)
        : scheme.surface.withValues(alpha: 0.82);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.85);

    final shell = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: glassFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: child ??
              Icon(
                icon,
                color: color ?? scheme.onSurface,
                size: 20,
              ),
        ),
      ),
    );

    if (child != null) return shell;

    return GestureDetector(onTap: onTap, child: shell);
  }
}
