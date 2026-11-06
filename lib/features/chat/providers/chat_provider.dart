import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../services/chat_service.dart';
import '../services/chat_cache.dart';
import '../models/chat_models.dart' as models;
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/message_reaction.dart';
import '../models/reply_preview.dart';
import '../models/user_presence.dart';
import '../utils/chat_message_utils.dart';
import '../utils/conversation_inbox_dedupe.dart';
import '../../../core/utils/media_utils.dart';

class ChatProvider with ChangeNotifier {
  late final ChatService _chatService;
  final AuthProvider _authProvider;
  final ApiClient _apiClient;

  // State
  List<ChatConversation> _conversations = [];
  Map<String, List<ChatMessage>> _conversationMessages = {};
  Map<String, bool> _typingUsers = {};
  /// Presence (online/last-seen) keyed by userId. Populated from WS
  /// `user_status` events so every chat screen can show real-time status.
  final Map<String, UserPresence> _presence = {};
  /// Pending reply preview per conversationId (shown above the composer).
  final Map<String, ReplyPreview> _pendingReplies = {};
  bool _isLoading = false;
  bool _isConnected = false;
  String? _error;

  // Chat presence privacy toggles (persisted via SharedPreferences). These
  // gate whether this device renders presence (online dot, "online" / "last
  // seen X") in every chat surface.
  static const _kShowOnlineStatus = 'chat_settings_show_online_status';
  static const _kShowLastSeen = 'chat_settings_show_last_seen';
  bool _showOnlineStatus = true;
  bool _showLastSeen = true;

  // Stream subscriptions
  StreamSubscription<models.ChatMessage>? _messageStreamSubscription;
  StreamSubscription<models.UserTypingNotification>? _typingStreamSubscription;
  StreamSubscription<Map<String, dynamic>>? _readReceiptStreamSubscription;
  StreamSubscription<models.UserStatusNotification>? _userStatusStreamSubscription;
  StreamSubscription<models.MessageDeliveredNotification>?
      _deliveredStreamSubscription;
  StreamSubscription<models.MessageReactionNotification>?
      _reactionStreamSubscription;

  // Debounce for refresh to prevent redundant API calls
  Timer? _refreshDebounceTimer;
  DateTime? _lastRefreshTime;
  static const Duration _refreshThrottleDuration = Duration(seconds: 5);

  /// Conversations whose message history was fetched from the API at least once.
  /// WS previews alone must not block a full history load on thread open.
  final Set<String> _historyLoadedFromApi = {};

  ChatProvider(this._authProvider, this._apiClient) {
    _chatService = ChatService(apiClient: _apiClient);
    _chatService.addListener(_relayFromService);
    _loadPresenceSettings();
    _initialize();
  }

  // Getters
  List<ChatConversation> get conversations => _conversations;
  Map<String, List<ChatMessage>> get conversationMessages => _conversationMessages;
  Map<String, bool> get typingUsers => _typingUsers;
  Map<String, UserPresence> get presence => _presence;
  UserPresence? presenceFor(String userId) => _presence[userId];
  ReplyPreview? pendingReplyFor(String conversationId) =>
      _pendingReplies[conversationId];
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String? get error => _error;

  /// Whether the UI should render online/last-seen status for other users.
  bool get showOnlineStatus => _showOnlineStatus;
  /// Whether "last seen X ago" text is rendered for offline users. Only
  /// meaningful when [showOnlineStatus] is also true.
  bool get showLastSeen => _showLastSeen;

