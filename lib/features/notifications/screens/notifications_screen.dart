import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/providers.dart';
import '../../../core/widgets/hub_fluid_tab_switcher.dart';
import '../../../core/widgets/hub_screen_top_bar.dart';
import '../../../features/common/widgets/interaction_components.dart';
import '../../../features/common/widgets/state_components.dart';
import '../../../features/common/widgets/custom_cards.dart' as custom_cards;
import '../../../features/settings/widgets/settings_ui.dart';
import '../../../core/utils/network_error_message.dart';
import '../widgets/notification_settings_sheet.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  static const _tabLabels = ['All', 'Unread', 'Read'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(_onTabControllerUpdate);
    _scrollController.addListener(_onScroll);
    
    // Initialize notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      provider.setReadFilter(null);
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

  @override
  void dispose() {
    _tabController.removeListener(_onTabControllerUpdate);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more notifications when near bottom
      context.read<NotificationProvider>().loadNotifications();
    }
  }

  custom_cards.NotificationType _convertNotificationType(NotificationType type) {
    switch (type) {
      case NotificationType.trade:
        return custom_cards.NotificationType.trade;
      case NotificationType.gift:
        return custom_cards.NotificationType.gift;
      case NotificationType.campaign:
        return custom_cards.NotificationType.campaign;
      case NotificationType.achievement:
        return custom_cards.NotificationType.achievement;
      case NotificationType.message:
        return custom_cards.NotificationType.message;
      case NotificationType.system:
        return custom_cards.NotificationType.system;
      case NotificationType.reminder:
        return custom_cards.NotificationType.reminder;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SettingsUi.pageBackground(context),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          if (notificationProvider.isLoading && 
              notificationProvider.notifications.isEmpty) {
            return Column(
              children: [
                HubScreenTopBar(
                  title: 'Notifications',
                  onBack: () => Navigator.maybePop(context),
                ),
                const Expanded(child: BybataLoader(message: 'Loading notifications...')),
              ],
            );
          }

          if (notificationProvider.errorMessage != null &&
              notificationProvider.notifications.isEmpty) {
            return Column(
              children: [
                HubScreenTopBar(
                  title: 'Notifications',
                  onBack: () => Navigator.maybePop(context),
                ),
                Expanded(child: _buildErrorState(notificationProvider)),
              ],
            );
          }

          return Column(
            children: [
              HubScreenTopBar(
                title: 'Notifications',
                onBack: () => Navigator.maybePop(context),
                trailingActions: [
                  if (notificationProvider.unreadCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: TextButton(
                        onPressed: () => notificationProvider.markAllAsRead(),
                        child: const Text('Mark all read'),
                      ),
                    ),
                  HubTopBarIconButton(
                    icon: Icons.settings_outlined,
                    onTap: () => _showSettingsSheet(context),
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  ),
                ],
              ),
              HubFluidTabSwitcher(
                controller: _tabController,
                labels: _tabLabels,
              ),
              Expanded(
                child: _buildNotificationList(
                  notificationProvider.notificationsFor(
                    type: null,
                    read: _tabController.index == 1
                        ? false
                        : _tabController.index == 2
                            ? true
                            : null,
                  ),
                ),
              ),
              if (notificationProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: BybataLoader(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationList(List<AppNotification> notifications) {
    return RefreshIndicator(
      onRefresh: () => context.read<NotificationProvider>().refresh(),
      child: notifications.isEmpty
          ? ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: _buildEmptyState(),
                ),
              ],
            )
          : ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationItem(notification);
              },
            ),
    );
  }

  Widget _buildNotificationItem(AppNotification notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red.shade100,
        child: Icon(
          Icons.delete,
          color: Colors.red.shade700,
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(notification);
      },
      onDismissed: (direction) {
        context.read<NotificationProvider>().deleteNotification(notification.id);
        AppToast.show(context, 'Notification deleted');
      },
      child: custom_cards.NotificationCard(
        title: notification.title,
        message: notification.message,
        timestamp: notification.createdAt,
        type: _convertNotificationType(notification.type),
        isRead: notification.isRead,
        imageUrl: notification.imageUrl,
        style: custom_cards.NotificationCardStyle.standard,
        onTap: () => _handleNotificationTap(notification),
        onDismiss: () => _deleteNotification(notification.id),
      ),
    );
  }

  Widget _buildErrorState(NotificationProvider provider) {
    return ErrorState(
      title: "Couldn't load notifications",
      message: NetworkErrorMessage.sanitize(
        provider.errorMessage,
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

  Widget _buildEmptyState() {
    return EmptyState(
      title: 'No notifications yet',
      message: 'When you have notifications, they\'ll appear here',
      type: EmptyStateType.notifications,
      icon: Icons.notifications_none,
      actionText: 'Refresh',
      onAction: () => context.read<NotificationProvider>().refresh(),
    );
  }

  void _handleNotificationTap(AppNotification notification) {
    context.read<NotificationProvider>().handleNotificationTap(notification);
  }

  Future<bool> _showDeleteConfirmation(AppNotification notification) async {
    return await ConfirmationDialog.show(
      context: context,
      title: 'Delete Notification',
      message: 'Are you sure you want to delete this notification?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDangerous: true,
      icon: Icons.delete_outline,
    ) ?? false;
  }

  void _deleteNotification(String notificationId) {
    context.read<NotificationProvider>().deleteNotification(notificationId);
  }

  void _showSettingsSheet(BuildContext context) {
    NotificationSettingsSheet.show(context);
  }
}