import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_timeouts.dart';

class GiftApi {
  final ApiClient _apiClient;
  
  GiftApi(this._apiClient);

  /// Create a new gift
  Future<Map<String, dynamic>> createGift({
    required String title,
    String? description,
    String? type,
    String? category,
    String? mediaType,
    List<String>? mediaKeys,
    String? videoKey,
    String? thumbnailKey,
    int? karmaReward,
    int? maxClaims,
    String? location,
    bool? isLocationRestricted,
    bool? isChainGift,
    String? chainParentId,
    String? targetUserId,
    Map<String, dynamic>? targetCriteria,
    String? minimumKarmaLevel,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    double? latitude,
    double? longitude,
    DateTime? expiresAt,
    bool isSeedingListing = false,
  }) async {
    final response = await _apiClient.dio.post(
      '/v1/gifts',
      data: {
      'title': title,
      if (description != null) 'description': description,
      if (type != null) 'type': type,
      if (category != null) 'category': category,
      if (mediaType != null) 'mediaType': mediaType,
      if (mediaKeys != null) 'mediaKeys': mediaKeys,
      if (videoKey != null) 'videoKey': videoKey,
      if (thumbnailKey != null) 'thumbnailKey': thumbnailKey,
      if (karmaReward != null) 'karmaReward': karmaReward,
      if (maxClaims != null) 'maxClaims': maxClaims,
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (isLocationRestricted != null) 'isLocationRestricted': isLocationRestricted,
      if (isChainGift != null) 'isChainGift': isChainGift,
      if (chainParentId != null) 'chainParentId': chainParentId,
      if (targetUserId != null) 'targetUserId': targetUserId,
      if (targetCriteria != null) 'targetCriteria': targetCriteria,
      if (minimumKarmaLevel != null) 'minimumKarmaLevel': minimumKarmaLevel,
      if (tags != null) 'tags': tags,
      if (metadata != null) 'metadata': metadata,
      if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
      if (isSeedingListing) 'isSeedingListing': true,
      },
      options: Options(receiveTimeout: ApiTimeouts.listingWrite),
    );
    return Map<String, dynamic>.from(response.data);
  }

