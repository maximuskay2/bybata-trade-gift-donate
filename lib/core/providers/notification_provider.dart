import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';
import '../config/env_config.dart';
import '../../features/notifications/api/notifications_api.dart';
import '../../features/notifications/services/push_notifications_service.dart';
import '../../features/notifications/utils/notification_navigation.dart';
import '../utils/network_error_message.dart';
import '../utils/offline_json_cache.dart';

class NotificationProvider extends ChangeNotifier {
  // Notifications
  List<AppNotification> _notifications = [];
  List<AppNotification> _filteredNotifications = [];
  
  // Filters
  NotificationType? _selectedType;
  bool? _isRead; // null = all, true = read, false = unread
  
  // UI state
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasMore = true;
  int _currentPage = 1;
  
  // Polling for unread badge (FCM/WebSocket also update the badge)
  Timer? _pollingTimer;
  bool _pollingIntent = false;
  static const Duration _pollingInterval = Duration(minutes: 2);

  /// Reuse one client for notification API calls to avoid new [ApiClient] + Dio log spam each poll.
  String? _notificationsApiBaseUrl;
  ApiClient? _notificationsApiClient;
  String? _cacheUserId;
  static const _notifBox = 'notifications_cache';

  // Settings
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = true;
  bool _nearbyListingsEnabled = true;
  Map<NotificationType, bool> _notificationTypeSettings = {
    NotificationType.message: true,
    NotificationType.trade: true,
    NotificationType.gift: true,
    NotificationType.campaign: true,
    NotificationType.achievement: true,
    NotificationType.system: true,
    NotificationType.reminder: true,
  };
  
  // Getters
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  List<AppNotification> get filteredNotifications => List.unmodifiable(_filteredNotifications);
  List<AppNotification> get unreadNotifications => _notifications.where((n) => !n.isRead).toList();
  int? _serverUnreadCount;
  int get unreadCount => _serverUnreadCount ?? unreadNotifications.length;
  
  NotificationType? get selectedType => _selectedType;
  bool? get isRead => _isRead;
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  int get currentPage => _currentPage;
  
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool get emailNotificationsEnabled => _emailNotificationsEnabled;
  bool get nearbyListingsEnabled => _nearbyListingsEnabled;
  Map<NotificationType, bool> get notificationTypeSettings =>
      Map.unmodifiable(_notificationTypeSettings);
  
  // Initialize
  Future<void> initializeNotifications({
    bool requireAuth = true,
    String? userId,
  }) async {
    if (userId != null && userId.isNotEmpty) {
      _cacheUserId = userId;
    }
    // Skip API calls if authentication is required but not available
    // This prevents 401 errors when called before user is authenticated
    if (requireAuth) {
      try {
        // Check if we have an access token before making API calls
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: 'access');
        if (token == null || token.isEmpty) {
          // No token available, skip API calls to avoid 401 errors
          return;
        }
      } catch (e) {
        // If token check fails, skip API calls to avoid errors
        return;
      }
    }

