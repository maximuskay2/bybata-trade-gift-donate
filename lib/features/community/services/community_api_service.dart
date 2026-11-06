/// Community API Service
library;

import 'dart:math';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../models/community_api.dart';

/// Service for handling community API interactions
class CommunityApiService {
  final ApiClient _apiClient;

  CommunityApiService(this._apiClient);

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c; // Distance in kilometers
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Get communities from API
  Future<List<CommunityApi>> getCommunitiesFromApi({
    int page = 1,
    int size = 20,
    String? category,
    String? type,
    String? query,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'size': size,
      };
      if (category != null) queryParams['category'] = category;
      if (type != null) queryParams['type'] = type;
      if (query != null) queryParams['query'] = query;

      final response = await _apiClient.get('/v1/communities', queryParameters: queryParams);
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> items = data['items'] ?? data['data'] ?? [];
        return items.map((json) => CommunityApi.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load communities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading communities: $e');
    }
  }

  /// Get single community from API
  Future<CommunityApi> getCommunityFromApi(String communityId) async {
    try {
      final response = await _apiClient.get('/v1/communities/$communityId');
      if (response.statusCode == 200) {
        final data = response.data;
        return CommunityApi.fromJson(data);
      } else {
        throw Exception('Failed to load community: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading community: $e');
    }
  }

  /// Get community details with members, posts, etc.
  Future<Map<String, dynamic>> getCommunityDetails(String communityId) async {
    try {
      final response = await _apiClient.get('/v1/communities/$communityId');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to load community details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading community details: $e');
    }
  }

  /// Create community via API
  Future<Map<String, dynamic>> createCommunityViaApi({
    required String name,
    String? description,
    String? shortDescription,
    String? category,
    String? type,
    double? centerLatitude,
    double? centerLongitude,
    String? imageUrl,
    String? location,
    List<String>? tags,
    String? rules,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        if (description != null) 'description': description,
        if (shortDescription != null) 'shortDescription': shortDescription,
        if (category != null) 'category': category,
        if (type != null) 'type': type,
        if (centerLatitude != null) 'center_latitude': centerLatitude,
        if (centerLongitude != null) 'center_longitude': centerLongitude,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (location != null) 'location': location,
        if (tags != null) 'tags': tags,
        if (rules != null) 'rules': rules,
      };

      final response = await _apiClient.post('/v1/communities', data: body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        return {'id': data?.toString()};
      } else {
        throw Exception('Failed to create community: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating community: $e');
    }
  }

  /// Update community
  Future<Map<String, dynamic>> updateCommunity(
    String communityId, {
    String? name,
    String? description,
    String? shortDescription,
    String? category,
    String? type,
    String? imageUrl,
    String? location,
    List<String>? tags,
    String? rules,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (shortDescription != null) body['shortDescription'] = shortDescription;
      if (category != null) body['category'] = category;
      if (type != null) body['type'] = type;
      if (imageUrl != null) body['imageUrl'] = imageUrl;
      if (location != null) body['location'] = location;
      if (tags != null) body['tags'] = tags;
      if (rules != null) body['rules'] = rules;

      final response = await _apiClient.patch('/v1/communities/$communityId', data: body);
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception('Error updating community: $e');
    }
  }

  /// Delete community
  Future<void> deleteCommunity(String communityId) async {
    try {
      await _apiClient.delete('/v1/communities/$communityId');
    } catch (e) {
      throw Exception('Error deleting community: $e');
    }
  }

  /// Get nearby communities within radius
  Future<List<CommunityApi>> getNearbyCommunitiesFromApi(
    double lat,
    double lng, {
    int radius = 20000, // in meters (20km)
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get('/v1/communities/nearby', queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius': radius.toString(),
        'page': page.toString(),
        'size': size.toString(),
      });
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> items = data['items'] ?? data['data'] ?? [];
        return items.map((json) => CommunityApi.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load nearby communities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading nearby communities: $e');
    }
  }

  /// Get user's joined communities
  Future<List<CommunityApi>> getJoinedCommunitiesFromApi({
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get('/v1/communities/joined', queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
      });
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> items = data['items'] ?? data['data'] ?? [];
        return items.map((json) => CommunityApi.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load joined communities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading joined communities: $e');
    }
  }

  /// Join community via API
  Future<Map<String, dynamic>> joinCommunityViaApi(
    String communityId, {
    String? inviteCode,
  }) async {
    try {
      final response = await _apiClient.post(
        '/v1/communities/$communityId/join',
        data: {
          if (inviteCode != null && inviteCode.isNotEmpty) 'inviteCode': inviteCode,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to join community: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // Handle "already a member" case gracefully
      if (e.response?.statusCode == 400) {
        final errorMessage = e.response?.data?['message'] ?? '';
        if (errorMessage.contains('Already a member') || errorMessage.contains('already a member')) {
          // User is already a member, return success
          return {'success': true, 'message': 'Already a member'};
        }
      }
      rethrow;
    } catch (e) {
      throw Exception('Error joining community: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPendingJoinRequests(
    String communityId, {
    int page = 1,
    int size = 20,
  }) async {
    final response = await _apiClient.get(
      '/v1/communities/$communityId/join-requests',
      queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
      },
    );
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getPendingJoinRequestsMeta(
    String communityId, {
    int page = 1,
    int size = 20,
  }) async {
    final response = await _apiClient.get(
      '/v1/communities/$communityId/join-requests',
      queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> approveJoinRequest(
    String communityId,
    String memberId,
  ) async {
    final response = await _apiClient.post(
      '/v1/communities/$communityId/join-requests/$memberId/approve',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> rejectJoinRequest(
    String communityId,
    String memberId, {
    String? reason,
  }) async {
    final response = await _apiClient.post(
      '/v1/communities/$communityId/join-requests/$memberId/reject',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> inviteMembers(
    String communityId, {
    List<String>? userIds,
    List<String>? emails,
    List<String>? usernames,
    String? message,
    DateTime? expiresAt,
    String? templateKey,
  }) async {
    final response = await _apiClient.post(
      '/v1/communities/$communityId/invite',
      data: {
        if (userIds != null && userIds.isNotEmpty) 'userIds': userIds,
        if (emails != null && emails.isNotEmpty) 'emails': emails,
        if (usernames != null && usernames.isNotEmpty) 'usernames': usernames,
        if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
        if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
        if (templateKey != null && templateKey.trim().isNotEmpty) 'templateKey': templateKey.trim(),
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> revokeInvite(
    String communityId, {
    String? userId,
    String? inviteId,
    String? email,
  }) async {
    final response = await _apiClient.post(
      '/v1/communities/$communityId/invite/revoke',
      data: {
        if (userId != null) 'userId': userId,
        if (inviteId != null) 'inviteId': inviteId,
        if (email != null) 'email': email,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> resendInvite(
    String communityId, {
    String? inviteId,
    List<String>? inviteIds,
    String? templateKey,
  }) async {
    final response = await _apiClient.post(
      '/v1/communities/$communityId/invite/resend',
      data: {
        if (inviteId != null) 'inviteId': inviteId,
        if (inviteIds != null && inviteIds.isNotEmpty) 'inviteIds': inviteIds,
        if (templateKey != null && templateKey.trim().isNotEmpty) 'templateKey': templateKey.trim(),
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> acceptInvite(String communityId) async {
    final response = await _apiClient.post(
      '/v1/communities/$communityId/invite/accept',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> acceptInviteByCode(String code) async {
    final response = await _apiClient.post(
      '/v1/communities/invite/accept-code',
      data: {'code': code},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> declineInvite(String communityId) async {
    final response = await _apiClient.post(
      '/v1/communities/$communityId/invite/decline',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> lookupInvite(String code) async {
    final response = await _apiClient.get(
      '/v1/communities/invite/lookup',
      queryParameters: {'code': code},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> getMyInvites() async {
    final response = await _apiClient.get('/v1/communities/invites');
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getCommunityInvites(String communityId) async {
    final response = await _apiClient.get('/v1/communities/$communityId/invites');
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Leave community via API
  Future<void> leaveCommunityViaApi(String communityId) async {
    try {
      await _apiClient.post('/v1/communities/$communityId/leave');
    } catch (e) {
      throw Exception('Error leaving community: $e');
    }
  }

  /// Get community members
  Future<List<Map<String, dynamic>>> getCommunityMembersFromApi(
    String communityId, {
    int page = 1,
    int size = 50,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/communities/$communityId/members',
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
        },
      );
      if (response.statusCode == 200) {
        final data = response.data;
        // API returns members at root level or in items/data
        final List<dynamic> items = data['members'] ?? data['items'] ?? data['data'] ?? [];
        return items.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        throw Exception('Failed to load members: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading members: $e');
    }
  }

  /// Check if user is member of community
  Future<bool> isUserMemberOfCommunity(String communityId) async {
    try {
      final response = await _apiClient.get('/v1/communities/$communityId/members/me');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['isMember'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if user is within community radius
  Future<bool> isUserWithinCommunityRadius(
    String communityId,
    double userLat,
    double userLng,
  ) async {
    try {
      final response = await _apiClient.get('/v1/communities/$communityId');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final centerLat = (data['centerLatitude'] as num?)?.toDouble();
        final centerLng = (data['centerLongitude'] as num?)?.toDouble();
        
        // If community doesn't have coordinates, assume user is in range
        if (centerLat == null || centerLng == null) {
          return true;
        }
        
        // Calculate distance using haversine formula
        final distance = _calculateDistance(userLat, userLng, centerLat, centerLng);
        return distance <= 20.0; // 20km radius
      }
    } catch (e) {
      // If there's an error fetching community data, assume user is in range
      return true;
    }
    return true;
  }

  /// Get community posts
  Future<List<Map<String, dynamic>>> getCommunityPostsFromApi(
    String communityId, {
    int page = 1,
    int size = 20,
    String? type,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'size': size.toString(),
      };
      if (type != null) queryParams['type'] = type;

      final response = await _apiClient.get(
        '/v1/communities/$communityId/posts',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> items = data['items'] ?? data['data'] ?? [];
        return items.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        throw Exception('Failed to load posts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading posts: $e');
    }
  }

  /// Create post via API
  Future<Map<String, dynamic>> createPostViaApi({
    required String communityId,
    String? title,
    String? content,
    String type = 'TEXT',
    List<String>? images,
    String? videoUrl,
    String? location,
    List<String>? tags,
    Map<String, dynamic>? pollData,
    Map<String, dynamic>? eventData,
    Map<String, dynamic>? resourceData,
  }) async {
    try {
      final body = <String, dynamic>{
        'communityId': communityId,
        'type': type,
        if (title != null) 'title': title,
        if (content != null) 'content': content,
        if (images != null && images.isNotEmpty) 'imageUrls': images,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (location != null) 'location': location,
        if (tags != null) 'tags': tags,
        if (pollData != null) 'pollDetails': pollData,
        if (eventData != null) 'eventDetails': eventData,
        if (resourceData != null) 'resourceDetails': resourceData,
      };

      final response = await _apiClient.post('/v1/communities/$communityId/posts', data: body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to create post: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating post: $e');
    }
  }

  /// Like a post
  Future<void> likePost(String communityId, String postId) async {
    try {
      await _apiClient.post('/v1/communities/$communityId/posts/$postId/like');
    } catch (e) {
      throw Exception('Error liking post: $e');
    }
  }

  /// Unlike a post
  Future<void> unlikePost(String communityId, String postId) async {
    try {
      await _apiClient.delete('/v1/communities/$communityId/posts/$postId/like');
    } catch (e) {
      throw Exception('Error unliking post: $e');
    }
  }

  /// Get post comments
  Future<List<Map<String, dynamic>>> getPostComments(
    String communityId,
    String postId, {
    int page = 1,
    int size = 50,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/communities/$communityId/posts/$postId/comments',
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
        },
      );
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> items = data['items'] ?? data['data'] ?? [];
        return items.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        throw Exception('Failed to load comments: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading comments: $e');
    }
  }

  /// Create post comment
  Future<Map<String, dynamic>> createPostComment({
    required String communityId,
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final body = <String, dynamic>{
        'content': content,
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
      };

      final response = await _apiClient.post(
        '/v1/communities/$communityId/posts/$postId/comments',
        data: body,
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to create comment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating comment: $e');
    }
  }

  /// Get community events
  Future<List<Map<String, dynamic>>> getCommunityEventsFromApi(
    String communityId, {
    int page = 1,
    int size = 20,
    String? status,
    bool? upcoming,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'size': size.toString(),
      };
      if (status != null) {
        queryParams['status'] = status;
      } else if (upcoming != null) {
        queryParams['upcoming'] = upcoming.toString();
      }

      final response = await _apiClient.get(
        '/v1/communities/$communityId/events',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> items = data['items'] ?? data['data'] ?? [];
        return items.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        throw Exception('Failed to load events: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading events: $e');
    }
  }

  /// Create event via API
  Future<Map<String, dynamic>> createEventViaApi({
    required String communityId,
    required String title,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    String? location,
    bool isVirtual = false,
    String? virtualLink,
    int? capacity,
    List<String>? imageUrls,
    String? videoUrl,
    Map<String, dynamic>? additionalInfo,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'isVirtual': isVirtual,
        if (description != null) 'description': description,
        if (location != null) 'location': location,
        if (virtualLink != null) 'virtualLink': virtualLink,
        if (capacity != null) 'capacity': capacity,
        if (imageUrls != null && imageUrls.isNotEmpty) 'imageUrls': imageUrls,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (additionalInfo != null) 'additionalInfo': additionalInfo,
      };

      final response = await _apiClient.post('/v1/communities/$communityId/events', data: body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to create event: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating event: $e');
    }
  }

  /// Register for event
  Future<Map<String, dynamic>> registerForEventViaApi(
    String communityId,
    String eventId,
  ) async {
    try {
      final response = await _apiClient.post(
        '/v1/communities/events/$eventId/register',
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Failed to register for event: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error registering for event: $e');
    }
  }

  /// Unregister from event
  Future<void> unregisterFromEventViaApi(String communityId, String eventId) async {
    try {
      await _apiClient.delete('/v1/communities/events/$eventId/register');
    } catch (e) {
      throw Exception('Error unregistering from event: $e');
    }
  }

  /// Update member role
  Future<void> updateMemberRole(
    String communityId,
    String userId, {
    required String role,
  }) async {
    try {
      await _apiClient.patch(
        '/v1/communities/$communityId/members/$userId',
        data: {'role': role},
      );
    } catch (e) {
      throw Exception('Error updating member role: $e');
    }
  }

  /// Remove member from community
  Future<void> removeMember(String communityId, String userId) async {
    try {
      await _apiClient.delete('/v1/communities/$communityId/members/$userId');
    } catch (e) {
      throw Exception('Error removing member: $e');
    }
  }

  /// Get user's communities (owned and joined)
  Future<List<CommunityApi>> getUserCommunities({
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get('/v1/communities/my', queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
      });
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> items = data['items'] ?? data['data'] ?? [];
        return items.map((json) => CommunityApi.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load user communities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading user communities: $e');
    }
  }

  /// Get user feed (aggregated from joined communities)
  Future<List<Map<String, dynamic>>> getUserFeed({
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.get('/v1/communities/feed', queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
      });
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> items = data['items'] ?? data['data'] ?? [];
        return items.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        throw Exception('Failed to load feed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading feed: $e');
    }
  }
}

