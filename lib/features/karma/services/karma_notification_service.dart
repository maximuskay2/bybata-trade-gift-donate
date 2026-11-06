import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/karma_provider.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// Service for managing KARMA notifications and achievement alerts
class KarmaNotificationService {
  static final KarmaNotificationService _instance = KarmaNotificationService._internal();
  factory KarmaNotificationService() => _instance;
  KarmaNotificationService._internal();

  final List<KarmaNotification> _notifications = [];
  final List<Function(KarmaNotification)> _listeners = [];

  /// Add a notification listener
  void addListener(Function(KarmaNotification) listener) {
    _listeners.add(listener);
  }

  /// Remove a notification listener
  void removeListener(Function(KarmaNotification) listener) {
    _listeners.remove(listener);
  }

  /// Show KARMA gain notification
  void showKarmaGainNotification({
    required BuildContext context,
    required int points,
    required String reason,
    String? achievementUnlocked,
    bool showInApp = true,
    bool playSound = true,
  }) {
    final notification = KarmaNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: KarmaNotificationType.karmaGain,
      title: '+$points KARMA',
      message: reason,
      points: points,
      achievementName: achievementUnlocked,
      timestamp: DateTime.now(),
    );

    _addNotification(notification);

    if (showInApp) {
      _showInAppNotification(context, notification);
    }

    if (playSound) {
      _playNotificationSound();
    }
  }

  /// Show level up notification
  void showLevelUpNotification({
    required BuildContext context,
    required int newLevel,
    List<String>? unlockedFeatures,
    bool showInApp = true,
    bool playSound = true,
  }) {
    final notification = KarmaNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: KarmaNotificationType.levelUp,
      title: 'Level Up!',
      message: 'Congratulations! You reached Level $newLevel',
      newLevel: newLevel,
      unlockedFeatures: unlockedFeatures ?? [],
      timestamp: DateTime.now(),
    );

    _addNotification(notification);

    if (showInApp) {
      _showLevelUpDialog(context, notification);
    }

    if (playSound) {
      _playLevelUpSound();
    }
  }

  /// Show achievement unlocked notification
  void showAchievementNotification({
    required BuildContext context,
    required String achievementName,
    required String description,
    required int pointsReward,
    String? iconUrl,
    bool showInApp = true,
    bool playSound = true,
  }) {
    final notification = KarmaNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: KarmaNotificationType.achievement,
      title: 'Achievement Unlocked!',
      message: description,
      achievementName: achievementName,
      points: pointsReward,
      iconUrl: iconUrl,
      timestamp: DateTime.now(),
    );

    _addNotification(notification);

    if (showInApp) {
      _showAchievementDialog(context, notification);
    }

    if (playSound) {
      _playAchievementSound();
    }
  }

  /// Show milestone notification
  void showMilestoneNotification({
    required BuildContext context,
    required int totalKarma,
    required String milestoneName,
    String? specialReward,
    bool showInApp = true,
    bool playSound = true,
  }) {
    final notification = KarmaNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: KarmaNotificationType.milestone,
      title: 'Milestone Reached!',
      message: milestoneName,
      points: totalKarma,
      specialReward: specialReward,
      timestamp: DateTime.now(),
    );

    _addNotification(notification);

    if (showInApp) {
      _showMilestoneDialog(context, notification);
    }

    if (playSound) {
      _playMilestoneSound();
    }
  }

  /// Add notification to internal list
  void _addNotification(KarmaNotification notification) {
    _notifications.insert(0, notification);
    
    // Keep only last 50 notifications
    if (_notifications.length > 50) {
      _notifications.removeRange(50, _notifications.length);
    }

    // Notify listeners
    for (final listener in _listeners) {
      listener(notification);
    }
  }

  /// Show in-app notification overlay
  void _showInAppNotification(BuildContext context, KarmaNotification notification) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _KarmaNotificationOverlay(
        notification: notification,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  /// Show level up dialog
  void _showLevelUpDialog(BuildContext context, KarmaNotification notification) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LevelUpDialog(notification: notification),
    );
  }

  /// Show achievement dialog
  void _showAchievementDialog(BuildContext context, KarmaNotification notification) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AchievementDialog(notification: notification),
    );
  }

  /// Show milestone dialog
  void _showMilestoneDialog(BuildContext context, KarmaNotification notification) {
    showDialog(
      context: context,
      builder: (context) => _MilestoneDialog(notification: notification),
    );
  }

  /// Play notification sound
  void _playNotificationSound() {
    SystemSound.play(SystemSoundType.click);
  }

  /// Play level up sound
  void _playLevelUpSound() {
    SystemSound.play(SystemSoundType.alert);
  }

  /// Play achievement sound
  void _playAchievementSound() {
    SystemSound.play(SystemSoundType.alert);
  }

  /// Play milestone sound
  void _playMilestoneSound() {
    SystemSound.play(SystemSoundType.alert);
  }

  /// Get all notifications
  List<KarmaNotification> getNotifications() => List.from(_notifications);

  /// Clear all notifications
  void clearAllNotifications() {
    _notifications.clear();
  }

  /// Clear specific notification
  void clearNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
  }
}

