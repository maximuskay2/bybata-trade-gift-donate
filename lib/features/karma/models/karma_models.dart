import 'package:flutter/material.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// Enumeration for KARMA levels based on points earned
enum KarmaLevel {
  newbie,      // 0-499 KARMA
  helper,      // 500-999 KARMA
  contributor, // 1000-2499 KARMA
  champion,    // 2500-4999 KARMA
  hero,        // 5000-9999 KARMA
  legend,      // 10000+ KARMA
}

/// Enumeration for user trust levels
enum TrustLevel {
  unverified, // New users
  basic,      // Email verified
  trusted,    // Phone + ID verified
  premium,    // High KARMA + verifications
  ambassador, // Top contributors
}

/// Enumeration for KARMA earning activities
enum KarmaActivity {
  completeTrade,      // +1 KARMA
  giveGift,          // +1 KARMA
  makeDonation,      // +1 KARMA
  helpCommunity,     // +20 KARMA
  createPost,        // +10 KARMA
  getVerified,       // +100 KARMA
  receiveReview,     // +25 KARMA
  mentorUser,        // +50 KARMA
  joinEvent,         // +15 KARMA
  shareContent,      // +5 KARMA
  reportIssue,       // +20 KARMA
  referFriend,       // +1 KARMA
}

/// Enumeration for achievement categories
enum AchievementCategory {
  trading,
  community,
  helping,
  verification,
  social,
  milestone,
  special,
}

/// Extensions for KARMA levels
extension KarmaLevelExtension on KarmaLevel {
  String get name {
    switch (this) {
      case KarmaLevel.newbie:
        return 'Newbie';
      case KarmaLevel.helper:
        return 'Helper';
      case KarmaLevel.contributor:
        return 'Contributor';
      case KarmaLevel.champion:
        return 'Champion';
      case KarmaLevel.hero:
        return 'Hero';
      case KarmaLevel.legend:
        return 'Legend';
    }
  }

  String get emoji {
    switch (this) {
      case KarmaLevel.newbie:
        return '🌱';
      case KarmaLevel.helper:
        return '🤝';
      case KarmaLevel.contributor:
        return '🌟';
      case KarmaLevel.champion:
        return '🏆';
      case KarmaLevel.hero:
        return '🦸';
      case KarmaLevel.legend:
        return '👑';
    }
  }

  String get description {
    switch (this) {
      case KarmaLevel.newbie:
        return 'New to the community - keep growing!';
      case KarmaLevel.helper:
        return 'Starting to help others in the community';
      case KarmaLevel.contributor:
        return 'Active contributor to the community';
      case KarmaLevel.champion:
        return 'Champion of community values';
      case KarmaLevel.hero:
        return 'Hero helping shape the community';
      case KarmaLevel.legend:
        return 'Legendary member of the community';
    }
  }

  int get minPoints {
    switch (this) {
      case KarmaLevel.newbie:
        return 0;
      case KarmaLevel.helper:
        return 500;
      case KarmaLevel.contributor:
        return 1000;
      case KarmaLevel.champion:
        return 2500;
      case KarmaLevel.hero:
        return 5000;
      case KarmaLevel.legend:
        return 10000;
    }
  }

  int get maxPoints {
    switch (this) {
      case KarmaLevel.newbie:
        return 499;
      case KarmaLevel.helper:
        return 999;
      case KarmaLevel.contributor:
        return 2499;
      case KarmaLevel.champion:
        return 4999;
      case KarmaLevel.hero:
        return 9999;
      case KarmaLevel.legend:
        return 999999; // No upper limit
    }
  }

  Color get color {
    switch (this) {
      case KarmaLevel.newbie:
        return Colors.green.shade300;
      case KarmaLevel.helper:
        return AppColors.primary;
      case KarmaLevel.contributor:
        return Colors.orange.shade400;
      case KarmaLevel.champion:
        return Colors.purple.shade500;
      case KarmaLevel.hero:
        return Colors.red.shade500;
      case KarmaLevel.legend:
        return Colors.amber.shade600;
    }
  }

