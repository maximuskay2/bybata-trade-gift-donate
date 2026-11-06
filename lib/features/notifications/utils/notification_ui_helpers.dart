import 'package:flutter/material.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_theme.dart';

/// Icon + color for in-app notification list items and settings rows.
class NotificationUi {
  NotificationUi._();

  static IconData iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return Icons.chat_bubble_rounded;
      case NotificationType.trade:
        return Icons.swap_horiz_rounded;
      case NotificationType.gift:
        return Icons.card_giftcard_rounded;
      case NotificationType.campaign:
        return Icons.volunteer_activism_rounded;
      case NotificationType.achievement:
        return Icons.emoji_events_rounded;
      case NotificationType.reminder:
        return Icons.schedule_rounded;
      case NotificationType.system:
        return Icons.notifications_rounded;
    }
  }

  static Color colorFor(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return AppColors.info;
      case NotificationType.trade:
        return AppColors.success;
      case NotificationType.gift:
        return const Color(0xFFEC4899);
      case NotificationType.campaign:
        return AppColors.primary;
      case NotificationType.achievement:
        return AppColors.warning;
      case NotificationType.reminder:
        return const Color(0xFF8B5CF6);
      case NotificationType.system:
        return AppColors.primary;
    }
  }

  static String labelFor(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return 'Messages';
      case NotificationType.trade:
        return 'Trades';
      case NotificationType.gift:
        return 'Gifts';
      case NotificationType.campaign:
        return 'Campaigns';
      case NotificationType.achievement:
        return 'Karma & achievements';
      case NotificationType.system:
        return 'Updates';
      case NotificationType.reminder:
        return 'Reminders';
    }
  }

  static String subtitleFor(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return 'Chats and direct messages';
      case NotificationType.trade:
        return 'Offers, accepts, and trade activity';
      case NotificationType.gift:
        return 'Gifts sent and received';
      case NotificationType.campaign:
        return 'Donations and campaign milestones';
      case NotificationType.achievement:
        return 'Karma, levels, and badges';
      case NotificationType.system:
        return 'Announcements and account updates';
      case NotificationType.reminder:
        return 'Helpful nudges and follow-ups';
    }
  }

  static Widget leadingAvatar(NotificationType type, {double size = 48}) {
    final color = colorFor(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(iconFor(type), color: color, size: size * 0.48),
    );
  }
}
