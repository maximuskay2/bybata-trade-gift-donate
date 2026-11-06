import 'package:flutter/material.dart';

/// Horizontal divider with a centered label for unread-message separation.
///
/// Insert this between the last-read message and the first unread message
/// so users see exactly where they left off.
class UnreadDivider extends StatelessWidget {
  final String label;
  final EdgeInsetsGeometry margin;

  const UnreadDivider({
    super.key,
    this.label = 'Unread Messages',
    this.margin = const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = theme.dividerColor.withValues(alpha: 0.5);
    final labelColor = theme.colorScheme.primary;
    return Padding(
      padding: margin,
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: lineColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: lineColor)),
        ],
      ),
    );
  }
}
