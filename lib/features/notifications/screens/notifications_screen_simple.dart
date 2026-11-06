import 'package:flutter/material.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/debounced_tap.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_models.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/network_error_message.dart';
import '../../../core/widgets/hub_fluid_tab_switcher.dart';
import '../../../core/widgets/hub_screen_top_bar.dart';
import '../../../features/common/widgets/state_components.dart';
import '../../../features/settings/widgets/settings_ui.dart';
import '../utils/notification_ui_helpers.dart';
import '../widgets/notification_settings_sheet.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabLabels = ['All', 'Unread', 'Read'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(_onTabControllerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      provider.setReadFilter(null);
      provider.setTypeFilter(null);
      provider.initializeNotifications();
    });
  }

  void _onTabControllerUpdate() {
    if (_tabController.indexIsChanging) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    final provider = context.read<NotificationProvider>();
    switch (_tabController.index) {
      case 1:
        provider.setReadFilter(false);
        break;
      case 2:
        provider.setReadFilter(true);
        break;
      default:
        provider.setReadFilter(null);
    }
    setState(() {});
  }

  /// Tab → read filter. Unread = false, Read = true, All = null.
  bool? get _readFilterForTab {
    switch (_tabController.index) {
      case 1:
        return false;
      case 2:
        return true;
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabControllerUpdate);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SettingsUi.pageBackground(context),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const BybataLoader();
          }

          if (provider.errorMessage != null && provider.notifications.isEmpty) {
            return Column(
              children: [
                HubScreenTopBar(
                  title: 'Notifications',
                  onBack: () => Navigator.maybePop(context),
                  trailingActions: [
                    HubTopBarIconButton(
                      icon: Icons.tune_rounded,
                      onTap: () => NotificationSettingsSheet.show(context),
                      isDark: Theme.of(context).brightness == Brightness.dark,
                    ),
                  ],
                ),
                Expanded(child: _buildErrorState(provider)),
              ],
            );
          }

          final visible = provider.notificationsFor(
            type: null,
            read: _readFilterForTab,
          );

          return Column(
            children: [
              HubScreenTopBar(
                title: 'Notifications',
                onBack: () => Navigator.maybePop(context),
                trailingActions: [
                  if (provider.unreadCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: TextButton(
                        onPressed: () => provider.markAllAsRead(),
                        child: const Text('Mark all read'),
                      ),
                    ),
                  HubTopBarIconButton(
                    icon: Icons.tune_rounded,
                    onTap: () => NotificationSettingsSheet.show(context),
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  ),
                ],
              ),
              HubFluidTabSwitcher(
                controller: _tabController,
                labels: _tabLabels,
              ),
              Expanded(child: _buildList(provider, visible)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(NotificationProvider provider, List<AppNotification> items) {
    if (items.isEmpty) {
      return _buildEmptyState(provider);
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: provider.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final notification = items[index];
          return _NotificationTile(
            notification: notification,
            onTap: () => provider.handleNotificationTap(notification),
            onDismiss: () => provider.deleteNotification(notification.id),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(NotificationProvider provider) {
    final readFilter = _readFilterForTab;
    late final String title;
    late final String message;
    if (readFilter == false) {
      title = 'No unread notifications';
      message = 'You\'re all caught up. Switch to All to see older ones.';
    } else if (readFilter == true) {
      title = 'No read notifications';
      message = 'Opened notifications will show up here.';
    } else {
      title = 'No notifications yet';
      message =
          'When you get trade offers, messages, or updates, they\'ll show up here.';
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: provider.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.secondaryText,
                      height: 1.4,
                    ),
                  ),
                ),
                if (readFilter != null) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      provider.setTypeFilter(null);
                      provider.setReadFilter(null);
                      _tabController.animateTo(0);
                    },
                    child: const Text('Show all notifications'),
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.read<NotificationProvider>().refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(NotificationProvider provider) {
    final raw = provider.errorMessage;
    return ErrorState(
      title: "Couldn't load notifications",
      message: NetworkErrorMessage.sanitize(
        raw,
        fallback: 'Check your connection and try again.',
      ),
      type: ErrorStateType.network,
      actionText: 'Try again',
      onRetry: () {
        provider.clearError();
        provider.refresh();
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = !notification.isRead;

    return Material(
      color: unread
          ? AppColors.primary.withValues(alpha: 0.08)
          : scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: DebouncedTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NotificationUi.leadingAvatar(notification.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 15,
                              color: scheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(notification.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 7) return '${dateTime.day}/${dateTime.month}';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Now';
  }
}