  static KarmaLevel fromPoints(int points) {
    if (points >= 10000) return KarmaLevel.legend;
    if (points >= 5000) return KarmaLevel.hero;
    if (points >= 2500) return KarmaLevel.champion;
    if (points >= 1000) return KarmaLevel.contributor;
    if (points >= 500) return KarmaLevel.helper;
    return KarmaLevel.newbie;
  }
}

/// Extensions for Trust levels
extension TrustLevelExtension on TrustLevel {
  String get name {
    switch (this) {
      case TrustLevel.unverified:
        return 'Unverified';
      case TrustLevel.basic:
        return 'Basic';
      case TrustLevel.trusted:
        return 'Trusted';
      case TrustLevel.premium:
        return 'Premium';
      case TrustLevel.ambassador:
        return 'Ambassador';
    }
  }

  String get emoji {
    switch (this) {
      case TrustLevel.unverified:
        return '❓';
      case TrustLevel.basic:
        return '✉️';
      case TrustLevel.trusted:
        return '🛡️';
      case TrustLevel.premium:
        return '💎';
      case TrustLevel.ambassador:
        return '👨‍💼';
    }
  }

  String get description {
    switch (this) {
      case TrustLevel.unverified:
        return 'New user - verify your account to build trust';
      case TrustLevel.basic:
        return 'Email verified - add more verifications';
      case TrustLevel.trusted:
        return 'Phone and ID verified - trusted member';
      case TrustLevel.premium:
        return 'High KARMA with full verification';
      case TrustLevel.ambassador:
        return 'Top contributor and community leader';
    }
  }

  Color get color {
    switch (this) {
      case TrustLevel.unverified:
        return Colors.grey.shade400;
      case TrustLevel.basic:
        return AppColors.primary;
      case TrustLevel.trusted:
        return Colors.green.shade500;
      case TrustLevel.premium:
        return Colors.purple.shade500;
      case TrustLevel.ambassador:
        return Colors.amber.shade600;
    }
  }

  List<String> get requirements {
    switch (this) {
      case TrustLevel.unverified:
        return ['Create account'];
      case TrustLevel.basic:
        return ['Verify email address'];
      case TrustLevel.trusted:
        return ['Verify email', 'Verify phone number', 'Verify ID'];
      case TrustLevel.premium:
        return ['All verifications', '1000+ KARMA points', 'Active for 3+ months'];
      case TrustLevel.ambassador:
        return ['Premium status', '5000+ KARMA points', 'Community contributions'];
    }
  }
}

/// Extensions for KARMA activities
extension KarmaActivityExtension on KarmaActivity {
  String get name {
    switch (this) {
      case KarmaActivity.completeTrade:
        return 'Complete Trade';
      case KarmaActivity.giveGift:
        return 'Give Gift';
      case KarmaActivity.makeDonation:
        return 'Make Donation';
      case KarmaActivity.helpCommunity:
        return 'Help in Community';
      case KarmaActivity.createPost:
        return 'Create Post';
      case KarmaActivity.getVerified:
        return 'Account Verification';
      case KarmaActivity.receiveReview:
        return 'Positive Review';
      case KarmaActivity.mentorUser:
        return 'Mentor New User';
      case KarmaActivity.joinEvent:
        return 'Join Event';
      case KarmaActivity.shareContent:
        return 'Share Content';
      case KarmaActivity.reportIssue:
        return 'Report Issue';
      case KarmaActivity.referFriend:
        return 'Refer Friend';
    }
  }

  int get points {
    switch (this) {
      case KarmaActivity.completeTrade:
        return 1;
      case KarmaActivity.giveGift:
        return 1;
      case KarmaActivity.makeDonation:
        return 1;
      case KarmaActivity.helpCommunity:
        return 20;
      case KarmaActivity.createPost:
        return 10;
      case KarmaActivity.getVerified:
        return 100;
      case KarmaActivity.receiveReview:
        return 25;
      case KarmaActivity.mentorUser:
        return 50;
      case KarmaActivity.joinEvent:
        return 15;
      case KarmaActivity.shareContent:
        return 5;
      case KarmaActivity.reportIssue:
        return 20;
      case KarmaActivity.referFriend:
        return 1;
    }
  }

