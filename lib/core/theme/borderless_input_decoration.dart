import 'package:flutter/material.dart';

/// Shared borderless [InputDecoration] for search pills and command bars.
///
/// Strips the inner rectangle that Flutter draws on focus by clearing every
/// border state — matching [CommandInputPill].
class BorderlessInputDecoration {
  BorderlessInputDecoration._();

  static InputDecoration search({
    String? hintText,
    TextStyle? hintStyle,
    Widget? prefixIcon,
    Widget? suffixIcon,
    EdgeInsetsGeometry? contentPadding,
    bool filled = false,
    Color? fillColor,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: hintStyle,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: filled,
      fillColor: fillColor,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      isDense: true,
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
    );
  }
}
