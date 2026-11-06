import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class NotificationsApi {
  final Dio _dio;
  NotificationsApi(ApiClient client) : _dio = client.dio;

  Future<Map<String, dynamic>> listNotifications({
    String? type,
    bool? read,
    String? priority,
    int page = 1,
    int size = 20,
  }) async {
    final res = await _dio.get('/v1/notifications', queryParameters: {
      'page': page,
      'size': size,
      if (type != null) 'type': type,
      if (read != null) 'read': read.toString(),
      if (priority != null) 'priority': priority,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<int> getUnreadCount() async {
    final res = await _dio.get('/v1/notifications/unread-count');
    final data = Map<String, dynamic>.from(res.data as Map);
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markAsRead(String id) async {
    await _dio.post('/v1/notifications/$id/read');
  }

  Future<int> markAllAsRead() async {
    final res = await _dio.post('/v1/notifications/mark-all-read');
    final data = Map<String, dynamic>.from(res.data as Map);
    return (data['markedCount'] as num?)?.toInt() ?? 0;
  }

  /// Deletes a single notification on the server.
  Future<void> deleteNotification(String id) async {
    await _dio.delete('/v1/notifications/$id');
  }

  /// Deletes ALL notifications for the current user on the server. Used by
  /// the mobile "Clear all" action so the unread badge resets immediately.
  Future<int> clearAll() async {
    final res = await _dio.delete('/v1/notifications');
    final data = Map<String, dynamic>.from(res.data as Map);
    return (data['deletedCount'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> getSettings() async {
    final res = await _dio.get('/v1/notifications/settings');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> updateSettings({
    bool? pushEnabled,
    bool? emailEnabled,
    Map<String, bool>? typeSettings,
  }) async {
    final res = await _dio.put('/v1/notifications/settings', data: {
      if (pushEnabled != null) 'pushEnabled': pushEnabled,
      if (emailEnabled != null) 'emailEnabled': emailEnabled,
      if (typeSettings != null) 'typeSettings': typeSettings,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> registerDeviceToken({
    required String token,
    required String deviceType,
  }) async {
    await _dio.post('/v1/notifications/device-tokens', data: {
      'token': token,
      'deviceType': deviceType,
    });
  }

  Future<void> removeDeviceToken({required String token}) async {
    await _dio.delete('/v1/notifications/device-tokens', data: {
      'token': token,
    });
  }
}