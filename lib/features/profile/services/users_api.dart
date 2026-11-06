import 'package:bybata/core/api/api_client.dart';
import 'package:bybata/core/config/env_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UsersApi {
  final ApiClient _client;

  UsersApi() : _client = ApiClient(EnvConfig.defaultBaseUrl, const FlutterSecureStorage());

  // Get active sessions
  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    final response = await _client.get('/v1/users/me/sessions');
    if (response.data is List) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  // Revoke a specific session
  Future<void> revokeSession(String sessionId) async {
    await _client.delete('/v1/users/me/sessions/$sessionId');
  }

  // Revoke all sessions
  Future<void> revokeAllSessions() async {
    await _client.delete('/v1/users/me/sessions');
  }

  // Get blocked users
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final response = await _client.get('/v1/users/me/blocked');
    if (response.data is List) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  // Block a user
  Future<void> blockUser(String userId, {String? reason}) async {
    await _client.post('/v1/users/me/block/$userId', data: {
      if (reason != null) 'reason': reason,
    });
  }

  // Unblock a user
  Future<void> unblockUser(String userId) async {
    await _client.delete('/v1/users/me/block/$userId');
  }

  // Request data download
  Future<void> requestDataDownload() async {
    await _client.post('/v1/users/me/data-export');
  }
}