/// KARMA notification model
class KarmaNotification {
  final String id;
  final KarmaNotificationType type;
  final String title;
  final String message;
  final int? points;
  final int? newLevel;
  final String? achievementName;
  final String? iconUrl;
  final String? specialReward;
  final List<String>? unlockedFeatures;
  final DateTime timestamp;

  const KarmaNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.points,
    this.newLevel,
    this.achievementName,
    this.iconUrl,
    this.specialReward,
    this.unlockedFeatures,
    required this.timestamp,
  });
}

/// KARMA notification types
enum KarmaNotificationType {
  karmaGain,
  levelUp,
  achievement,
  milestone,
}

/// In-app notification overlay widget
class _KarmaNotificationOverlay extends StatefulWidget {
  final KarmaNotification notification;
  final VoidCallback onDismiss;

  const _KarmaNotificationOverlay({
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<_KarmaNotificationOverlay> createState() => _KarmaNotificationOverlayState();
}

class _KarmaNotificationOverlayState extends State<_KarmaNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: ShadowCard(
              shadowIntensity: ShadowIntensity.medium,
              gradient: const LinearGradient(
                colors: [Colors.amber, Colors.orange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        _getNotificationIcon(widget.notification.type),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.notification.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.notification.message,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(KarmaNotificationType type) {
    switch (type) {
      case KarmaNotificationType.karmaGain:
        return Icons.star;
      case KarmaNotificationType.levelUp:
        return Icons.trending_up;
      case KarmaNotificationType.achievement:
        return Icons.emoji_events;
      case KarmaNotificationType.milestone:
        return Icons.flag;
    }
  }
}

/// Level up dialog widget
class _LevelUpDialog extends StatelessWidget {
  final KarmaNotification notification;

  const _LevelUpDialog({required this.notification});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                notification.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notification.message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              if (notification.unlockedFeatures?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                const Text(
                  'New Features Unlocked:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...notification.unlockedFeatures!.map((feature) => Text(
                      '• $feature',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.purple,
          ),
          child: const Text('Awesome!'),
        ),
      ],
    );
  }
}

/// Achievement dialog widget
class _AchievementDialog extends StatelessWidget {
  final KarmaNotification notification;

  const _AchievementDialog({required this.notification});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber, Colors.orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                notification.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (notification.achievementName != null)
                Text(
                  notification.achievementName!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              Text(
                notification.message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (notification.points != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '+${notification.points} KARMA',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.orange,
          ),
          child: const Text('Great!'),
        ),
      ],
    );
  }
}

/// Milestone dialog widget
class _MilestoneDialog extends StatelessWidget {
  final KarmaNotification notification;

  const _MilestoneDialog({required this.notification});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green, Colors.teal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.flag,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                notification.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notification.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (notification.points != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Total KARMA: ${notification.points}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
              if (notification.specialReward != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Special Reward:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.specialReward!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.green,
          ),
          child: const Text('Celebrate!'),
        ),
      ],
    );
  }
}