import '../../../core/api/api_client.dart';

class AchievementsApiService {
  final ApiClient _apiClient;

  AchievementsApiService(this._apiClient);

  /// Fetch user achievements (unlocked and locked)
  Future<Map<String, dynamic>> getUserAchievements() async {
    try {
      final response = await _apiClient.get('/v1/karma/achievements');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to fetch user achievements: $e');
    }
  }

  /// Get all available achievements (for discovery)
  Future<List<dynamic>> getAllAchievements() async {
    try {
      final response = await _apiClient.get('/v1/karma/achievements/all');
      return response.data is List 
        ? response.data as List<dynamic>
        : [];
    } catch (e) {
      throw Exception('Failed to fetch all achievements: $e');
    }
  }

  /// Claim an achievement reward
  Future<Map<String, dynamic>> claimAchievement(String achievementId) async {
    try {
      final response = await _apiClient.post(
        '/v1/karma/achievements/$achievementId/claim',
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to claim achievement: $e');
    }
  }

  /// Parse achievement response to get stats
  Map<String, dynamic> parseAchievementStats(Map<String, dynamic> data) {
    final unlocked = (data['unlocked'] as List?) ?? [];
    final locked = (data['locked'] as List?) ?? [];
    final total = unlocked.length + locked.length;
    final percentage = total > 0 
        ? ((unlocked.length / total) * 100).round()
        : 0;

    return {
      'unlocked': unlocked,
      'locked': locked,
      'total': total,
      'unlockedCount': unlocked.length,
      'lockedCount': locked.length,
      'percentage': percentage,
    };
  }
}
