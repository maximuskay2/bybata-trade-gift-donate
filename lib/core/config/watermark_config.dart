import 'dart:ui';

/// Centralized watermark configuration that can be customized per environment
/// or updated by admins at runtime.
class WatermarkConfig {
  // Badge position and sizing (as percentage of image dimensions)
  static const double badgeHeightPercent = 0.18; // 18% of image height
  static const double badgeHorizontalPaddingPercent = 0.06; // 6% from left/right edges
  static const double badgeBottomMarginPercent = 0.03; // 3% space from bottom

  // Badge background colors (RGBA)
  static const int badgeBgRed = 0;
  static const int badgeBgGreen = 0;
  static const int badgeBgBlue = 0;
  static const int badgeBgAlpha = 160; // Semi-transparent (160/255 = ~63%)

  // Inner glass overlay colors for glassmorphic effect
  static const int glassOverlayRed = 255;
  static const int glassOverlayGreen = 255;
  static const int glassOverlayBlue = 255;
  static const int glassOverlayAlpha = 40; // Light overlay (40/255 = ~16%)

  // Inner margin for glass overlay
  static const double glassMarginPercent = 0.01; // 1% margin inside badge

  // Text styling
  static const int textRed = 255;
  static const int textGreen = 255;
  static const int textBlue = 255;
  static const int textAlpha = 255; // Fully opaque

  // Font size (built-in fonts available: arial14, arial24, etc.)
  static const String fontFamily = 'arial14'; // Maps to img.arial14

  // Fallback handle when user doesn't have a name
  static const String fallbackHandle = '@bybata';

  // Text prefix (e.g., "@" before username)
  static const String handlePrefix = '@';

  /// Runtime-configurable settings that can be updated by admins
  static double badgeOpacity = 1.0; // 0.0 to 1.0, where 1.0 = fully opaque

  /// Enable/disable watermarking globally
  static bool enableWatermarking = true;

  /// Get computed alpha value for badge background based on opacity setting
  static int getComputedBadgeBgAlpha() {
    return (badgeBgAlpha * badgeOpacity).round();
  }

  /// Get computed alpha value for text based on opacity setting
  static int getComputedTextAlpha() {
    return (textAlpha * badgeOpacity).round();
  }

  /// Set watermark opacity (0.0 to 1.0)
  /// This allows users to control watermark visibility
  static void setWatermarkOpacity(double opacity) {
    if (opacity < 0.0 || opacity > 1.0) {
      throw ArgumentError('Opacity must be between 0.0 and 1.0');
    }
    badgeOpacity = opacity;
  }

  /// Reset to default configuration
  static void reset() {
    badgeOpacity = 1.0;
    enableWatermarking = true;
  }

  /// Convenience method to disable watermarking entirely
  static void disable() {
    enableWatermarking = false;
  }

  /// Convenience method to enable watermarking
  static void enable() {
    enableWatermarking = true;
  }
}
