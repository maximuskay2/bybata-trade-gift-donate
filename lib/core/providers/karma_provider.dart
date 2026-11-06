import 'package:flutter/foundation.dart';
import '../models/app_models.dart';

class KarmaProvider extends ChangeNotifier {
  // Current user's KARMA data
  int _currentPoints = 0;
  KarmaLevel? _currentLevel;
  List<Achievement> _achievements = [];
  List<Achievement> _availableAchievements = [];
  Map<String, int> _pointsHistory = {};
  bool _isLoading = false;
  String? _errorMessage;

  // KARMA level configuration
  static const List<KarmaLevel> _karmaLevels = [
    KarmaLevel(
      level: 1,
      title: 'Newcomer',
      minPoints: 0,
      maxPoints: 99,
      color: '#9E9E9E',
      icon: '🌱',
      perks: ['Basic trading', 'Community access'],
    ),
    KarmaLevel(
      level: 2,
      title: 'Explorer',
      minPoints: 100,
      maxPoints: 499,
      color: '#4CAF50',
      icon: '🌿',
      perks: ['Basic trading', 'Community access', 'Profile customization'],
    ),
    KarmaLevel(
      level: 3,
      title: 'Trader',
      minPoints: 500,
      maxPoints: 999,
      color: '#7E57C2',
      icon: '🏪',
      perks: ['Enhanced trading', 'Priority support', 'Custom badges'],
    ),
    KarmaLevel(
      level: 4,
      title: 'Champion',
      minPoints: 1000,
      maxPoints: 2499,
      color: '#FF9800',
      icon: '🏆',
      perks: ['Premium features', 'Exclusive communities', 'Trading bonuses'],
    ),
    KarmaLevel(
      level: 5,
      title: 'Legend',
      minPoints: 2500,
      maxPoints: 4999,
      color: '#E91E63',
      icon: '⭐',
      perks: ['VIP status', 'Early access', 'Special recognition'],
    ),
    KarmaLevel(
      level: 6,
      title: 'Master',
      minPoints: 5000,
      maxPoints: 9999,
      color: '#9C27B0',
      icon: '💎',
      perks: ['Master privileges', 'Community leadership', 'Exclusive events'],
    ),
    KarmaLevel(
      level: 7,
      title: 'Grandmaster',
      minPoints: 10000,
      maxPoints: 99999,
      color: '#FFD700',
      icon: '👑',
      perks: ['Ultimate status', 'Platform influence', 'Special rewards'],
    ),
  ];

  // Getters
  int get currentPoints => _currentPoints;
  KarmaLevel? get currentLevel => _currentLevel;
  List<Achievement> get achievements => _achievements;
  List<Achievement> get availableAchievements => _availableAchievements;
  List<Achievement> get unlockedAchievements => 
      _achievements.where((a) => a.isUnlocked).toList();
  List<Achievement> get lockedAchievements => 
      _achievements.where((a) => !a.isUnlocked).toList();
  Map<String, int> get pointsHistory => Map.unmodifiable(_pointsHistory);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<KarmaLevel> get allLevels => _karmaLevels;

  // Progress to next level
  double get progressToNextLevel {
    if (_currentLevel == null) return 0.0;
    
    final nextLevel = _getNextLevel();
    if (nextLevel == null) return 1.0; // Already at max level
    
    final currentLevelMin = _currentLevel!.minPoints;
    final nextLevelMin = nextLevel.minPoints;
    final progress = (_currentPoints - currentLevelMin) / (nextLevelMin - currentLevelMin);
    
    return progress.clamp(0.0, 1.0);
  }

  // Points needed for next level
  int get pointsToNextLevel {
    final nextLevel = _getNextLevel();
    if (nextLevel == null) return 0;
    return nextLevel.minPoints - _currentPoints;
  }

  // Initialize KARMA provider
  Future<void> initializeKarma(int initialPoints) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentPoints = initialPoints;
      _currentLevel = _calculateLevel(initialPoints);
      await _loadAchievements();
      await _loadPointsHistory();
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to initialize KARMA: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Calculate level from points
  KarmaLevel _calculateLevel(int points) {
    for (int i = _karmaLevels.length - 1; i >= 0; i--) {
      if (points >= _karmaLevels[i].minPoints) {
        return _karmaLevels[i];
      }
    }
    return _karmaLevels.first; // Newcomer level
  }

  // Get next level
  KarmaLevel? _getNextLevel() {
    if (_currentLevel == null) return null;
    
    final currentIndex = _karmaLevels.indexOf(_currentLevel!);
    if (currentIndex < _karmaLevels.length - 1) {
      return _karmaLevels[currentIndex + 1];
    }
    return null; // Already at max level
  }

