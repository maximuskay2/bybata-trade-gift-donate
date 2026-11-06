import 'package:flutter/material.dart';
import '../providers/karma_provider.dart';

/// Service for managing KARMA-based feature unlocking
class KarmaFeatureService {
  static const Map<String, int> _featureRequirements = {
    // Basic features (available to everyone)
    'basic_trade': 0,
    'basic_gift': 0,
    'basic_community': 0,
    
    // Level 2 features
    'premium_trade_filters': 100,
    'gift_scheduling': 150,
    'community_creation': 200,
    
    // Level 3 features
    'bulk_trading': 250,
    'gift_templates': 300,
    'community_moderation': 400,
    
    // Level 4 features
    'advanced_analytics': 500,
    'priority_support': 600,
    'custom_themes': 750,
    
    // Level 5+ features
    'api_access': 1000,
    'white_label': 2000,
    'enterprise_features': 3500,
    'beta_access': 5000,
  };

  static const Map<String, FeatureInfo> _featureInfo = {
    'premium_trade_filters': FeatureInfo(
      name: 'Premium Trade Filters',
      description: 'Advanced filtering options for finding trades',
      icon: Icons.filter_list,
      category: FeatureCategory.trading,
    ),
    'gift_scheduling': FeatureInfo(
      name: 'Gift Scheduling',
      description: 'Schedule gifts to be sent automatically',
      icon: Icons.schedule,
      category: FeatureCategory.gifting,
    ),
    'community_creation': FeatureInfo(
      name: 'Community Creation',
      description: 'Create and manage your own communities',
      icon: Icons.group_add,
      category: FeatureCategory.community,
    ),
    'bulk_trading': FeatureInfo(
      name: 'Bulk Trading',
      description: 'Trade multiple items at once',
      icon: Icons.inventory,
      category: FeatureCategory.trading,
    ),
    'gift_templates': FeatureInfo(
      name: 'Gift Templates',
      description: 'Create reusable gift templates',
      icon: Icons.save,
      category: FeatureCategory.gifting,
    ),
    'community_moderation': FeatureInfo(
      name: 'Community Moderation',
      description: 'Advanced moderation tools for communities',
      icon: Icons.shield,
      category: FeatureCategory.community,
    ),
    'advanced_analytics': FeatureInfo(
      name: 'Advanced Analytics',
      description: 'Detailed insights and analytics',
      icon: Icons.analytics,
      category: FeatureCategory.analytics,
    ),
    'priority_support': FeatureInfo(
      name: 'Priority Support',
      description: '24/7 priority customer support',
      icon: Icons.support_agent,
      category: FeatureCategory.support,
    ),
    'custom_themes': FeatureInfo(
      name: 'Custom Themes',
      description: 'Personalize your app appearance',
      icon: Icons.palette,
      category: FeatureCategory.personalization,
    ),
    'api_access': FeatureInfo(
      name: 'API Access',
      description: 'Access to developer APIs',
      icon: Icons.api,
      category: FeatureCategory.developer,
    ),
    'white_label': FeatureInfo(
      name: 'White Label',
      description: 'Rebrand the app with your own branding',
      icon: Icons.branding_watermark,
      category: FeatureCategory.enterprise,
    ),
    'enterprise_features': FeatureInfo(
      name: 'Enterprise Features',
      description: 'Advanced features for enterprise users',
      icon: Icons.business,
      category: FeatureCategory.enterprise,
    ),
    'beta_access': FeatureInfo(
      name: 'Beta Access',
      description: 'Early access to new features',
      icon: Icons.science,
      category: FeatureCategory.special,
    ),
  };

  /// Check if a feature is unlocked for the current user
  static bool isFeatureUnlocked(String featureId, int userKarma) {
    final requiredKarma = _featureRequirements[featureId];
    if (requiredKarma == null) return false;
    return userKarma >= requiredKarma;
  }

  /// Get required KARMA points for a feature
  static int getRequiredKarma(String featureId) {
    return _featureRequirements[featureId] ?? 999999;
  }

