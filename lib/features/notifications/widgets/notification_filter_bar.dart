import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_models.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Type filter chips for the notifications inbox.
class NotificationFilterBar extends StatelessWidget {
  const NotificationFilterBar({super.key});

  static const filters = <({NotificationType? type, String label, IconData icon})>[
    (type: null, label: 'All', icon: Icons.notifications_outlined),
    (type: NotificationType.message, label: 'Messages', icon: Icons.chat_bubble_outline),
    (type: NotificationType.trade, label: 'Trades', icon: Icons.swap_horiz),
    (type: NotificationType.gift, label: 'Gifts', icon: Icons.card_giftcard),
    (type: NotificationType.campaign, label: 'Campaigns', icon: Icons.campaign_outlined),
    (type: NotificationType.system, label: 'System', icon: Icons.info_outline),
    (
      type: NotificationType.achievement,
      label: 'Achievements',
      icon: Icons.emoji_events_outlined
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final stats = provider.notificationTypeStats;
        final scheme = Theme.of(context).colorScheme;

        return Material(
          color: scheme.surface,
          child: SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = filters[index];
                final selected = provider.selectedType == filter.type;
                final count = filter.type == null
                    ? provider.notifications.length
                    : (stats[filter.type] ?? 0);

                return _TypeChip(
                  label: filter.label,
                  icon: filter.icon,
                  count: count,
                  selected: selected,
                  onTap: () {
                    if (selected && filter.type != null) {
                      provider.setTypeFilter(null);
                    } else {
                      provider.setTypeFilter(filter.type);
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? AppColors.primary : scheme.surfaceContainerHighest;
    final fg = selected ? Colors.white : scheme.onSurface;

    return Material(
      color: bg,
      elevation: selected ? 1 : 0,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
