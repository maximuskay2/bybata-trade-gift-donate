import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../navigation/main_navigation.dart';
import '../theme/app_theme.dart';

/// Home-only create orb — opens the global create sheet (Trade, Gift, Donate, Ask).
class AppCreateOrbButton extends StatelessWidget {
  final double size;

  const AppCreateOrbButton({
    super.key,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.mediumImpact();
          showAppCreateSheet(context);
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.75),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: scheme.surface.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: size * 0.54,
          ),
        ),
      ),
    );
  }
}
