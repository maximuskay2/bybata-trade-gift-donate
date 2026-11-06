import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

/// Utility class for consistent text styling across themes
class ThemeTextStyles {
  ThemeTextStyles._();

  /// Get theme-aware text color
  static Color getTextColor(BuildContext context, {double opacity = 1.0}) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final theme = Theme.of(context);
    
    if (themeProvider.isGlassTheme) {
      return Colors.white.withValues(alpha: opacity);
    } else if (themeProvider.isDarkTheme) {
      return theme.colorScheme.onSurface.withValues(alpha: opacity);
    } else {
      return theme.colorScheme.onSurface.withValues(alpha: opacity);
    }
  }

  /// Get theme-aware secondary text color (muted)
  static Color getSecondaryTextColor(BuildContext context, {double opacity = 0.7}) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    if (themeProvider.isGlassTheme) {
      return Colors.white.withValues(alpha: opacity);
    } else if (themeProvider.isDarkTheme) {
      return Colors.grey[400]!.withValues(alpha: opacity);
    } else {
      return Colors.grey[600]!.withValues(alpha: opacity);
    }
  }

  /// Header text style - large, bold
  static TextStyle getHeaderStyle(BuildContext context, {
    double fontSize = 24,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.bold,
      color: color ?? getTextColor(context),
    );
  }

  /// Subheader text style - medium, semi-bold
  static TextStyle getSubHeaderStyle(BuildContext context, {
    double fontSize = 18,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? getTextColor(context),
    );
  }

  /// Body text style - normal size, mild bold for clarity
  static TextStyle getBodyStyle(BuildContext context, {
    double fontSize = 14,
    FontWeight? fontWeight,
    Color? color,
    double? opacity,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500, // Mild bold for clarity
      color: color ?? getTextColor(context, opacity: opacity ?? 1.0),
    );
  }

  /// Caption text style - small, normal weight
  static TextStyle getCaptionStyle(BuildContext context, {
    double fontSize = 12,
    FontWeight? fontWeight,
    Color? color,
    double? opacity,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500, // Mild bold for clarity
      color: color ?? getSecondaryTextColor(context, opacity: opacity ?? 0.7),
    );
  }

  /// Button text style - medium, semi-bold
  static TextStyle getButtonStyle(BuildContext context, {
    double fontSize = 14,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? Colors.white,
    );
  }

  /// Input text style - for text fields and inputs
  static TextStyle getInputStyle(BuildContext context, {
    double fontSize = 14,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500, // Mild bold for clarity
      color: color ?? getTextColor(context),
    );
  }

  /// Hint text style - for placeholder text
  static TextStyle getHintStyle(BuildContext context, {
    double fontSize = 14,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: getSecondaryTextColor(context, opacity: 0.5),
    );
  }

  /// Get appropriate white text style for colored backgrounds
  static TextStyle getWhiteTextStyle({
    double fontSize = 14,
    FontWeight? fontWeight,
    double opacity = 1.0,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500, // Mild bold for clarity
      color: Colors.white.withValues(alpha: opacity),
    );
  }

  /// Get contrast text color for any background color
  static Color getContrastTextColor(Color backgroundColor) {
    // Calculate luminance to determine if text should be light or dark
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

/// Theme-aware Text widget that automatically adapts to current theme
class ThemeAwareText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextStyle Function(BuildContext)? styleBuilder;
  final double? opacity;

  const ThemeAwareText(
    this.text, {
    super.key,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.styleBuilder,
    this.opacity,
  });

  /// Create a header text widget
  const ThemeAwareText.header(
    this.text, {
    super.key,
    this.fontSize = 24,
    this.fontWeight = FontWeight.bold,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.opacity,
  }) : styleBuilder = null;

  /// Create a subheader text widget
  const ThemeAwareText.subheader(
    this.text, {
    super.key,
    this.fontSize = 18,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.opacity,
  }) : styleBuilder = null;

  /// Create a body text widget
  const ThemeAwareText.body(
    this.text, {
    super.key,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w500,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.opacity,
  }) : styleBuilder = null;

  /// Create a caption text widget
  const ThemeAwareText.caption(
    this.text, {
    super.key,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w500,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.opacity = 0.7,
  }) : styleBuilder = null;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = styleBuilder?.call(context) ?? 
      ThemeTextStyles.getBodyStyle(
        context,
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.w500,
        color: color,
        opacity: opacity,
      );

    return Text(
      text,
      style: effectiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}