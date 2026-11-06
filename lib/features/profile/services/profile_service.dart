import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../models/user_profile.dart';
import '../models/activity.dart';
import '../models/achievement.dart';
import 'activity_api_service.dart';

class ProfileService {
  static const String baseUrl = 'https://api.bybata.com/v1';
  
  // Mock user ID - in a real app, this would come from auth service
  static const String mockUserId = 'user_123';

  /// Get user profile by ID
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      // Mock API delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // In a real implementation, this would make an HTTP request:
      // final response = await http.get(
      //   Uri.parse('$baseUrl/users/$userId'),
      //   headers: {'Authorization': 'Bearer $token'},
      // );
      
      // For now, return mock data
      return _getMockUserProfile();
    } catch (e) {
      throw ProfileException('Failed to load user profile: $e');
    }
  }

  /// Update user profile
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    try {
      // Mock API delay
      await Future.delayed(const Duration(milliseconds: 800));
      
      // In a real implementation:
      // final response = await http.put(
      //   Uri.parse('$baseUrl/users/${profile.id}'),
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'Authorization': 'Bearer $token',
      //   },
      //   body: jsonEncode(profile.toJson()),
      // );
      
      // Return updated profile with current timestamp
      return profile.copyWith(lastActiveAt: DateTime.now());
    } catch (e) {
      throw ProfileException('Failed to update profile: $e');
    }
  }

  /// Get user activities with optional filtering
  Future<List<Activity>> getUserActivities({
    String? userId,
    ActivityFilter? filter,
  }) async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ActivityApiService(
        ApiClient(baseUrl, const FlutterSecureStorage()),
      );
      final type = filter?.types?.isNotEmpty == true
          ? filter!.types!.first.name
          : null;
      final data = await api.getUserActivity(
        page: 1,
        size: 50,
        type: type,
        forceRefresh: true,
      );
      final items = (data['items'] as List?) ?? const [];
      return api.parseActivities(items);
    } catch (e) {
      throw ProfileException('Failed to load activities: $e');
    }
  }

  /// Get user achievements
  Future<List<Achievement>> getUserAchievements(String userId) async {
    try {
      // Mock API delay
      await Future.delayed(const Duration(milliseconds: 400));
      
      // In a real implementation:
      // final response = await http.get(
      //   Uri.parse('$baseUrl/users/$userId/achievements'),
      //   headers: {'Authorization': 'Bearer $token'},
      // );
      
      return _getMockAchievements();
    } catch (e) {
      throw ProfileException('Failed to load achievements: $e');
    }
  }

  /// Upload profile picture
  Future<String> uploadProfilePicture(String filePath) async {
    try {
      // Mock API delay
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // In a real implementation:
      // var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/users/$userId/avatar'));
      // request.files.add(await http.MultipartFile.fromPath('avatar', filePath));
      // request.headers['Authorization'] = 'Bearer $token';
      // 
      // var streamedResponse = await request.send();
      // var response = await http.Response.fromStream(streamedResponse);
      
      // Return mock URL
      return 'https://api.bybata.com/uploads/avatars/user_123_${DateTime.now().millisecondsSinceEpoch}.jpg';
    } catch (e) {
      throw ProfileException('Failed to upload profile picture: $e');
    }
  }

  /// Verify user identity
  Future<VerificationStatus> submitVerificationDocuments({
    required String userId,
    required Map<VerificationType, String> documents,
  }) async {
    try {
      // Mock API delay
      await Future.delayed(const Duration(milliseconds: 1200));
      
      // In a real implementation:
      // final response = await http.post(
      //   Uri.parse('$baseUrl/users/$userId/verification'),
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'Authorization': 'Bearer $token',
      //   },
      //   body: jsonEncode({'documents': documents}),
      // );
      
      // Return mock verification status
      return VerificationStatus(
        status: VerificationStatusType.pending,
        completedVerifications: documents.keys.toList(),
      );
    } catch (e) {
      throw ProfileException('Failed to submit verification documents: $e');
    }
  }

  /// Update profile settings
  Future<ProfileSettings> updateProfileSettings(
    String userId,
    ProfileSettings settings,
  ) async {
    try {
      // Mock API delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // In a real implementation:
      // final response = await http.put(
      //   Uri.parse('$baseUrl/users/$userId/settings'),
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'Authorization': 'Bearer $token',
      //   },
      //   body: jsonEncode(settings.toJson()),
      // );
      
      return settings;
    } catch (e) {
      throw ProfileException('Failed to update settings: $e');
    }
  }

  /// Change password
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Mock API delay
      await Future.delayed(const Duration(milliseconds: 800));
      
      // In a real implementation:
      // final response = await http.put(
      //   Uri.parse('$baseUrl/users/$userId/password'),
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'Authorization': 'Bearer $token',
      //   },
      //   body: jsonEncode({
      //     'currentPassword': currentPassword,
      //     'newPassword': newPassword,
      //   }),
      // );
      
      // Success - no return value needed
    } catch (e) {
      throw ProfileException('Failed to change password: $e');
    }
  }

  /// Delete user account
  Future<void> deleteAccount(String userId) async {
    try {
      // Mock API delay
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // In a real implementation:
      // final response = await http.delete(
      //   Uri.parse('$baseUrl/users/$userId'),
      //   headers: {'Authorization': 'Bearer $token'},
      // );
      
      // Success - account deleted
    } catch (e) {
      throw ProfileException('Failed to delete account: $e');
    }
  }

  /// Request data export
  Future<void> requestDataExport(String userId) async {
    try {
      // Mock API delay
      await Future.delayed(const Duration(milliseconds: 600));
      
      // In a real implementation:
      // final response = await http.post(
      //   Uri.parse('$baseUrl/users/$userId/export'),
      //   headers: {'Authorization': 'Bearer $token'},
      // );
      
      // Success - export request submitted
    } catch (e) {
      throw ProfileException('Failed to request data export: $e');
    }
  }

  // Mock data methods
  UserProfile _getMockUserProfile() {
    return UserProfile(
      id: mockUserId,
      firstName: 'John',
      lastName: 'Doe',
      email: 'john.doe@example.com',
      phone: '+1234567890',
      bio: 'Active community member passionate about sustainable trading and helping others.',
      location: 'New York, USA',
      occupation: 'Software Engineer',
      interests: ['Technology', 'Environment', 'Community'],
      stats: ProfileStats(
        totalTrades: 23,
        successfulTrades: 21,
        totalGifts: 15,
        totalDonations: 5,
        totalCommunities: 7,
        totalFollowers: 156,
        totalFollowing: 89,
        totalPosts: 43,
        totalLikes: 234,
        averageRating: 4.8,
        totalReviews: 18,
      ),
      trustScore: TrustScore(
        score: 4.8,
        level: 5,
        badges: [
          TrustBadge(
            id: 'verified',
            name: 'Verified Member',
            description: 'Identity verified',
            icon: 'verified',
            earnedAt: DateTime.now().subtract(const Duration(days: 30)),
          ),
        ],
        lastUpdated: DateTime.now(),
      ),
      verification: VerificationStatus(
        status: VerificationStatusType.verified,
        completedVerifications: [
          VerificationType.identity,
          VerificationType.email,
          VerificationType.phone,
        ],
        verifiedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      settings: ProfileSettings(),
      createdAt: DateTime.now().subtract(const Duration(days: 365)),
      lastActiveAt: DateTime.now(),
    );
  }

  List<Activity> _getMockActivities() {
    return [
      Activity(
        id: '1',
        userId: mockUserId,
        type: ActivityType.trade,
        status: ActivityStatus.completed,
        title: 'Trade Completed',
        description: 'Traded smartphone for laptop with Alex M.',
        karmaPoints: 15,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        completedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Activity(
        id: '2',
        userId: mockUserId,
        type: ActivityType.community,
        status: ActivityStatus.completed,
        title: 'Joined Community',
        description: 'Became a member of Tech Enthusiasts',
        karmaPoints: 5,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        completedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Activity(
        id: '3',
        userId: mockUserId,
        type: ActivityType.gift,
        status: ActivityStatus.completed,
        title: 'Gift Sent',
        description: 'Sent welcome gift to new member Sarah K.',
        karmaPoints: 10,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        completedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }

  List<Achievement> _getMockAchievements() {
    return [
      Achievement(
        id: '1',
        name: 'First Trade',
        description: 'Complete your first trade',
        icon: 'trade',
        type: AchievementType.trade,
        rarity: AchievementRarity.common,
        karmaReward: 10,
        unlockedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Achievement(
        id: '2',
        name: 'Community Helper',
        description: 'Help 10 people in communities',
        icon: 'helper',
        type: AchievementType.community,
        rarity: AchievementRarity.uncommon,
        karmaReward: 40,
        unlockedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];
  }
}

/// Custom exception for profile-related operations
class ProfileException implements Exception {
  final String message;
  
  ProfileException(this.message);
  
  @override
  String toString() => 'ProfileException: $message';
}