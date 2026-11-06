import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/karma_models.dart';
import '../../../core/api/api_client.dart';
import 'karma_api_service.dart' as api;
import '../../../core/config/env_config.dart';
import '../../../core/karma/karma_points_config.dart';
import '../../../core/karma/karma_membership_utils.dart';

/// Service for managing KARMA system operations
/// This is a singleton that must never be disposed by the provider system
class KarmaService extends ChangeNotifier {
  static final KarmaService _instance = KarmaService._internal();
  factory KarmaService() => _instance;
  KarmaService._internal() {
    _initializeApiService();
  }
  
  // API service for backend integration
  api.KarmaApiService? _apiService;
  bool _useBackendApi = true; // Always use backend API - no local storage fallback
  
  Future<void> _initializeApiService() async {
    final baseUrl = await EnvConfig.getBaseUrl();
    const storage = FlutterSecureStorage();
    final apiClient = ApiClient(baseUrl, storage);
    _apiService = api.KarmaApiService(apiClient);
  }

  // State
  UserKarma? _currentUserKarma;
  List<LeaderboardEntry> _leaderboard = [];
  List<Achievement> _availableAchievements = [];
  bool _isLoading = false;
  String? _error;

  // Simple TTL to avoid re-fetching all karma data too often.
  String? _lastInitUserId;
  DateTime? _lastInitAt;
  final Duration _initTtl = const Duration(seconds: 60);
  
  // Prevent multiple simultaneous initialization requests
  Future<void>? _pendingInitializationFuture;

  // Stream controllers for real-time updates
  final StreamController<UserKarma> _karmaUpdateController = StreamController<UserKarma>.broadcast();
  final StreamController<KarmaTransaction> _newTransactionController = StreamController<KarmaTransaction>.broadcast();
  final StreamController<Achievement> _achievementUnlockedController = StreamController<Achievement>.broadcast();

  // Getters
  UserKarma? get currentUserKarma => _currentUserKarma;
  List<LeaderboardEntry> get leaderboard => _leaderboard;
  List<Achievement> get availableAchievements => _availableAchievements;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isUsingBackendApi => _useBackendApi;
  api.KarmaApiService? get apiService => _apiService; // Expose API service for screens
  
  /// Get current user's KARMA points (for backward compatibility)
  int get userKarmaPoints => _currentUserKarma?.totalPoints ?? 0;

  // Streams
  Stream<UserKarma> get karmaUpdateStream => _karmaUpdateController.stream;
  Stream<KarmaTransaction> get newTransactionStream => _newTransactionController.stream;
  Stream<Achievement> get achievementUnlockedStream => _achievementUnlockedController.stream;

  // Local storage removed - using API only

  /// Initialize the KARMA service with deduplication to prevent multiple simultaneous calls
  Future<void> initialize(String userId) async {
    // If initialization is already in progress, wait for it instead of starting another
    if (_pendingInitializationFuture != null) {
      await _pendingInitializationFuture;
      return;
    }
    
    // If we've recently loaded karma for this user, avoid re-fetching.
    if (_lastInitUserId == userId && _lastInitAt != null) {
      final age = DateTime.now().difference(_lastInitAt!);
      if (age < _initTtl && _currentUserKarma != null) {
        return;
      }
    }

    _setLoading(true);
    _pendingInitializationFuture = _doInitialize(userId);
    try {
      await _pendingInitializationFuture;
    } finally {
      _pendingInitializationFuture = null;
      _setLoading(false);
    }
  }

  Future<void> _doInitialize(String userId) async {
    try {
      // Offline-first: paint last known karma, then refresh from API.
      await _hydrateKarmaFromDisk(userId);

      if (_apiService == null) {
        throw Exception('API service not initialized');
      }
      
      await _loadUserKarmaFromApi(userId);
      await _loadAchievementsFromApi();
      await _loadLeaderboardFromApi();
      _mergeAchievementsAndRank();
      _lastInitUserId = userId;
      _lastInitAt = DateTime.now();
      _setError(null);
      await _saveUserKarma();
      await _saveAvailableAchievements();
    } catch (e) {
      print('Failed to initialize KARMA system from API: $e');
      if (_currentUserKarma != null) {
        _setError(null);
      } else {
        _setError('Failed to load karma data. Please check your connection and try again.');
      }
    }
  }

