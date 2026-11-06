import 'package:flutter/material.dart';
import '../models/karma_models.dart';
import 'package:bybata/core/theme/app_theme.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Navigation routes for KARMA module
class KarmaRoutes {
  static const String karma = '/karma';
  static const String karmaProfile = '/karma/profile';
  static const String leaderboard = '/karma/leaderboard';
  static const String achievements = '/karma/achievements';
  static const String karmaHistory = '/karma/history';
  static const String trustLevel = '/karma/trust-level';
  static const String earnKarma = '/karma/earn';
  static const String achievementDetail = '/karma/achievement-detail';
  static const String karmaStats = '/karma/stats';
  static const String karmaSettings = '/karma/settings';
}

/// Navigation helper for KARMA module
class KarmaNavigator {
  /// Navigate to main KARMA screen
  static Future<void> toKarmaHome(BuildContext context) async {
    await GuardedNavigator.pushNamed(context, KarmaRoutes.karma);
  }

  /// Navigate to KARMA profile screen
  static Future<void> toKarmaProfile(BuildContext context) async {
    await GuardedNavigator.pushNamed(context, KarmaRoutes.karmaProfile);
  }

  /// Navigate to leaderboard screen
  static Future<void> toLeaderboard(BuildContext context) async {
    await GuardedNavigator.pushNamed(context, KarmaRoutes.leaderboard);
  }

  /// Navigate to achievements screen
  static Future<void> toAchievements(BuildContext context) async {
    await GuardedNavigator.pushNamed(context, KarmaRoutes.achievements);
  }

  /// Navigate to KARMA history screen
  static Future<void> toKarmaHistory(BuildContext context) async {
    await GuardedNavigator.pushNamed(context, KarmaRoutes.karmaHistory);
  }

  /// Navigate to trust level screen
  static Future<void> toTrustLevel(BuildContext context) async {
    await GuardedNavigator.pushNamed(context, KarmaRoutes.trustLevel);
  }

  /// Navigate to earn KARMA screen
  static Future<void> toEarnKarma(BuildContext context) async {
    await GuardedNavigator.pushNamed(context, KarmaRoutes.earnKarma);
  }

  /// Navigate to achievement detail screen
  static Future<void> toAchievementDetail(
    BuildContext context, {
    required Achievement achievement,
  }) async {
    await GuardedNavigator.pushNamed(
      context,
      KarmaRoutes.achievementDetail,
      arguments: achievement,
    );
  }

  /// Navigate to KARMA statistics screen
  static Future<void> toKarmaStats(BuildContext context) async {
    await GuardedNavigator.pushNamed(context, KarmaRoutes.karmaStats);
  }

  /// Navigate to KARMA settings screen
  static Future<void> toKarmaSettings(BuildContext context) async {
    await GuardedNavigator.pushNamed(context, KarmaRoutes.karmaSettings);
  }

  /// Navigate to KARMA screen and replace current screen
  static Future<void> toKarmaHomeAndReplace(BuildContext context) async {
    await GuardedNavigator.pushReplacementNamed(context, KarmaRoutes.karma);
  }

  /// Navigate to KARMA screen and clear navigation stack
  static Future<void> toKarmaHomeAndClearStack(BuildContext context) async {
    await GuardedNavigator.pushNamedAndRemoveUntil(
      context,
      KarmaRoutes.karma,
      (route) => false,
    );
  }

  /// Show KARMA activity bottom sheet
  static Future<KarmaActivity?> showKarmaActivitySelector(BuildContext context) {
    return showModalBottomSheet<KarmaActivity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _KarmaActivitySelector(),
    );
  }

  /// Show achievement unlocked dialog
  static Future<void> showAchievementUnlockedDialog(
    BuildContext context, {
    required Achievement achievement,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AchievementUnlockedDialog(achievement: achievement),
    );
  }

  /// Show level up celebration dialog
  static Future<void> showLevelUpDialog(
    BuildContext context, {
    required KarmaLevel oldLevel,
    required KarmaLevel newLevel,
    required int pointsEarned,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LevelUpDialog(
        oldLevel: oldLevel,
        newLevel: newLevel,
        pointsEarned: pointsEarned,
      ),
    );
  }

  /// Show KARMA transaction details bottom sheet
  static Future<void> showTransactionDetails(
    BuildContext context, {
    required KarmaTransaction transaction,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransactionDetailsSheet(transaction: transaction),
    );
  }

  /// Show trust level upgrade dialog
  static Future<bool?> showTrustLevelUpgradeDialog(
    BuildContext context, {
    required TrustLevel currentLevel,
    required TrustLevel targetLevel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => _TrustLevelUpgradeDialog(
        currentLevel: currentLevel,
        targetLevel: targetLevel,
      ),
    );
  }

  /// Show KARMA info dialog
  static Future<void> showKarmaInfoDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const _KarmaInfoDialog(),
    );
  }

  /// Pop current screen
  static void pop(BuildContext context, [dynamic result]) {
    Navigator.pop(context, result);
  }

  /// Pop until specific route
  static void popUntil(BuildContext context, String routeName) {
    Navigator.popUntil(context, ModalRoute.withName(routeName));
  }

  /// Check if can pop
  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }
}

