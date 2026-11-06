import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';

/// Follow / unfollow and follow-status helpers for user profiles.
class UserSocialService {
  UserSocialService._();
  static final UserSocialService instance = UserSocialService._();

  Future<ApiClient> _client() async {
    final baseUrl = await EnvConfig.getBaseUrl();
    return ApiClient(baseUrl, const FlutterSecureStorage());
  }

  Future<bool> isFollowing(String userId) async {
    try {
      final client = await _client();
      final response = await client.get('/v1/users/$userId/follow-status');
      final data = response.data as Map<String, dynamic>;
      return data['isFollowing'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> follow(String userId) async {
    final client = await _client();
    await client.post('/v1/users/$userId/follow');
  }

  Future<void> unfollow(String userId) async {
    final client = await _client();
    await client.delete('/v1/users/$userId/follow');
  }

  Future<({int followers, int following})> getFollowCounts(String userId) async {
    try {
      final client = await _client();
      final response = await client.get('/v1/users/$userId');
      final data = response.data as Map<String, dynamic>;
      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      return (
        followers: (profile['followersCount'] as num?)?.toInt() ?? 0,
        following: (profile['followingCount'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return (followers: 0, following: 0);
    }
  }

  Future<({int followers, int following, int donatedByc, int donatedKarma})>
      getProfileSocialStats(String userId) async {
    try {
      final client = await _client();
      final response = await client.get('/v1/users/$userId');
      final data = response.data as Map<String, dynamic>;
      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      return (
        followers: (profile['followersCount'] as num?)?.toInt() ?? 0,
        following: (profile['followingCount'] as num?)?.toInt() ?? 0,
        donatedByc: (profile['donatedByc'] as num?)?.toInt() ?? 0,
        donatedKarma: (profile['donatedKarma'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return (followers: 0, following: 0, donatedByc: 0, donatedKarma: 0);
    }
  }

  Future<({int followers, int following, int donatedByc, int donatedKarma})>
      getMyProfileSocialStats() async {
    try {
      final client = await _client();
      final response = await client.dio.get('/v1/users/me');
      final data = response.data as Map<String, dynamic>;
      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      return (
        followers: (profile['followersCount'] as num?)?.toInt() ?? 0,
        following: (profile['followingCount'] as num?)?.toInt() ?? 0,
        donatedByc: (profile['donatedByc'] as num?)?.toInt() ?? 0,
        donatedKarma: (profile['donatedKarma'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return (followers: 0, following: 0, donatedByc: 0, donatedKarma: 0);
    }
  }
}