  String get description {
    switch (this) {
      case KarmaActivity.completeTrade:
        return 'Successfully complete a trade transaction';
      case KarmaActivity.giveGift:
        return 'Send a gift to another user';
      case KarmaActivity.makeDonation:
        return 'Make a donation to support the community';
      case KarmaActivity.helpCommunity:
        return 'Help other users in community forums';
      case KarmaActivity.createPost:
        return 'Create a helpful community post';
      case KarmaActivity.getVerified:
        return 'Complete account verification process';
      case KarmaActivity.receiveReview:
        return 'Receive positive review from other users';
      case KarmaActivity.mentorUser:
        return 'Help and mentor new community members';
      case KarmaActivity.joinEvent:
        return 'Participate in community events';
      case KarmaActivity.shareContent:
        return 'Share helpful content with community';
      case KarmaActivity.reportIssue:
        return 'Report issues to improve platform';
      case KarmaActivity.referFriend:
        return 'Refer friends to join the community';
    }
  }

  IconData get icon {
    switch (this) {
      case KarmaActivity.completeTrade:
        return Icons.handshake;
      case KarmaActivity.giveGift:
        return Icons.card_giftcard;
      case KarmaActivity.makeDonation:
        return Icons.volunteer_activism;
      case KarmaActivity.helpCommunity:
        return Icons.help_outline;
      case KarmaActivity.createPost:
        return Icons.post_add;
      case KarmaActivity.getVerified:
        return Icons.verified_user;
      case KarmaActivity.receiveReview:
        return Icons.star;
      case KarmaActivity.mentorUser:
        return Icons.school;
      case KarmaActivity.joinEvent:
        return Icons.event;
      case KarmaActivity.shareContent:
        return Icons.share;
      case KarmaActivity.reportIssue:
        return Icons.report;
      case KarmaActivity.referFriend:
        return Icons.person_add;
    }
  }

  Color get color {
    switch (this) {
      case KarmaActivity.completeTrade:
        return Colors.green;
      case KarmaActivity.giveGift:
        return Colors.pink;
      case KarmaActivity.makeDonation:
        return Colors.red;
      case KarmaActivity.helpCommunity:
        return AppColors.primary;
      case KarmaActivity.createPost:
        return Colors.orange;
      case KarmaActivity.getVerified:
        return Colors.purple;
      case KarmaActivity.receiveReview:
        return Colors.amber;
      case KarmaActivity.mentorUser:
        return AppColors.primaryDark;
      case KarmaActivity.joinEvent:
        return Colors.teal;
      case KarmaActivity.shareContent:
        return AppColors.primaryLight;
      case KarmaActivity.reportIssue:
        return Colors.brown;
      case KarmaActivity.referFriend:
        return Colors.deepOrange;
    }
  }
}

/// User KARMA profile model
class UserKarma {
  final String userId;
  final int totalPoints;
  final KarmaLevel level;
  final TrustLevel trustLevel;
  final DateTime lastUpdated;
  final List<KarmaTransaction> recentActivity;
  final Map<KarmaActivity, int> activityCounts;
  final List<Achievement> achievements;
  final KarmaStreak currentStreak;
  final KarmaStats stats;

  const UserKarma({
    required this.userId,
    required this.totalPoints,
    required this.level,
    required this.trustLevel,
    required this.lastUpdated,
    this.recentActivity = const [],
    this.activityCounts = const {},
    this.achievements = const [],
    required this.currentStreak,
    required this.stats,
  });

