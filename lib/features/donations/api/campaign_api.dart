import '../../../core/api/api_client.dart';
import '../../../core/api/api_timeouts.dart';
import 'package:dio/dio.dart' as dio;

class CampaignApi {
  final ApiClient _apiClient;

  CampaignApi(this._apiClient);

  /// Create a new campaign
  Future<Map<String, dynamic>> createCampaign({
    required String title,
    String? description,
    String? shortDescription,
    String? category,
    required double goalAmount,
    String? currency,
    String? mediaType,
    List<String>? mediaKeys,
    String? videoKey,
    String? thumbnailKey,
    List<String>? tags,
    String? location,
    bool? isUrgent,
    double? minimumDonation,
    DateTime? endsAt,
    Map<String, dynamic>? metadata,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _apiClient.dio.post(
      '/v1/campaigns',
      data: {
        'title': title,
        if (description != null) 'description': description,
        if (shortDescription != null) 'shortDescription': shortDescription,
        if (category != null) 'category': category,
        'goalAmount': goalAmount,
        if (currency != null) 'currency': currency,
        if (mediaType != null) 'mediaType': mediaType,
        if (mediaKeys != null) 'mediaKeys': mediaKeys,
        if (videoKey != null) 'videoKey': videoKey,
        if (thumbnailKey != null) 'thumbnailKey': thumbnailKey,
        if (tags != null) 'tags': tags,
        if (location != null) 'location': location,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (isUrgent != null) 'isUrgent': isUrgent,
        if (minimumDonation != null) 'minimumDonation': minimumDonation,
        if (endsAt != null) 'endsAt': endsAt.toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      },
      options: dio.Options(receiveTimeout: ApiTimeouts.listingWrite),
    );
    return Map<String, dynamic>.from(response.data);
  }

  /// List campaigns with filters.
  ///
  /// Falls back to `/v1/public/browse/campaigns` on 401/403 so browse-home
  /// visitors can see active campaigns without signing in.
  Future<Map<String, dynamic>> listCampaigns({
    String? query,
    String? category,
    String? status,
    String? founderId,
    String? location,
    bool? isUrgent,
    bool? isFeatured,
    int page = 1,
    int size = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    if (query != null) params['query'] = query;
    if (category != null) params['category'] = category;
    if (status != null) params['status'] = status;
    if (founderId != null) params['founderId'] = founderId;
    if (location != null) params['location'] = location;
    if (isUrgent != null) params['isUrgent'] = isUrgent.toString();
    if (isFeatured != null) params['isFeatured'] = isFeatured.toString();

    try {
      final response = await _apiClient.dio.get(
        '/v1/campaigns',
        queryParameters: params,
      );
      return response.data as Map<String, dynamic>;
    } on dio.DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        final response = await _apiClient.dio.get(
          '/v1/public/browse/campaigns',
          queryParameters: params,
        );
        return response.data as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  /// Get specific campaign details.
  ///
  /// Tries the authenticated endpoint first, then falls back to the public
  /// browse endpoint on 401/403 so guests can open campaign cards.
  Future<Map<String, dynamic>> getCampaign(String campaignId) async {
    try {
      final response = await _apiClient.dio.get('/v1/campaigns/$campaignId');
      return response.data as Map<String, dynamic>;
    } on dio.DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        final response = await _apiClient.dio.get(
          '/v1/public/browse/campaigns/$campaignId',
        );
        return response.data as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> likeCampaign(String campaignId) async {
    final response = await _apiClient.dio.post('/v1/campaigns/$campaignId/like');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> unlikeCampaign(String campaignId) async {
    final response = await _apiClient.dio.delete('/v1/campaigns/$campaignId/like');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Update campaign
  Future<Map<String, dynamic>> updateCampaign(
    String campaignId, {
    String? title,
    String? description,
    String? shortDescription,
    String? category,
    double? goalAmount,
    String? mediaType,
    List<String>? mediaKeys,
    String? videoKey,
    String? thumbnailKey,
    List<String>? tags,
    String? location,
    bool? isUrgent,
    double? minimumDonation,
    DateTime? endsAt,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _apiClient.dio.patch(
      '/v1/campaigns/$campaignId',
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (shortDescription != null) 'shortDescription': shortDescription,
        if (category != null) 'category': category,
        if (goalAmount != null) 'goalAmount': goalAmount,
        if (mediaType != null) 'mediaType': mediaType,
        if (mediaKeys != null) 'mediaKeys': mediaKeys,
        if (videoKey != null || mediaType == 'IMAGE') 'videoKey': videoKey,
        if (thumbnailKey != null) 'thumbnailKey': thumbnailKey,
        if (tags != null) 'tags': tags,
        if (location != null) 'location': location,
        if (isUrgent != null) 'isUrgent': isUrgent,
        if (minimumDonation != null) 'minimumDonation': minimumDonation,
        if (endsAt != null) 'endsAt': endsAt.toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  /// Update campaign status
  Future<Map<String, dynamic>> updateCampaignStatus(
    String campaignId,
    String status,
  ) async {
    final response = await _apiClient.dio.post(
      '/v1/campaigns/$campaignId/status',
      data: {'status': status},
      options: dio.Options(receiveTimeout: ApiTimeouts.listingWrite),
    );

    return response.data as Map<String, dynamic>;
  }

  /// Donate to campaign
  Future<Map<String, dynamic>> donateToCampaign(
    String campaignId, {
    required double amount,
    String? currency,
    bool? isAnonymous,
    String? message,
    String? rewardTierId,
  }) async {
    final response = await _apiClient.dio.post(
      '/v1/campaigns/$campaignId/donate',
      data: {
        'amount': amount,
        if (currency != null) 'currency': currency,
        if (isAnonymous != null) 'isAnonymous': isAnonymous,
        if (message != null) 'message': message,
        if (rewardTierId != null) 'rewardTierId': rewardTierId,
      },
      options: dio.Options(receiveTimeout: ApiTimeouts.listingWrite),
    );

    return response.data as Map<String, dynamic>;
  }

  /// Get my campaigns
  Future<Map<String, dynamic>> getMyCampaigns({
    int page = 1,
    int size = 20,
    String? status,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    if (status != null) params['status'] = status;

    final response = await _apiClient.dio.get(
      '/v1/campaigns/my-campaigns',
      queryParameters: params,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get donation history
  Future<Map<String, dynamic>> getDonationHistory({
    int page = 1,
    int size = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    final response = await _apiClient.dio.get(
      '/v1/campaigns/donation-history',
      queryParameters: params,
    );
    return response.data as Map<String, dynamic>;
  }

  /// List reward tiers for a campaign
  Future<List<Map<String, dynamic>>> getRewardTiers(String campaignId) async {
    try {
      final response = await _apiClient.dio.get(
        '/v1/campaigns/$campaignId/tiers',
      );
      final data = response.data;
      if (data is List) return data.cast<Map<String, dynamic>>();
      return (data['items'] as List?)?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[];
    } catch (e) {
      final status = e is dio.DioException
          ? e.response?.statusCode
          : e is dio.DioError
          ? e.response?.statusCode
          : null;
      if (status == 404) return <Map<String, dynamic>>[];
      rethrow;
    }
  }

  /// Get comments for a campaign
  Future<Map<String, dynamic>> getComments(String campaignId, {int page = 1, int size = 50}) async {
    final response = await _apiClient.dio.get(
      '/v1/campaigns/$campaignId/comments',
      queryParameters: {'page': page, 'size': size},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Add a comment to a campaign
  Future<Map<String, dynamic>> addComment(String campaignId, String content, {String? parentId}) async {
    final response = await _apiClient.dio.post(
      '/v1/campaigns/$campaignId/comments',
      data: {
        'content': content,
        if (parentId != null) 'parentId': parentId,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// List campaign updates
  Future<List<Map<String, dynamic>>> getCampaignUpdates(
    String campaignId,
  ) async {
    try {
      final response = await _apiClient.dio.get(
        '/v1/campaigns/$campaignId/updates',
      );
      final data = response.data;
      if (data is List) return data.cast<Map<String, dynamic>>();
      return (data['items'] as List?)?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[];
    } catch (e) {
      final status = e is dio.DioException
          ? e.response?.statusCode
          : e is dio.DioError
          ? e.response?.statusCode
          : null;
      if (status == 404) return <Map<String, dynamic>>[];
      rethrow;
    }
  }

  /// Post a campaign update (founder-only)
  Future<Map<String, dynamic>> postCampaignUpdate(
    String campaignId, {
    String? type,
    String? content,
    List<String>? mediaKeys,
  }) async {
    final response = await _apiClient.dio.post(
      '/v1/campaigns/$campaignId/updates',
      data: {
        if (type != null) 'type': type,
        if (content != null) 'content': content,
        if (mediaKeys != null) 'mediaKeys': mediaKeys,
      },
    );
    return Map<String, dynamic>.from(response.data);
  }

  /// Creator analytics
  Future<Map<String, dynamic>> getCreatorAnalytics() async {
    final response = await _apiClient.dio.get(
      '/v1/campaigns/creator/analytics',
    );
    return response.data as Map<String, dynamic>;
  }

  /// Donor analytics
  Future<Map<String, dynamic>> getDonorAnalytics() async {
    final response = await _apiClient.dio.get(
      '/v1/campaigns/donor/analytics',
    );
    return response.data as Map<String, dynamic>;
  }

  /// Generate yearly donation receipt (upload + signed URL).
  Future<Map<String, dynamic>> generateDonationReceipt({required int year}) async {
    final response = await _apiClient.dio.get(
      '/v1/campaigns/donation-receipts/$year',
    );
    return response.data as Map<String, dynamic>;
  }

  /// Single donation receipt PDF bytes.
  Future<List<int>> downloadDonationReceiptPdf(String donationId) async {
    final response = await _apiClient.dio.get<List<int>>(
      '/v1/campaigns/donations/$donationId/receipt.pdf',
      options: dio.Options(responseType: dio.ResponseType.bytes),
    );
    return _parsePdfBytes(response.data, 'donation receipt');
  }

  /// Yearly donation summary PDF bytes.
  Future<List<int>> downloadYearlyDonationReceiptPdf(int year) async {
    final response = await _apiClient.dio.get<List<int>>(
      '/v1/campaigns/donation-receipts/$year.pdf',
      options: dio.Options(responseType: dio.ResponseType.bytes),
    );
    return _parsePdfBytes(response.data, 'yearly donation receipt');
  }

  List<int> _parsePdfBytes(List<int>? data, String label) {
    if (data == null || data.isEmpty) {
      throw Exception('Empty $label');
    }
    if (data.length < 4 ||
        data[0] != 0x25 ||
        data[1] != 0x50 ||
        data[2] != 0x44 ||
        data[3] != 0x46) {
      throw Exception('Invalid $label from server');
    }
    return data;
  }

  /// Campaign analytics
  Future<Map<String, dynamic>> getCampaignAnalytics(String campaignId) async {
    final response = await _apiClient.dio.get(
      '/v1/campaigns/$campaignId/analytics',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> searchDonations({
    List<String>? categories,
    double? minAmount,
    double? maxAmount,
    bool exactAmount = false,
    int page = 1,
    int size = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (categories != null && categories.isNotEmpty) 'categories': categories,
      if (minAmount != null) 'minAmount': minAmount,
      if (maxAmount != null) 'maxAmount': maxAmount,
      if (exactAmount) 'exactAmount': true,
    };
    final response = await _apiClient.dio.get(
      '/v1/campaigns/search',
      queryParameters: params,
    );
    return Map<String, dynamic>.from(response.data);
  }

  /// Create reward tier
  Future<Map<String, dynamic>> createRewardTier(
    String campaignId, {
    required String title,
    String? description,
    required double minimumDonation,
    int? limitedQuantity,
  }) async {
    final response = await _apiClient.dio.post(
      '/v1/campaigns/$campaignId/tiers',
      data: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'minimumDonation': minimumDonation,
        if (limitedQuantity != null) 'limitedQuantity': limitedQuantity,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Update reward tier
  Future<Map<String, dynamic>> updateRewardTier(
    String campaignId,
    String tierId, {
    String? title,
    String? description,
    double? minimumDonation,
    int? limitedQuantity,
    String? status,
  }) async {
    final response = await _apiClient.dio.patch(
      '/v1/campaigns/$campaignId/tiers/$tierId',
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (minimumDonation != null) 'minimumDonation': minimumDonation,
        if (limitedQuantity != null) 'limitedQuantity': limitedQuantity,
        if (status != null) 'status': status,
      },
    );
    return Map<String, dynamic>.from(response.data);
  }

  /// Delete reward tier
  Future<void> deleteRewardTier(String campaignId, String tierId) async {
    await _apiClient.dio.delete('/v1/campaigns/$campaignId/tiers/$tierId');
  }

  /// Permanently delete a campaign (only when no donations received).
  Future<void> deleteCampaign(String campaignId) async {
    await _apiClient.dio.delete('/v1/campaigns/$campaignId');
  }
}
