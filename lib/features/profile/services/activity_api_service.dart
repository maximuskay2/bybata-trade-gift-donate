import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/cache_store.dart';
import '../models/activity.dart';

class ActivityApiService {
  final ApiClient _apiClient;

  // Cache for activity pages to avoid re-fetching on every tab switch.
  // A short TTL keeps data reasonably fresh without hammering the API.
  final CacheStore<String, Map<String, dynamic>> _activityCache =
      CacheStore<String, Map<String, dynamic>>(ttl: const Duration(seconds: 60));

  ActivityApiService(this._apiClient);

  /// Fetch user activity history
  Future<Map<String, dynamic>> getUserActivity({
    int page = 1,
    int size = 20,
    String? type,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = 'me:$page:$size:${type ?? ''}';
      if (!forceRefresh) {
        final cached = _activityCache.getIfFresh(cacheKey);
        if (cached != null) {
          return cached;
        }
      }

      final params = {
        'page': page,
        'size': size,
        if (type != null) 'type': type,
      };
      
      final response = await _apiClient.get(
        '/v1/users/me/activity',
        queryParameters: params,
      );
      final data = response.data as Map<String, dynamic>;
      _activityCache.set(cacheKey, data);
      return data;
    } catch (e) {
      throw Exception('Failed to fetch user activity: $e');
    }
  }

  void invalidateCache() {
    _activityCache.invalidate();
  }

  /// Parse activity response into Activity objects
  List<Activity> parseActivities(List<dynamic> items) {
    return items.map((item) {
      final map = item as Map<String, dynamic>;
      return Activity(
        id: map['id'] ?? '',
        userId: map['userId'] ?? '',
        type: _parseActivityType(map['type'] ?? ''),
        status: _parseActivityStatus(map['status'] ?? ''),
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        metadata: map['metadata'] ?? {},
        relatedUserId: map['relatedUserId'],
        relatedItemId: map['relatedItemId'],
        karmaPoints: map['karmaPoints'] as int?,
        createdAt: _parseDateTime(map['createdAt']),
        completedAt: map['completedAt'] != null ? _parseDateTime(map['completedAt']) : null,
      );
    }).toList();
  }

  ActivityType _parseActivityType(String type) {
    switch (type.toLowerCase()) {
      case 'trade':
        return ActivityType.trade;
      case 'gift':
        return ActivityType.gift;
      case 'donation':
        return ActivityType.donation;
      case 'community':
        return ActivityType.community;
      case 'post':
        return ActivityType.post;
      case 'comment':
        return ActivityType.comment;
      case 'like':
        return ActivityType.like;
      case 'follow':
        return ActivityType.follow;
      case 'achievement':
        return ActivityType.achievement;
      case 'verification':
        return ActivityType.verification;
      case 'karma':
        return ActivityType.karma;
      default:
        return ActivityType.karma;
    }
  }

  ActivityStatus _parseActivityStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return ActivityStatus.pending;
      case 'completed':
        return ActivityStatus.completed;
      case 'failed':
        return ActivityStatus.failed;
      case 'cancelled':
        return ActivityStatus.cancelled;
      default:
        return ActivityStatus.pending;
    }
  }

  DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