  /// List gifts with filters
  Future<Map<String, dynamic>> listGifts({
    String? query,
    String? category,
    String? type,
    String? status,
    String? giverId,
    String? location,
    int? minKarma,
    int? maxKarma,
    String? sortBy,
    String? sortOrder,
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
    if (giverId != null) params['giverId'] = giverId;
    if (location != null) params['location'] = location;
    if (minKarma != null) params['minKarma'] = minKarma.toString();
    if (maxKarma != null) params['maxKarma'] = maxKarma.toString();
    if (sortBy != null) params['sortBy'] = sortBy;
    if (sortOrder != null) params['sortOrder'] = sortOrder;

    try {
      final response = await _apiClient.dio.get('/v1/gifts', queryParameters: params);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (giverId != null) rethrow;
      final status = e.response?.statusCode;
      // Auth missing OR server browse failure → public feed still works.
      if (status == 401 ||
          status == 403 ||
          (status != null && status >= 500)) {
        final response = await _apiClient.dio.get(
          '/v1/public/browse/gifts',
          queryParameters: params,
        );
        return response.data as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  /// Get specific gift details.
  ///
  /// Tries the authenticated endpoint first (richer payload: isLiked,
  /// requestStatus, etc.), and falls back to the public browse endpoint
  /// on 401/403 so unauthenticated browse-home visitors can still open
  /// gift cards without being forced to sign in.
  Future<Map<String, dynamic>> getGift(String giftId) async {
    try {
      final response = await _apiClient.dio.get('/v1/gifts/$giftId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        final response = await _apiClient.dio.get('/v1/public/browse/gifts/$giftId');
        return response.data as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  /// Get similar gifts (same category and type)
  Future<List<Map<String, dynamic>>> getSimilarGifts(String giftId, {int limit = 8}) async {
    final response = await _apiClient.dio.get(
      '/v1/gifts/$giftId/similar',
      queryParameters: {'limit': limit},
    );
    final list = response.data;
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Increment gift view count (call when user opens gift details)
  Future<Map<String, dynamic>> incrementGiftView(String giftId) async {
    final response = await _apiClient.dio.post('/v1/gifts/$giftId/view');
    return response.data as Map<String, dynamic>;
  }

  /// Update gift
  Future<Map<String, dynamic>> updateGift(String giftId, {
    String? title,
    String? description,
    String? mediaType,
    List<String>? mediaKeys,
    String? videoKey,
    String? thumbnailKey,
    int? karmaReward,
    int? maxClaims,
    String? location,
    List<String>? tags,
    DateTime? expiresAt,
  }) async {
    final response = await _apiClient.dio.patch('/v1/gifts/$giftId', data: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (mediaType != null) 'mediaType': mediaType,
      if (mediaKeys != null) 'mediaKeys': mediaKeys,
      if (videoKey != null || mediaType == 'IMAGE') 'videoKey': videoKey,
      if (thumbnailKey != null) 'thumbnailKey': thumbnailKey,
      if (karmaReward != null) 'karmaReward': karmaReward,
      if (maxClaims != null) 'maxClaims': maxClaims,
      if (location != null) 'location': location,
      if (tags != null) 'tags': tags,
      if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
    });
    
    return response.data as Map<String, dynamic>;
  }

  /// Cancel a gift
  Future<Map<String, dynamic>> cancelGift(String giftId) async {
    final response = await _apiClient.dio.post('/v1/gifts/$giftId/cancel');
    return response.data as Map<String, dynamic>;
  }

  /// Permanently delete a gift (only when no claims/requests).
  Future<void> deleteGift(String giftId) async {
    await _apiClient.dio.delete('/v1/gifts/$giftId');
  }

  /// Claim a gift
  ///
  /// Uses relaxed validateStatus so we can surface backend error messages
  /// (e.g. "Request already pending for this gift") instead of a generic
  /// DioException. Callers should catch and display the thrown Exception.
  Future<Map<String, dynamic>> claimGift(String giftId, {String? claimCode}) async {
    try {
      final response = await _apiClient.dio.post(
        '/v1/gifts/$giftId/claim',
        data: {
          if (claimCode != null) 'claimCode': claimCode,
        },
        options: Options(
          receiveTimeout: ApiTimeouts.listingWrite,
          // Let us inspect non-2xx responses instead of throwing directly
          validateStatus: (_) => true,
        ),
      );

      final status = response.statusCode ?? 0;
      if (status >= 400) {
        final data = response.data;
        String serverMessage = '';

        if (data is Map<String, dynamic>) {
          final m = data['message'];
          if (m is String) serverMessage = m;
          if (serverMessage.isEmpty && data['error'] is String) {
            serverMessage = data['error'] as String;
          }
        } else if (data is String) {
          serverMessage = data;
        }

        throw Exception(
          serverMessage.isNotEmpty
              ? serverMessage
              : 'Failed to claim gift (HTTP $status)',
        );
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      // Let provider surface this via snackbar
      rethrow;
    }
  }

  /// Get my gifts
  Future<Map<String, dynamic>> getMyGifts({
    int page = 1,
    int size = 20,
    String? status,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    
    if (status != null) params['status'] = status;

    final response = await _apiClient.dio.get('/v1/gifts/my-gifts', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  /// Get gift claim history
  Future<Map<String, dynamic>> getGiftHistory({
    int page = 1,
    int size = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    final response = await _apiClient.dio.get('/v1/gifts/history', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  /// List gift requests (incoming and outgoing for the current user)
  Future<Map<String, dynamic>> listGiftRequests({
    int page = 1,
    int size = 20,
    String? status, // PENDING, APPROVED, DECLINED
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    if (status != null) params['status'] = status;

    final response = await _apiClient.dio.get('/v1/gifts/requests', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  /// Approve a specific gift request
  Future<Map<String, dynamic>> approveGiftRequest(String requestId, {String? message}) async {
    final response = await _apiClient.dio.post(
      '/v1/gifts/requests/$requestId/approve',
      data: {
        if (message != null) 'message': message,
      },
      options: Options(receiveTimeout: ApiTimeouts.listingWrite),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Decline a specific gift request
  Future<Map<String, dynamic>> declineGiftRequest(String requestId, {String? reason}) async {
    final response = await _apiClient.dio.post(
      '/v1/gifts/requests/$requestId/decline',
      data: {
        if (reason != null) 'reason': reason,
      },
      options: Options(receiveTimeout: ApiTimeouts.listingWrite),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get user gift analytics
  Future<Map<String, dynamic>> getUserGiftAnalytics() async {
    try {
      final response = await _apiClient.dio.get('/v1/gifts/analytics/user');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        final retryAfter = e.response?.headers.value('retry-after') ?? 
                          e.response?.headers.value('retry-after-short');
        final retrySeconds = retryAfter != null ? int.tryParse(retryAfter) : null;
        throw Exception(
          retrySeconds != null
              ? 'Too many requests. Please wait $retrySeconds seconds before trying again.'
              : 'Too many requests. Please wait a moment before trying again.'
        );
      }
      rethrow;
    }
  }

  /// Get recommended gifts
  Future<List<dynamic>> getRecommendedGifts() async {
    final response = await _apiClient.dio.get('/v1/gifts/recommendations');
    return response.data as List<dynamic>;
  }

  /// Share a gift
  Future<Map<String, dynamic>> shareGift(String giftId, String platform, {String? message}) async {
    final response = await _apiClient.dio.post('/v1/gifts/$giftId/share', data: {
      'platform': platform,
      if (message != null) 'message': message,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Get comments for a gift
  Future<Map<String, dynamic>> getComments(String giftId, {int page = 1, int size = 50}) async {
    final response = await _apiClient.dio.get('/v1/gifts/$giftId/comments', queryParameters: {
      'page': page,
      'size': size,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Add a comment to a gift
  Future<Map<String, dynamic>> addComment(String giftId, String content, {String? parentId}) async {
    final response = await _apiClient.dio.post('/v1/gifts/$giftId/comments', data: {
      'content': content,
      if (parentId != null) 'parentId': parentId,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Like a gift
  Future<Map<String, dynamic>> likeGift(String giftId) async {
    final response = await _apiClient.dio.post('/v1/gifts/$giftId/like');
    return response.data as Map<String, dynamic>;
  }

  /// Unlike a gift
  Future<Map<String, dynamic>> unlikeGift(String giftId) async {
    final response = await _apiClient.dio.delete('/v1/gifts/$giftId/like');
    return response.data as Map<String, dynamic>;
  }
}