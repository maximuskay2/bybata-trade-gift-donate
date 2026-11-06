import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/karma_models.dart';
import '../services/karma_service.dart';
import '../services/karma_api_service.dart' as api;
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';

/// Provider for managing KARMA state across the app
class KarmaProvider extends ChangeNotifier {
  final KarmaService _karmaService = KarmaService();
  late api.KarmaApiService _apiService;
  
  // State variables
  int _totalKarma = 0;
  int _level = 1;
  List<KarmaTransaction> _transactions = [];
  DateTime? _lastDailyLogin;
  bool _isLoading = false;
  String? _error;

  // Getters
  int get totalKarma => _totalKarma;
  int get level => _calculateLevel(_totalKarma);
  List<KarmaTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize the provider
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Initialize API service
      final baseUrl = await EnvConfig.getBaseUrl();
      const storage = FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      _apiService = api.KarmaApiService(apiClient);
      
      // Load data from API
      await _loadDataFromApi();
      _error = null;
    } catch (e) {
      _error = 'Failed to initialize KARMA: $e';
      print('KarmaProvider Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load data from API
  Future<void> _loadDataFromApi() async {
    try {
      final karmaAccount = await _apiService.getMyKarma();
      final karmaHistory = await _apiService.getKarmaHistory();
      
      // Update state from API response
      _totalKarma = karmaAccount.currentPoints;
      _level = karmaAccount.level;
      
      // Convert API events to transactions
      _transactions = karmaHistory.events
          .map((event) => KarmaTransaction(
            id: event.id,
            points: event.points,
            type: event.type,
            description: event.reason ?? event.type,
            timestamp: event.createdAt,
          ))
          .toList();
    } catch (e) {
      throw Exception('Failed to load karma data from API: $e');
    }
  }

  /// Check if user can receive daily login bonus
  Future<bool> canAwardDailyLoginBonus() async {
    if (_lastDailyLogin == null) return true;
    
    final now = DateTime.now();
    final lastLogin = _lastDailyLogin!;
    
    // Check if more than 24 hours have passed
    final hoursSinceLastLogin = now.difference(lastLogin).inHours;
    return hoursSinceLastLogin >= 24;
  }

  /// Award daily login bonus and update last login time
  Future<void> awardDailyLoginBonus() async {
    _lastDailyLogin = DateTime.now();
    notifyListeners();
  }

  /// Add a KARMA transaction (for local tracking and UI updates)
  Future<void> addTransaction(int points, String type, String description) async {
    final transaction = KarmaTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      points: points,
      type: type,
      description: description,
      timestamp: DateTime.now(),
    );

    _transactions.insert(0, transaction);
    _totalKarma += points;

    // Keep only last 100 transactions
    if (_transactions.length > 100) {
      _transactions = _transactions.take(100).toList();
    }

    notifyListeners();
  }

  /// Calculate user level based on KARMA points
  int _calculateLevel(int karma) {
    if (karma < 100) return 1;
    if (karma < 250) return 2;
    if (karma < 500) return 3;
    if (karma < 1000) return 4;
    if (karma < 2000) return 5;
    if (karma < 3500) return 6;
    if (karma < 5000) return 7;
    if (karma < 7500) return 8;
    if (karma < 10000) return 9;
    return 10; // Max level
  }

  /// Get points needed for next level
  int getPointsForNextLevel() {
    final nextLevel = level + 1;
    if (nextLevel > 10) return 0; // Already at max level
    
    final thresholds = [0, 100, 250, 500, 1000, 2000, 3500, 5000, 7500, 10000];
    return thresholds[nextLevel] - _totalKarma;
  }

  /// Get progress to next level (0.0 to 1.0)
  double getProgressToNextLevel() {
    final nextLevel = level + 1;
    if (nextLevel > 10) return 1.0; // Already at max level
    
    final thresholds = [0, 100, 250, 500, 1000, 2000, 3500, 5000, 7500, 10000];
    final currentThreshold = thresholds[level];
    final nextThreshold = thresholds[nextLevel];
    
    return (_totalKarma - currentThreshold) / (nextThreshold - currentThreshold);
  }

  /// Check for achievements (simplified version)
  void _checkAchievements() {
    // Check milestone achievements
    if (_totalKarma >= 100 && !_hasAchievement('first_100')) {
      _unlockAchievement('first_100', 'First 100 KARMA', 'Earned your first 100 KARMA points');
    }
    
    if (_totalKarma >= 500 && !_hasAchievement('karma_500')) {
      _unlockAchievement('karma_500', 'KARMA Collector', 'Accumulated 500 KARMA points');
    }
    
    if (_totalKarma >= 1000 && !_hasAchievement('karma_1000')) {
      _unlockAchievement('karma_1000', 'KARMA Master', 'Reached 1000 KARMA points');
    }
  }

  /// Check if user has specific achievement
  bool _hasAchievement(String achievementId) {
    // This is a simplified version - in real app you'd check actual achievements
    return false;
  }

  /// Unlock achievement (placeholder)
  void _unlockAchievement(String id, String name, String description) {
    // This would unlock an actual achievement in the full implementation
    if (kDebugMode) {
      print('Achievement unlocked: $name - $description');
    }
  }

  /// Reset all KARMA data (for testing/admin purposes)
  Future<void> resetKarma() async {
    _totalKarma = 0;
    _transactions.clear();
    _lastDailyLogin = null;
    notifyListeners();
  }
}

/// Simple KARMA transaction model
class KarmaTransaction {
  final String id;
  final int points;
  final String type;
  final String description;
  final DateTime timestamp;

  KarmaTransaction({
    required this.id,
    required this.points,
    required this.type,
    required this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points,
        'type': type,
        'description': description,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory KarmaTransaction.fromJson(Map<String, dynamic> json) => KarmaTransaction(
        id: json['id'],
        points: json['points'],
        type: json['type'],
        description: json['description'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      );

  String toJsonString() => '${toJson()}';

  factory KarmaTransaction.fromJsonString(String jsonString) {
    // Simple JSON string parsing (in real app you'd use json.decode)
    final data = jsonString.replaceAll('{', '').replaceAll('}', '');
    final pairs = data.split(', ');
    final map = <String, dynamic>{};
    
    for (final pair in pairs) {
      final keyValue = pair.split(': ');
      if (keyValue.length == 2) {
        final key = keyValue[0];
        final value = keyValue[1];
        
        if (key == 'points' || key == 'timestamp') {
          map[key] = int.tryParse(value) ?? 0;
        } else {
          map[key] = value;
        }
      }
    }
    
    return KarmaTransaction.fromJson(map);
  }
}