/// KARMA activity selector bottom sheet
class _KarmaActivitySelector extends StatelessWidget {
  const _KarmaActivitySelector();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Select KARMA Activity',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Activity list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: KarmaActivity.values.length,
              itemBuilder: (context, index) {
                final activity = KarmaActivity.values[index];
                return ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: activity.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      activity.icon,
                      color: activity.color,
                    ),
                  ),
                  title: Text(activity.name),
                  subtitle: Text(activity.description),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+${activity.points}',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  onTap: () => Navigator.pop(context, activity),
                );
              },
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Achievement unlocked dialog
class _AchievementUnlockedDialog extends StatelessWidget {
  final Achievement achievement;
  
  const _AchievementUnlockedDialog({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: achievement.rarityColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  achievement.iconUrl,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Title
            Text(
              'Achievement Unlocked!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: achievement.rarityColor,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Achievement name
            Text(
              achievement.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Description
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Points reward
            if (achievement.pointsReward > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '+${achievement.pointsReward} KARMA',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: achievement.rarityColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Awesome!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Level up dialog
class _LevelUpDialog extends StatelessWidget {
  final KarmaLevel oldLevel;
  final KarmaLevel newLevel;
  final int pointsEarned;
  
  const _LevelUpDialog({
    required this.oldLevel,
    required this.newLevel,
    required this.pointsEarned,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Level up animation
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [newLevel.color.withValues(alpha: 0.2), newLevel.color.withValues(alpha: 0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  newLevel.emoji,
                  style: const TextStyle(fontSize: 50),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Congratulations
            Text(
              'Level Up!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: newLevel.color,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Level progression
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: Theme.of(context).textTheme.titleMedium,
                children: [
                  TextSpan(
                    text: oldLevel.name,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const TextSpan(text: ' → '),
                  TextSpan(
                    text: newLevel.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: newLevel.color,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Description
            Text(
              newLevel.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Bonus points
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.celebration, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Level Up Bonus: +$pointsEarned KARMA',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: newLevel.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transaction details bottom sheet
class _TransactionDetailsSheet extends StatelessWidget {
  final KarmaTransaction transaction;
  
  const _TransactionDetailsSheet({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: transaction.activity.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        transaction.activity.icon,
                        color: transaction.activity.color,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.activity.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '+${transaction.pointsEarned} KARMA',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Description
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Timestamp
                Text(
                  'Date & Time',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(transaction.timestamp),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Transaction ID
                Text(
                  'Transaction ID',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.id,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontFamily: 'monospace',
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Trust level upgrade dialog
class _TrustLevelUpgradeDialog extends StatelessWidget {
  final TrustLevel currentLevel;
  final TrustLevel targetLevel;
  
  const _TrustLevelUpgradeDialog({
    required this.currentLevel,
    required this.targetLevel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Upgrade Trust Level',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: targetLevel.color,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Are you ready to upgrade your trust level?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: currentLevel.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        currentLevel.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentLevel.name,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Icon(Icons.arrow_forward, color: Colors.grey.shade600),
              Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: targetLevel.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        targetLevel.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    targetLevel.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: targetLevel.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            targetLevel.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: targetLevel.color,
            foregroundColor: Colors.white,
          ),
          child: const Text('Upgrade'),
        ),
      ],
    );
  }
}

/// KARMA info dialog
class _KarmaInfoDialog extends StatelessWidget {
  const _KarmaInfoDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary),
          SizedBox(width: 8),
          Text('About KARMA'),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'KARMA is our community points system that rewards positive contributions and engagement.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'How to Earn KARMA:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('• Complete trades and transactions'),
            Text('• Help community members'),
            Text('• Create valuable posts and content'),
            Text('• Refer friends to the platform'),
            Text('• Verify your account'),
            Text('• Participate in community events'),
            SizedBox(height: 16),
            Text(
              'Benefits of KARMA:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('• Unlock exclusive features'),
            Text('• Increase trust level'),
            Text('• Access to premium content'),
            Text('• Recognition in community'),
            Text('• Better trading opportunities'),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it!'),
        ),
      ],
    );
  }
}