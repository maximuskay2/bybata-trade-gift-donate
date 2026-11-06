import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.padding,
    this.margin,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (color ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: color ?? Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color ?? Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Section Content
            Padding(
              padding: padding ?? const EdgeInsets.fromLTRB(0, 0, 0, 8),
              child: Column(
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}