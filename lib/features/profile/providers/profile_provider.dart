import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../models/activity.dart';
import '../models/achievement.dart';
import '../services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileService _profileService = ProfileService();

  // Current user profile
  UserProfile? _currentUserProfile;
  UserProfile? get currentUserProfile => _currentUserProfile;

  // User activities
  List<Activity> _userActivities = [];
  List<Activity> get userActivities => _userActivities;

  // User achievements
  List<Achievement> _userAchievements = [];
  List<Achievement> get userAchievements => _userAchievements;

  // Loading states
  bool _isLoadingProfile = false;
  bool _isLoadingActivities = false;
  bool _isLoadingAchievements = false;
  bool _isUpdatingProfile = false;

  bool get isLoadingProfile => _isLoadingProfile;
  bool get isLoadingActivities => _isLoadingActivities;
  bool get isLoadingAchievements => _isLoadingAchievements;
  bool get isUpdatingProfile => _isUpdatingProfile;

  // Error handling
  String? _error;
  String? get error => _error;

  /// Initialize provider and load current user profile
  Future<void> initialize({String? userId}) async {
    await loadUserProfile(userId ?? ProfileService.mockUserId);
  }

  /// Load user profile
  Future<void> loadUserProfile(String userId) async {
    _isLoadingProfile = true;
    _error = null;
    notifyListeners();

    try {
      _currentUserProfile = await _profileService.getUserProfile(userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error loading profile: $e');
      }
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile(UserProfile updatedProfile) async {
    _isUpdatingProfile = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _profileService.updateUserProfile(updatedProfile);
      _currentUserProfile = updated;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error updating profile: $e');
      }
      notifyListeners();
      return false;
    } finally {
      _isUpdatingProfile = false;
      notifyListeners();
    }
  }

  /// Update profile settings
  Future<bool> updateProfileSettings(ProfileSettings settings) async {
    if (_currentUserProfile == null) return false;

    _isUpdatingProfile = true;
    _error = null;
    notifyListeners();

    try {
      await _profileService.updateProfileSettings(_currentUserProfile!.id, settings);
      _currentUserProfile = _currentUserProfile!.copyWith(settings: settings);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error updating settings: $e');
      }
      notifyListeners();
      return false;
    } finally {
      _isUpdatingProfile = false;
      notifyListeners();
    }
  }

  /// Upload profile picture
  Future<bool> uploadProfilePicture(String filePath) async {
    if (_currentUserProfile == null) return false;

    _isUpdatingProfile = true;
    _error = null;
    notifyListeners();

    try {
      final avatarUrl = await _profileService.uploadProfilePicture(filePath);
      _currentUserProfile = _currentUserProfile!.copyWith(avatar: avatarUrl);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error uploading profile picture: $e');
      }
      notifyListeners();
      return false;
    } finally {
      _isUpdatingProfile = false;
      notifyListeners();
    }
  }

  /// Load user activities
  Future<void> loadUserActivities({
    String? userId,
    ActivityFilter? filter,
  }) async {
    _isLoadingActivities = true;
    _error = null;
    notifyListeners();

    try {
      _userActivities = await _profileService.getUserActivities(
        userId: userId ?? _currentUserProfile?.id,
        filter: filter,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error loading activities: $e');
      }
    } finally {
      _isLoadingActivities = false;
      notifyListeners();
    }
  }

  /// Load user achievements
  Future<void> loadUserAchievements({String? userId}) async {
    _isLoadingAchievements = true;
    _error = null;
    notifyListeners();

    try {
      _userAchievements = await _profileService.getUserAchievements(
        userId ?? _currentUserProfile?.id ?? ProfileService.mockUserId,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error loading achievements: $e');
      }
    } finally {
      _isLoadingAchievements = false;
      notifyListeners();
    }
  }

  /// Submit verification documents
  Future<bool> submitVerificationDocuments(
    Map<VerificationType, String> documents,
  ) async {
    if (_currentUserProfile == null) return false;

    _isUpdatingProfile = true;
    _error = null;
    notifyListeners();

    try {
      final verificationStatus = await _profileService.submitVerificationDocuments(
        userId: _currentUserProfile!.id,
        documents: documents,
      );

      _currentUserProfile = _currentUserProfile!.copyWith(
        verification: verificationStatus,
      );
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error submitting verification: $e');
      }
      notifyListeners();
      return false;
    } finally {
      _isUpdatingProfile = false;
      notifyListeners();
    }
  }

  /// Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUserProfile == null) return false;

    _isUpdatingProfile = true;
    _error = null;
    notifyListeners();

    try {
      await _profileService.changePassword(
        userId: _currentUserProfile!.id,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error changing password: $e');
      }
      notifyListeners();
      return false;
    } finally {
      _isUpdatingProfile = false;
      notifyListeners();
    }
  }

  /// Request data export
  Future<bool> requestDataExport() async {
    if (_currentUserProfile == null) return false;

    try {
      await _profileService.requestDataExport(_currentUserProfile!.id);
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error requesting data export: $e');
      }
      notifyListeners();
      return false;
    }
  }

  /// Delete account
  Future<bool> deleteAccount() async {
    if (_currentUserProfile == null) return false;

    _isUpdatingProfile = true;
    _error = null;
    notifyListeners();

    try {
      await _profileService.deleteAccount(_currentUserProfile!.id);
      _currentUserProfile = null;
      _userActivities.clear();
      _userAchievements.clear();
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error deleting account: $e');
      }
      notifyListeners();
      return false;
    } finally {
      _isUpdatingProfile = false;
      notifyListeners();
    }
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh all profile data
  Future<void> refreshAll() async {
    if (_currentUserProfile == null) return;

    await Future.wait([
      loadUserProfile(_currentUserProfile!.id),
      loadUserActivities(),
      loadUserAchievements(),
    ]);
  }

  /// Get filtered activities
  List<Activity> getFilteredActivities(ActivityFilter? filter) {
    if (filter == null) return _userActivities;

    return _userActivities.where((activity) {
      // Apply type filter
      if (filter.types != null && !filter.types!.contains(activity.type)) {
        return false;
      }

      // Apply status filter
      if (filter.statuses != null && !filter.statuses!.contains(activity.status)) {
        return false;
      }

      // Apply date range filter
      if (filter.startDate != null && activity.createdAt.isBefore(filter.startDate!)) {
        return false;
      }
      if (filter.endDate != null && activity.createdAt.isAfter(filter.endDate!)) {
        return false;
      }

      // Apply search query
      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        final query = filter.searchQuery!.toLowerCase();
        if (!activity.title.toLowerCase().contains(query) &&
            !activity.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Get filtered achievements
  List<Achievement> getFilteredAchievements({
    AchievementType? type,
    bool? unlockedOnly,
  }) {
    return _userAchievements.where((achievement) {
      if (type != null && achievement.type != type) {
        return false;
      }
      if (unlockedOnly == true && !achievement.isUnlocked) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Get achievement statistics
  Map<String, dynamic> getAchievementStats() {
    final total = _userAchievements.length;
    final unlocked = _userAchievements.where((a) => a.isUnlocked).length;
    final totalKarma = _userAchievements
        .where((a) => a.isUnlocked)
        .fold(0, (sum, a) => sum + a.karmaReward);

    return {
      'total': total,
      'unlocked': unlocked,
      'locked': total - unlocked,
      'completionRate': total > 0 ? (unlocked / total * 100).round() : 0,
      'totalKarmaEarned': totalKarma,
    };
  }

  /// Get activity statistics
  Map<String, dynamic> getActivityStats() {
    final total = _userActivities.length;
    final completed = _userActivities
        .where((a) => a.status == ActivityStatus.completed)
        .length;
    final totalKarma = _userActivities
        .where((a) => a.karmaPoints != null)
        .fold(0, (sum, a) => sum + a.karmaPoints!);

    return {
      'total': total,
      'completed': completed,
      'pending': _userActivities
          .where((a) => a.status == ActivityStatus.pending)
          .length,
      'completionRate': total > 0 ? (completed / total * 100).round() : 0,
      'totalKarmaEarned': totalKarma,
    };
  }

  /// Update user stats (called from external services)
  void updateUserStats(ProfileStats newStats) {
    if (_currentUserProfile == null) return;

    _currentUserProfile = _currentUserProfile!.copyWith(stats: newStats);
    notifyListeners();
  }

  /// Update verification status (called from external services)
  void updateVerificationStatus(VerificationStatus newStatus) {
    if (_currentUserProfile == null) return;

    _currentUserProfile = _currentUserProfile!.copyWith(verification: newStatus);
    notifyListeners();
  }

  /// Add new activity (called from external services)
  void addActivity(Activity activity) {
    _userActivities.insert(0, activity);
    notifyListeners();
  }

  /// Unlock achievement (called from external services)
  void unlockAchievement(String achievementId) {
    final index = _userAchievements.indexWhere((a) => a.id == achievementId);
    if (index != -1 && !_userAchievements[index].isUnlocked) {
      _userAchievements[index] = _userAchievements[index].copyWith(
        unlockedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }
}