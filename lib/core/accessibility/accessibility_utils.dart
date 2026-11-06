import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// Comprehensive accessibility system for screen readers and assistive technologies

class AccessibilityUtils {
  /// Check if screen reader is active
  static bool isScreenReaderActive(BuildContext context) {
    return MediaQuery.of(context).accessibleNavigation;
  }

  /// Check if high contrast is enabled
  static bool isHighContrastEnabled(BuildContext context) {
    return MediaQuery.of(context).highContrast;
  }

  /// Check if animations should be reduced
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get text scale factor for accessibility
  static double getTextScaleFactor(BuildContext context) {
    return MediaQuery.of(context).textScaler.scale(1.0);
  }

  /// Announce message to screen reader
  static void announce(String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Focus on a specific widget
  static void focusOn(FocusNode focusNode) {
    focusNode.requestFocus();
  }

  /// Create semantic label for complex widgets
  static String createSemanticLabel({
    required String mainText,
    String? hint,
    String? value,
    bool? isSelected,
    bool? isEnabled,
  }) {
    final buffer = StringBuffer(mainText);
    
    if (value != null) {
      buffer.write(', $value');
    }
    
    if (isSelected == true) {
      buffer.write(', selected');
    }
    
    if (isEnabled == false) {
      buffer.write(', disabled');
    }
    
    if (hint != null) {
      buffer.write(', $hint');
    }
    
    return buffer.toString();
  }
}

/// Enhanced button with comprehensive accessibility support
class AccessibleButton extends StatelessWidget {
  final String label;
  final String? hint;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget? child;
  final bool excludeSemantics;
  final bool isLoading;
  final bool isDestructive;
  final ButtonStyle? style;
  final FocusNode? focusNode;

  const AccessibleButton({
    Key? key,
    required this.label,
    this.hint,
    this.semanticLabel,
    this.onPressed,
    this.onLongPress,
    this.child,
    this.excludeSemantics = false,
    this.isLoading = false,
    this.isDestructive = false,
    this.style,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveSemanticLabel = semanticLabel ?? 
        AccessibilityUtils.createSemanticLabel(
          mainText: label,
          hint: hint,
          isEnabled: onPressed != null && !isLoading,
        );

    Widget button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      onLongPress: isLoading ? null : onLongPress,
      style: style ?? _getDefaultStyle(context),
      focusNode: focusNode,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (child ?? Text(label)),
    );

    if (excludeSemantics) return button;

    return Semantics(
      label: effectiveSemanticLabel,
      hint: hint,
      button: true,
      enabled: onPressed != null && !isLoading,
      focusable: true,
      child: button,
    );
  }

  ButtonStyle _getDefaultStyle(BuildContext context) {
    if (isDestructive) {
      return ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      );
    }
    return Theme.of(context).elevatedButtonTheme.style ?? const ButtonStyle();
  }
}

/// Accessible text field with proper semantic labels
class AccessibleTextField extends StatelessWidget {
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool obscureText;
  final bool readOnly;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final int? maxLines;
  final int? maxLength;
  final bool required;

  const AccessibleTextField({
    Key? key,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.semanticLabel,
    this.controller,
    this.focusNode,
    this.obscureText = false,
    this.readOnly = false,
    this.keyboardType,
    this.onChanged,
    this.onTap,
    this.maxLines,
    this.maxLength,
    this.required = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = labelText ?? semanticLabel ?? hintText;
    final accessibilityLabel = required 
        ? '$effectiveLabel, required' 
        : effectiveLabel;

    return Semantics(
      label: accessibilityLabel,
      hint: helperText,
      textField: true,
      readOnly: readOnly,
      focusable: !readOnly,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        readOnly: readOnly,
        keyboardType: keyboardType,
        onChanged: onChanged,
        onTap: onTap,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: effectiveLabel,
          hintText: hintText,
          helperText: helperText,
          errorText: errorText,
          suffixIcon: required 
              ? const Icon(Icons.star, size: 8, color: Colors.red)
              : null,
        ),
        validator: required
            ? (value) {
                if (value == null || value.isEmpty) {
                  return '$effectiveLabel is required';
                }
                return null;
              }
            : null,
      ),
    );
  }
}

/// Accessible card with proper semantic structure
class AccessibleCard extends StatelessWidget {
  final Widget child;
  final String? semanticLabel;
  final String? hint;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isButton;
  final bool isSelected;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const AccessibleCard({
    Key? key,
    required this.child,
    this.semanticLabel,
    this.hint,
    this.onTap,
    this.onLongPress,
    this.isButton = false,
    this.isSelected = false,
    this.margin,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget card = Card(
      margin: margin ?? const EdgeInsets.all(8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

    return Semantics(
      label: semanticLabel,
      hint: hint,
      button: isButton && onTap != null,
      selected: isSelected,
      focusable: onTap != null,
      child: card,
    );
  }
}

/// Accessible list tile with enhanced semantic support
class AccessibleListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? semanticLabel;
  final String? hint;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isThreeLine;
  final bool selected;
  final bool enabled;

  const AccessibleListTile({
    Key? key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.semanticLabel,
    this.hint,
    this.onTap,
    this.onLongPress,
    this.isThreeLine = false,
    this.selected = false,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = semanticLabel ?? 
        AccessibilityUtils.createSemanticLabel(
          mainText: title,
          value: subtitle,
          hint: hint,
          isSelected: selected,
          isEnabled: enabled,
        );

    return Semantics(
      label: effectiveLabel,
      hint: hint,
      button: onTap != null,
      selected: selected,
      enabled: enabled,
      focusable: enabled && onTap != null,
      child: ListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        leading: leading,
        trailing: trailing,
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        isThreeLine: isThreeLine,
        selected: selected,
        enabled: enabled,
      ),
    );
  }
}

/// Accessible switch with proper labeling
class AccessibleSwitch extends StatelessWidget {
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  const AccessibleSwitch({
    Key? key,
    required this.label,
    this.hint,
    required this.value,
    this.onChanged,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final semanticLabel = AccessibilityUtils.createSemanticLabel(
      mainText: label,
      value: value ? 'on' : 'off',
      hint: hint,
      isEnabled: enabled && onChanged != null,
    );

    return Semantics(
      label: semanticLabel,
      hint: hint,
      toggled: value,
      enabled: enabled && onChanged != null,
      focusable: enabled && onChanged != null,
      child: SwitchListTile(
        title: Text(label),
        subtitle: hint != null ? Text(hint!) : null,
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

/// High contrast theme support
class HighContrastTheme {
  static ThemeData getHighContrastLight() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.light(primary: AppColors.primary),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        bodySmall: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        titleSmall: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.black, width: 2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black, width: 3),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
    );
  }

  static ThemeData getHighContrastDark() {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.yellow,
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.yellow,
        foregroundColor: Colors.black,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        bodySmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        titleSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.yellow,
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.yellow, width: 2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 3),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.yellow, width: 3),
        ),
      ),
    );
  }
}