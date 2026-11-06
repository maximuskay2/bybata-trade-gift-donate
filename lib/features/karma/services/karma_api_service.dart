import '../../../core/api/api_client.dart';
import '../../../core/karma/karma_points_config.dart';

/// API service for karma-related backend operations
class KarmaApiService {
  final ApiClient _apiClient;

  KarmaApiService(this._apiClient);

  /// Get current user's karma account
  Future<KarmaAccount> getMyKarma() async {
    try {
      final raw = await getMyKarmaRaw();
      return KarmaAccount.fromJson(raw);
    } catch (e) {
      throw Exception('Failed to fetch karma account: $e');
    }
  }

  /// Full `/v1/karma/me` payload including membership enrichment.
  Future<Map<String, dynamic>> getMyKarmaRaw() async {
    try {
      final response = await _apiClient.get('/v1/karma/me');
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw Exception('Failed to fetch karma account: $e');
    }
  }

  /// Live earn guide with completion state from the backend.
  Future<KarmaEarnGuide> getEarnGuide() async {
    try {
      final response = await _apiClient.get('/v1/karma/earn-guide');
      return KarmaEarnGuide.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception('Failed to fetch earn guide: $e');
    }
  }

  /// Get karma history with pagination
  Future<KarmaHistory> getKarmaHistory({int page = 1, int limit = 20}) async {
    try {
      final response = await _apiClient.get(
        '/v1/karma/history',
        queryParameters: {'page': page, 'limit': limit},
      );
      return KarmaHistory.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch karma history: $e');
    }
  }

  /// Get karma leaderboard
  Future<KarmaLeaderboard> getLeaderboard({int page = 1, int limit = 50}) async {
    try {
      final response = await _apiClient.get(
        '/v1/karma/leaderboard',
        queryParameters: {'page': page, 'limit': limit},
      );
      return KarmaLeaderboard.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch leaderboard: $e');
    }
  }

  /// Get user achievements (unlocked and locked)
  Future<UserAchievements> getUserAchievements() async {
    try {
      final response = await _apiClient.get('/v1/karma/achievements');
      return UserAchievements.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch achievements: $e');
    }
  }

  /// Get all available achievements
  Future<List<KarmaAchievement>> getAllAchievements() async {
    try {
      final response = await _apiClient.get('/v1/karma/achievements/all');
      return (response.data as List)
          .map((json) => KarmaAchievement.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch all achievements: $e');
    }
  }

  /// Claim an achievement
  Future<void> claimAchievement(String achievementId) async {
    try {
      await _apiClient.post('/v1/karma/achievements/$achievementId/claim');
    } catch (e) {
      throw Exception('Failed to claim achievement: $e');
    }
  }

  /// Earn karma from a suggested action
  /// actionType: Type of action (e.g., 'SHARE_CONTENT', 'CREATE_POST', 'DAILY_LOGIN', etc.)
  /// metadata: Additional data about the action (optional)
  Future<EarnActionResponse> earnFromAction(
    String actionType, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _apiClient.post(
        '/v1/karma/actions/earn',
        queryParameters: {'actionType': actionType},
        data: metadata ?? {},
      );
      return EarnActionResponse.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to earn karma from action: $e');
    }
  }

  /// Get karma withdrawal settings (min threshold, conversion rate)
  Future<KarmaWithdrawSettings> getWithdrawSettings() async {
    try {
      final response = await _apiClient.get('/v1/karma/withdraw-settings');
      return KarmaWithdrawSettings.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch withdraw settings: $e');
    }
  }

  /// Active karma earn amounts from admin settings.
  Future<KarmaPointsConfigResponse> getPointsConfig() async {
    try {
      final response = await _apiClient.get('/v1/karma/points-config');
      return KarmaPointsConfigResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception('Failed to fetch karma points config: $e');
    }
  }

  /// Withdraw karma points to main wallet
  Future<KarmaWithdrawResult> withdrawToWallet(int karmaPoints) async {
    try {
      final response = await _apiClient.post(
        '/v1/karma/withdraw',
        data: {'karmaPoints': karmaPoints},
      );
      return KarmaWithdrawResult.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to withdraw karma: $e');
    }
  }
}

/// Karma withdrawal settings
class KarmaWithdrawSettings {
  final int minThreshold;
  final double karmaToBycRate;

  KarmaWithdrawSettings({
    required this.minThreshold,
    required this.karmaToBycRate,
  });

  factory KarmaWithdrawSettings.fromJson(Map<String, dynamic> json) {
    return KarmaWithdrawSettings(
      minThreshold: (json['minThreshold'] as num?)?.toInt() ?? 500,
      karmaToBycRate: (json['karmaToBycRate'] as num?)?.toDouble() ?? 100,
    );
  }

  double karmaToByc(int karma) => karma / karmaToBycRate;
}

class KarmaPointsConfigResponse {
  final KarmaPointsConfig points;
  final KarmaWithdrawSettings withdraw;

  KarmaPointsConfigResponse({
    required this.points,
    required this.withdraw,
  });

