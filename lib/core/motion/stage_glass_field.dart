import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Soft glass text field used inside Living Stage act forms.
class StageGlassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool dense;
  final Key? fieldKey;

  const StageGlassField({
    super.key,
    required this.controller,
    required this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.dense = false,
    this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.08);
    final fg = isDark ? Colors.white : Colors.black87;
    final hintColor = fg.withValues(alpha: 0.45);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: TextField(
          key: fieldKey,
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: dense ? 14 : 15,
            height: 1.35,
          ),
          cursorColor: fg,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: hintColor,
              fontWeight: FontWeight.w500,
              fontSize: dense ? 14 : 15,
            ),
            filled: true,
            fillColor: fill,
            isDense: dense,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: dense ? 12 : 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: fg.withValues(alpha: 0.35),
                width: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Staggers a child in with fade + lift. Used by act forms on the stage.
class StageStaggerIn extends StatelessWidget {
  final int index;
  final Widget child;
  final int stepMs;
  final int runMs;

  const StageStaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.stepMs = 70,
    this.runMs = 360,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final delay = stepMs * index;
    final total = delay + runMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: Transform.scale(
              scale: 0.96 + 0.04 * t,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