  // Add KARMA points
  Future<void> addPoints(int points, String reason) async {
    if (points <= 0) return;

    try {
      _errorMessage = null;
      
      final previousLevel = _currentLevel;
      _currentPoints += points;
      _currentLevel = _calculateLevel(_currentPoints);
      
      // Record points history
      final today = DateTime.now().toString().split(' ')[0];
      _pointsHistory[today] = (_pointsHistory[today] ?? 0) + points;
      
      // Check for level up
      if (previousLevel != null && _currentLevel!.level > previousLevel.level) {
        await _handleLevelUp(previousLevel, _currentLevel!);
      }
      
      // Check for achievement unlocks
      await _checkAchievementUnlocks();
      
      // TODO: Save to backend
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate API call
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to add KARMA points: ${e.toString()}';
      notifyListeners();
    }
  }

  // Subtract KARMA points (for penalties)
  Future<void> subtractPoints(int points, String reason) async {
    if (points <= 0) return;

    try {
      _errorMessage = null;
      
      final previousLevel = _currentLevel;
      _currentPoints = (_currentPoints - points).clamp(0, _currentPoints);
      _currentLevel = _calculateLevel(_currentPoints);
      
      // Record points history (negative)
      final today = DateTime.now().toString().split(' ')[0];
      _pointsHistory[today] = (_pointsHistory[today] ?? 0) - points;
      
      // Check for level down
      if (previousLevel != null && _currentLevel!.level < previousLevel.level) {
        await _handleLevelDown(previousLevel, _currentLevel!);
      }
      
      // TODO: Save to backend
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate API call
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to subtract KARMA points: ${e.toString()}';
      notifyListeners();
    }
  }

  // Handle level up
  Future<void> _handleLevelUp(KarmaLevel oldLevel, KarmaLevel newLevel) async {
    // TODO: Show level up notification
    // TODO: Grant level up rewards
    // TODO: Update user achievements
    
    // Unlock level-based achievements
    final levelAchievement = _achievements.firstWhere(
      (a) => a.id == 'level_${newLevel.level}' && !a.isUnlocked,
      orElse: () => Achievement(
        id: 'level_${newLevel.level}',
        title: 'Level ${newLevel.level} - ${newLevel.title}',
        description: 'Reached ${newLevel.title} level!',
        karmaPoints: newLevel.level * 100,
        badgeType: 'gold',
        category: AchievementCategory.milestones,
        isUnlocked: true,
        unlockedAt: DateTime.now(),
      ),
    );
    
    if (!levelAchievement.isUnlocked) {
      await _unlockAchievement(levelAchievement.id);
    }
  }

  // Handle level down
  Future<void> _handleLevelDown(KarmaLevel oldLevel, KarmaLevel newLevel) async {
    // TODO: Show level down notification
    // TODO: Remove level-based privileges if necessary
  }

  // Load achievements
  Future<void> _loadAchievements() async {
    try {
      // TODO: Load from backend
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate API call
      
      _achievements = [
        // Trading achievements
        Achievement(
          id: 'first_trade',
          title: 'First Trade',
          description: 'Complete your first trade',
          karmaPoints: 50,
          badgeType: 'bronze',
          category: AchievementCategory.trading,
          requirement: 'Complete 1 trade',
          progress: 0.0,
        ),
        Achievement(
          id: 'trade_master',
          title: 'Trade Master',
          description: 'Complete 100 successful trades',
          karmaPoints: 500,
          badgeType: 'gold',
          category: AchievementCategory.trading,
          requirement: 'Complete 100 trades',
          progress: 0.25,
        ),
        
        // Community achievements
        Achievement(
          id: 'community_helper',
          title: 'Community Helper',
          description: 'Help 10 community members',
          karmaPoints: 200,
          badgeType: 'silver',
          category: AchievementCategory.community,
          requirement: 'Help 10 members',
          progress: 0.6,
        ),
        
        // Donation achievements
        Achievement(
          id: 'generous_donor',
          title: 'Generous Donor',
          description: 'Donate 1000 BYC to campaigns',
          karmaPoints: 300,
          badgeType: 'gold',
          category: AchievementCategory.donations,
          requirement: 'Donate 1000 BYC',
          progress: 0.15,
        ),
        
        // Social achievements
        Achievement(
          id: 'social_butterfly',
          title: 'Social Butterfly',
          description: 'Follow 50 users',
          karmaPoints: 100,
          badgeType: 'bronze',
          category: AchievementCategory.social,
          requirement: 'Follow 50 users',
          progress: 0.8,
        ),
        
        // Milestone achievements
        Achievement(
          id: 'karma_collector',
          title: 'KARMA Collector',
          description: 'Reach 1000 KARMA points',
          karmaPoints: 100,
          badgeType: 'silver',
          category: AchievementCategory.milestones,
          requirement: 'Earn 1000 KARMA points',
          progress: _currentPoints / 1000.0,
          isUnlocked: _currentPoints >= 1000,
          unlockedAt: _currentPoints >= 1000 ? DateTime.now() : null,
        ),
      ];
      
      // Update achievement progress based on current points
      _updateAchievementProgress();
      
    } catch (e) {
      _errorMessage = 'Failed to load achievements: ${e.toString()}';
    }
  }