  factory KarmaPointsConfigResponse.fromJson(Map<String, dynamic> json) {
    return KarmaPointsConfigResponse(
      points: KarmaPointsConfig.fromJson(
        Map<String, dynamic>.from(json['points'] as Map? ?? {}),
      ),
      withdraw: KarmaWithdrawSettings.fromJson(
        Map<String, dynamic>.from(json['withdraw'] as Map? ?? {}),
      ),
    );
  }
}

/// Karma withdrawal result
class KarmaWithdrawResult {
  final bool ok;
  final double bycAmount;
  final String? message;

  KarmaWithdrawResult({
    required this.ok,
    required this.bycAmount,
    this.message,
  });

  factory KarmaWithdrawResult.fromJson(Map<String, dynamic> json) {
    return KarmaWithdrawResult(
      ok: json['ok'] == true,
      bycAmount: (json['bycAmount'] as num?)?.toDouble() ?? 0,
      message: json['message'] as String?,
    );
  }
}

/// Karma account model for API responses
class KarmaAccount {
  final String id;
  final String userId;
  final int currentPoints;
  final int totalPointsEarned;
  final int level;
  final String trustLevel;
  final int streak;
  final DateTime? lastActivityAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  KarmaAccount({
    required this.id,
    required this.userId,
    required this.currentPoints,
    required this.totalPointsEarned,
    required this.level,
    required this.trustLevel,
    required this.streak,
    this.lastActivityAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KarmaAccount.fromJson(Map<String, dynamic> json) {
    return KarmaAccount(
      id: json['id'],
      userId: json['userId'],
      currentPoints: json['currentPoints'],
      totalPointsEarned: json['totalPointsEarned'],
      level: json['level'],
      trustLevel: json['trustLevel'],
      streak: json['streak'],
      lastActivityAt: json['lastActivityAt'] != null 
          ? DateTime.parse(json['lastActivityAt']) 
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

/// Karma history response model
class KarmaHistory {
  final List<KarmaEvent> events;
  final Pagination pagination;

  KarmaHistory({required this.events, required this.pagination});

  factory KarmaHistory.fromJson(Map<String, dynamic> json) {
    return KarmaHistory(
      events: (json['events'] as List)
          .map((e) => KarmaEvent.fromJson(e))
          .toList(),
      pagination: Pagination.fromJson(json['pagination']),
    );
  }
}

/// Karma event model
class KarmaEvent {
  final String id;
  final String userId;
  final String type;
  final int points;
  final String? reason;
  final Map<String, dynamic>? metadata;
  final String? sourceId;
  final String? sourceType;
  final DateTime createdAt;

  KarmaEvent({
    required this.id,
    required this.userId,
    required this.type,
    required this.points,
    this.reason,
    this.metadata,
    this.sourceId,
    this.sourceType,
    required this.createdAt,
  });

  factory KarmaEvent.fromJson(Map<String, dynamic> json) {
    return KarmaEvent(
      id: json['id'],
      userId: json['userId'],
      type: json['type'],
      points: json['points'],
      reason: json['reason'],
      metadata: json['metadata'],
      sourceId: json['sourceId'],
      sourceType: json['sourceType'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

/// Karma leaderboard response model
class KarmaLeaderboard {
  final List<ApiLeaderboardEntry> leaderboard;
  final Pagination pagination;

  KarmaLeaderboard({required this.leaderboard, required this.pagination});

  factory KarmaLeaderboard.fromJson(Map<String, dynamic> json) {
    return KarmaLeaderboard(
      leaderboard: (json['leaderboard'] as List)
          .map((e) => ApiLeaderboardEntry.fromJson(e))
          .toList(),
      pagination: Pagination.fromJson(json['pagination']),
    );
  }
}

/// API Leaderboard entry model
class ApiLeaderboardEntry {
  final int rank;
  final String userId;
  final String displayName;
  final String? avatarKey;
  final int points;
  final int level;
  final String trustLevel;

  ApiLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    this.avatarKey,
    required this.points,
    required this.level,
    required this.trustLevel,
  });

  factory ApiLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return ApiLeaderboardEntry(
      rank: json['rank'],
      userId: json['userId'],
      displayName: json['displayName'],
      avatarKey: json['avatarKey'],
      points: json['points'],
      level: json['level'],
      trustLevel: json['trustLevel'],
    );
  }
}

/// User achievements response model
class UserAchievements {
  final List<KarmaAchievement> unlocked;
  final List<KarmaAchievement> locked;
  final int total;
  final int unlockedCount;

  UserAchievements({
    required this.unlocked,
    required this.locked,
    required this.total,
    required this.unlockedCount,
  });

  factory UserAchievements.fromJson(Map<String, dynamic> json) {
    return UserAchievements(
      unlocked: (json['unlocked'] as List)
          .map((e) => KarmaAchievement.fromJson(e))
          .toList(),
      locked: (json['locked'] as List)
          .map((e) => KarmaAchievement.fromJson(e))
          .toList(),
      total: json['total'],
      unlockedCount: json['unlockedCount'],
    );
  }
}

/// Karma achievement model
class KarmaAchievement {
  final String id;
  final String slug;
  final String name;
  final String description;
  final String? iconUrl;
  final String category;
  final int? pointsRequired;
  final int pointsReward;
  final String rarity;
  final bool isActive;
  final Map<String, dynamic>? unlockCriteria;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? unlockedAt;
  final DateTime? claimedAt;

  KarmaAchievement({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    this.iconUrl,
    required this.category,
    this.pointsRequired,
    required this.pointsReward,
    required this.rarity,
    required this.isActive,
    this.unlockCriteria,
    required this.createdAt,
    required this.updatedAt,
    this.unlockedAt,
    this.claimedAt,
  });

  factory KarmaAchievement.fromJson(Map<String, dynamic> json) {
    return KarmaAchievement(
      id: json['id'],
      slug: json['slug'],
      name: json['name'],
      description: json['description'],
      iconUrl: json['iconUrl'],
      category: json['category'],
      pointsRequired: json['pointsRequired'],
      pointsReward: json['pointsReward'],
      rarity: json['rarity'],
      isActive: json['isActive'],
      unlockCriteria: json['unlockCriteria'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      unlockedAt: json['unlockedAt'] != null 
          ? DateTime.parse(json['unlockedAt']) 
          : null,
      claimedAt: json['claimedAt'] != null 
          ? DateTime.parse(json['claimedAt']) 
          : null,
    );
  }

  bool get isUnlocked => unlockedAt != null;
  bool get isClaimed => claimedAt != null;
}

/// Pagination model
class Pagination {
  final int page;
  final int limit;
  final int total;
  final int pages;

  Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'],
      limit: json['limit'],
      total: json['total'],
      pages: json['pages'],
    );
  }
}

/// Earn guide payload from GET /v1/karma/earn-guide
class KarmaEarnGuide {
  final List<String> categories;
  final List<EarnGuideMethod> methods;
  final EarnGuideStats stats;
  final List<String> tips;

  KarmaEarnGuide({
    required this.categories,
    required this.methods,
    required this.stats,
    required this.tips,
  });

  factory KarmaEarnGuide.fromJson(Map<String, dynamic> json) {
    return KarmaEarnGuide(
      categories: (json['categories'] as List<dynamic>? ?? ['All'])
          .map((e) => e.toString())
          .toList(),
      methods: (json['methods'] as List<dynamic>? ?? [])
          .map((e) => EarnGuideMethod.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      stats: EarnGuideStats.fromJson(
        Map<String, dynamic>.from(json['stats'] as Map? ?? {}),
      ),
      tips: (json['tips'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class EarnGuideMethod {
  final String id;
  final String category;
  final String title;
  final String description;
  final int points;
  final String iconKey;
  final String route;
  final String actionLabel;
  final bool isRecurring;
  final String? claimActionType;
  final bool isCompleted;
  final bool canClaim;

  EarnGuideMethod({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.points,
    required this.iconKey,
    required this.route,
    required this.actionLabel,
    required this.isRecurring,
    this.claimActionType,
    required this.isCompleted,
    required this.canClaim,
  });

  factory EarnGuideMethod.fromJson(Map<String, dynamic> json) {
    return EarnGuideMethod(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? 'Social',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      iconKey: json['iconKey'] as String? ?? 'stars',
      route: json['route'] as String? ?? '',
      actionLabel: json['actionLabel'] as String? ?? 'Go',
      isRecurring: json['isRecurring'] == true,
      claimActionType: json['claimActionType'] as String?,
      isCompleted: json['isCompleted'] == true,
      canClaim: json['canClaim'] == true,
    );
  }
}

class EarnGuideStats {
  final int streak;
  final bool dailyClaimedToday;
  final int referralCount;
  final int completedOneTime;
  final int totalOneTime;

  EarnGuideStats({
    required this.streak,
    required this.dailyClaimedToday,
    required this.referralCount,
    required this.completedOneTime,
    required this.totalOneTime,
  });

  factory EarnGuideStats.fromJson(Map<String, dynamic> json) {
    return EarnGuideStats(
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      dailyClaimedToday: json['dailyClaimedToday'] == true,
      referralCount: (json['referralCount'] as num?)?.toInt() ?? 0,
      completedOneTime: (json['completedOneTime'] as num?)?.toInt() ?? 0,
      totalOneTime: (json['totalOneTime'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Response model for earning karma from actions
class EarnActionResponse {
  final String actionType;
  final int pointsEarned;
  final int totalPoints;
  final int newLevel;
  final String message;
  final bool leveledUp;
  final DateTime timestamp;

  EarnActionResponse({
    required this.actionType,
    required this.pointsEarned,
    required this.totalPoints,
    required this.newLevel,
    required this.message,
    required this.leveledUp,
    required this.timestamp,
  });

  factory EarnActionResponse.fromJson(Map<String, dynamic> json) {
    return EarnActionResponse(
      actionType: json['actionType'],
      pointsEarned: json['pointsEarned'],
      totalPoints: json['totalPoints'],
      newLevel: json['newLevel'],
      message: json['message'],
      leveledUp: json['leveledUp'] ?? false,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}