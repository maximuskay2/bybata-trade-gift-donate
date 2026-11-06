import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final String? text;
  final Gradient? gradient;
  final List<Color>? colors;
  final IconData? icon;
  final bool isLoading;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final TextStyle? textStyle;

  const GradientButton({
    super.key,
    required this.onPressed,
    this.child,
    this.text,
    this.gradient,
    this.colors,
    this.icon,
    this.isLoading = false,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.width,
    this.height,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final Gradient effectiveGradient = gradient ??
        LinearGradient(colors: colors ?? [
          AppColors.primary,
          HSLColor.fromColor(AppColors.primary).withLightness(0.78).toColor(),
        ]);

    Widget content;
    if (isLoading) {
      content = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    } else if (child != null) {
      content = child!;
    } else {
      final List<Widget> rowChildren = [];
      if (icon != null) {
        rowChildren.add(Icon(icon, color: Colors.white, size: 18));
        rowChildren.add(const SizedBox(width: 8));
      }
      rowChildren.add(Text(
        text ?? '',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)
            .merge(textStyle),
      ));
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: rowChildren,
      );
    }

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Ink(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: effectiveGradient,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(
          child: Padding(
            padding: padding,
            child: content,
          ),
        ),
      ),
    );
  }
}
