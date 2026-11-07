import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_timeouts.dart';

class TradeApi {
  final Dio _dio;
  TradeApi(ApiClient client) : _dio = client.dio;

  // Trades
  Future<Map<String, dynamic>> createTrade({
    required String title,
    String? description,
    String? mediaType,
    List<String>? mediaKeys,
    String? videoKey,
    String? thumbnailKey,
    String? category,
    bool? isNegotiable,
    bool? requiresPickup,
    bool? allowDelivery,
    bool? allowShipping,
    bool? enableBYCPromotion,
    String? location,
    double? latitude,
    double? longitude,
    bool asDraft = false,
    bool isSeedingListing = false,
  }) async {
    final res = await _dio.post(
      '/v1/trades',
      data: {
      'title': title,
      if (description != null) 'description': description,
      if (mediaType != null) 'mediaType': mediaType,
      if (mediaKeys != null) 'mediaKeys': mediaKeys,
      if (videoKey != null) 'videoKey': videoKey,
      if (thumbnailKey != null) 'thumbnailKey': thumbnailKey,
      if (category != null) 'category': category,
      if (isNegotiable != null) 'isNegotiable': isNegotiable,
      if (requiresPickup != null) 'requiresPickup': requiresPickup,
      if (allowDelivery != null) 'allowDelivery': allowDelivery,
      if (allowShipping != null) 'allowShipping': allowShipping,
      if (enableBYCPromotion != null) 'enableBYCPromotion': enableBYCPromotion,
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (asDraft) 'status': 'DRAFT',
      if (isSeedingListing) 'isSeedingListing': true,
      },
      options: Options(receiveTimeout: ApiTimeouts.listingWrite),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> publishDraft(String tradeId) async {
    final res = await _dio.post('/v1/trades/$tradeId/publish');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> listTrades({
    String? query,
    String? ownerId,
    String? status,
    String? category,
    int page = 1,
    int size = 20,
  }) async {
    final params = {
      if (query != null) 'query': query,
      if (ownerId != null) 'ownerId': ownerId,
      if (status != null) 'status': status,
      if (category != null && category.isNotEmpty) 'category': category,
      'page': page,
      'size': size,
    };
    try {
      final res = await _dio.get('/v1/trades', queryParameters: params);
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      if (ownerId != null) rethrow;
      final code = e.response?.statusCode;
      if (code == 401 ||
          code == 403 ||
          (code != null && code >= 500)) {
        final res = await _dio.get(
          '/v1/public/browse/trades',
          queryParameters: params,
        );
        return Map<String, dynamic>.from(res.data as Map);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTrade(String id) async {
    try {
      final res = await _dio.get('/v1/trades/$id');
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        final res = await _dio.get('/v1/public/browse/trades/$id');
        return Map<String, dynamic>.from(res.data as Map);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> likeTrade(String tradeId) async {
    final res = await _dio.post('/v1/trades/$tradeId/like');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> unlikeTrade(String tradeId) async {
    final res = await _dio.delete('/v1/trades/$tradeId/like');
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Combined trade history for the current user (owned + accepted as bidder)
  Future<Map<String, dynamic>> getMyTradeHistory({int page = 1, int size = 20}) async {
    final res = await _dio.get('/v1/trades/history/me', queryParameters: {
      'page': page,
      'size': size,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> getTradeComments(String id, {int page = 1, int size = 50}) async {
    final res = await _dio.get('/v1/trades/$id/comments', queryParameters: {'page': page, 'size': size});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> addTradeComment(String tradeId, String content, {String? parentId}) async {
    final res = await _dio.post('/v1/trades/$tradeId/comments', data: {
      'content': content,
      if (parentId != null) 'parentId': parentId,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> getSimilarTrades({
    required int categoryId,
    required String excludeTradeId,
    int limit = 10,
  }) async {
    final res = await _dio.get('/v1/trades/similar', queryParameters: {
      'categoryId': categoryId,
      'excludeId': excludeTradeId,
      'limit': limit,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> updateTrade(
    String id, {
    String? title,
    String? description,
    String? mediaType,
    List<String>? mediaKeys,
    String? videoKey,
    String? thumbnailKey,
    String? category,
    bool? isNegotiable,
    bool? requiresPickup,
    bool? allowDelivery,
    bool? allowShipping,
    bool? enableBYCPromotion,
  }) async {
    final res = await _dio.patch('/v1/trades/$id', data: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (mediaType != null) 'mediaType': mediaType,
      if (mediaKeys != null) 'mediaKeys': mediaKeys,
      if (videoKey != null || mediaType == 'IMAGE') 'videoKey': videoKey,
      if (thumbnailKey != null) 'thumbnailKey': thumbnailKey,
      if (category != null) 'category': category,
      if (isNegotiable != null) 'isNegotiable': isNegotiable,
      if (requiresPickup != null) 'requiresPickup': requiresPickup,
      if (allowDelivery != null) 'allowDelivery': allowDelivery,
      if (allowShipping != null) 'allowShipping': allowShipping,
      if (enableBYCPromotion != null) 'enableBYCPromotion': enableBYCPromotion,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> closeTrade(String id) async {
    final res = await _dio.post('/v1/trades/$id/close');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> cancelTrade(String id) async {
    final res = await _dio.post('/v1/trades/$id/cancel');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> deleteTrade(String id) async {
    await _dio.delete('/v1/trades/$id');
  }

  // Offers
  Future<List<Map<String, dynamic>>> listOffers(String tradeId) async {
    final res = await _dio.get('/v1/trades/$tradeId/offers');
    return List<Map<String, dynamic>>.from((res.data as List).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  Future<Map<String, dynamic>> createOffer(
    String tradeId, {
    String? amount,
    String? offeredTradeId,
    String? message,
    String? parentOfferId,
    String? requestedTradeId,
    String? requestedAmount,
  }) async {
    final res = await _dio.post(
      '/v1/trades/$tradeId/offers',
      data: {
      if (amount != null) 'amount': amount,
      if (offeredTradeId != null) 'offeredTradeId': offeredTradeId,
      if (message != null) 'message': message,
      if (parentOfferId != null) 'parentOfferId': parentOfferId,
      if (requestedTradeId != null) 'requestedTradeId': requestedTradeId,
      if (requestedAmount != null) 'requestedAmount': requestedAmount,
      },
      options: Options(receiveTimeout: ApiTimeouts.listingWrite),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> getOfferHistory(String offerId) async {
    final res = await _dio.get('/v1/trades/offers/$offerId/history');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> acceptOffer(String offerId) async {
    final res = await _dio.post(
      '/v1/offers/$offerId/accept',
      options: Options(receiveTimeout: ApiTimeouts.listingWrite),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> finalizeOffer(String offerId) async {
    final res = await _dio.post(
      '/v1/trades/offers/$offerId/finalize',
      options: Options(receiveTimeout: ApiTimeouts.listingWrite),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> rejectOffer(String offerId) async {
    final res = await _dio.post('/v1/offers/$offerId/reject');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> withdrawOffer(String offerId) async {
    final res = await _dio.post('/v1/offers/$offerId/withdraw');
    return Map<String, dynamic>.from(res.data as Map);
  }

  // Negotiation
  Future<List<Map<String, dynamic>>> listMessages(String offerId) async {
    try {
      final res = await _dio.get('/v1/offers/$offerId/negotiation/messages');
      return List<Map<String, dynamic>>.from(
        (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        // Respect Retry-After if present, otherwise wait briefly then retry once
        final retryAfter = e.response?.headers.value('retry-after');
        int waitMs = 1200;
        if (retryAfter != null) {
          final parsed = int.tryParse(retryAfter);
          if (parsed != null && parsed > 0) {
            // Header is seconds per RFC; convert to ms
            waitMs = parsed * 1000;
          }
        }
        await Future.delayed(Duration(milliseconds: waitMs));
        final res = await _dio.get('/v1/offers/$offerId/negotiation/messages');
        return List<Map<String, dynamic>>.from(
          (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> postMessage(
    String offerId,
    String content, {
    String? messageType,
    Map<String, dynamic>? proposalData,
  }) async {
    try {
      final res = await _dio.post(
        '/v1/offers/$offerId/negotiation/messages',
        data: {
          'content': content,
          if (messageType != null) 'messageType': messageType.toUpperCase(),
          if (proposalData != null) 'proposalData': proposalData,
        },
      );
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        final retryAfter = e.response?.headers.value('retry-after');
        int waitMs = 1500;
        if (retryAfter != null) {
          final parsed = int.tryParse(retryAfter);
          if (parsed != null && parsed > 0) waitMs = parsed * 1000;
        }
        await Future.delayed(Duration(milliseconds: waitMs));
        final res = await _dio.post(
          '/v1/offers/$offerId/negotiation/messages',
          data: {
            'content': content,
            if (messageType != null) 'messageType': messageType.toUpperCase(),
            if (proposalData != null) 'proposalData': proposalData,
          },
        );
        return Map<String, dynamic>.from(res.data as Map);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> evenTrade(
    String tradeId,
    String offerId, {
    String? ownerCondition,
    String? bidderCondition,
  }) async {
    final res = await _dio.post(
      '/v1/trades/$tradeId/offers/$offerId/even',
      data: {
        if (ownerCondition != null) 'ownerCondition': ownerCondition,
        if (bidderCondition != null) 'bidderCondition': bidderCondition,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<Map<String, dynamic>>> listTradeTopUps(String tradeId) async {
    final res = await _dio.get('/v1/trades/$tradeId/topups');
    final data = res.data;
    if (data is List) {
      return data.map((row) => Map<String, dynamic>.from(row as Map)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> respondTradeTopUp(
    String topUpId, {
    required String action,
    double? amount,
  }) async {
    final res = await _dio.post(
      '/v1/trade-topups/$topUpId/respond',
      data: {
        'action': action,
        if (amount != null) 'amount': amount,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> createTradeTopUpOrder(String topUpId) async {
    final res = await _dio.post('/v1/trade-topups/$topUpId/paypal/order');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> captureTradeTopUp(String topUpId, {String? orderId}) async {
    final res = await _dio.post(
      '/v1/trade-topups/$topUpId/paypal/capture',
      data: {
        if (orderId != null) 'orderId': orderId,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> disputeTrade(String tradeId, {String? reason}) async {
    final res = await _dio.post(
      '/v1/trades/$tradeId/dispute',
      data: {
        if (reason != null) 'reason': reason,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }
}
