import 'package:flutter/material.dart';

/// Centralized shadow styles for consistent 3D effects across the app
class ShadowStyles {
  // Private constructor to prevent instantiation
  ShadowStyles._();

  /// Light 3D shadow for subtle elevation
  static List<BoxShadow> get lightShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      offset: const Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      offset: const Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 0,
    ),
  ];

  /// Medium 3D shadow for standard cards
  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      offset: const Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      offset: const Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      offset: const Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  /// Heavy 3D shadow for prominent cards and dialogs
  static List<BoxShadow> get heavyShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      offset: const Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      offset: const Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      offset: const Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  /// Floating 3D shadow for floating action buttons and elevated elements
  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.18),
      offset: const Offset(0, 12),
      blurRadius: 32,
      spreadRadius: -8,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      offset: const Offset(0, 6),
      blurRadius: 16,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      offset: const Offset(0, 3),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  /// Pressed 3D shadow for pressed states (reduces shadow depth)
  static List<BoxShadow> get pressedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      offset: const Offset(0, 1),
      blurRadius: 4,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      offset: const Offset(0, 0.5),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  /// Colored shadow that adapts to theme colors
  static List<BoxShadow> coloredShadow(Color color, {double opacity = 0.25}) => [
    BoxShadow(
      color: color.withValues(alpha: opacity * 0.6),
      offset: const Offset(0, 4),
      blurRadius: 16,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: color.withValues(alpha: opacity * 0.4),
      offset: const Offset(0, 2),
      blurRadius: 8,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      offset: const Offset(0, 1),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  /// Glass morphism shadow for glass theme
  static List<BoxShadow> get glassShadow => [
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.2),
      offset: const Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      offset: const Offset(0, 8),
      blurRadius: 32,
      spreadRadius: -8,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      offset: const Offset(0, 4),
      blurRadius: 16,
      spreadRadius: -4,
    ),
  ];

  /// Get appropriate shadow based on theme brightness and glass mode
  static List<BoxShadow> getThemeAwareShadow(
    BuildContext context, {
    bool isGlass = false,
    ShadowIntensity intensity = ShadowIntensity.medium,
  }) {
    final brightness = Theme.of(context).brightness;
    
    if (isGlass) {
      return glassShadow;
    }
    
    // For dark themes, reduce shadow opacity
    final shadowMultiplier = brightness == Brightness.dark ? 0.6 : 1.0;
    
    switch (intensity) {
      case ShadowIntensity.light:
        return lightShadow.map((shadow) => BoxShadow(
          color: Color.lerp(shadow.color, Colors.transparent, 1 - shadowMultiplier)!,
          offset: shadow.offset,
          blurRadius: shadow.blurRadius,
          spreadRadius: shadow.spreadRadius,
        )).toList();
      case ShadowIntensity.medium:
        return mediumShadow.map((shadow) => BoxShadow(
          color: Color.lerp(shadow.color, Colors.transparent, 1 - shadowMultiplier)!,
          offset: shadow.offset,
          blurRadius: shadow.blurRadius,
          spreadRadius: shadow.spreadRadius,
        )).toList();
      case ShadowIntensity.heavy:
        return heavyShadow.map((shadow) => BoxShadow(
          color: Color.lerp(shadow.color, Colors.transparent, 1 - shadowMultiplier)!,
          offset: shadow.offset,
          blurRadius: shadow.blurRadius,
          spreadRadius: shadow.spreadRadius,
        )).toList();
      case ShadowIntensity.floating:
        return floatingShadow.map((shadow) => BoxShadow(
          color: Color.lerp(shadow.color, Colors.transparent, 1 - shadowMultiplier)!,
          offset: shadow.offset,
          blurRadius: shadow.blurRadius,
          spreadRadius: shadow.spreadRadius,
        )).toList();
    }
  }
}

/// Shadow intensity levels
enum ShadowIntensity {
  light,
  medium,
  heavy,
  floating,
}

/// Helper method to create shadows based on intensity
BoxDecoration createShadowDecoration({
  ShadowIntensity intensity = ShadowIntensity.medium,
  bool isGlass = false,
  Color? color,
  Gradient? gradient,
  double borderRadius = 12,
  Border? border,
}) {
  final shadows = isGlass
      ? ShadowStyles.glassShadow
      : intensity == ShadowIntensity.light
          ? ShadowStyles.lightShadow
          : intensity == ShadowIntensity.medium
              ? ShadowStyles.mediumShadow
              : intensity == ShadowIntensity.heavy
                  ? ShadowStyles.heavyShadow
                  : ShadowStyles.floatingShadow;
  
  return BoxDecoration(
    color: gradient == null ? color : null,
    gradient: gradient,
    borderRadius: BorderRadius.circular(borderRadius),
    boxShadow: shadows,
    border: border,
  );
}
