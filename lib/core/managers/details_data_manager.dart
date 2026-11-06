import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env_config.dart';
import '../api/api_client.dart';
import '../utils/media_utils.dart';

class DetailsDataManager {
  final String itemId;
  final String itemType; // 'TRADE' | 'GIFT' | 'CAMPAIGN'

  final Map<String, dynamic> _mediaCache = {};
  final Map<String, dynamic> _commentsCache = {};
  final Map<String, dynamic> _similarCache = {};

  late ApiClient _apiClient;

  DetailsDataManager({required this.itemId, required this.itemType});

  Future<void> _ensureClient() async {
    final baseUrl = await EnvConfig.getBaseUrl();
    _apiClient = ApiClient(baseUrl, const FlutterSecureStorage());
  }

  /// Resolve media URLs (HTTP URLs or storage keys)
  Future<List<String>> resolveMediaUrls(List<String> mediaInputs) async {
    if (mediaInputs.isEmpty) return [];

    final cacheKey = 'media:$itemId:${mediaInputs.join('|')}';
    if (_mediaCache.containsKey(cacheKey)) {
      return List<String>.from(_mediaCache[cacheKey] as List);
    }

    final urls = await MediaResolver.resolveUrls(mediaInputs);

    _mediaCache[cacheKey] = urls;
    return urls;
  }

  /// Load paginated comments
  Future<List<Map<String, dynamic>>> loadComments({
    int limit = 10,
    int offset = 0,
  }) async {
    final cacheKey = 'comments:$itemId:$limit:$offset';
    if (_commentsCache.containsKey(cacheKey)) {
      return List<Map<String, dynamic>>.from(_commentsCache[cacheKey] as List);
    }

    try {
      await _ensureClient();
      final endpoint = _getCommentEndpoint();
      final response = await _apiClient.get(
        endpoint,
        queryParameters: {'page': (offset ~/ limit) + 1, 'size': limit},
      );

      final data = response.data;
      final rawComments = data is Map<String, dynamic>
          ? (data['comments'] as List? ?? data['items'] as List? ?? const [])
          : const [];
      final comments = rawComments
          .map<Map<String, dynamic>>(_formatComment)
          .toList();
      _commentsCache[cacheKey] = comments;
      return comments;
    } catch (e) {
      return [];
    }
  }

  Future<bool> addComment(String comment, {String? parentId}) async {
    final content = comment.trim();
    if (content.isEmpty) return false;

    try {
      await _ensureClient();
      await _apiClient.post(
        _getCommentEndpoint(),
        data: {'content': content, if (parentId != null) 'parentId': parentId},
      );
      _commentsCache.clear();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateComment(String commentId, String comment) async {
    final content = comment.trim();
    if (content.isEmpty || commentId.trim().isEmpty) return false;

    try {
      await _ensureClient();
      await _apiClient.patch(
        '${_getCommentEndpoint()}/$commentId',
        data: {'content': content},
      );
      _commentsCache.clear();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Load similar items (type-aware)
  Future<List<dynamic>> loadSimilarItems({
    int limit = 8,
    Map<String, dynamic>? queryParameters,
  }) async {
    await _ensureClient();

    final cacheKey = 'similar:$itemId:$limit:${queryParameters.toString()}';
    if (_similarCache.containsKey(cacheKey)) {
      return List<dynamic>.from(_similarCache[cacheKey] as List);
    }

    try {
      final endpoint = _getSimilarItemsEndpoint();
      final response = await _apiClient.get(
        endpoint,
        queryParameters: {
          ...?queryParameters,
          if (itemType == 'CAMPAIGN') 'size': limit else 'limit': limit,
          if (itemType != 'GIFT') 'excludeId': itemId,
        },
      );

      final data = response.data;
      final rawItems = data is Map<String, dynamic>
          ? (data['items'] as List? ??
                data['gifts'] as List? ??
                data['campaigns'] as List? ??
                data['trades'] as List? ??
                const [])
          : data is List
          ? data
          : const [];
      final items = rawItems.where((item) {
        if (item is! Map) return true;
        return item['id']?.toString() != itemId;
      }).toList();
      _similarCache[cacheKey] = items;
      return items;
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic> _formatComment(dynamic raw) {
    if (raw is! Map) {
      return {
        'id': '',
        'user': 'Anonymous',
        'avatar': 'A',
        'time': null,
        'comment': '',
      };
    }

    final user = raw['user'];
    final userName =
        raw['userName'] ??
        raw['authorName'] ??
        raw['name'] ??
        (user is Map
            ? user['name'] ?? user['displayName'] ?? user['email']
            : null) ??
        'Anonymous';
    final name = userName.toString();

    return {
      'id': raw['id']?.toString() ?? '',
      'authorId': raw['authorId']?.toString() ?? '',
      'user': name,
      'avatar': name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A',
      'time': raw['createdAt']?.toString() ?? raw['time']?.toString(),
      'updatedAt': raw['updatedAt']?.toString(),
      'comment': raw['content']?.toString() ?? raw['comment']?.toString() ?? '',
    };
  }

  /// Fetch with centralized error handling
  Future<T> fetchWithErrorHandling<T>(
    Future<T> Function() fn,
    String fallbackMessage,
  ) async {
    try {
      return await fn();
    } catch (e) {
      throw Exception('$fallbackMessage: ${e.toString()}');
    }
  }

  /// Get the appropriate comments endpoint based on itemType
  String _getCommentEndpoint() {
    switch (itemType) {
      case 'TRADE':
        return '/v1/trades/$itemId/comments';
      case 'GIFT':
        return '/v1/gifts/$itemId/comments';
      case 'CAMPAIGN':
        return '/v1/campaigns/$itemId/comments';
      default:
        return '/v1/comments';
    }
  }

  /// Get the appropriate similar items endpoint based on itemType
  String _getSimilarItemsEndpoint() {
    switch (itemType) {
      case 'TRADE':
        return '/v1/trades/similar';
      case 'GIFT':
        return '/v1/gifts/$itemId/similar';
      case 'CAMPAIGN':
        return '/v1/campaigns';
      default:
        return '/v1/similar';
    }
  }

  /// Clear all caches
  void clearCache() {
    _mediaCache.clear();
    _commentsCache.clear();
    _similarCache.clear();
  }

  /// Clear specific cache
  void clearCacheKey(String key) {
    _mediaCache.remove(key);
    _commentsCache.remove(key);
    _similarCache.remove(key);
  }

  void dispose() {
    clearCache();
  }
}
