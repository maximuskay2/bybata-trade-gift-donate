import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_models.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../utils/notification_ui_helpers.dart';
import 'package:bybata/core/widgets/app_toast.dart';

/// Notification preferences bottom sheet (from the inbox tune button).
class NotificationSettingsSheet extends StatefulWidget {
  const NotificationSettingsSheet({super.key});

  static const _categoryTypes = <NotificationType>[
    NotificationType.trade,
    NotificationType.gift,
    NotificationType.campaign,
    NotificationType.message,
    NotificationType.system,
    NotificationType.achievement,
  ];

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationSettingsSheet(),
    );
  }

  @override
  State<NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().reloadSettings();
    });
  }

  Future<void> _run(Future<bool> Function() action, {String? successMessage}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await action();
      if (!mounted) return;
      if (ok && successMessage != null) {
        AppToast.show(context, successMessage);
      } else if (!ok) {
        final err = context.read<NotificationProvider>().errorMessage;
        AppToast.show(context, err ?? 'Something went wrong');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final divider = isDark
        ? AppColors.darkTextSecondary.withValues(alpha: 0.25)
        : AppColors.lightTextSecondary.withValues(alpha: 0.2);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                ),
              ],
            ),
          ),
          Flexible(
            child: Consumer<NotificationProvider>(
              builder: (context, provider, _) {
                final allCategoriesOn = NotificationSettingsSheet._categoryTypes
                    .every(provider.isNotificationTypeEnabled);

                return ListView(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
                  children: [
                    if (provider.errorMessage != null) ...[
                      _InfoBanner(
                        message: provider.errorMessage!,
                        onDismiss: provider.clearError,
                        textPrimary: textPrimary,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _SectionLabel('Delivery', textSecondary),
                    const SizedBox(height: 8),
                    _ToggleRow(
                      title: 'Push notifications',
                      subtitle: 'Alerts on this device',
                      value: provider.pushNotificationsEnabled,
                      enabled: !_busy,
                      onChanged: (v) => _run(
                        () => provider.setPushNotificationsEnabled(v),
                      ),
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      divider: divider,
                    ),
                    _ToggleRow(
                      title: 'Email notifications',
                      subtitle: 'Updates in your inbox',
                      value: provider.emailNotificationsEnabled,
                      enabled: !_busy,
                      onChanged: (v) => _run(
                        () => provider.setEmailNotificationsEnabled(v),
                      ),
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      divider: divider,
                      showDividerAbove: true,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _SectionLabel('Categories', textSecondary),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  final enable = !allCategoriesOn;
                                  _run(
                                    () => provider
                                        .setAllNotificationTypesEnabled(enable),
                                    successMessage: enable
                                        ? 'All categories enabled'
                                        : 'All categories disabled',
                                  );
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            allCategoriesOn ? 'Turn off all' : 'Turn on all',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...NotificationSettingsSheet._categoryTypes.map((type) {
                      return _CategoryRow(
                        type: type,
                        value: provider.isNotificationTypeEnabled(type),
                        enabled: !_busy,
                        onChanged: (v) => _run(
                          () => provider.setNotificationTypeEnabled(type, v),
                        ),
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        divider: divider,
                        showDividerAbove:
                            type != NotificationSettingsSheet._categoryTypes.first,
                      );
                    }),
                    _NearbyRow(
                      value: provider.nearbyListingsEnabled,
                      enabled: !_busy,
                      onChanged: (v) => _run(
                        () => provider.setNearbyListingsEnabled(v),
                      ),
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      divider: divider,
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel('Inbox', textSecondary),
                    const SizedBox(height: 8),
                    _ActionRow(
                      label: 'Mark all as read',
                      enabled: !_busy,
                      onTap: () => _run(
                        () => provider.markAllAsRead(),
                        successMessage: 'All notifications marked as read',
                      ),
                      textPrimary: textPrimary,
                      divider: divider,
                    ),
                    _ActionRow(
                      label: 'Clear all notifications',
                      enabled: !_busy,
                      onTap: () => _confirmClearAll(context, provider),
                      textPrimary: textPrimary,
                      divider: divider,
                      destructive: true,
                      showDividerAbove: true,
                    ),
                    _ActionRow(
                      label: 'Refresh list',
                      enabled: !_busy,
                      onTap: () async {
                        if (_busy) return;
                        setState(() => _busy = true);
                        try {
                          await provider.refresh();
                          if (!mounted) return;
                          AppToast.show(this.context, 'Notifications refreshed');
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                      textPrimary: textPrimary,
                      divider: divider,
                      showDividerAbove: true,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, NotificationProvider provider) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all?'),
        content: const Text(
          'This removes every notification from your inbox. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final navigator = Navigator.of(this.context);
              final messenger = ScaffoldMessenger.maybeOf(this.context);
              final ok = await provider.clearAllNotifications();
              if (!mounted) return;
              navigator.pop(); // close settings sheet
              final msg = ok
                  ? 'Inbox cleared'
                  : (provider.errorMessage ?? 'Couldn\'t clear inbox');
              messenger?.showSnackBar(SnackBar(content: Text(msg)));
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: color,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.message,
    required this.onDismiss,
    required this.textPrimary,
  });

  final String message;
  final VoidCallback onDismiss;
  final Color textPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: textPrimary, height: 1.35),
            ),
          ),
          TextButton(
            onPressed: onDismiss,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    this.enabled = true,
    this.showDividerAbove = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final bool enabled;
  final bool showDividerAbove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDividerAbove) Divider(height: 1, color: divider),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: enabled ? onChanged : null,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.type,
    required this.value,
    required this.onChanged,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    this.enabled = true,
    this.showDividerAbove = false,
  });

  final NotificationType type;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final bool enabled;
  final bool showDividerAbove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDividerAbove) Divider(height: 1, color: divider),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(
                NotificationUi.iconFor(type),
                size: 22,
                color: AppColors.primary.withValues(alpha: value ? 1 : 0.45),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      NotificationUi.labelFor(type),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      NotificationUi.subtitleFor(type),
                      style: TextStyle(fontSize: 12, color: textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: enabled ? onChanged : null,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({
    required this.value,
    required this.onChanged,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(height: 1, color: divider),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.near_me_outlined,
                size: 22,
                color: AppColors.primary.withValues(alpha: value ? 1 : 0.45),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nearby listings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'New trades, gifts & campaigns within 100 km',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: enabled ? onChanged : null,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.onTap,
    required this.textPrimary,
    required this.divider,
    this.enabled = true,
    this.destructive = false,
    this.showDividerAbove = false,
  });

  final String label;
  final VoidCallback onTap;
  final Color textPrimary;
  final Color divider;
  final bool enabled;
  final bool destructive;
  final bool showDividerAbove;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : textPrimary;

    return Column(
      children: [
        if (showDividerAbove) Divider(height: 1, color: divider),
        InkWell(
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: textPrimary.withValues(alpha: 0.35),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