  /// Get feature information
  static FeatureInfo? getFeatureInfo(String featureId) {
    return _featureInfo[featureId];
  }

  /// Get all available features for current KARMA level
  static List<String> getUnlockedFeatures(int userKarma) {
    return _featureRequirements.entries
        .where((entry) => userKarma >= entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get next features to unlock
  static List<UpcomingFeature> getUpcomingFeatures(int userKarma, {int limit = 3}) {
    final upcoming = <UpcomingFeature>[];
    
    for (final entry in _featureRequirements.entries) {
      if (userKarma < entry.value) {
        final featureInfo = _featureInfo[entry.key];
        if (featureInfo != null) {
          upcoming.add(UpcomingFeature(
            id: entry.key,
            info: featureInfo,
            requiredKarma: entry.value,
            karmaNeeded: entry.value - userKarma,
          ));
        }
      }
    }

    // Sort by required KARMA and return limited results
    upcoming.sort((a, b) => a.requiredKarma.compareTo(b.requiredKarma));
    return upcoming.take(limit).toList();
  }

  /// Get features by category
  static List<String> getFeaturesByCategory(FeatureCategory category) {
    return _featureInfo.entries
        .where((entry) => entry.value.category == category)
        .map((entry) => entry.key)
        .toList();
  }

  /// Show feature unlock dialog
  static void showFeatureUnlockDialog(
    BuildContext context,
    String featureId,
    int userKarma,
  ) {
    final featureInfo = getFeatureInfo(featureId);
    final requiredKarma = getRequiredKarma(featureId);
    final isUnlocked = isFeatureUnlocked(featureId, userKarma);
    
    if (featureInfo == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(featureInfo.icon, color: isUnlocked ? Colors.green : Colors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text(featureInfo.name)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(featureInfo.description),
            const SizedBox(height: 16),
            if (isUnlocked) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Feature Unlocked!',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Requires $requiredKarma KARMA',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You need ${requiredKarma - userKarma} more KARMA points',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (!isUnlocked)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to earn KARMA screen or show tips
                _showEarnKarmaTips(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
              ),
              child: const Text('Earn KARMA'),
            ),
        ],
      ),
    );
  }

  /// Show tips for earning KARMA
  static void _showEarnKarmaTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Earn KARMA'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KarmaTip(
              icon: Icons.swap_horiz,
              title: 'Complete Trades',
              description: 'Earn 25-100 KARMA per successful trade',
              points: '25-100',
            ),
            _KarmaTip(
              icon: Icons.card_giftcard,
              title: 'Send & Receive Gifts',
              description: 'Get 30 KARMA for each gift transaction',
              points: '30',
            ),
            _KarmaTip(
              icon: Icons.favorite,
              title: 'Make Donations',
              description: 'Earn 75 KARMA for supporting campaigns',
              points: '75',
            ),
            _KarmaTip(
              icon: Icons.article,
              title: 'Community Posts',
              description: 'Share valuable content in communities',
              points: '50',
            ),
            _KarmaTip(
              icon: Icons.login,
              title: 'Daily Login',
              description: 'Get 10 KARMA for logging in daily',
              points: '10',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

/// Feature information class
class FeatureInfo {
  final String name;
  final String description;
  final IconData icon;
  final FeatureCategory category;

  const FeatureInfo({
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
  });
}

/// Upcoming feature class
class UpcomingFeature {
  final String id;
  final FeatureInfo info;
  final int requiredKarma;
  final int karmaNeeded;

  const UpcomingFeature({
    required this.id,
    required this.info,
    required this.requiredKarma,
    required this.karmaNeeded,
  });
}

/// Feature categories
enum FeatureCategory {
  trading,
  gifting,
  community,
  analytics,
  support,
  personalization,
  developer,
  enterprise,
  special,
}

/// KARMA tip widget for the tips dialog
class _KarmaTip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String points;

  const _KarmaTip({
    required this.icon,
    required this.title,
    required this.description,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.amber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$points',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}