    await _hydrateNotificationsFromDisk();
    // Always force a network refresh so cleared/deleted items cannot stay
    // stuck from the offline cache on first paint.
    await loadNotifications(refresh: true);
    await _refreshUnreadCount();
    await _loadSettings();
    await _registerDeviceToken();
    _startPolling();
  }

  Future<void> _hydrateNotificationsFromDisk() async {
    final userId = _cacheUserId;
    if (userId == null || userId.isEmpty) return;
    try {
      final maps =
          await OfflineJsonCache.getList(_notifBox, userId, 'list');
      if (maps.isEmpty) return;
      // Stale cache is OK as a quick paint only — network refresh always follows.
      _notifications = maps.map(_fromCacheItem).toList();
      final unread = await OfflineJsonCache.getJson(
        _notifBox,
        userId,
        'unread_count',
      );
      if (unread is num) {
        _serverUnreadCount = unread.toInt();
      }
      _applyFilters();
      _errorMessage = null;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persistNotificationsToDisk() async {
    final userId = _cacheUserId;
    if (userId == null || userId.isEmpty) return;
    try {
      final clipped = _notifications.length > 50
          ? _notifications.take(50).toList()
          : _notifications;
      await OfflineJsonCache.putList(
        _notifBox,
        userId,
        'list',
        clipped.map(_toCacheItem).toList(),
      );
      await OfflineJsonCache.putJson(
        _notifBox,
        userId,
        'unread_count',
        _serverUnreadCount ?? 0,
      );
    } catch (_) {}
  }

  Future<void> _clearNotificationsDiskCache() async {
    final userId = _cacheUserId;
    if (userId == null || userId.isEmpty) return;
    try {
      await OfflineJsonCache.putList(_notifBox, userId, 'list', const []);
      await OfflineJsonCache.putJson(_notifBox, userId, 'unread_count', 0);
    } catch (_) {}
  }

  Map<String, dynamic> _toCacheItem(AppNotification n) => {
        'id': n.id,
        'title': n.title,
        'message': n.message,
        'body': n.message,
        'type': n.type.name,
        'imageUrl': n.imageUrl,
        'targetId': n.targetId,
        'actionUrl': n.actionUrl,
        'isRead': n.isRead,
        'read': n.isRead,
        'createdAt': n.createdAt.toIso8601String(),
        'data': n.data,
      };

  AppNotification _fromCacheItem(Map<String, dynamic> json) =>
      _fromServerItem(json);

  void _startPolling() {
    _pollingIntent = true;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      await _refreshUnreadCount();
    });
  }

  void stopPolling() {
    _pollingIntent = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _disposeNotificationsApiClient();
  }

  /// Clears in-memory notification state when the session ends (sign-out / expiry).
  void clearSessionOnSignOut() {
    stopPolling();
    _notifications.clear();
    _filteredNotifications.clear();
    _serverUnreadCount = 0;
    _selectedType = null;
    _isRead = null;
    _isLoading = false;
    _errorMessage = null;
    _hasMore = true;
    _currentPage = 1;
    notifyListeners();
  }

  /// Stops the periodic timer while the app is in the background; keeps intent so we resume on foreground.
  void pausePollingForAppBackground() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Restarts polling after [pausePollingForAppBackground] and refreshes count once.
  Future<void> resumePollingAfterAppForeground() async {
    if (!_pollingIntent) return;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      await _refreshUnreadCount();
    });
    await _refreshUnreadCount();
    await loadNotifications(refresh: true);
    // Re-upsert FCM token — heals cases where the server purged a stale token.
    unawaited(_registerDeviceToken());
  }

  void _disposeNotificationsApiClient() {
    try {
      _notificationsApiClient?.dio.close(force: true);
    } catch (_) {}
    _notificationsApiClient = null;
    _notificationsApiBaseUrl = null;
  }
  
  // Load notifications
  Future<void> loadNotifications({bool refresh = false}) async {
    if (_isLoading && !refresh) return;
    _isLoading = true;
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    notifyListeners();
    
    try {
      final api = await _getApi();
      final pageToLoad = _currentPage;
      // Always fetch the full inbox; All/Unread/Read + type chips filter client-side.
      // Passing `read` here previously wiped the list and broke Campaigns/System filters.
      final response = await api.listNotifications(
        page: pageToLoad,
        size: 50,
      );

      final items = List<Map<String, dynamic>>.from(
        (response['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? const [],
      );

      final totalPages = (response['totalPages'] as num?)?.toInt() ?? pageToLoad;
      final fetched = items.map(_fromServerItem).toList();

      if (refresh || pageToLoad == 1) {
        _notifications = fetched;
      } else {
        _notifications.addAll(fetched);
      }

      _hasMore = pageToLoad < totalPages && fetched.isNotEmpty;
      _currentPage = pageToLoad + 1;
      _applyFilters();
      _errorMessage = null;
      await _refreshUnreadCount();
      if (fetched.isEmpty && (refresh || pageToLoad == 1)) {
        unawaited(_clearNotificationsDiskCache());
      } else {
        unawaited(_persistNotificationsToDisk());
      }
    } catch (e) {
      if (_notifications.isNotEmpty) {
        _errorMessage = null;
      } else {
        _errorMessage = NetworkErrorMessage.from(
          e,
          fallback: 'Couldn\'t load notifications. Please try again.',
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Load settings
  Future<void> _loadSettings() async {
    try {
      final api = await _getApi();
      final data = await api.getSettings();
      _pushNotificationsEnabled = data['pushEnabled'] as bool? ?? true;
      _emailNotificationsEnabled = data['emailEnabled'] as bool? ?? true;
      final typeSettings = Map<String, dynamic>.from(
        (data['typeSettings'] as Map?) ?? const {},
      );
      bool readFlag(String key) {
        final v = typeSettings[key];
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) return v.toLowerCase() == 'true' || v == '1';
        return true;
      }
      _notificationTypeSettings = {
        NotificationType.message: readFlag('message'),
        NotificationType.trade: readFlag('trade'),
        NotificationType.gift: readFlag('gift'),
        NotificationType.campaign: readFlag('campaign'),
        NotificationType.achievement: readFlag('achievement'),
        NotificationType.system: readFlag('system'),
        NotificationType.reminder: readFlag('reminder'),
      };
      _nearbyListingsEnabled = readFlag('nearby');
      notifyListeners();
    } catch (e) {
      // Keep local defaults if settings fetch fails.
    }
  }

  Future<void> _registerDeviceToken() async {
    try {
      await PushNotificationsService.syncTokenWithServer();
    } catch (_) {}
  }
  
  // Mark as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1 && !_notifications[idx].isRead) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
        _applyFilters();
        notifyListeners();
        
        // Sync with backend
        final api = await _getApi();
        await api.markAsRead(notificationId);
        await _refreshUnreadCount();
      }
    } catch (e) {
      _errorMessage = 'Failed to mark notification as read: ${e.toString()}';
      notifyListeners();
    }
  }
  
  // Mark all as read
  Future<bool> markAllAsRead() async {
    try {
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
        }
      }
      _applyFilters();
      _serverUnreadCount = 0;
      notifyListeners();

      final api = await _getApi();
      await api.markAllAsRead();
      await _refreshUnreadCount();
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t mark all as read. Please try again.',
      );
      notifyListeners();
      return false;
    }
  }
  
  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      // Track whether the deleted notification was unread so we can decrement
      // the server-side badge count optimistically.
      final wasUnread = _notifications
          .any((n) => n.id == notificationId && !n.isRead);

      _notifications.removeWhere((n) => n.id == notificationId);
      _applyFilters();
      if (wasUnread && _serverUnreadCount != null && _serverUnreadCount! > 0) {
        _serverUnreadCount = _serverUnreadCount! - 1;
      }
      notifyListeners();

      // Persist the deletion on the server so the badge stays in sync across
      // devices and the next polling tick doesn't resurrect the count.
      try {
        final api = await _getApi();
        await api.deleteNotification(notificationId);
      } catch (_) {
        // Non-blocking: local state already updated.
      }

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to delete notification: ${e.toString()}';
      notifyListeners();
    }
  }
  
  // Clear all notifications
  Future<bool> clearAllNotifications() async {
    try {
      _notifications.clear();
      _filteredNotifications.clear();
      _serverUnreadCount = 0;
      notifyListeners();
      await _clearNotificationsDiskCache();

      final api = await _getApi();
      await api.clearAll();
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t clear notifications. Please try again.',
      );
      notifyListeners();
      unawaited(loadNotifications(refresh: true));
      return false;
    }
  }
  
  // Add new notification (for real-time updates)
  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    _applyFilters();
    _serverUnreadCount = (_serverUnreadCount ?? 0) + (notification.isRead ? 0 : 1);
    notifyListeners();
  }

  /// Add notification from FCM or WebSocket payload. Used by NotificationInitializer.
  void addNotificationFromPayload({
    required String id,
    required String title,
    required String message,
    required NotificationType type,
    String? targetId,
    String? actionUrl,
    String? conversationId,
    String? offerId,
    String? sourceType,
    String? campaignId,
    String? donationId,
    String? giftId,
    String? requestId,
    String? kind,
  }) {
    // Deduplicate: avoid adding same notification twice (e.g. from both WebSocket and FCM)
    if (_notifications.any((n) => n.id == id)) return;

    final data = <String, dynamic>{
      if (conversationId != null) 'conversationId': conversationId,
      if (offerId != null) 'offerId': offerId,
      if (targetId != null) 'sourceId': targetId,
      if (sourceType != null) 'sourceType': sourceType,
      if (campaignId != null) 'campaignId': campaignId,
      if (donationId != null) 'donationId': donationId,
      if (giftId != null) 'giftId': giftId,
      if (requestId != null) 'requestId': requestId,
      if (kind != null) 'kind': kind,
    };
    addNotification(AppNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      targetId: targetId,
      actionUrl: actionUrl,
      isRead: false,
      createdAt: DateTime.now(),
      data: data.isNotEmpty ? data : null,
    ));
  }
  
  // Filters
  void setTypeFilter(NotificationType? type) {
    if (_selectedType == type) {
      // Already selected — still notify so UI can react to re-taps.
      notifyListeners();
      return;
    }
    _selectedType = type;
    _applyFilters();
    notifyListeners();
  }
  
  void setReadFilter(bool? isRead) {
    if (_isRead == isRead) {
      notifyListeners();
      return;
    }
    _isRead = isRead;
    _applyFilters();
    notifyListeners();
  }
  
  void clearFilters() {
    _selectedType = null;
    _isRead = null;
    _applyFilters();
    notifyListeners();
  }

  /// Notifications matching the active type + read filters (newest first).
  List<AppNotification> get visibleNotifications => filteredNotifications;

  /// Compute a filtered slice without mutating tab/type state.
  List<AppNotification> notificationsFor({
    NotificationType? type,
    bool? read,
  }) {
    final typeFilter = type ?? _selectedType;
    var list = List<AppNotification>.from(_notifications);
    if (typeFilter != null) {
      list = list.where((n) => n.type == typeFilter).toList();
    }
    if (read != null) {
      list = list.where((n) => n.isRead == read).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
  
  void _applyFilters() {
    _filteredNotifications = notificationsFor(
      type: _selectedType,
      read: _isRead,
    );
  }
  
  // Settings management
  Future<bool> setPushNotificationsEnabled(bool enabled) async {
    final previous = _pushNotificationsEnabled;
    _pushNotificationsEnabled = enabled;
    notifyListeners();
    
    try {
      final api = await _getApi();
      await api.updateSettings(pushEnabled: enabled);
      _errorMessage = null;
      return true;
    } catch (e) {
      _pushNotificationsEnabled = previous;
      _errorMessage = NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t update push settings.',
      );
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> setEmailNotificationsEnabled(bool enabled) async {
    final previous = _emailNotificationsEnabled;
    _emailNotificationsEnabled = enabled;
    notifyListeners();
    
    try {
      final api = await _getApi();
      await api.updateSettings(emailEnabled: enabled);
      _errorMessage = null;
      return true;
    } catch (e) {
      _emailNotificationsEnabled = previous;
      _errorMessage = NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t update email settings.',
      );
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> setNotificationTypeEnabled(NotificationType type, bool enabled) async {
    final previous = Map<NotificationType, bool>.from(_notificationTypeSettings);
    _notificationTypeSettings = {
      ..._notificationTypeSettings,
      type: enabled,
    };
    notifyListeners();
    
    try {
      final api = await _getApi();
      await api.updateSettings(typeSettings: _serializeTypeSettings());
      _errorMessage = null;
      return true;
    } catch (e) {
      _notificationTypeSettings = previous;
      _errorMessage = NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t update notification categories.',
      );
      notifyListeners();
      return false;
    }
  }

  /// Turn every category on/off in one API call (avoids race from parallel toggles).
  Future<bool> setAllNotificationTypesEnabled(bool enabled) async {
    final previous = Map<NotificationType, bool>.from(_notificationTypeSettings);
    final previousNearby = _nearbyListingsEnabled;
    _notificationTypeSettings = {
      for (final type in NotificationType.values) type: enabled,
    };
    _nearbyListingsEnabled = enabled;
    notifyListeners();

    try {
      final api = await _getApi();
      await api.updateSettings(typeSettings: _serializeTypeSettings());
      _errorMessage = null;
      return true;
    } catch (e) {
      _notificationTypeSettings = previous;
      _nearbyListingsEnabled = previousNearby;
      _errorMessage = NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t update notification categories.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> setNearbyListingsEnabled(bool enabled) async {
    final previous = _nearbyListingsEnabled;
    _nearbyListingsEnabled = enabled;
    notifyListeners();
    try {
      final api = await _getApi();
      await api.updateSettings(typeSettings: _serializeTypeSettings());
      _errorMessage = null;
      return true;
    } catch (e) {
      _nearbyListingsEnabled = previous;
      _errorMessage = NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t update nearby alerts.',
      );
      notifyListeners();
      return false;
    }
  }

  // Check if type is enabled
  bool isNotificationTypeEnabled(NotificationType type) {
    return _notificationTypeSettings[type] ?? true;
  }

  Future<void> reloadSettings() async {
    await _loadSettings();
  }

  Map<String, bool> _serializeTypeSettings() {
    return {
      'message': _notificationTypeSettings[NotificationType.message] ?? true,
      'trade': _notificationTypeSettings[NotificationType.trade] ?? true,
      'gift': _notificationTypeSettings[NotificationType.gift] ?? true,
      'campaign': _notificationTypeSettings[NotificationType.campaign] ?? true,
      'achievement': _notificationTypeSettings[NotificationType.achievement] ?? true,
      'system': _notificationTypeSettings[NotificationType.system] ?? true,
      'reminder': _notificationTypeSettings[NotificationType.reminder] ?? true,
      'broadcast': _notificationTypeSettings[NotificationType.system] ?? true,
      'nearby': _nearbyListingsEnabled,
    };
  }
  
  // Get notifications by type
  List<AppNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }
  
  // Get recent notifications
  List<AppNotification> getRecentNotifications({int limit = 5}) {
    final recent = List<AppNotification>.from(_notifications);
    recent.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return recent.take(limit).toList();
  }
  
  // Search notifications
  List<AppNotification> searchNotifications(String query) {
    if (query.isEmpty) return _notifications;
    
    final lowerQuery = query.toLowerCase();
    return _notifications.where((n) {
      return n.title.toLowerCase().contains(lowerQuery) ||
             n.message.toLowerCase().contains(lowerQuery);
    }).toList();
  }
  
  // Helpers
  AppNotification? getNotificationById(String notificationId) {
    try {
      return _notifications.firstWhere((n) => n.id == notificationId);
    } catch (e) {
      return null;
    }
  }
  
  // Statistics
  Map<NotificationType, int> get notificationTypeStats {
    final stats = <NotificationType, int>{};
    for (final notification in _notifications) {
      stats[notification.type] = (stats[notification.type] ?? 0) + 1;
    }
    return stats;
  }
  
  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Refresh
  Future<void> refresh() async {
    await loadNotifications(refresh: true);
  }
  
  /// Handle notification tap - navigates to the relevant screen.
  void handleNotificationTap(AppNotification notification) {
    // Navigate first so mark-as-read list rebuilds don't delay the open.
    NotificationNavigation.navigateFromPayload(
      NotificationNavigation.buildPayloadFromNotification(notification),
    );
    if (!notification.isRead) {
      markAsRead(notification.id);
    }
  }

  String _typeToString(NotificationType type) {
    switch (type) {
      case NotificationType.trade: return 'TRADE';
      case NotificationType.gift: return 'GIFT';
      case NotificationType.campaign: return 'CAMPAIGN';
      case NotificationType.message: return 'CHAT';
      case NotificationType.achievement: return 'ACHIEVEMENT';
      case NotificationType.system: return 'SYSTEM';
      case NotificationType.reminder: return 'REMINDER';
    }
  }

  String _typeToSourceType(NotificationType type) {
    switch (type) {
      case NotificationType.trade: return 'trade';
      case NotificationType.gift: return 'gift';
      case NotificationType.campaign: return 'campaign';
      case NotificationType.message: return 'chat_message';
      default: return '';
    }
  }

  // API client helper
  Future<NotificationsApi> _getApi() async {
    final baseUrl = await EnvConfig.getBaseUrl();
    if (_notificationsApiClient != null && _notificationsApiBaseUrl == baseUrl) {
      return NotificationsApi(_notificationsApiClient!);
    }
    _disposeNotificationsApiClient();
    _notificationsApiBaseUrl = baseUrl;
    const storage = FlutterSecureStorage();
    _notificationsApiClient = ApiClient(baseUrl, storage);
    return NotificationsApi(_notificationsApiClient!);
  }

  // Server unread count sync
  Future<void> _refreshUnreadCount() async {
    try {
      final api = await _getApi();
      final previous = _serverUnreadCount ?? 0;
      final count = await api.getUnreadCount();
      _serverUnreadCount = count;
      notifyListeners();
      // New in-app notifications (e.g. admin broadcast) may arrive without FCM.
      // Pull the list when unread rises so the inbox stays in sync.
      if (count > previous) {
        unawaited(loadNotifications(refresh: true));
      }
    } catch (_) {
      // Silently ignore; fallback getter will compute locally
    }
  }

  // Map server notification to AppNotification
  AppNotification _fromServerItem(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String?) ?? 'system';
    final normalized = typeStr.toLowerCase();

    final data = json['data'];
    Map<String, dynamic> payload = {};
    if (data is Map) {
      payload = Map<String, dynamic>.from(data);
    }
    final rootSourceType = (json['sourceType'] as String?)?.toLowerCase() ?? '';
    final nestedSourceType =
        (payload['sourceType'] as String?)?.toLowerCase() ?? '';
    final sourceType =
        rootSourceType.isNotEmpty ? rootSourceType : nestedSourceType;
    final actionUrl = (json['actionUrl'] as String?) ?? '';
    final dataType = (payload['type'] as String?)?.toLowerCase() ?? '';
    final title = (json['title'] as String?) ?? '';

    // Chat is stored as SYSTEM_ANNOUNCEMENT on the API — classify by source first
    // so Messages / Trades / Gifts chips actually filter the inbox.
    final NotificationType type = _resolveNotificationType(
      normalized: normalized,
      sourceType: sourceType,
      dataType: dataType,
      actionUrl: actionUrl,
      title: title,
    );

    if (rootSourceType.isNotEmpty) {
      payload['sourceType'] = rootSourceType;
    } else if (nestedSourceType.isNotEmpty) {
      payload['sourceType'] = nestedSourceType;
    }
    // Prefer resolved category over raw Prisma enum (chat is often SYSTEM_ANNOUNCEMENT).
    payload['notificationType'] = sourceType == 'broadcast'
        ? 'BROADCAST'
        : _typeToString(type);

    final createdAt = json['createdAt'];
    DateTime created;
    if (createdAt is String) {
      created = DateTime.tryParse(createdAt) ?? DateTime.now();
    } else if (createdAt is int) {
      created = DateTime.fromMillisecondsSinceEpoch(createdAt);
    } else {
      created = DateTime.now();
    }

    return AppNotification(
      id: (json['id'] ?? json['uuid'] ?? '') as String,
      title: title,
      message: (json['message'] ?? '') as String,
      type: type,
      imageUrl: json['imageUrl'] as String?,
      targetId: (json['targetId'] ?? json['sourceId']) as String?,
      actionUrl: json['actionUrl'] as String?,
      isRead: _parseReadFlag(json),
      createdAt: created,
      data: payload.isEmpty ? null : payload,
    );
  }

  static NotificationType _resolveNotificationType({
    required String normalized,
    required String sourceType,
    required String dataType,
    required String actionUrl,
    required String title,
  }) {
    final titleLower = title.toLowerCase();

    if (sourceType == 'chat_message' ||
        sourceType == 'chat' ||
        dataType == 'chat' ||
        actionUrl.startsWith('/chat/') ||
        titleLower.startsWith('message from') ||
        titleLower.contains('mentioned you')) {
      return NotificationType.message;
    }
    if (sourceType == 'transfer' ||
        sourceType == 'wallet' ||
        actionUrl.startsWith('/wallet') ||
        normalized.contains('transfer') ||
        titleLower.contains('transfer sent') ||
        titleLower.contains('transfer received')) {
      return NotificationType.system;
    }
    if (sourceType == 'nearby_trade' ||
        sourceType == 'trade' ||
        actionUrl.startsWith('/trades/')) {
      return NotificationType.trade;
    }
    if (sourceType == 'nearby_gift' ||
        sourceType == 'gift' ||
        sourceType == 'gift_request' ||
        actionUrl.startsWith('/gifts/') ||
        actionUrl.contains('/gifting/')) {
      return NotificationType.gift;
    }
    if (sourceType == 'nearby_campaign' ||
        sourceType == 'campaign' ||
        sourceType == 'donation' ||
        actionUrl.contains('/campaign')) {
      return NotificationType.campaign;
    }
    if (normalized.contains('nearby')) {
      // Fallback when sourceType missing — treat as system until kind is known.
      return NotificationType.system;
    }
    if (sourceType == 'broadcast') {
      return NotificationType.system;
    }

    switch (normalized) {
      case 'message':
      case 'chat':
        return NotificationType.message;
      case 'trade':
      case 'trade_offer_received':
      case 'trade_offer_accepted':
      case 'trade_offer_rejected':
      case 'trade_completed':
      case 'trade_cancelled':
        return NotificationType.trade;
      case 'campaign':
      case 'donation':
      case 'donation_received':
      case 'campaign_milestone':
      case 'campaign_completed':
        return NotificationType.campaign;
      case 'gift':
      case 'gift_received':
      case 'gift_claimed':
      case 'gift_expired':
      case 'gift_request':
        return NotificationType.gift;
      case 'achievement':
      case 'karma':
      case 'karma_level_up':
      case 'karma_achievement':
      case 'referral_signup':
      case 'referral_bonus_earned':
        return NotificationType.achievement;
      case 'reminder':
        return NotificationType.reminder;
      case 'welcome':
      case 'system':
      case 'system_announcement':
      case 'broadcast':
      case 'security':
      case 'account_security':
      case 'verification_required':
      case 'promotion_available':
      case 'community_invite':
      case 'community_post_liked':
      case 'community_post_commented':
      case 'community_event_reminder':
        // SYSTEM_ANNOUNCEMENT without chat markers = system/broadcast.
        return NotificationType.system;
      default:
        if (normalized.contains('trade')) return NotificationType.trade;
        if (normalized.contains('gift')) return NotificationType.gift;
        if (normalized.contains('chat') || normalized.contains('message')) {
          return NotificationType.message;
        }
        if (normalized.contains('karma') || normalized.contains('referral')) {
          return NotificationType.achievement;
        }
        if (normalized.contains('donat') || normalized.contains('campaign')) {
          return NotificationType.campaign;
        }
        return NotificationType.system;
    }
  }

  static bool _parseReadFlag(Map<String, dynamic> json) {
    final raw = json.containsKey('read') ? json['read'] : json['isRead'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final v = raw.toLowerCase().trim();
      return v == 'true' || v == '1' || v == 'yes';
    }
    return false;
  }
}