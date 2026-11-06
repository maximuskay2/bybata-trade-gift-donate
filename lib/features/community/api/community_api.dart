import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

/// Community API service following the same pattern as CampaignApi and TradeApi
class CommunityApi {
  final Dio _dio;

  CommunityApi(ApiClient client) : _dio = client.dio;

  // ==================== Communities CRUD ====================

  /// Create a new community
  Future<Map<String, dynamic>> createCommunity({
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
    String? visibility,
    bool? requiresApproval,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _dio.post(
      '/v1/communities',
      data: {
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
        if (visibility != null) 'visibility': visibility,
        if (requiresApproval != null) 'requiresApproval': requiresApproval,
        if (settings != null) 'settings': settings,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// List communities with filters
  Future<Map<String, dynamic>> listCommunities({
    String? query,
    String? category,
    String? type,
    String? status,
    String? visibility,
    int page = 1,
    int size = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    if (query != null) params['query'] = query;
    if (category != null) params['category'] = category;
    if (type != null) params['type'] = type;
    if (status != null) params['status'] = status;
    if (visibility != null) params['visibility'] = visibility;

    final response = await _dio.get(
      '/v1/communities',
      queryParameters: params,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Get specific community details
  Future<Map<String, dynamic>> getCommunity(String communityId) async {
    final response = await _dio.get('/v1/communities/$communityId');
    return Map<String, dynamic>.from(response.data as Map);
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
    String? visibility,
    bool? requiresApproval,
    Map<String, dynamic>? settings,
  }) async {
    final response = await _dio.patch(
      '/v1/communities/$communityId',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (shortDescription != null) 'shortDescription': shortDescription,
        if (category != null) 'category': category,
        if (type != null) 'type': type,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (location != null) 'location': location,
        if (tags != null) 'tags': tags,
        if (rules != null) 'rules': rules,
        if (visibility != null) 'visibility': visibility,
        if (requiresApproval != null) 'requiresApproval': requiresApproval,
        if (settings != null) 'settings': settings,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Delete community
  Future<void> deleteCommunity(String communityId) async {
    await _dio.delete('/v1/communities/$communityId');
  }

  /// Get nearby communities within radius
  Future<Map<String, dynamic>> getNearbyCommunities({
    required double lat,
    required double lng,
    int radius = 20000, // in meters (20km)
    int page = 1,
    int size = 20,
  }) async {
    final params = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius': radius.toString(),
      'page': page.toString(),
      'size': size.toString(),
    };

    final response = await _dio.get(
      '/v1/communities/nearby',
      queryParameters: params,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Get user's joined communities
  Future<Map<String, dynamic>> getJoinedCommunities({
    int page = 1,
    int size = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    final response = await _dio.get(
      '/v1/communities/joined',
      queryParameters: params,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Get user's owned and joined communities
  Future<Map<String, dynamic>> getMyCommunities({
    int page = 1,
    int size = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    final response = await _dio.get(
      '/v1/communities/my',
      queryParameters: params,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  // ==================== Membership Management ====================

  /// Join a community
  Future<Map<String, dynamic>> joinCommunity(String communityId) async {
    final response = await _dio.post('/v1/communities/$communityId/join');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Leave a community
  Future<void> leaveCommunity(String communityId) async {
    await _dio.post('/v1/communities/$communityId/leave');
  }

  /// Check if user is a member of a community
  Future<bool> isMember(String communityId) async {
    try {
      await _dio.get('/v1/communities/$communityId/members/me');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if user is within community radius
  Future<bool> isWithinRadius(
    String communityId,
    double userLat,
    double userLng,
  ) async {
    try {
      final response = await _dio.post(
        '/v1/communities/$communityId/check-radius',
        data: {
          'lat': userLat,
          'lng': userLng,
        },
      );
      return response.data['withinRadius'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get community members
  Future<Map<String, dynamic>> getMembers(
    String communityId, {
    int page = 1,
    int size = 50,
    String? role,
    String? status,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    if (role != null) params['role'] = role;
    if (status != null) params['status'] = status;

    final response = await _dio.get(
      '/v1/communities/$communityId/members',
      queryParameters: params,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Update member role
  Future<Map<String, dynamic>> updateMemberRole(
    String communityId,
    String userId, {
    required String role,
  }) async {
    final response = await _dio.patch(
      '/v1/communities/$communityId/members/$userId',
      data: {'role': role},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Remove member from community
  Future<void> removeMember(String communityId, String userId) async {
    await _dio.delete('/v1/communities/$communityId/members/$userId');
  }

  /// Approve pending member request
  Future<Map<String, dynamic>> approveMember(
    String communityId,
    String userId,
  ) async {
    final response = await _dio.post(
      '/v1/communities/$communityId/members/$userId/approve',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Reject pending member request
  Future<void> rejectMember(String communityId, String userId) async {
    await _dio.post('/v1/communities/$communityId/members/$userId/reject');
  }

  /// Ban member from community
  Future<void> banMember(String communityId, String userId) async {
    await _dio.post('/v1/communities/$communityId/members/$userId/ban');
  }

  /// Unban member from community
  Future<void> unbanMember(String communityId, String userId) async {
    await _dio.post('/v1/communities/$communityId/members/$userId/unban');
  }

  // ==================== Posts Management ====================

  /// Get community posts
  Future<Map<String, dynamic>> getPosts(
    String communityId, {
    int page = 1,
    int size = 20,
    String? type,
    String? sortBy,
    bool? isPinned,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    if (type != null) params['type'] = type;
    if (sortBy != null) params['sortBy'] = sortBy;
    if (isPinned != null) params['isPinned'] = isPinned.toString();

    final response = await _dio.get(
      '/v1/communities/$communityId/posts',
      queryParameters: params,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Create a post
  Future<Map<String, dynamic>> createPost(
    String communityId, {
    String? title,
    String? content,
    String type = 'TEXT',
    List<String>? imageUrls,
    String? videoUrl,
    String? location,
    List<String>? tags,
    Map<String, dynamic>? pollDetails,
    Map<String, dynamic>? eventDetails,
    Map<String, dynamic>? resourceDetails,
    bool? isAnnouncement,
    bool? isPinned,
  }) async {
    final response = await _dio.post(
      '/v1/communities/$communityId/posts',
      data: {
        'type': type,
        if (title != null) 'title': title,
        if (content != null) 'content': content,
        if (imageUrls != null && imageUrls.isNotEmpty) 'imageUrls': imageUrls,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (location != null) 'location': location,
        if (tags != null) 'tags': tags,
        if (pollDetails != null) 'pollDetails': pollDetails,
        if (eventDetails != null) 'eventDetails': eventDetails,
        if (resourceDetails != null) 'resourceDetails': resourceDetails,
        if (isAnnouncement != null) 'isAnnouncement': isAnnouncement,
        if (isPinned != null) 'isPinned': isPinned,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Get specific post
  Future<Map<String, dynamic>> getPost(
    String communityId,
    String postId,
  ) async {
    final response = await _dio.get(
      '/v1/communities/$communityId/posts/$postId',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Update a post
  Future<Map<String, dynamic>> updatePost(
    String communityId,
    String postId, {
    String? title,
    String? content,
    List<String>? imageUrls,
    String? videoUrl,
    String? location,
    List<String>? tags,
    bool? isPinned,
  }) async {
    final response = await _dio.patch(
      '/v1/communities/$communityId/posts/$postId',
      data: {
        if (title != null) 'title': title,
        if (content != null) 'content': content,
        if (imageUrls != null) 'imageUrls': imageUrls,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (location != null) 'location': location,
        if (tags != null) 'tags': tags,
        if (isPinned != null) 'isPinned': isPinned,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Delete a post
  Future<void> deletePost(String communityId, String postId) async {
    await _dio.delete('/v1/communities/$communityId/posts/$postId');
  }

  /// Like a post
  Future<Map<String, dynamic>> likePost(
    String communityId,
    String postId,
  ) async {
    final response = await _dio.post(
      '/v1/communities/$communityId/posts/$postId/like',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Unlike a post
  Future<void> unlikePost(String communityId, String postId) async {
    await _dio.delete('/v1/communities/$communityId/posts/$postId/like');
  }

  /// Vote on a poll
  Future<Map<String, dynamic>> voteOnPoll(
    String communityId,
    String postId,
    String optionId,
  ) async {
    final response = await _dio.post(
      '/v1/communities/$communityId/posts/$postId/poll/vote',
      data: {'optionId': optionId},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Get post comments
  Future<Map<String, dynamic>> getComments(
    String communityId,
    String postId, {
    int page = 1,
    int size = 50,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    final response = await _dio.get(
      '/v1/communities/$communityId/posts/$postId/comments',
      queryParameters: params,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Create a comment
  Future<Map<String, dynamic>> createComment(
    String communityId,
    String postId, {
    required String content,
    String? parentCommentId,
  }) async {
    final response = await _dio.post(
      '/v1/communities/$communityId/posts/$postId/comments',
      data: {
        'content': content,
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Update a comment
  Future<Map<String, dynamic>> updateComment(
    String communityId,
    String postId,
    String commentId, {
    required String content,
  }) async {
    final response = await _dio.patch(
      '/v1/communities/$communityId/posts/$postId/comments/$commentId',
      data: {'content': content},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Delete a comment
  Future<void> deleteComment(
    String communityId,
    String postId,
    String commentId,
  ) async {
    await _dio.delete(
      '/v1/communities/$communityId/posts/$postId/comments/$commentId',
    );
  }

  /// Like a comment
  Future<Map<String, dynamic>> likeComment(
    String communityId,
    String postId,
    String commentId,
  ) async {
    final response = await _dio.post(
      '/v1/communities/$communityId/posts/$postId/comments/$commentId/like',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Unlike a comment
  Future<void> unlikeComment(
    String communityId,
    String postId,
    String commentId,
  ) async {
    await _dio.delete(
      '/v1/communities/$communityId/posts/$postId/comments/$commentId/like',
    );
  }

  // ==================== Events Management ====================

  /// Get community events
  Future<Map<String, dynamic>> getEvents(
    String communityId, {
    int page = 1,
    int size = 20,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    if (status != null) params['status'] = status;
    if (startDate != null) params['startDate'] = startDate.toIso8601String();
    if (endDate != null) params['endDate'] = endDate.toIso8601String();

    final response = await _dio.get(
      '/v1/communities/$communityId/events',
      queryParameters: params,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Create an event
  Future<Map<String, dynamic>> createEvent(
    String communityId, {
    required String title,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    String? location,
    bool isVirtual = false,
    String? virtualLink,
    int? capacity,
    Map<String, dynamic>? additionalInfo,
  }) async {
    final response = await _dio.post(
      '/v1/communities/$communityId/events',
      data: {
        'title': title,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'isVirtual': isVirtual,
        if (description != null) 'description': description,
        if (location != null) 'location': location,
        if (virtualLink != null) 'virtualLink': virtualLink,
        if (capacity != null) 'capacity': capacity,
        if (additionalInfo != null) 'additionalInfo': additionalInfo,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Get specific event
  Future<Map<String, dynamic>> getEvent(
    String communityId,
    String eventId,
  ) async {
    final response = await _dio.get(
      '/v1/communities/$communityId/events/$eventId',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Update an event
  Future<Map<String, dynamic>> updateEvent(
    String communityId,
    String eventId, {
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    bool? isVirtual,
    String? virtualLink,
    int? capacity,
    String? status,
    Map<String, dynamic>? additionalInfo,
  }) async {
    final response = await _dio.patch(
      '/v1/communities/$communityId/events/$eventId',
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
        if (location != null) 'location': location,
        if (isVirtual != null) 'isVirtual': isVirtual,
        if (virtualLink != null) 'virtualLink': virtualLink,
        if (capacity != null) 'capacity': capacity,
        if (status != null) 'status': status,
        if (additionalInfo != null) 'additionalInfo': additionalInfo,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Delete an event
  Future<void> deleteEvent(String communityId, String eventId) async {
    await _dio.delete('/v1/communities/$communityId/events/$eventId');
  }

  /// Register for an event
  Future<Map<String, dynamic>> registerForEvent(
    String communityId,
    String eventId,
  ) async {
    final response = await _dio.post(
      '/v1/communities/$communityId/events/$eventId/register',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Unregister from an event
  Future<void> unregisterFromEvent(
    String communityId,
    String eventId,
  ) async {
    await _dio.delete(
      '/v1/communities/$communityId/events/$eventId/register',
    );
  }

  /// Get event attendees
  Future<Map<String, dynamic>> getEventAttendees(
    String communityId,
    String eventId, {
    int page = 1,
    int size = 50,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    final response = await _dio.get(
      '/v1/communities/$communityId/events/$eventId/attendees',
      queryParameters: params,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  // ==================== Feed & User Communities ====================

  /// Get user feed (aggregated from joined communities)
  Future<Map<String, dynamic>> getUserFeed({
    int page = 1,
    int size = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    final response = await _dio.get(
      '/v1/communities/feed',
      queryParameters: params,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  // ==================== Moderation & Reports ====================

  /// Report a post
  Future<Map<String, dynamic>> reportPost(
    String communityId,
    String postId, {
    required String reason,
    String? description,
  }) async {
    final response = await _dio.post(
      '/v1/communities/$communityId/posts/$postId/report',
      data: {
        'reason': reason,
        if (description != null) 'description': description,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Report a comment
  Future<Map<String, dynamic>> reportComment(
    String communityId,
    String postId,
    String commentId, {
    required String reason,
    String? description,
  }) async {
    final response = await _dio.post(
      '/v1/communities/$communityId/posts/$postId/comments/$commentId/report',
      data: {
        'reason': reason,
        if (description != null) 'description': description,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Get reported content for moderation
  Future<Map<String, dynamic>> getReports(
    String communityId, {
    int page = 1,
    int size = 20,
    String? status,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    if (status != null) params['status'] = status;

    final response = await _dio.get(
      '/v1/communities/$communityId/reports',
      queryParameters: params,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Resolve a report
  Future<Map<String, dynamic>> resolveReport(
    String communityId,
    String reportId, {
    required String action, // 'approve', 'reject', 'remove'
    String? note,
  }) async {
    final response = await _dio.post(
      '/v1/communities/$communityId/reports/$reportId/resolve',
      data: {
        'action': action,
        if (note != null) 'note': note,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}

