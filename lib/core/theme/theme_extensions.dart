import 'package:flutter/material.dart';

/// Theme-aware colors for screens that previously hardcoded light-mode values.
extension ThemeColors on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get pageBackground => Theme.of(this).scaffoldBackgroundColor;
  Color get cardSurface => scheme.surface;
  Color get primaryText => scheme.onSurface;
  Color get secondaryText => scheme.onSurface.withValues(alpha: 0.65);
  Color get tertiaryText => scheme.onSurface.withValues(alpha: 0.45);
  Color get dividerColor => scheme.outline.withValues(alpha: isDarkMode ? 0.35 : 0.25);
  Color get inputFill => isDarkMode
      ? scheme.surface.withValues(alpha: 0.85)
      : const Color(0xFFF4F7FA);
  Color get subtleFill => isDarkMode
      ? scheme.onSurface.withValues(alpha: 0.06)
      : scheme.onSurface.withValues(alpha: 0.04);
  Color get shadowColor => isDarkMode
      ? Colors.black.withValues(alpha: 0.4)
      : Colors.black.withValues(alpha: 0.06);

  /// Card / panel surface used on details, negotiation, and PIN flows.
  BoxDecoration surfaceCardDecoration({
    double radius = 16,
    Color? color,
    bool elevated = true,
  }) {
    return BoxDecoration(
      color: color ?? cardSurface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: dividerColor),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: shadowColor,
                blurRadius: isDarkMode ? 10 : 16,
                offset: Offset(0, isDarkMode ? 4 : 6),
              ),
            ]
          : null,
    );
  }

  /// Soft page gradient (PIN / wallet flows).
  BoxDecoration get pageGradientDecoration {
    final top = pageBackground;
    final bottom = isDarkMode
        ? scheme.surface.withValues(alpha: 0.92)
        : const Color(0xFFE8ECF2);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [top, bottom],
      ),
    );
  }

  InputDecoration recessedInputDecoration({
    required String hint,
    Widget? suffixIcon,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      filled: true,
      fillColor: inputFill,
      hintStyle: TextStyle(color: tertiaryText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }
}
