import 'package:flutter/material.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/theme/app_theme.dart';
import '../models/wallet_models.dart';
import '../services/wallet_service.dart';

class WalletNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  bool isRead;
  final Map<String, dynamic>? metadata;

  WalletNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.metadata,
  });
}

enum NotificationType {
  transaction,
  lowBalance,
  promotion,
  security,
  system,
}

class WalletNotificationsScreen extends StatefulWidget {
  const WalletNotificationsScreen({super.key});

  @override
  State<WalletNotificationsScreen> createState() => _WalletNotificationsScreenState();
}

class _WalletNotificationsScreenState extends State<WalletNotificationsScreen> {
  List<WalletNotification> _notifications = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, unread, transactions, promotions

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final wallet = WalletService();
      final userId = wallet.currentBalance?.userId;
      if (userId != null) {
        await wallet.initializeWallet(userId);
      }

      final txs = wallet.transactions;
      final items = <WalletNotification>[];
      for (final t in txs.take(50)) {
        items.add(WalletNotification(
          id: t.id,
          title: _titleForTx(t),
          message: t.description,
          timestamp: t.timestamp,
          type: t.type == TransactionType.promotion
              ? NotificationType.promotion
              : NotificationType.transaction,
          isRead: true,
          metadata: {
            'amount': t.amount,
            'type': t.type.name,
            'status': t.status.name,
          },
        ));
      }

      final bal = wallet.currentBalance?.availableBalance ?? 0;
      if (bal > 0 && bal < 10) {
        items.insert(
          0,
          WalletNotification(
            id: 'low_balance',
            title: 'Low Balance Alert',
            message: 'Your available balance is ${bal.toStringAsFixed(2)} BYC',
            timestamp: DateTime.now(),
            type: NotificationType.lowBalance,
            isRead: false,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifications = [];
        _isLoading = false;
      });
    }
  }

  String _titleForTx(WalletTransaction t) {
    switch (t.type) {
      case TransactionType.fund:
        return 'Wallet funded';
      case TransactionType.send:
        return 'BYC sent';
      case TransactionType.receive:
        return 'BYC received';
      case TransactionType.promotion:
        return 'Promotion';
      case TransactionType.refund:
        return 'Refund';
      default:
        return 'Wallet update';
    }
  }

  List<WalletNotification> get _filteredNotifications {
    switch (_filter) {
      case 'unread':
        return _notifications.where((n) => !n.isRead).toList();
      case 'transactions':
        return _notifications.where((n) => n.type == NotificationType.transaction).toList();
      case 'promotions':
        return _notifications.where((n) => n.type == NotificationType.promotion).toList();
      default:
        return _notifications;
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.transaction:
        return Icons.swap_horiz;
      case NotificationType.lowBalance:
        return Icons.warning;
      case NotificationType.promotion:
        return Icons.local_offer;
      case NotificationType.security:
        return Icons.security;
      case NotificationType.system:
        return Icons.info;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.transaction:
        return AppColors.primary;
      case NotificationType.lowBalance:
        return Colors.orange;
      case NotificationType.promotion:
        return Colors.purple;
      case NotificationType.security:
        return Colors.red;
      case NotificationType.system:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Notifications'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _filter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'unread', child: Text('Unread')),
              const PopupMenuItem(value: 'transactions', child: Text('Transactions')),
              const PopupMenuItem(value: 'promotions', child: Text('Promotions')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: _isLoading
          ? const BybataLoader()
          : _filteredNotifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredNotifications.length,
                    itemBuilder: (context, index) {
                      final notification = _filteredNotifications[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ShadowCard(
                          shadowIntensity: ShadowIntensity.light,
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getNotificationColor(notification.type)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getNotificationIcon(notification.type),
                                color: _getNotificationColor(notification.type),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(notification.message),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimestamp(notification.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            trailing: notification.isRead
                                ? null
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            onTap: () {
                              // Mark as read and show details
                              setState(() {
                                notification.isRead = true;
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