  Future<void> _hydrateKarmaFromDisk(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user_karma_$userId');
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _currentUserKarma = UserKarma.fromJson(map);
      }
      final achievementsRaw = prefs.getString('available_achievements');
      if (achievementsRaw != null && achievementsRaw.isNotEmpty) {
        final list = jsonDecode(achievementsRaw) as List;
        _availableAchievements = list
            .whereType<Map>()
            .map((e) => Achievement.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (_currentUserKarma != null) {
        notifyListeners();
      }
    } catch (e) {
      print('Failed to hydrate karma from disk: $e');
    }
  }

  Future<void> refreshPointsConfig() async {
    if (_apiService == null) return;
    try {
      final res = await _apiService!.getPointsConfig();
      KarmaPointsConfigCache.instance.update(res.points);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to refresh karma points config: $e');
      }
    }
  }

  /// Force a full refresh of karma data, ignoring the TTL cache.
  Future<void> refresh(String userId) async {
    _setLoading(true);
    try {
      if (_apiService == null) {
        throw Exception('API service not initialized');
      }
      await refreshPointsConfig();
      await _loadUserKarmaFromApi(userId);
      await _loadAchievementsFromApi();
      await _loadLeaderboardFromApi();
      _mergeAchievementsAndRank();
      _lastInitUserId = userId;
      _lastInitAt = DateTime.now();
      _setError(null);
    } catch (e) {
      print('Failed to refresh KARMA system from API: $e');
      _setError('Failed to refresh karma data. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  /// Merge unlocked achievements and leaderboard rank into current user karma
  void _mergeAchievementsAndRank() {
    if (_currentUserKarma == null) return;
    final unlocked = _availableAchievements.where((a) => a.isUnlocked).toList();
    int rank = _currentUserKarma!.stats.globalRank;
    for (final entry in _leaderboard) {
      if (entry.userId == _currentUserKarma!.userId) {
        rank = entry.rank;
        break;
      }
    }
    _currentUserKarma = UserKarma(
      userId: _currentUserKarma!.userId,
      totalPoints: _currentUserKarma!.totalPoints,
      level: _currentUserKarma!.level,
      trustLevel: _currentUserKarma!.trustLevel,
      lastUpdated: _currentUserKarma!.lastUpdated,
      recentActivity: _currentUserKarma!.recentActivity,
      activityCounts: _currentUserKarma!.activityCounts,
      achievements: unlocked,
      currentStreak: _currentUserKarma!.currentStreak,
      stats: KarmaStats(
        totalTransactions: _currentUserKarma!.stats.totalTransactions,
        thisWeekPoints: _currentUserKarma!.stats.thisWeekPoints,
        thisMonthPoints: _currentUserKarma!.stats.thisMonthPoints,
        globalRank: rank,
        countryRank: _currentUserKarma!.stats.countryRank,
        topActivities: _currentUserKarma!.stats.topActivities,
        monthlyProgress: _currentUserKarma!.stats.monthlyProgress,
      ),
    );
    notifyListeners();
  }

  // Local storage methods removed - using API only

  // Dummy data generation methods removed - using API only

  // Local storage methods removed - API only

  // All dummy data generation and local storage methods removed - API only

  // ========== API-BASED METHODS ==========

  /// Raw karma account from API (membership + unlockedFeatures).
  Future<Map<String, dynamic>?> fetchKarmaAccountFromApi() async {
    if (_apiService == null) {
      await _initializeApiService();
    }
    try {
      return await _apiService!.getMyKarmaRaw();
    } catch (e) {
      if (kDebugMode) {
        print('fetchKarmaAccountFromApi failed: $e');
      }
      return null;
    }
  }

  /// Load user karma from backend API
  Future<void> _loadUserKarmaFromApi(String userId) async {
    if (_apiService == null) throw Exception('API service not initialized');
    
    try {
      final karmaAccount = await _apiService!.getMyKarma();
      final karmaHistory = await _apiService!.getKarmaHistory();
      
      // Convert API models to local models
      _currentUserKarma = _convertApiKarmaToLocal(karmaAccount, karmaHistory);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to load karma from API: $e');
    }
  }

  /// Load achievements from backend API
  Future<void> _loadAchievementsFromApi() async {
    if (_apiService == null) throw Exception('API service not initialized');
    
    try {
      final userAchievements = await _apiService!.getUserAchievements();
      
      // Convert API achievements to local models
      _availableAchievements = _convertApiAchievementsToLocal(userAchievements);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to load achievements from API: $e');
    }
  }

  /// Load leaderboard from backend API
  Future<void> _loadLeaderboardFromApi() async {
    if (_apiService == null) throw Exception('API service not initialized');
    
    try {
      final leaderboard = await _apiService!.getLeaderboard();
      
      // Convert API leaderboard to local models
      _leaderboard = _convertApiLeaderboardToLocal(leaderboard);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to load leaderboard from API: $e');
    }
  }

  // ========== CONVERSION METHODS ==========

  /// Convert API karma account to local UserKarma model
  UserKarma _convertApiKarmaToLocal(api.KarmaAccount apiAccount, api.KarmaHistory karmaHistory) {
    final trustLevel = mapApiTrustLevelToLocal(
      apiAccount.trustLevel,
      points: apiAccount.currentPoints,
    );

    // Convert karma events to transactions
    final transactions = karmaHistory.events.map((event) => _convertApiEventToTransaction(event)).toList();
    
    // Calculate activity counts from transactions
    final activityCounts = <KarmaActivity, int>{};
    for (final transaction in transactions) {
      activityCounts[transaction.activity] = (activityCounts[transaction.activity] ?? 0) + 1;
    }

    // Create streak data (simplified for now)
    final streak = KarmaStreak(
      currentStreak: apiAccount.streak,
      longestStreak: apiAccount.streak,
      lastActivityDate: apiAccount.lastActivityAt,
      activeDays: [], // This would need more data from the API
    );

    // Create stats
    final stats = KarmaStats(
      totalTransactions: karmaHistory.events.length,
      thisWeekPoints: _calculateWeeklyPoints(karmaHistory.events),
      thisMonthPoints: _calculateMonthlyPoints(karmaHistory.events),
      globalRank: 999999, // This would come from leaderboard
      countryRank: 999999,
      topActivities: _calculateTopActivities(transactions),
      monthlyProgress: _calculateMonthlyProgress(transactions),
    );

    return UserKarma(
      userId: apiAccount.userId,
      totalPoints: apiAccount.currentPoints,
      level: KarmaLevelExtension.fromPoints(apiAccount.currentPoints),
      trustLevel: trustLevel,
      lastUpdated: apiAccount.updatedAt,
      recentActivity: transactions.take(50).toList(),
      activityCounts: activityCounts,
      achievements: [], // Will be populated separately
      currentStreak: streak,
      stats: stats,
    );
  }

  /// Convert API karma event to local transaction
  KarmaTransaction _convertApiEventToTransaction(api.KarmaEvent event) {
    // Map event type to karma activity
    KarmaActivity activity;
    switch (event.type.toLowerCase()) {
      case 'first_login':
      case 'daily_login':
        activity = KarmaActivity.createPost; // Generic activity for login bonuses
        break;
      case 'trade_complete':
        activity = KarmaActivity.completeTrade;
        break;
      case 'verification':
        activity = KarmaActivity.getVerified;
        break;
      case 'community_help':
        activity = KarmaActivity.helpCommunity;
        break;
      case 'gift_sent':
        activity = KarmaActivity.giveGift;
        break;
      case 'donation_made':
        activity = KarmaActivity.makeDonation;
        break;
      case 'post_created':
        activity = KarmaActivity.createPost;
        break;
      case 'content_shared':
        activity = KarmaActivity.shareContent;
        break;
      case 'user_referred':
        activity = KarmaActivity.referFriend;
        break;
      default:
        activity = KarmaActivity.createPost; // Default
        break;
    }

    return KarmaTransaction(
      id: event.id,
      userId: event.userId,
      activity: activity,
      pointsEarned: event.points,
      timestamp: event.createdAt,
      description: event.reason ?? activity.description,
      metadata: event.metadata ?? {},
      relatedId: event.sourceId,
    );
  }

  /// Convert API achievements to local achievements
  List<Achievement> _convertApiAchievementsToLocal(api.UserAchievements userAchievements) {
    final achievements = <Achievement>[];
    
    // Add unlocked achievements
    for (final apiAchievement in userAchievements.unlocked) {
      achievements.add(_convertApiAchievementToLocal(apiAchievement, true));
    }
    
    // Add locked achievements
    for (final apiAchievement in userAchievements.locked) {
      achievements.add(_convertApiAchievementToLocal(apiAchievement, false));
    }
    
    return achievements;
  }

  /// Convert single API achievement to local achievement
  Achievement _convertApiAchievementToLocal(api.KarmaAchievement apiAchievement, bool isUnlocked) {
    // Map category
    AchievementCategory category;
    switch (apiAchievement.category.toLowerCase()) {
      case 'trading':
        category = AchievementCategory.trading;
        break;
      case 'community':
        category = AchievementCategory.community;
        break;
      case 'helping':
        category = AchievementCategory.helping;
        break;
      case 'verification':
        category = AchievementCategory.verification;
        break;
      case 'social':
        category = AchievementCategory.social;
        break;
      case 'milestone':
        category = AchievementCategory.milestone;
        break;
      default:
        category = AchievementCategory.special;
        break;
    }

    return Achievement(
      id: apiAchievement.id,
      name: apiAchievement.name,
      description: apiAchievement.description,
      iconUrl: apiAchievement.iconUrl ?? '🏆',
      category: category,
      requiredValue: apiAchievement.pointsRequired ?? 1,
      requiredActivity: _mapAchievementRequirement(apiAchievement),
      unlockedAt: apiAchievement.unlockedAt,
      isUnlocked: isUnlocked,
      pointsReward: apiAchievement.pointsReward,
      rarity: apiAchievement.rarity,
    );
  }

  /// Convert API leaderboard to local leaderboard entries
  List<LeaderboardEntry> _convertApiLeaderboardToLocal(api.KarmaLeaderboard apiLeaderboard) {
    return apiLeaderboard.leaderboard.map((entry) {
      final trustLevel = mapApiTrustLevelToLocal(
        entry.trustLevel,
        points: entry.points,
      );

      return LeaderboardEntry(
        userId: entry.userId,
        userName: entry.displayName,
        userAvatar: entry.avatarKey,
        totalPoints: entry.points,
        level: KarmaLevelExtension.fromPoints(entry.points),
        trustLevel: trustLevel,
        rank: entry.rank,
        thisWeekPoints: 0, // Would need weekly data from API
        isCurrentUser: _currentUserKarma?.userId == entry.userId,
      );
    }).toList();
  }

  // ========== HELPER METHODS ==========

  /// Calculate weekly points from karma events
  int _calculateWeeklyPoints(List<api.KarmaEvent> events) {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return events
        .where((event) => event.createdAt.isAfter(weekAgo))
        .fold(0, (sum, event) => sum + event.points);
  }

  /// Calculate monthly points from karma events
  int _calculateMonthlyPoints(List<api.KarmaEvent> events) {
    final monthAgo = DateTime.now().subtract(const Duration(days: 30));
    return events
        .where((event) => event.createdAt.isAfter(monthAgo))
        .fold(0, (sum, event) => sum + event.points);
  }

  /// Calculate top activities from transactions
  Map<KarmaActivity, int> _calculateTopActivities(List<KarmaTransaction> transactions) {
    final activityPoints = <KarmaActivity, int>{};
    for (final transaction in transactions) {
      activityPoints[transaction.activity] = 
          (activityPoints[transaction.activity] ?? 0) + transaction.pointsEarned;
    }
    return activityPoints;
  }

  /// Calculate monthly progress from transactions
  Map<String, int> _calculateMonthlyProgress(List<KarmaTransaction> transactions) {
    final monthlyProgress = <String, int>{};
    for (final transaction in transactions) {
      final monthKey = '${transaction.timestamp.year}-${transaction.timestamp.month.toString().padLeft(2, '0')}';
      monthlyProgress[monthKey] = (monthlyProgress[monthKey] ?? 0) + transaction.pointsEarned;
    }
    return monthlyProgress;
  }

  /// Map achievement requirement based on API data
  String _mapAchievementRequirement(api.KarmaAchievement apiAchievement) {
    // Try to derive the requirement from the unlock criteria
    if (apiAchievement.unlockCriteria != null) {
      final criteria = apiAchievement.unlockCriteria!;
      if (criteria.containsKey('activityType')) {
        return criteria['activityType'].toString();
      }
    }
    
    // Fallback based on category
    switch (apiAchievement.category.toLowerCase()) {
      case 'trading':
        return 'completeTrade';
      case 'community':
        return 'helpCommunity';
      case 'helping':
        return 'mentorUser';
      case 'verification':
        return 'getVerified';
      case 'social':
        return 'shareContent';
      case 'milestone':
        return 'milestone';
      default:
        return 'createPost';
    }
  }

  /// Add KARMA points for an activity
  Future<void> addKarmaPoints(
    KarmaActivity activity, {
    String? description,
    Map<String, dynamic>? metadata,
    String? relatedId,
  }) async {
    if (_currentUserKarma == null) return;

    final transaction = KarmaTransaction(
      id: _generateTransactionId(),
      userId: _currentUserKarma!.userId,
      activity: activity,
      pointsEarned: activity.points,
      timestamp: DateTime.now(),
      description: description ?? activity.description,
      metadata: metadata ?? {},
      relatedId: relatedId,
    );

    await _processKarmaTransaction(transaction);
  }

  /// Process a KARMA transaction
  Future<void> _processKarmaTransaction(KarmaTransaction transaction) async {
    if (_currentUserKarma == null) return;

    final oldLevel = _currentUserKarma!.level;
    final oldTotalPoints = _currentUserKarma!.totalPoints;
    final newTotalPoints = oldTotalPoints + transaction.pointsEarned;
        final newLevel = KarmaLevelExtension.fromPoints(newTotalPoints);

    // Update activity counts
    final updatedActivityCounts = Map<KarmaActivity, int>.from(_currentUserKarma!.activityCounts);
    updatedActivityCounts[transaction.activity] = (updatedActivityCounts[transaction.activity] ?? 0) + 1;

    // Update recent activity
    final updatedRecentActivity = List<KarmaTransaction>.from(_currentUserKarma!.recentActivity);
    updatedRecentActivity.insert(0, transaction);
    if (updatedRecentActivity.length > 50) {
      updatedRecentActivity.removeLast();
    }

    // Update streak
    final updatedStreak = _updateStreak(_currentUserKarma!.currentStreak, transaction.timestamp);

    // Update stats
    final updatedStats = _updateStats(_currentUserKarma!.stats, transaction);

    // Create updated user KARMA
    _currentUserKarma = UserKarma(
      userId: _currentUserKarma!.userId,
      totalPoints: newTotalPoints,
      level: newLevel,
      trustLevel: _currentUserKarma!.trustLevel,
      lastUpdated: transaction.timestamp,
      recentActivity: updatedRecentActivity,
      activityCounts: updatedActivityCounts,
      achievements: _currentUserKarma!.achievements,
      currentStreak: updatedStreak,
      stats: updatedStats,
    );

    // Check for new achievements
    await _checkAndUnlockAchievements(transaction);

    // Check for level up
    if (newLevel != oldLevel) {
      await _handleLevelUp(oldLevel, newLevel);
    }

    // Save changes
    await _saveUserKarma();
    
    // Notify listeners
    notifyListeners();
    _karmaUpdateController.add(_currentUserKarma!);
    _newTransactionController.add(transaction);
  }

  /// Update user streak
  KarmaStreak _updateStreak(KarmaStreak currentStreak, DateTime activityDate) {
    final today = DateTime.now();
    final activityDay = DateTime(activityDate.year, activityDate.month, activityDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);

    List<DateTime> updatedActiveDays = List.from(currentStreak.activeDays);
    
    // Add today if not already present
    if (!updatedActiveDays.any((day) => 
        day.year == activityDay.year && 
        day.month == activityDay.month && 
        day.day == activityDay.day)) {
      updatedActiveDays.add(activityDay);
    }

    // Sort active days
    updatedActiveDays.sort();

    // Calculate current streak
    int newCurrentStreak = 0;
    DateTime? lastDay;
    
    for (int i = updatedActiveDays.length - 1; i >= 0; i--) {
      final day = updatedActiveDays[i];
      if (lastDay == null) {
        lastDay = day;
        newCurrentStreak = 1;
      } else if (lastDay.difference(day).inDays == 1) {
        newCurrentStreak++;
        lastDay = day;
      } else {
        break;
      }
    }

    final newLongestStreak = max(currentStreak.longestStreak, newCurrentStreak);

    return KarmaStreak(
      currentStreak: newCurrentStreak,
      longestStreak: newLongestStreak,
      lastActivityDate: activityDate,
      activeDays: updatedActiveDays,
    );
  }

  /// Update user stats
  KarmaStats _updateStats(KarmaStats currentStats, KarmaTransaction transaction) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    int newThisWeekPoints = currentStats.thisWeekPoints;
    if (transaction.timestamp.isAfter(weekStart)) {
      newThisWeekPoints += transaction.pointsEarned;
    }

    int newThisMonthPoints = currentStats.thisMonthPoints;
    if (transaction.timestamp.isAfter(monthStart)) {
      newThisMonthPoints += transaction.pointsEarned;
    }

    // Update top activities
    final updatedTopActivities = Map<KarmaActivity, int>.from(currentStats.topActivities);
    updatedTopActivities[transaction.activity] = 
        (updatedTopActivities[transaction.activity] ?? 0) + transaction.pointsEarned;

    // Update monthly progress
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final updatedMonthlyProgress = Map<String, int>.from(currentStats.monthlyProgress);
    updatedMonthlyProgress[monthKey] = 
        (updatedMonthlyProgress[monthKey] ?? 0) + transaction.pointsEarned;

    return KarmaStats(
      totalTransactions: currentStats.totalTransactions + 1,
      thisWeekPoints: newThisWeekPoints,
      thisMonthPoints: newThisMonthPoints,
      globalRank: currentStats.globalRank, // Will be updated by leaderboard refresh
      countryRank: currentStats.countryRank,
      topActivities: updatedTopActivities,
      monthlyProgress: updatedMonthlyProgress,
    );
  }

  /// Check and unlock achievements
  Future<void> _checkAndUnlockAchievements(KarmaTransaction transaction) async {
    if (_currentUserKarma == null) return;

    final unlockedAchievements = <Achievement>[];

    for (final achievement in _availableAchievements) {
      if (achievement.isUnlocked) continue;

      bool shouldUnlock = false;

      // Check activity-specific achievements
      if (achievement.requiredActivity == transaction.activity.name) {
        final activityCount = _currentUserKarma!.activityCounts[transaction.activity] ?? 0;
        shouldUnlock = activityCount >= achievement.requiredValue;
      }
      // Check milestone achievements
      else if (achievement.requiredActivity == 'milestone') {
        shouldUnlock = _currentUserKarma!.totalPoints >= achievement.requiredValue;
      }

      if (shouldUnlock) {
        final unlockedAchievement = Achievement(
          id: achievement.id,
          name: achievement.name,
          description: achievement.description,
          iconUrl: achievement.iconUrl,
          category: achievement.category,
          requiredValue: achievement.requiredValue,
          requiredActivity: achievement.requiredActivity,
          unlockedAt: DateTime.now(),
          isUnlocked: true,
          pointsReward: achievement.pointsReward,
          rarity: achievement.rarity,
        );

        unlockedAchievements.add(unlockedAchievement);

        // Add bonus points for achievement
        if (achievement.pointsReward > 0) {
          final bonusTransaction = KarmaTransaction(
            id: _generateTransactionId(),
            userId: _currentUserKarma!.userId,
            activity: KarmaActivity.createPost, // Generic activity for achievements
            pointsEarned: achievement.pointsReward,
            timestamp: DateTime.now(),
            description: 'Achievement unlocked: ${achievement.name}',
            metadata: {'achievementId': achievement.id},
          );

          // Update total points
          _currentUserKarma = UserKarma(
            userId: _currentUserKarma!.userId,
            totalPoints: _currentUserKarma!.totalPoints + achievement.pointsReward,
                level: KarmaLevelExtension.fromPoints(_currentUserKarma!.totalPoints + achievement.pointsReward),
            trustLevel: _currentUserKarma!.trustLevel,
            lastUpdated: DateTime.now(),
            recentActivity: [bonusTransaction, ..._currentUserKarma!.recentActivity],
            activityCounts: _currentUserKarma!.activityCounts,
            achievements: [..._currentUserKarma!.achievements, unlockedAchievement],
            currentStreak: _currentUserKarma!.currentStreak,
            stats: _currentUserKarma!.stats,
          );
        }

        // Notify achievement unlocked
        _achievementUnlockedController.add(unlockedAchievement);
      }
    }

    // Update available achievements
    _availableAchievements = _availableAchievements.map((achievement) {
      final unlocked = unlockedAchievements.firstWhere(
        (unlocked) => unlocked.id == achievement.id,
        orElse: () => achievement,
      );
      return unlocked;
    }).toList();

    await _saveAvailableAchievements();
  }

  /// Handle level up
  Future<void> _handleLevelUp(KarmaLevel oldLevel, KarmaLevel newLevel) async {
    // Add bonus points for level up
    const levelUpBonus = 100;
    
    final levelUpTransaction = KarmaTransaction(
      id: _generateTransactionId(),
      userId: _currentUserKarma!.userId,
      activity: KarmaActivity.createPost, // Generic activity for level ups
      pointsEarned: levelUpBonus,
      timestamp: DateTime.now(),
      description: 'Level up bonus: ${oldLevel.name} → ${newLevel.name}',
      metadata: {
        'oldLevel': oldLevel.name,
        'newLevel': newLevel.name,
        'isLevelUpBonus': true,
      },
    );

    // Update user KARMA with level up bonus
    final updatedRecentActivity = [levelUpTransaction, ..._currentUserKarma!.recentActivity];
    
    _currentUserKarma = UserKarma(
      userId: _currentUserKarma!.userId,
      totalPoints: _currentUserKarma!.totalPoints + levelUpBonus,
          level: KarmaLevelExtension.fromPoints(_currentUserKarma!.totalPoints + levelUpBonus),
      trustLevel: _currentUserKarma!.trustLevel,
      lastUpdated: DateTime.now(),
      recentActivity: updatedRecentActivity,
      activityCounts: _currentUserKarma!.activityCounts,
      achievements: _currentUserKarma!.achievements,
      currentStreak: _currentUserKarma!.currentStreak,
      stats: _currentUserKarma!.stats,
    );
  }

  /// Upgrade trust level
  Future<void> upgradeTrustLevel(TrustLevel newTrustLevel) async {
    if (_currentUserKarma == null) return;

    final trustUpgradeTransaction = KarmaTransaction(
      id: _generateTransactionId(),
      userId: _currentUserKarma!.userId,
      activity: KarmaActivity.getVerified,
      pointsEarned: 100, // Bonus for trust level upgrade
      timestamp: DateTime.now(),
      description: 'Trust level upgraded to ${newTrustLevel.name}',
      metadata: {
        'oldTrustLevel': _currentUserKarma!.trustLevel.name,
        'newTrustLevel': newTrustLevel.name,
      },
    );

    await _processKarmaTransaction(trustUpgradeTransaction);

    _currentUserKarma = UserKarma(
      userId: _currentUserKarma!.userId,
      totalPoints: _currentUserKarma!.totalPoints,
      level: _currentUserKarma!.level,
      trustLevel: newTrustLevel,
      lastUpdated: DateTime.now(),
      recentActivity: _currentUserKarma!.recentActivity,
      activityCounts: _currentUserKarma!.activityCounts,
      achievements: _currentUserKarma!.achievements,
      currentStreak: _currentUserKarma!.currentStreak,
      stats: _currentUserKarma!.stats,
    );

    await _saveUserKarma();
    notifyListeners();
  }

  /// Refresh leaderboard
  Future<void> refreshLeaderboard() async {
    _setLoading(true);
    try {
      if (_apiService == null) {
        throw Exception('API service not initialized');
      }
      await _loadLeaderboardFromApi();
      _setError(null);
    } catch (e) {
      print('Failed to refresh leaderboard from API: $e');
      _setError('Failed to refresh leaderboard. Please check your connection and try again.');
    } finally {
      _setLoading(false);
    }
  }

  /// Get user's karma history
  List<KarmaTransaction> getUserKarmaHistory() {
    return _currentUserKarma?.recentActivity ?? [];
  }

  /// Get user's unlocked achievements
  List<Achievement> getUserUnlockedAchievements() {
    return _currentUserKarma?.achievements ?? [];
  }

  /// Get user's progress towards next level
  double getLevelProgress() {
    return _currentUserKarma?.progressToNextLevel ?? 0.0;
  }

  /// Get points needed for next level
  int getPointsToNextLevel() {
    return _currentUserKarma?.pointsToNextLevel ?? 0;
  }

  /// Generate transaction ID
  String _generateTransactionId() {
    return 'tx_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error state
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Save user karma data to local storage
  Future<void> _saveUserKarma() async {
    if (_currentUserKarma == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_karma_${_currentUserKarma!.userId}', 
          jsonEncode(_currentUserKarma!.toJson()));
    } catch (e) {
      print('Failed to save user karma: $e');
    }
  }

  /// Save available achievements to local storage
  Future<void> _saveAvailableAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final achievementsJson = _availableAchievements.map((a) => a.toJson()).toList();
      await prefs.setString('available_achievements', jsonEncode(achievementsJson));
    } catch (e) {
      print('Failed to save available achievements: $e');
    }
  }

  /// Reset user karma (for testing purposes)
  Future<void> resetUserKarma() async {
    if (_currentUserKarma == null) return;
    
    _currentUserKarma = UserKarma(
      userId: _currentUserKarma!.userId,
      totalPoints: 0,
      level: KarmaLevel.newbie,
      trustLevel: TrustLevel.unverified,
      lastUpdated: DateTime.now(),
      recentActivity: [],
      activityCounts: {},
      achievements: [],
      currentStreak: KarmaStreak(
        currentStreak: 0,
        longestStreak: 0,
        lastActivityDate: DateTime.now(),
        activeDays: [],
      ),
      stats: KarmaStats(
        totalTransactions: 0,
        thisWeekPoints: 0,
        thisMonthPoints: 0,
        globalRank: 0,
        countryRank: 0,
        topActivities: {},
        monthlyProgress: {},
      ),
    );
    
    await _saveUserKarma();
    notifyListeners();
  }

  /// Override the disposal assertion to prevent "used after being disposed" errors
  /// This singleton must never be treated as disposable
  @override
  void debugAssertNotDisposed() {
    // Do nothing - this singleton is never truly disposed
    // The dispose() method is called by providers but we ignore it
  }

  /// Override dispose to prevent provider from closing streams
  /// This is a singleton service that must persist for the app lifetime
  @override
  void dispose() {
    // Intentionally empty - do not dispose stream controllers
    // This singleton manages its own lifecycle for the application duration
  }

  /// Refresh all karma data from API
  Future<void> refreshAllKarmaData() async {
    if (_currentUserKarma == null) return;
    
    await initialize(_currentUserKarma!.userId);
  }

  /// Claim achievement through API
  Future<void> claimAchievement(String achievementId) async {
    if (_useBackendApi && _apiService != null) {
      try {
        await _apiService!.claimAchievement(achievementId);
        // Refresh achievements to reflect the claim
        await _loadAchievementsFromApi();
        notifyListeners();
      } catch (e) {
        throw Exception('Failed to claim achievement: $e');
      }
    }
    // If using local storage, claiming would be handled in the local achievement logic
  }

  /// Get karma statistics summary
  Map<String, dynamic> getKarmaStatsSummary() {
    if (_currentUserKarma == null) return {};

    return {
      'totalPoints': _currentUserKarma!.totalPoints,
      'level': _currentUserKarma!.level.name,
      'levelEmoji': _currentUserKarma!.level.emoji,
      'trustLevel': _currentUserKarma!.trustLevel.name,
      'trustEmoji': _currentUserKarma!.trustLevel.emoji,
      'currentStreak': _currentUserKarma!.currentStreak.currentStreak,
      'longestStreak': _currentUserKarma!.currentStreak.longestStreak,
      'globalRank': _currentUserKarma!.stats.globalRank,
      'thisWeekPoints': _currentUserKarma!.stats.thisWeekPoints,
      'thisMonthPoints': _currentUserKarma!.stats.thisMonthPoints,
      'totalTransactions': _currentUserKarma!.stats.totalTransactions,
      'achievementsCount': _currentUserKarma!.achievements.length,
      'pointsToNextLevel': getPointsToNextLevel(),
      'progressToNextLevel': getLevelProgress(),
    };
  }
}