  // Update achievement progress
  void _updateAchievementProgress() {
    for (int i = 0; i < _achievements.length; i++) {
      final achievement = _achievements[i];
      
      switch (achievement.id) {
        case 'karma_collector':
          _achievements[i] = achievement.copyWith(
            progress: (_currentPoints / 1000.0).clamp(0.0, 1.0),
            isUnlocked: _currentPoints >= 1000,
            unlockedAt: _currentPoints >= 1000 && !achievement.isUnlocked 
                ? DateTime.now() 
                : achievement.unlockedAt,
          );
          break;
        // Add more achievement progress updates here
      }
    }
  }

  // Check for achievement unlocks
  Future<void> _checkAchievementUnlocks() async {
    for (final achievement in _achievements) {
      if (!achievement.isUnlocked && achievement.progress != null && 
          achievement.progress! >= 1.0) {
        await _unlockAchievement(achievement.id);
      }
    }
  }

  // Unlock achievement
  Future<void> _unlockAchievement(String achievementId) async {
    try {
      final achievementIndex = _achievements.indexWhere((a) => a.id == achievementId);
      if (achievementIndex == -1) return;
      
      final achievement = _achievements[achievementIndex];
      if (achievement.isUnlocked) return;
      
      // Unlock achievement
      _achievements[achievementIndex] = achievement.copyWith(
        isUnlocked: true,
        unlockedAt: DateTime.now(),
        progress: 1.0,
      );
      
      // Award KARMA points
      await addPoints(achievement.karmaPoints, 'Achievement: ${achievement.title}');
      
      // TODO: Show achievement unlock notification
      // TODO: Save to backend
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to unlock achievement: ${e.toString()}';
      notifyListeners();
    }
  }

  // Load points history
  Future<void> _loadPointsHistory() async {
    try {
      // TODO: Load from backend
      await Future.delayed(const Duration(milliseconds: 300)); // Simulate API call
      
      // Mock data for last 7 days
      final now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i)).toString().split(' ')[0];
        _pointsHistory[date] = (i * 10) + (i == 0 ? 0 : 5); // Mock points
      }
      
    } catch (e) {
      _errorMessage = 'Failed to load points history: ${e.toString()}';
    }
  }

  // Get KARMA activities for specific actions
  Future<void> handleTradeCompleted() async {
    await addPoints(25, 'Trade completed');
  }

  Future<void> handleDonationMade(double amount) async {
    final points = (amount / 10).round(); // 1 point per 10 BYC donated
    await addPoints(points, 'Donation made');
  }

  Future<void> handleCommunityPost() async {
    await addPoints(5, 'Community post');
  }

  Future<void> handleHelpfulReview() async {
    await addPoints(15, 'Helpful review');
  }

  Future<void> handleReferralSignup() async {
    await addPoints(100, 'Referral signup');
  }

  Future<void> handleDailyLogin() async {
    await addPoints(2, 'Daily login');
  }

  // Handle penalties
  Future<void> handleTradeCancellation() async {
    await subtractPoints(10, 'Trade cancellation');
  }

  Future<void> handleCommunityViolation() async {
    await subtractPoints(50, 'Community violation');
  }

  Future<void> handleFraudReport() async {
    await subtractPoints(200, 'Fraud report');
  }

  // Get achievements by category
  List<Achievement> getAchievementsByCategory(AchievementCategory category) {
    return _achievements.where((a) => a.category == category).toList();
  }

  // Get recent KARMA activities
  List<MapEntry<String, int>> getRecentActivities({int days = 7}) {
    final now = DateTime.now();
    final activities = <MapEntry<String, int>>[];
    
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i)).toString().split(' ')[0];
      final points = _pointsHistory[date] ?? 0;
      activities.add(MapEntry(date, points));
    }
    
    return activities;
  }

  // Calculate total points earned
  int get totalPointsEarned {
    return _pointsHistory.values.fold(0, (sum, points) => sum + points);
  }

  // Get level perks
  List<String> getCurrentLevelPerks() {
    return _currentLevel?.perks ?? [];
  }

  // Get next level perks
  List<String> getNextLevelPerks() {
    final nextLevel = _getNextLevel();
    return nextLevel?.perks ?? [];
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Refresh KARMA data
  Future<void> refreshKarmaData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadAchievements();
      await _loadPointsHistory();
      _updateAchievementProgress();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to refresh KARMA data: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset KARMA data (for testing)
  void resetKarmaData() {
    _currentPoints = 0;
    _currentLevel = _karmaLevels.first;
    _achievements.clear();
    _pointsHistory.clear();
    _errorMessage = null;
    notifyListeners();
  }
}