  factory UserKarma.fromJson(Map<String, dynamic> json) {
    return UserKarma(
      userId: json['userId'],
      totalPoints: json['totalPoints'] ?? 0,
          level: KarmaLevelExtension.fromPoints(json['totalPoints'] ?? 0),
      trustLevel: TrustLevel.values.firstWhere(
        (t) => t.name == json['trustLevel'],
        orElse: () => TrustLevel.unverified,
      ),
      lastUpdated: DateTime.parse(json['lastUpdated']),
      recentActivity: (json['recentActivity'] as List?)
          ?.map((a) => KarmaTransaction.fromJson(a))
          .toList() ?? [],
      activityCounts: Map<KarmaActivity, int>.from(
        (json['activityCounts'] as Map?)?.map(
          (key, value) => MapEntry(
            KarmaActivity.values.firstWhere((a) => a.name == key),
            value,
          ),
        ) ?? {},
      ),
      achievements: (json['achievements'] as List?)
          ?.map((a) => Achievement.fromJson(a))
          .toList() ?? [],
      currentStreak: KarmaStreak.fromJson(json['currentStreak'] ?? {}),
      stats: KarmaStats.fromJson(json['stats'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'totalPoints': totalPoints,
    'level': level.name,
    'trustLevel': trustLevel.name,
    'lastUpdated': lastUpdated.toIso8601String(),
    'recentActivity': recentActivity.map((a) => a.toJson()).toList(),
    'activityCounts': activityCounts.map(
      (key, value) => MapEntry(key.name, value),
    ),
    'achievements': achievements.map((a) => a.toJson()).toList(),
    'currentStreak': currentStreak.toJson(),
    'stats': stats.toJson(),
  };

  // Helper getters
  int get pointsToNextLevel {
    if (level == KarmaLevel.legend) return 0;
    final nextLevel = KarmaLevel.values[level.index + 1];
    return nextLevel.minPoints - totalPoints;
  }

  double get progressToNextLevel {
    if (level == KarmaLevel.legend) return 1.0;
    final currentMin = level.minPoints;
    final nextLevel = KarmaLevel.values[level.index + 1];
    final nextMin = nextLevel.minPoints;
    return (totalPoints - currentMin) / (nextMin - currentMin);
  }

  int get rank => stats.globalRank;
  
  bool get canUpgradeToTrusted {
    return trustLevel == TrustLevel.basic && totalPoints >= 100;
  }

  bool get canUpgradeToPremium {
    return trustLevel == TrustLevel.trusted && totalPoints >= 1000;
  }

  bool get canUpgradeToAmbassador {
    return trustLevel == TrustLevel.premium && totalPoints >= 5000;
  }
}

/// Individual KARMA transaction/activity record
class KarmaTransaction {
  final String id;
  final String userId;
  final KarmaActivity activity;
  final int pointsEarned;
  final DateTime timestamp;
  final String description;
  final Map<String, dynamic> metadata;
  final String? relatedId; // ID of related trade, post, etc.

  const KarmaTransaction({
    required this.id,
    required this.userId,
    required this.activity,
    required this.pointsEarned,
    required this.timestamp,
    required this.description,
    this.metadata = const {},
    this.relatedId,
  });

  factory KarmaTransaction.fromJson(Map<String, dynamic> json) {
    return KarmaTransaction(
      id: json['id'],
      userId: json['userId'],
      activity: KarmaActivity.values.firstWhere(
        (a) => a.name == json['activity'],
      ),
      pointsEarned: json['pointsEarned'],
      timestamp: DateTime.parse(json['timestamp']),
      description: json['description'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      relatedId: json['relatedId'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'activity': activity.name,
    'pointsEarned': pointsEarned,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'metadata': metadata,
    'relatedId': relatedId,
  };
}

/// Achievement model for gamification
class Achievement {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final AchievementCategory category;
  final int requiredValue;
  final String requiredActivity;
  final DateTime? unlockedAt;
  final bool isUnlocked;
  final int pointsReward;
  final String rarity; // Common, Rare, Epic, Legendary

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.category,
    required this.requiredValue,
    required this.requiredActivity,
    this.unlockedAt,
    required this.isUnlocked,
    required this.pointsReward,
    required this.rarity,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconUrl: json['iconUrl'],
      category: AchievementCategory.values.firstWhere(
        (c) => c.name == json['category'],
      ),
      requiredValue: json['requiredValue'],
      requiredActivity: json['requiredActivity'],
      unlockedAt: json['unlockedAt'] != null 
        ? DateTime.parse(json['unlockedAt'])
        : null,
      isUnlocked: json['isUnlocked'] ?? false,
      pointsReward: json['pointsReward'],
      rarity: json['rarity'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'iconUrl': iconUrl,
    'category': category.name,
    'requiredValue': requiredValue,
    'requiredActivity': requiredActivity,
    'unlockedAt': unlockedAt?.toIso8601String(),
    'isUnlocked': isUnlocked,
    'pointsReward': pointsReward,
    'rarity': rarity,
  };

  Color get rarityColor {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey;
      case 'rare':
        return AppColors.primary;
      case 'epic':
        return Colors.purple;
      case 'legendary':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}

/// KARMA streak tracking
class KarmaStreak {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;
  final List<DateTime> activeDays;

  const KarmaStreak({
    required this.currentStreak,
    required this.longestStreak,
    this.lastActivityDate,
    this.activeDays = const [],
  });

  factory KarmaStreak.fromJson(Map<String, dynamic> json) {
    return KarmaStreak(
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      lastActivityDate: json['lastActivityDate'] != null
        ? DateTime.parse(json['lastActivityDate'])
        : null,
      activeDays: (json['activeDays'] as List?)
          ?.map((d) => DateTime.parse(d))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastActivityDate': lastActivityDate?.toIso8601String(),
    'activeDays': activeDays.map((d) => d.toIso8601String()).toList(),
  };
}

/// KARMA statistics and analytics
class KarmaStats {
  final int totalTransactions;
  final int thisWeekPoints;
  final int thisMonthPoints;
  final int globalRank;
  final int countryRank;
  final Map<KarmaActivity, int> topActivities;
  final Map<String, int> monthlyProgress; // month -> points

  const KarmaStats({
    required this.totalTransactions,
    required this.thisWeekPoints,
    required this.thisMonthPoints,
    required this.globalRank,
    required this.countryRank,
    this.topActivities = const {},
    this.monthlyProgress = const {},
  });

  factory KarmaStats.fromJson(Map<String, dynamic> json) {
    return KarmaStats(
      totalTransactions: json['totalTransactions'] ?? 0,
      thisWeekPoints: json['thisWeekPoints'] ?? 0,
      thisMonthPoints: json['thisMonthPoints'] ?? 0,
      globalRank: json['globalRank'] ?? 999999,
      countryRank: json['countryRank'] ?? 999999,
      topActivities: Map<KarmaActivity, int>.from(
        (json['topActivities'] as Map?)?.map(
          (key, value) => MapEntry(
            KarmaActivity.values.firstWhere((a) => a.name == key),
            value,
          ),
        ) ?? {},
      ),
      monthlyProgress: Map<String, int>.from(json['monthlyProgress'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'totalTransactions': totalTransactions,
    'thisWeekPoints': thisWeekPoints,
    'thisMonthPoints': thisMonthPoints,
    'globalRank': globalRank,
    'countryRank': countryRank,
    'topActivities': topActivities.map(
      (key, value) => MapEntry(key.name, value),
    ),
    'monthlyProgress': monthlyProgress,
  };
}

/// Leaderboard entry model
class LeaderboardEntry {
  final String userId;
  final String userName;
  final String? userAvatar;
  final int totalPoints;
  final KarmaLevel level;
  final TrustLevel trustLevel;
  final int rank;
  final int thisWeekPoints;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.totalPoints,
    required this.level,
    required this.trustLevel,
    required this.rank,
    required this.thisWeekPoints,
    required this.isCurrentUser,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['userId'],
      userName: json['userName'],
      userAvatar: json['userAvatar'],
      totalPoints: json['totalPoints'],
          level: KarmaLevelExtension.fromPoints(json['totalPoints']),
      trustLevel: TrustLevel.values.firstWhere(
        (t) => t.name == json['trustLevel'],
        orElse: () => TrustLevel.unverified,
      ),
      rank: json['rank'],
      thisWeekPoints: json['thisWeekPoints'] ?? 0,
      isCurrentUser: json['isCurrentUser'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userName': userName,
    'userAvatar': userAvatar,
    'totalPoints': totalPoints,
    'level': level.name,
    'trustLevel': trustLevel.name,
    'rank': rank,
    'thisWeekPoints': thisWeekPoints,
    'isCurrentUser': isCurrentUser,
  };
}