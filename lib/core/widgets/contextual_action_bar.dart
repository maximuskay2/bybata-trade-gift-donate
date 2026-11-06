import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ContextualAction {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final int flex;

  const ContextualAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
    this.flex = 1,
  });
}

class ContextualActionBar extends StatelessWidget {
  final List<ContextualAction> actions;
  final EdgeInsets padding;
  final Color? accentColor;

  const ContextualActionBar({
    super.key,
    required this.actions,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 24),
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = accentColor ?? AppColors.primary;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.88),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  Expanded(
                    flex: actions[i].flex,
                    child: _ActionButton(
                      action: actions[i],
                      primaryColor: primaryColor,
                    ),
                  ),
                  if (i != actions.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final ContextualAction action;
  final Color primaryColor;

  const _ActionButton({required this.action, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final isPrimary = action.isPrimary;
    final isEnabled = action.onPressed != null;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isPrimary
        ? primaryColor
        : isDark
        ? scheme.surface.withValues(alpha: 0.35)
        : scheme.surface;
    final foregroundColor = isPrimary
        ? Colors.white
        : isDark
        ? Colors.white
        : primaryColor;

    return FilledButton.icon(
      onPressed: action.onPressed,
      icon: Icon(action.icon, size: 18),
      label: Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 50),
        backgroundColor: isEnabled
            ? backgroundColor
            : backgroundColor.withValues(alpha: 0.45),
        foregroundColor: isEnabled
            ? foregroundColor
            : foregroundColor.withValues(alpha: 0.55),
        elevation: isPrimary ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isPrimary
                ? Colors.transparent
                : primaryColor.withValues(alpha: 0.18),
          ),
        ),
      ),
    );
  }
}
