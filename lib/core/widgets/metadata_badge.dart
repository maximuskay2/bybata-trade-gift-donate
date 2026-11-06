import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BadgeStyle {
  primary,
  success,
  warning,
  danger,
  info,
}

extension BadgeStyleExtension on BadgeStyle {
  Color get backgroundColor {
    switch (this) {
      case BadgeStyle.primary:
        return AppColors.primary.withOpacity(0.15);
      case BadgeStyle.success:
        return const Color(0xFF10B981).withOpacity(0.15);
      case BadgeStyle.warning:
        return const Color(0xFFF59E0B).withOpacity(0.15);
      case BadgeStyle.danger:
        return const Color(0xFFEF4444).withOpacity(0.15);
      case BadgeStyle.info:
        return AppColors.primary.withOpacity(0.15);
    }
  }

  Color get foregroundColor {
    switch (this) {
      case BadgeStyle.primary:
        return AppColors.primary;
      case BadgeStyle.success:
        return const Color(0xFF10B981);
      case BadgeStyle.warning:
        return const Color(0xFFF59E0B);
      case BadgeStyle.danger:
        return const Color(0xFFEF4444);
      case BadgeStyle.info:
        return AppColors.primary;
    }
  }
}

class MetadataBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final BadgeStyle style;
  final VoidCallback? onTap;
  final double fontSize;
  final EdgeInsets padding;
  final bool showDot;

  const MetadataBadge({
    super.key,
    required this.label,
    this.icon,
    this.style = BadgeStyle.primary,
    this.onTap,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = style.backgroundColor;
    final fgColor = style.foregroundColor;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDot)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fgColor,
              ),
            ),
          ),
        if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              icon,
              color: fgColor,
              size: fontSize + 2,
            ),
          ),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: fgColor,
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: fgColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: content,
      ),
    );
  }

  // Utility factory constructors for common statuses
  factory MetadataBadge.status({
    required String status,
    VoidCallback? onTap,
    double fontSize = 12,
  }) {
    final (icon, style) = switch (status.toLowerCase()) {
      'active' || 'available' || 'open' => (Icons.check_circle_rounded, BadgeStyle.success),
      'completed' || 'closed' => (Icons.verified_rounded, BadgeStyle.info),
      'pending' => (Icons.schedule_rounded, BadgeStyle.warning),
      'cancelled' || 'rejected' => (Icons.cancel_rounded, BadgeStyle.danger),
      'archived' => (Icons.archive_rounded, BadgeStyle.info),
      _ => (null, BadgeStyle.primary),
    };

    return MetadataBadge(
      label: status,
      icon: icon,
      style: style,
      onTap: onTap,
      fontSize: fontSize,
      showDot: false,
    );
  }

  factory MetadataBadge.category({
    required String category,
    VoidCallback? onTap,
  }) {
    const categoryInfo = {
      'ELECTRONICS': (Icons.devices, BadgeStyle.primary),
      'FURNITURE': (Icons.chair, BadgeStyle.info),
      'CLOTHING': (Icons.checkroom, BadgeStyle.success),
      'BOOKS': (Icons.library_books_rounded, BadgeStyle.info),
      'HEALTH': (Icons.health_and_safety, BadgeStyle.warning),
      'VEHICLE': (Icons.directions_car, BadgeStyle.primary),
    };

    final info = categoryInfo[category] ?? (Icons.category, BadgeStyle.primary);

    return MetadataBadge(
      label: category,
      icon: info.$1,
      style: info.$2,
      onTap: onTap,
      showDot: false,
    );
  }

  factory MetadataBadge.priority({
    required String priority,
    VoidCallback? onTap,
  }) {
    final (icon, style) = switch (priority.toLowerCase()) {
      'high' => (Icons.priority_high, BadgeStyle.danger),
      'medium' => (Icons.priority_high, BadgeStyle.warning),
      'low' => (Icons.priority_high, BadgeStyle.success),
      _ => (null, BadgeStyle.primary),
    };

    return MetadataBadge(
      label: priority,
      icon: icon,
      style: style,
      onTap: onTap,
      showDot: true,
    );
  }
}