  Future<void> _loadPresenceSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _showOnlineStatus = prefs.getBool(_kShowOnlineStatus) ?? true;
      _showLastSeen = prefs.getBool(_kShowLastSeen) ?? true;
      notifyListeners();
    } catch (_) {
      // Preferences unavailable — fall back to defaults silently.
    }
  }

  Future<void> setShowOnlineStatus(bool value) async {
    if (_showOnlineStatus == value) return;
    _showOnlineStatus = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kShowOnlineStatus, value);
    } catch (_) {}
  }

  Future<void> setShowLastSeen(bool value) async {
    if (_showLastSeen == value) return;
    _showLastSeen = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kShowLastSeen, value);
    } catch (_) {}
  }

  int get totalUnreadCount {
    return _conversations.fold(0, (sum, conversation) => sum + conversation.unreadCount);
  }

  String? get _currentUserId => _authProvider.currentUser?.id;

  /// Last signed-in user — used to clear disk cache after logout when
  /// [AuthProvider.currentUser] is already null.
  String? _persistedUserId;

  bool _isFromCurrentUser(String senderId) =>
      isSenderCurrentUser(senderId, _currentUserId);

  // Initialize provider
  void _initialize() {
    if (_authProvider.isAuthenticated && _authProvider.currentUser != null) {
      unawaited(_bootstrapFromDiskThenNetwork());
    }

    // Listen to auth changes
    _authProvider.addListener(_onAuthChanged);
  }

  /// Offline-first: paint cached inbox/threads immediately, then sync.
  Future<void> _bootstrapFromDiskThenNetwork() async {
    _persistedUserId = _currentUserId;
    await _hydrateFromDiskCache();
    _connectToChat();
    unawaited(_loadConversations());
  }

  Future<void> _hydrateFromDiskCache() async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;
    try {
      final cachedConversations = await ChatCache.loadConversations(userId);
      final cachedMessages = await ChatCache.loadAllMessages(userId);
      if (cachedConversations.isEmpty && cachedMessages.isEmpty) return;

      if (_conversations.isEmpty && cachedConversations.isNotEmpty) {
        _conversations = cachedConversations;
      }
      for (final entry in cachedMessages.entries) {
        final existing = _conversationMessages[entry.key];
        if (existing == null || existing.isEmpty) {
          _conversationMessages[entry.key] = entry.value;
        }
      }
      _clearError();
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatProvider] disk hydrate failed: $e');
    }
  }

  void _persistConversations() {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;
    unawaited(ChatCache.saveConversations(userId, _conversations));
  }

  void _persistMessages(String conversationId) {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;
    final msgs = _conversationMessages[conversationId];
    if (msgs == null) return;
    unawaited(ChatCache.saveMessages(userId, conversationId, msgs));
  }

  void _onAuthChanged() {
    if (_authProvider.isAuthenticated && _authProvider.currentUser != null) {
      _persistedUserId = _authProvider.currentUser!.id;
      unawaited(_bootstrapFromDiskThenNetwork());
    } else {
      final uid = _persistedUserId;
      _persistedUserId = null;
      _disconnectFromChat();
      _clearData(cacheUserId: uid);
    }
  }

  void _relayFromService() {
    notifyListeners();
  }

  // Connect to WebSocket
  Future<void> _connectToChat() async {
    if (_authProvider.currentUser == null) return;

    try {
      // Build WS base URL from configured HTTP base, switching scheme appropriately
      final httpBase = await EnvConfig.getBaseUrl();
      final uri = Uri.parse(httpBase);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final wsBase = Uri(
        scheme: wsScheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80),
      ).toString();

      // Use actual JWT access token for chat auth
      final token = _authProvider.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Missing auth token for chat connection');
      }

      await _chatService.initialize(
        baseUrl: wsBase,
        authToken: token,
        userId: _authProvider.currentUser!.id,
      );
      _isConnected = _chatService.isConnected;
      if (_conversations.isEmpty && _chatService.conversations.isNotEmpty) {
        _conversations = List<ChatConversation>.from(_chatService.conversations);
      }
      // Setup stream listeners now that ChatService exposes streams
      _setupStreamListeners();
      notifyListeners();
    } catch (e) {
      // Offline is fine if we already hydrated inbox from disk.
      if (_conversations.isEmpty) {
        _error =
            'Couldn\'t connect to chat. Check your connection and try again.';
      }
      notifyListeners();
    }
  }

  // Public reconnect API for UI to trigger connection recovery
  Future<void> reconnect() async {
    try {
      _disconnectFromChat();
      await _connectToChat();
    } catch (e) {
      _setError('Reconnect failed: $e');
    }
  }

  // Setup real-time stream listeners
  void _setupStreamListeners() {
    // Cancel existing subscriptions to avoid duplicates
    _messageStreamSubscription?.cancel();
    _typingStreamSubscription?.cancel();
    _readReceiptStreamSubscription?.cancel();
    _userStatusStreamSubscription?.cancel();
    _deliveredStreamSubscription?.cancel();
    _reactionStreamSubscription?.cancel();
    
    // Listen to WebSocket events from ChatService
    _messageStreamSubscription = _chatService.onNewMessage.listen((message) {
      print('ChatProvider: Received new message via WebSocket: ${message.content} for conversation ${message.conversationId}');
      _handleNewMessage(message);
    }, onError: (error) {
      print('ChatProvider: Error in message stream: $error');
    });

    _typingStreamSubscription = _chatService.onUserTyping.listen((typing) {
      _handleTypingIndicator({
        'userId': typing.userId,
        'isTyping': typing.isTyping,
        'conversationId': typing.conversationId,
      });
    });

    _readReceiptStreamSubscription = _chatService.onMessageRead.listen((data) {
      _handleReadReceipt(data);
    });

    _userStatusStreamSubscription = _chatService.onUserStatus.listen((status) {
      _handleUserStatus(status);
    });

    _deliveredStreamSubscription =
        _chatService.onMessageDelivered.listen(_handleMessageDelivered);

    _reactionStreamSubscription =
        _chatService.onMessageReaction.listen(_handleMessageReaction);
  }

  // Handle new message
  void _handleNewMessage(models.ChatMessage message) {
    // Add message to conversation messages
    final conversationId = message.conversationId;
    if (_conversationMessages[conversationId] == null) {
      _conversationMessages[conversationId] = [];
    }
    
    final localMessage = _convertToLocalMessage(message);
    final existingIndex = _conversationMessages[conversationId]!
        .indexWhere((m) => m.id == message.id);
    if (existingIndex != -1) {
      _conversationMessages[conversationId]![existingIndex] = localMessage;
    } else {
      _conversationMessages[conversationId]!.add(localMessage);
    }
    print('ChatProvider: Added message ${message.id} to conversation $conversationId (total: ${_conversationMessages[conversationId]!.length})');

    // Update conversation in list
    final conversationIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (conversationIndex != -1) {
      final updatedConversation = _conversations[conversationIndex].copyWith(
        lastMessage: localMessage,
        lastActivity: message.createdAt,
        unreadCount: _isFromCurrentUser(message.senderId)
            ? 0
            : _conversations[conversationIndex].unreadCount + 1,
      );
      _conversations[conversationIndex] = updatedConversation;
      
      // Move conversation to top
      _conversations.removeAt(conversationIndex);
      _conversations.insert(0, updatedConversation);
    } else {
      unawaited(_ensureConversationInList(
        conversationId,
        latestMessage: localMessage,
      ));
    }

    notifyListeners();
    _persistMessages(conversationId);
    _persistConversations();
  }

  void upsertConversation(ChatConversation conversation) {
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index == -1) {
      _conversations.insert(0, conversation);
    } else {
      _conversations[index] = conversation;
      _conversations.removeAt(index);
      _conversations.insert(0, conversation);
    }
    // Seed inbox preview so opening a chat never starts blank while history loads.
    final existing = _conversationMessages[conversation.id];
    if ((existing == null || existing.isEmpty) &&
        conversation.lastMessage != null) {
      _conversationMessages[conversation.id] = [conversation.lastMessage!];
    }
    _persistConversations();
    if (_conversationMessages[conversation.id] != null) {
      _persistMessages(conversation.id);
    }
  }

  /// Ensures a thread appears in the inbox — fetches from API or builds from message.
  Future<void> _ensureConversationInList(
    String conversationId, {
    ChatMessage? latestMessage,
  }) async {
    if (_conversations.any((c) => c.id == conversationId)) return;

    try {
      final conv = await _chatService.getConversation(
        conversationId,
        viewerUserId: _currentUserId,
      );
      var merged = conv;
      if (latestMessage != null) {
        merged = conv.copyWith(
          lastMessage: latestMessage,
          lastActivity: latestMessage.timestamp,
          unreadCount: latestMessage.isFromCurrentUser
              ? conv.unreadCount
              : conv.unreadCount + 1,
        );
      }
      upsertConversation(merged);
      notifyListeners();
    } catch (_) {
      if (latestMessage == null) return;
      final placeholder = ChatConversation(
        id: conversationId,
        otherUserId: latestMessage.isFromCurrentUser
            ? ''
            : latestMessage.senderId,
        otherUserName: latestMessage.isFromCurrentUser
            ? 'Chat'
            : (latestMessage.senderName.isNotEmpty
                ? latestMessage.senderName
                : 'Chat'),
        otherUserAvatar: '',
        chatType: ChatType.direct,
        contextTitle: '',
        contextId: '',
        lastMessage: latestMessage,
        lastActivity: latestMessage.timestamp,
        unreadCount: latestMessage.isFromCurrentUser ? 0 : 1,
      );
      upsertConversation(placeholder);
      notifyListeners();
    }
  }

  /// Fetch a single conversation and insert/update it in the inbox list.
  Future<ChatConversation?> fetchAndUpsertConversation(String conversationId) async {
    final trimmed = conversationId.trim();
    if (trimmed.isEmpty) return null;

    final cachedIndex = _conversations.indexWhere((c) => c.id == trimmed);
    if (cachedIndex != -1) return _conversations[cachedIndex];

    try {
      final conv = await _chatService.getConversation(
        trimmed,
        viewerUserId: _currentUserId,
      );
      upsertConversation(conv);
      notifyListeners();
      return conv;
    } catch (e) {
      print('[ChatProvider] fetchAndUpsertConversation failed: $e');
      return null;
    }
  }

  // Handle typing indicator
  void _handleTypingIndicator(Map<String, dynamic> data) {
    final userId = data['userId'] as String?;
    final isTyping = data['isTyping'] as bool? ?? false;
    
    if (userId != null) {
      final prev = _typingUsers[userId] == true;
      if (prev == isTyping) return;
      _typingUsers[userId] = isTyping;
      notifyListeners();
    }
  }

  void _mirrorServiceMessages(String conversationId) {
    final serviceMsgs = _chatService.getMessagesForConversation(conversationId);
    if (serviceMsgs.isEmpty) return;
    final next = dedupeChatMessagesById(
      serviceMsgs.map(_convertToLocalMessage).toList(),
    );
    final prev = _conversationMessages[conversationId];
    if (_sameMessageFingerprint(prev, next)) return;
    _conversationMessages[conversationId] = next;
  }

  bool _sameMessageFingerprint(List<ChatMessage>? a, List<ChatMessage> b) {
    if (a == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].deliveryStatus != b[i].deliveryStatus) {
        return false;
      }
    }
    return true;
  }

  // Handle read receipt — ChatService has already updated statuses; mirror into UI model
  void _handleReadReceipt(Map<String, dynamic> data) {
    final conversationId = data['conversationId'] as String?;
    if (conversationId == null) return;
    if (!_conversationMessages.containsKey(conversationId)) return;
    final before = _conversationMessages[conversationId];
    _mirrorServiceMessages(conversationId);
    final after = _conversationMessages[conversationId];
    if (!_sameMessageFingerprint(before, after ?? const [])) {
      notifyListeners();
    }
  }

  // Handle user status changes — update presence map for every screen.
  void _handleUserStatus(models.UserStatusNotification status) {
    final isOnline = status.status.toLowerCase() == 'online';
    final prev = _presence[status.userId];
    if (prev != null &&
        prev.isOnline == isOnline &&
        prev.lastSeenAt == status.lastSeenAt) {
      return;
    }
    _presence[status.userId] = UserPresence(
      userId: status.userId,
      isOnline: isOnline,
      lastSeenAt: status.lastSeenAt,
    );
    notifyListeners();
  }

  /// Mirror DELIVERED status from ChatService into the local UI model so all
  /// screens re-render the double grey tick for our outgoing messages.
  void _handleMessageDelivered(models.MessageDeliveredNotification event) {
    if (!_conversationMessages.containsKey(event.conversationId)) return;
    final before = _conversationMessages[event.conversationId];
    _mirrorServiceMessages(event.conversationId);
    final after = _conversationMessages[event.conversationId];
    if (!_sameMessageFingerprint(before, after ?? const [])) {
      notifyListeners();
    }
  }

  /// Mirror reaction add/remove from ChatService into the local UI model.
  void _handleMessageReaction(models.MessageReactionNotification event) {
    if (!_conversationMessages.containsKey(event.conversationId)) return;
    final before = _conversationMessages[event.conversationId];
    _mirrorServiceMessages(event.conversationId);
    final after = _conversationMessages[event.conversationId];
    if (!_sameMessageFingerprint(before, after ?? const [])) {
      notifyListeners();
    }
  }

  // Load conversations
  Future<void> _loadConversations({String? module}) async {
    // Check authentication before making API call
    if (!_authProvider.isAuthenticated || _authProvider.currentUser == null) {
      print('[ChatProvider] Cannot load conversations - user not authenticated');
      _setError('Please log in to view conversations');
      _setLoading(false);
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      await _chatService.loadConversations(module: module);
      _conversations = _chatService.conversations;
      _clearError();
      notifyListeners();
      _persistConversations();
    } catch (e) {
      print('[ChatProvider] Error loading conversations: $e');
      // Check if it's an authentication error
          if (e.toString().contains('401') || 
          e.toString().contains('Unauthorized') ||
          e.toString().contains('jwt expired') ||
          e.toString().contains('No auth token')) {
        _setError('Session expired. Please log in again.');
        // Clear in-memory only — keep disk cache for offline reopen after login.
        _conversations.clear();
        _conversationMessages.clear();
        _historyLoadedFromApi.clear();
        notifyListeners();
      } else if (_conversations.isEmpty) {
        // Offline with no cache — friendly error.
        _setError(
          'Couldn\'t load chats. Check your connection and try again.',
        );
      } else {
        // Keep showing cached inbox offline; clear blocking error.
        _clearError();
      }
    } finally {
      _setLoading(false);
    }
  }

  // Load conversations filtered by module.
  // GIFT uses DIRECT type with metadata.sourceType; backend has no GIFT enum.
  // Load all conversations for Gift tab and filter client-side.
  Future<void> loadConversationsByModule(String module) async {
    final apiModule = module == 'GIFT' ? null : module;
    await _loadConversations(module: apiModule);
  }

  /// In-memory lookup — no network round-trip.
  ChatConversation? findConversationInCache({
    String? contextId,
    required String partnerId,
  }) {
    final cid = contextId?.trim();
    if (cid != null && cid.isNotEmpty) {
      for (final c in _conversations) {
        if (c.contextId == cid && c.otherUserId == partnerId) return c;
      }
      for (final c in _conversations) {
        if (c.contextId == cid) return c;
      }
    }
    for (final c in _conversations) {
      if (c.otherUserId == partnerId) return c;
    }
    return null;
  }

  // Reload all conversations (used for deep links) with throttle to prevent redundant calls
  Future<void> refreshConversations({bool force = false}) async {
    if (!_authProvider.isAuthenticated || _authProvider.currentUser == null) {
      return;
    }
    
    // Check if we've refreshed too recently
    if (!force && _lastRefreshTime != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
      if (timeSinceLastRefresh < _refreshThrottleDuration) {
        // Too soon, skip this refresh
        return;
      }
    }
    
    try {
      final localsBefore = List<ChatConversation>.from(_conversations);
      await _chatService.loadConversations(refresh: true);
      _lastRefreshTime = DateTime.now();
      final fetched = _chatService.conversations;
      final fetchedIds = fetched.map((c) => c.id).toSet();
      final localsOnly = localsBefore
          .where((c) => !fetchedIds.contains(c.id))
          .toList();
      _conversations = [...fetched, ...localsOnly];
      _conversations.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
      notifyListeners();
      _persistConversations();
    } catch (e) {
      print('[ChatProvider] Error refreshing conversations: $e');
      if (_conversations.isEmpty && _chatService.conversations.isNotEmpty) {
        _conversations = List<ChatConversation>.from(_chatService.conversations);
        notifyListeners();
        _persistConversations();
      }
    }
  }

  bool hasLoadedHistory(String conversationId) =>
      _historyLoadedFromApi.contains(conversationId);

  // Load messages for a conversation.
  // Cache-first: existing messages stay visible; fetch replaces/merges in place
  // (never clears to [] first). Sibling-thread merge runs in the background.
  Future<void> loadMessages(String conversationId, {bool refresh = false}) async {
    final needsFetch = refresh || !_historyLoadedFromApi.contains(conversationId);
    print(
      'Loading messages for conversation: $conversationId, refresh: $refresh, needsFetch: $needsFetch',
    );

    // Seed from disk if this process has nothing yet (cold start / offline).
    final existing = _conversationMessages[conversationId];
    if (existing == null || existing.isEmpty) {
      final userId = _currentUserId;
      if (userId != null && userId.isNotEmpty) {
        final disk = await ChatCache.loadMessages(userId, conversationId);
        if (disk.isNotEmpty) {
          _conversationMessages[conversationId] = disk;
          notifyListeners();
        }
      }
    }

    if (!needsFetch) {
      print('Message history already loaded for conversation: $conversationId');
      // Still join the WS room so live receive works on reopen.
      unawaited(_chatService.ensureJoinedConversation(conversationId));
      return;
    }

    final beforeFetch = _conversationMessages[conversationId];

    try {
      // Prefer service cache when available; always hit HTTP on first history
      // load or explicit refresh so seeded preview bubbles don't skip fetch.
      await _chatService.loadMessages(conversationId, refresh: true);
      final serviceMessages =
          _chatService.getMessagesForConversation(conversationId);
      print(
        'Loaded ${serviceMessages.length} messages from service for conversation: $conversationId',
      );

      var localMessages = dedupeChatMessagesById(
        serviceMessages.map(_convertToLocalMessage).toList(),
      );

      // Keep any optimistic / WS / disk messages that arrived before HTTP.
      if (beforeFetch != null && beforeFetch.isNotEmpty) {
        localMessages = dedupeChatMessagesById([
          ...beforeFetch,
          ...localMessages,
        ]);
        localMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }

      _conversationMessages[conversationId] = localMessages;
      _historyLoadedFromApi.add(conversationId);
      print(
        'Stored ${localMessages.length} messages locally for conversation: $conversationId',
      );
      // Avoid idle flicker: only rebuild when history actually changed.
      if (!_sameMessageFingerprint(beforeFetch, localMessages)) {
        notifyListeners();
      }

      _persistMessages(conversationId);

      // Warm URL cache in background (don't delay first paint).
      unawaited(_prefetchChatMediaUrls(localMessages));
      // Don't block the first paint on sibling-thread merges.
      unawaited(_mergeSiblingMessagesInBackground(conversationId));
    } catch (e) {
      print('Failed to load messages for conversation $conversationId: $e');
      // Keep disk/memory cache visible offline — don't block the thread UI.
      final stillHave =
          _conversationMessages[conversationId]?.isNotEmpty == true;
      if (!stillHave) {
        _setError(
          'Couldn\'t load messages. Check your connection and try again.',
        );
      }
    }
  }

  Future<void> _mergeSiblingMessagesInBackground(String conversationId) async {
    ChatConversation? primary;
    for (final c in _conversations) {
      if (c.id == conversationId) {
        primary = c;
        break;
      }
    }
    if (primary == null || primary.otherUserId.trim().isEmpty) return;

    final siblings = siblingConversationsForContact(
      _conversations,
      otherUserId: primary.otherUserId,
      chatType: primary.chatType,
      primaryId: conversationId,
    );
    if (siblings.isEmpty) return;

    var localMessages =
        List<ChatMessage>.from(_conversationMessages[conversationId] ?? const []);
    var changed = false;
    for (final sibling in siblings) {
      try {
        // Use cached sibling history when possible.
        final forceHttp = !_historyLoadedFromApi.contains(sibling.id);
        await _chatService.loadMessages(sibling.id, refresh: forceHttp);
        final extra = _chatService
            .getMessagesForConversation(sibling.id)
            .map(_convertToLocalMessage);
        final before = localMessages.length;
        localMessages = dedupeChatMessagesById([...localMessages, ...extra]);
        if (localMessages.length != before) changed = true;
        _historyLoadedFromApi.add(sibling.id);
      } catch (e) {
        debugPrint('[ChatProvider] sibling merge failed for ${sibling.id}: $e');
      }
    }
    if (!changed) return;
    localMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final existing = _conversationMessages[conversationId];
    if (_sameMessageFingerprint(existing, localMessages)) return;
    _conversationMessages[conversationId] = localMessages;
    notifyListeners();
    unawaited(_prefetchChatMediaUrls(localMessages));
    _persistMessages(conversationId);
  }

  /// Warm MediaResolver URL cache for image/video keys (Facebook/WhatsApp
  /// style). Bubbles show fixed placeholders; when URLs resolve, disk cache
  /// paints without restarting futures on every parent rebuild.
  Future<void> _prefetchChatMediaUrls(List<ChatMessage> messages) async {
    final futures = <Future<void>>[];
    for (final m in messages) {
      final key = m.mediaStorageKey?.trim();
      if (key == null || key.isEmpty) continue;
      if (m.messageType == MessageType.image) {
        if (MediaResolver.peekCachedUrl(key) != null) continue;
        futures.add(MediaResolver.resolveUrl(key).then((_) {}));
      } else if (m.messageType == MessageType.video) {
        if (MediaResolver.peekCachedUrl(key) != null) continue;
        futures.add(
          MediaResolver.resolveUrl(key, forVideo: true).then((_) {}),
        );
      }
    }
    if (futures.isEmpty) return;
    await Future.wait(futures);
  }

  // Load earlier messages (pagination)
  Future<int> loadEarlierMessages(String conversationId) async {
    try {
      final added = await _chatService.loadEarlier(conversationId);
      notifyListeners();
      return added;
    } catch (e) {
      _setError('Failed to load earlier messages: $e');
      return 0;
    }
  }

  // Send message. Returns true on success.
  Future<bool> sendMessage(
    String conversationId,
    String content, {
    MessageType type = MessageType.text,
    String? replyToId,
    Map<String, dynamic>? metadata,
  }) async {
    print('Sending message to conversation: $conversationId, content: $content');
    try {
      // Map local MessageType enum to API ChatMessageType string
      String apiType;
      switch (type) {
        case MessageType.text:
          apiType = 'TEXT';
          break;
        case MessageType.image:
          apiType = 'IMAGE';
          break;
        case MessageType.video:
        case MessageType.file:
        case MessageType.voice:
          apiType = 'FILE';
          break;
        case MessageType.system:
          apiType = 'SYSTEM';
          break;
        case MessageType.trade:
          apiType = 'TRADE_OFFER';
          break;
        case MessageType.gift:
          apiType = 'PAYMENT';
          break;
        case MessageType.donation:
          apiType = 'PAYMENT';
          break;
      }

      await _chatService.sendMessage(
        conversationId: conversationId,
        content: content,
        type: apiType,
        replyToId: replyToId,
        metadata: metadata,
      );

      // Ensure UI has the message even if the stream listener was late.
      final serviceMsgs =
          _chatService.getMessagesForConversation(conversationId);
      if (serviceMsgs.isNotEmpty) {
        _handleNewMessage(serviceMsgs.last);
      }

      if (_error != null) {
        _error = null;
        notifyListeners();
      }
      print('Message sent successfully to conversation: $conversationId');
      return true;
    } catch (e) {
      print('Failed to send message to conversation $conversationId: $e');
      _setError('Failed to send message: $e');
      return false;
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _chatService.deleteConversation(conversationId);
      _conversations.removeWhere((c) => c.id == conversationId);
      _conversationMessages.remove(conversationId);
      _historyLoadedFromApi.remove(conversationId);
      notifyListeners();
      _persistConversations();
      final userId = _currentUserId;
      if (userId != null && userId.isNotEmpty) {
        unawaited(ChatCache.saveMessages(userId, conversationId, const []));
      }
    } catch (e) {
      _setError('Failed to delete conversation: $e');
      throw e;
    }
  }

  // Mark conversation as read (clears unread badge when user opens chat)
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      await _chatService.markConversationAsRead(conversationId);
      // Update local state so UI updates immediately
      final conversationIndex = _conversations.indexWhere((c) => c.id == conversationId);
      if (conversationIndex != -1 && _conversations[conversationIndex].unreadCount > 0) {
        _conversations[conversationIndex] = _conversations[conversationIndex].copyWith(unreadCount: 0);
        notifyListeners();
      }
    } catch (e) {
      // Still clear local badge on error so user doesn't see stale count
      final conversationIndex = _conversations.indexWhere((c) => c.id == conversationId);
      if (conversationIndex != -1 && _conversations[conversationIndex].unreadCount > 0) {
        _conversations[conversationIndex] = _conversations[conversationIndex].copyWith(unreadCount: 0);
        notifyListeners();
      }
    }
  }

  // User online status
  String? getUserStatus(String userId) {
    return _chatService.userStatuses[userId];
  }

  // Start direct message
  Future<ChatConversation?> startDirectMessage({
    required String recipientId,
    String? recipientName,
    String? initialMessage,
    String? contextTitle,
    String? contextId,
    String? apiType,
  }) async {
    print('DEBUG: startDirectMessage called with recipientId=$recipientId, contextId=$contextId, contextTitle=$contextTitle, apiType=$apiType');
    // Prevent attempting to start a DM with oneself, which can cause server errors
    final currentUserId = _authProvider.currentUser?.id;
    if (currentUserId != null && currentUserId == recipientId) {
      _setError('You cannot start a chat with yourself.');
      return null;
    }
    
    // First try to find an existing conversation with the same context (for gift-related chats)
    if (contextId != null && contextId.isNotEmpty) {
      print('DEBUG: Searching for existing conversation with contextId=$contextId and recipientId=$recipientId');
      var existingIndex = _conversations.indexWhere(
        (c) => c.contextId == contextId && c.otherUserId == recipientId,
      );
      // If not found with both context + recipient (e.g. older conversations
      // that may be missing one of the IDs), fall back to matching on
      // contextId alone so we still reuse the correct gift thread.
      if (existingIndex == -1) {
        existingIndex = _conversations.indexWhere(
          (c) => c.contextId == contextId,
        );
      }
      print('DEBUG: Found existing conversation at index: $existingIndex');
      if (existingIndex != -1) {
        final existing = _conversations[existingIndex];
        print('DEBUG: Found existing conversation: id=${existing.id}, contextId=${existing.contextId}, contextTitle=${existing.contextTitle}');
        await loadMessages(existing.id);
        notifyListeners();
        return existing;
      }
    }

    // If no context-specific conversation, fall back to any direct
    // conversation with this recipient. This prevents creating multiple
    // DMs (and repeating the auto "I'm interested" message) when a
    // generic DIRECT conversation between the two users already exists
    // from another flow (e.g. a campaign).
    final directWithRecipientIndex = _conversations.indexWhere(
      (c) => c.otherUserId == recipientId,
    );
    if (directWithRecipientIndex != -1) {
      final existing = _conversations[directWithRecipientIndex];
      print('DEBUG: Reusing existing DIRECT conversation with recipientId=$recipientId, id=${existing.id}, contextId=${existing.contextId}, contextTitle=${existing.contextTitle}');
      await loadMessages(existing.id, refresh: true);
      notifyListeners();
      return existing;
    }
    
    try {
      // First try to start a direct message
      final conversation = await _chatService.startDirectMessage(
        recipientId: recipientId,
        initialMessage: initialMessage,
        type: apiType,
        contextId: contextId,
        contextTitle: contextTitle,
        viewerUserId: currentUserId,
      );
      
      // Update conversation with additional context if provided
      final updatedConversation =
          (recipientName != null || contextTitle != null || contextId != null)
          ? conversation.copyWith(
              otherUserName: recipientName ?? conversation.otherUserName,
              contextTitle: contextTitle ?? conversation.contextTitle,
              contextId: contextId ?? conversation.contextId,
            )
          : conversation;
      
      // Debug logging
      print('Created/updated conversation: id=${updatedConversation.id}, contextId=${updatedConversation.contextId}, contextTitle=${updatedConversation.contextTitle}, otherUserId=${updatedConversation.otherUserId}');

      // Add to conversations list if not already present
      final existingIndex = _conversations.indexWhere((c) => c.id == updatedConversation.id);
      if (existingIndex == -1) {
        _conversations.insert(0, updatedConversation);
      } else {
        _conversations[existingIndex] = updatedConversation;
      }

      // Ensure message history is available immediately (for existing or new conversations)
      try {
        await loadMessages(updatedConversation.id, refresh: true);
      } catch (messageError) {
        // Log but don't fail - conversation is created, messages can load later
        print('DEBUG: Failed to load initial messages, but conversation created: $messageError');
      }
      
      notifyListeners();
      return updatedConversation;
    } catch (e) {
      // Fallback: try to locate an existing conversation with the recipient and open it
      try {
        print('DEBUG: Loading conversations from service');
        await _chatService.loadConversations(refresh: true);
        _conversations = _chatService.conversations;
        print('DEBUG: Loaded ${_conversations.length} conversations from service');
        for (var i = 0; i < _conversations.length; i++) {
          final conv = _conversations[i];
          print('DEBUG: Conversation $i: id=${conv.id}, contextId=${conv.contextId}, contextTitle=${conv.contextTitle}, otherUserId=${conv.otherUserId}');
        }
        
        // First try to find by context ID if provided (for gift-related chats)
        int existingIndex = -1;
        if (contextId != null && contextId.isNotEmpty) {
          existingIndex = _conversations.indexWhere(
            (c) => c.contextId == contextId && c.otherUserId == recipientId,
          );
          print('Searching for existing conversation by contextId=$contextId and recipientId=$recipientId, found index: $existingIndex');
          // If still not found, try by contextId alone.
          if (existingIndex == -1) {
            existingIndex = _conversations.indexWhere(
              (c) => c.contextId == contextId,
            );
            print('Searching for existing conversation by contextId=$contextId only, found index: $existingIndex');
          }
        }
        
        // If not found by context ID, try to find by recipient ID
        if (existingIndex == -1) {
          existingIndex = _conversations.indexWhere((c) => c.otherUserId == recipientId);
          print('Searching for existing conversation by recipientId=$recipientId, found index: $existingIndex');
        }
        
        if (existingIndex != -1) {
          final existing = _conversations[existingIndex];
          print('Found existing conversation: id=${existing.id}, contextId=${existing.contextId}, contextTitle=${existing.contextTitle}');
          await loadMessages(existing.id);
          notifyListeners();
          return existing;
        }
        
        // If no existing conversation, return null to let the caller handle the error
        // The startDirectMessage call should have created the conversation if possible
      } catch (_) {
        // ignore fallback errors and surface the original
      }

      print('Failed to start direct message: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');
      if (e is Error) {
        print('Error stack: ${e.stackTrace}');
      }
      // Provide a more user-friendly error message
      final errorMessage = e.toString().contains('Exception') || e.toString().contains('Error')
          ? 'An error occurred. Please try again.'
          : 'Failed to start chat: ${e.toString()}';
      _setError(errorMessage);
      return null;
    }
  }

  /// Sends [content] only if the thread has no messages yet (e.g. reused
  /// conversation where the API did not send an initial message).
  Future<bool> sendFirstMessageIfThreadEmpty({
    required String conversationId,
    required String content,
    String? listingPreviewImageKey,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    if (_conversationMessages[conversationId] == null) {
      await loadMessages(conversationId, refresh: true);
    }
    final msgs = _conversationMessages[conversationId] ?? [];
    if (msgs.isNotEmpty) return false;
    await sendMessage(conversationId, trimmed);
    await sendListingThumbnailIfNeeded(
      conversationId: conversationId,
      previewImageKey: listingPreviewImageKey,
    );
    await loadMessages(conversationId, refresh: true);
    return true;
  }

  /// Attaches the listing photo/poster after the intro text when starting
  /// chats from trade, gift, or donation details.
  Future<void> sendListingThumbnailIfNeeded({
    required String conversationId,
    String? previewImageKey,
  }) async {
    final key = previewImageKey?.trim();
    if (key == null || key.isEmpty) return;

    if (_conversationMessages[conversationId] == null) {
      await loadMessages(conversationId, refresh: true);
    }
    final msgs = _conversationMessages[conversationId] ?? [];
    final alreadySent = msgs.any((m) {
      if (m.messageType != MessageType.image) return false;
      if (m.imageUrl == key) return true;
      final mediaKeys = m.metadata?['mediaKeys'];
      if (mediaKeys is List && mediaKeys.map((e) => e.toString()).contains(key)) {
        return true;
      }
      return false;
    });
    if (alreadySent) return;

    await sendMessage(
      conversationId,
      'Listing preview',
      type: MessageType.image,
      metadata: {'mediaKeys': [key]},
    );
    await loadMessages(conversationId, refresh: true);
  }

  // Search conversations
  Future<List<ChatConversation>> searchConversations(String query) async {
    try {
      return await _chatService.searchConversations(query);
    } catch (e) {
      _setError('Failed to search conversations: $e');
      return [];
    }
  }

  // Add reaction to message
  Future<void> addReaction(String messageId, String emoji) async {
    try {
      await _chatService.addReaction(messageId, emoji);
    } catch (e) {
      _setError('Failed to add reaction: $e');
    }
  }

  // Remove reaction from message
  Future<void> removeReaction(String messageId, String emoji) async {
    try {
      await _chatService.removeReaction(messageId, emoji);
    } catch (e) {
      _setError('Failed to remove reaction: $e');
    }
  }

  /// Set (or replace) the pending reply preview for [conversationId]. The
  /// composer should show a quoted preview above the input when this is set.
  void setReplyTarget(String conversationId, ReplyPreview preview) {
    _pendingReplies[conversationId] = preview;
    notifyListeners();
  }

  /// Clear any pending reply target for [conversationId].
  void clearReplyTarget(String conversationId) {
    if (_pendingReplies.remove(conversationId) != null) {
      notifyListeners();
    }
  }

  /// Send a reply to [replyToMessageId]. Convenience wrapper around
  /// [sendMessage] that also clears the pending reply preview.
  Future<bool> sendReply({
    required String conversationId,
    required String content,
    required String replyToMessageId,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    final ok = await sendMessage(
      conversationId,
      content,
      type: type,
      replyToId: replyToMessageId,
      metadata: metadata,
    );
    if (ok) clearReplyTarget(conversationId);
    return ok;
  }

  // Report message
  Future<void> reportMessage(String messageId, String reason, {String? description}) async {
    try {
      await _chatService.reportMessage(
        messageId: messageId,
        reason: reason,
        description: description,
      );
    } catch (e) {
      _setError('Failed to report message: $e');
    }
  }

  // Typing indicators
  void startTyping(String conversationId) {
    _chatService.startTyping(conversationId);
  }

  void stopTyping(String conversationId) {
    _chatService.stopTyping();
  }

  // Join conversation (for WebSocket) so live messages arrive in this room.
  void joinConversation(String conversationId) {
    unawaited(_chatService.ensureJoinedConversation(conversationId));
  }

  // Utility methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void _clearData({String? cacheUserId}) {
    // Keep Hive chat cache so threads reopen offline after restart/login.
    // Cache keys are scoped per userId.
    _conversations.clear();
    _conversationMessages.clear();
    _historyLoadedFromApi.clear();
    _typingUsers.clear();
    _isConnected = false;
    notifyListeners();
  }

  void _disconnectFromChat() {
    // TODO: ChatService doesn't have disconnect method yet
    // _chatService.disconnect();
    _messageStreamSubscription?.cancel();
    _typingStreamSubscription?.cancel();
    _readReceiptStreamSubscription?.cancel();
    _userStatusStreamSubscription?.cancel();
    _deliveredStreamSubscription?.cancel();
    _reactionStreamSubscription?.cancel();
    _isConnected = false;
  }

  // Helper method to convert models.ChatMessage to local ChatMessage
  ChatMessage _convertToLocalMessage(models.ChatMessage message) {
    final meta = message.metadata as Map<String, dynamic>?;
    final mediaKeys = meta?['mediaKeys'] as List?;
    final imageKey = mediaKeys?.isNotEmpty == true
        ? mediaKeys!.first.toString()
        : null;
    final audioKey = meta?['audioKey'] as String?;

    // Carry quoted-reply preview from the service model across the boundary.
    ReplyPreview? replyPreview;
    if (message.replyTo != null) {
      final r = message.replyTo!;
      replyPreview = ReplyPreview(
        messageId: r.id,
        senderId: r.senderId,
        senderName: r.sender.displayName ?? 'Unknown',
        contentPreview: r.content.length > 160
            ? r.content.substring(0, 160)
            : r.content,
        type: r.type,
      );
    }

    // Carry emoji reactions.
    final localReactions = message.reactions
        .map(
          (r) => MessageReaction(
            userId: r.userId,
            emoji: r.emoji,
            createdAt: r.createdAt,
          ),
        )
        .toList();

    return ChatMessage(
      id: message.id,
      senderId: message.senderId,
      senderName: message.sender.displayName ?? 'Unknown',
      message: message.content,
      timestamp: message.createdAt,
      isFromCurrentUser: _isFromCurrentUser(message.senderId),
      messageType: _mapMessageType(message.type, meta),
      deliveryStatus: message.status,
      imageUrl: imageKey,
      audioKey: audioKey,
      replyTo: replyPreview,
      reactions: localReactions,
      metadata: message.metadata,
    );
  }

  // Helper method to convert API MessageType to local MessageType
  MessageType _mapMessageType(String apiType, [Map<String, dynamic>? meta]) {
    switch (apiType.toUpperCase()) {
      case 'TEXT':
        return MessageType.text;
      case 'IMAGE':
        return MessageType.image;
      case 'FILE':
        if (meta?['audioKey'] != null) return MessageType.voice;
        if (ChatMessage.isVideoMetadata(meta)) return MessageType.video;
        return MessageType.file;
      case 'SYSTEM':
        return MessageType.system;
      case 'TRADE_OFFER':
        return MessageType.trade;
      case 'PAYMENT':
        return MessageType.gift;
      default:
        return MessageType.text;
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    _refreshDebounceTimer?.cancel();
    _disconnectFromChat();
    _chatService.dispose();
    super.dispose();
  }
}
