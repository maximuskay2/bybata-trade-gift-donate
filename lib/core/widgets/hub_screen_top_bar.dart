import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/settings/widgets/settings_ui.dart';
import '../navigation/app_routes.dart';
import '../providers/notification_provider.dart';

/// Shared top bar for hub screens (Messages, Trade Center, Wallet-style hubs).
class HubScreenTopBar extends StatelessWidget {
  /// Space between the leading back/drawer control and the title.
  static const double leadingTitleGap = 14;

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onOpenDrawer;
  final bool showNotifications;
  final List<Widget> trailingActions;

  const HubScreenTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.onOpenDrawer,
    this.showNotifications = false,
    this.trailingActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = SettingsUi.pageBackground(context);

    return Material(
      color: pageBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  if (onBack != null)
                    HubTopBarIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: onBack!,
                      isDark: isDark,
                    )
                  else if (onOpenDrawer != null)
                    HubTopBarIconButton(
                      icon: Icons.grid_view_rounded,
                      onTap: onOpenDrawer!,
                      isDark: isDark,
                    ),
                  if (onBack != null || onOpenDrawer != null)
                    const SizedBox(width: leadingTitleGap),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (showNotifications) const HubTopBarNotifications(),
                  ...trailingActions,
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

class HubTopBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final Color? iconColor;

  const HubTopBarIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.isDark,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: iconColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}

class HubTopBarNotifications extends StatelessWidget {
  const HubTopBarNotifications({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        final unread = notificationProvider.unreadCount;
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              HubTopBarIconButton(
                icon: Icons.notifications_outlined,
                onTap: () => AppRoutes.navigateToNotifications(context),
                isDark: isDark,
              ),
              if (unread > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: SettingsUi.pageBackground(context),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onError,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

}
