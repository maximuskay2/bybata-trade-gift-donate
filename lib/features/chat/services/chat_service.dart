import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart' as local;
import '../../../core/api/api_client.dart';
import 'chat_http_service.dart';
import 'chat_websocket_service.dart';

class ChatService extends ChangeNotifier {
  final ChatHttpService _httpService;
  final ChatWebSocketService _webSocketService;

  // State
  List<ChatConversation> _conversations = [];
  Map<String, List<ChatMessage>> _messages = {};
  Map<String, Set<String>> _typingUsers = {};
  Map<String, String> _userStatuses = {};
  final Map<String, int> _messagePages = {};
  final Map<String, String?> _messageCursors = {};
  bool _isInitialized = false;
  String? _currentUserId;

  // Stream subscriptions
  StreamSubscription? _newMessageSubscription;
  StreamSubscription? _messageReadSubscription;
  StreamSubscription? _messageDeliveredSubscription;
  StreamSubscription? _messageReactionSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _userStatusSubscription;
  StreamSubscription? _connectionSubscription;

  /// Map of userId -> last known `lastSeenAt` timestamp reported by the
  /// server. Used by presence UI when a user goes offline.
  final Map<String, DateTime> _userLastSeen = {};

  ChatService({required ApiClient apiClient})
    : _httpService = ChatHttpService(apiClient: apiClient),
      _webSocketService = ChatWebSocketService();

  // Getters
  List<ChatConversation> get conversations => _conversations;
  Map<String, List<ChatMessage>> get messages => _messages;
  Map<String, Set<String>> get typingUsers => _typingUsers;
  Map<String, String> get userStatuses => _userStatuses;
  Map<String, DateTime> get userLastSeen => _userLastSeen;
  bool get isInitialized => _isInitialized;
  bool get isConnected => _webSocketService.isConnected;
  
  // Stream getters for ChatProvider
  Stream<ChatMessage> get onNewMessage => _webSocketService.onNewMessage;
  Stream<Map<String, dynamic>> get onMessageRead => _webSocketService.onMessageRead;
  Stream<MessageDeliveredNotification> get onMessageDelivered =>
      _webSocketService.onMessageDelivered;
  Stream<MessageReactionNotification> get onMessageReaction =>
      _webSocketService.onMessageReaction;
  Stream<UserTypingNotification> get onUserTyping => _webSocketService.onUserTyping;
  Stream<UserStatusNotification> get onUserStatus => _webSocketService.onUserStatus;

  // Get messages for a specific conversation
  List<ChatMessage> getMessagesForConversation(String conversationId) {
    return _messages[conversationId] ?? [];
  }

  // Get typing users for a conversation (excluding current user)
  Set<String> getTypingUsersForConversation(String conversationId) {
    final typingUsers = _typingUsers[conversationId] ?? {};
    return typingUsers.where((userId) => userId != _currentUserId).toSet();
  }

  // Initialize the chat service
  Future<void> initialize({
    required String baseUrl,
    required String authToken,
    required String userId,
  }) async {
    try {
      log('Initializing chat service for user: $userId');
      _currentUserId = userId;

      // Connect to WebSocket
      await _webSocketService.connect(
        baseUrl: baseUrl,
        authToken: authToken,
        userId: userId,
      );

      // Replace listeners (initialize may run more than once on reconnect).
      _cancelWebSocketListeners();
      _setupWebSocketListeners();

      // Conversations load must not block send/receive listeners.
      try {
        await loadConversations();
      } catch (e) {
        log('Initial conversations load failed (will retry later): $e');
      }

      _isInitialized = true;
      notifyListeners();

      log('Chat service initialized successfully');
    } catch (e) {
      log('Failed to initialize chat service: $e');
      rethrow;
    }
  }

  void _cancelWebSocketListeners() {
    _newMessageSubscription?.cancel();
    _messageReadSubscription?.cancel();
    _messageDeliveredSubscription?.cancel();
    _messageReactionSubscription?.cancel();
    _typingSubscription?.cancel();
    _userStatusSubscription?.cancel();
    _connectionSubscription?.cancel();
    _newMessageSubscription = null;
    _messageReadSubscription = null;
    _messageDeliveredSubscription = null;
    _messageReactionSubscription = null;
    _typingSubscription = null;
    _userStatusSubscription = null;
    _connectionSubscription = null;
  }

  void _setupWebSocketListeners() {
    // New message events
    _newMessageSubscription = _webSocketService.onNewMessage.listen((message) {
      _handleNewMessage(message);
    });

    // Message read events
    _messageReadSubscription = _webSocketService.onMessageRead.listen((data) {
      _handleMessageRead(data);
    });

    // Message delivered events (double grey tick)
    _messageDeliveredSubscription =
        _webSocketService.onMessageDelivered.listen(_handleMessageDelivered);

    // Message reaction events (emoji add/remove)
    _messageReactionSubscription =
        _webSocketService.onMessageReaction.listen(_handleMessageReaction);

    // Typing events
    _typingSubscription = _webSocketService.onUserTyping.listen((typing) {
      _handleTypingEvent(typing);
    });

    // User status events
    _userStatusSubscription = _webSocketService.onUserStatus.listen((status) {
      _handleUserStatusEvent(status);
    });

    // Connection events
    _connectionSubscription = _webSocketService.onConnectionChanged.listen((
      isConnected,
    ) {
      if (isConnected) {
        log('WebSocket reconnected, rejoining conversations');
        _rejoinActiveConversations();
      }
      notifyListeners();
    });
  }

  void _handleNewMessage(ChatMessage message) {
    if (_messages[message.conversationId] == null) {
      _messages[message.conversationId] = [];
    }
    final list = _messages[message.conversationId]!;
    if (list.any((m) => m.id == message.id)) {
      return;
    }
    list.add(message);

    // Update conversation list
    final conversationIndex = _conversations.indexWhere(
      (c) => c.id == message.conversationId,
    );
    if (conversationIndex != -1) {
      final conversation = _conversations[conversationIndex];
      // Convert to local ChatMessage for the conversation
      final localMessage = local.ChatMessage.fromText(
        message.content,
        message.senderId,
      );
      final updatedConversation = conversation.copyWith(
        lastMessage: localMessage,
        lastActivity: message.createdAt,
        unreadCount: message.senderId != _currentUserId
            ? conversation.unreadCount + 1
            : 0,
      );

      _conversations[conversationIndex] = updatedConversation;

      // Move to top
      _conversations.removeAt(conversationIndex);
      _conversations.insert(0, updatedConversation);
    }

    // Clear typing indicator for sender
    _typingUsers[message.conversationId]?.remove(message.senderId);

    // Auto-ack delivery for messages from other users so the sender gets the
    // double grey tick as soon as our device receives the payload.
    if (_currentUserId != null &&
        message.senderId != _currentUserId &&
        message.senderId.isNotEmpty &&
        _webSocketService.isConnected) {
      _webSocketService.ackMessageDelivered(
        conversationId: message.conversationId,
        messageId: message.id,
      );
    }

    notifyListeners();
    log('New message added: ${message.content}');
  }

  void _handleMessageRead(Map<String, dynamic> data) {
    final conversationId = data['conversationId'] as String;
    final messageId = data['messageId'] as String;
    final readBy = data['readBy'] as String;

    // Other user read our messages — mark our outgoing messages up to [messageId] as READ
    final messages = _messages[conversationId];
    if (messages != null && readBy != _currentUserId) {
      final messageIndex = messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        final newList = List<ChatMessage>.from(messages);
        for (int i = 0; i <= messageIndex; i++) {
          final m = newList[i];
          if (m.senderId == _currentUserId &&
              m.status.toUpperCase() != 'READ') {
            newList[i] = m.copyWith(status: 'READ');
            log('Message ${m.id} marked as read by $readBy');
          }
        }
        _messages[conversationId] = newList;
      }
    }

    notifyListeners();
  }

  void _handleTypingEvent(UserTypingNotification typing) {
    if (typing.userId == _currentUserId) return; // Ignore our own typing

    if (_typingUsers[typing.conversationId] == null) {
      _typingUsers[typing.conversationId] = {};
    }

    if (typing.isTyping) {
      _typingUsers[typing.conversationId]!.add(typing.userId);
    } else {
      _typingUsers[typing.conversationId]!.remove(typing.userId);
    }

    notifyListeners();
  }

  void _handleUserStatusEvent(UserStatusNotification status) {
    _userStatuses[status.userId] = status.status;
    if (status.lastSeenAt != null) {
      _userLastSeen[status.userId] = status.lastSeenAt!;
    }
    notifyListeners();
  }

  /// Mark outgoing messages as DELIVERED when the recipient's device has
  /// confirmed receipt (double grey tick on the sender's UI).
  void _handleMessageDelivered(MessageDeliveredNotification event) {
    final list = _messages[event.conversationId];
    if (list == null || list.isEmpty || event.messageIds.isEmpty) return;
    final idSet = event.messageIds.toSet();
    var changed = false;
    final updated = List<ChatMessage>.from(list);
    for (var i = 0; i < updated.length; i++) {
      final m = updated[i];
      if (idSet.contains(m.id) &&
          m.senderId == _currentUserId &&
          m.status.toUpperCase() == 'SENT') {
        updated[i] = m.copyWith(status: 'DELIVERED');
        changed = true;
      }
    }
    if (changed) {
      _messages[event.conversationId] = updated;
      notifyListeners();
    }
  }

  /// Merge an emoji add/remove event into the local reaction list for the
  /// target message.
  void _handleMessageReaction(MessageReactionNotification event) {
    final list = _messages[event.conversationId];
    if (list == null || list.isEmpty) return;
    final idx = list.indexWhere((m) => m.id == event.messageId);
    if (idx == -1) return;
    final target = list[idx];
    final nextReactions = List<ChatReaction>.from(target.reactions);
    if (event.action == 'removed') {
      nextReactions.removeWhere(
        (r) => r.userId == event.userId && r.emoji == event.emoji,
      );
    } else {
      final already = nextReactions.any(
        (r) => r.userId == event.userId && r.emoji == event.emoji,
      );
      if (!already) {
        nextReactions.add(
          ChatReaction(
            id: 'local-${event.messageId}-${event.userId}-${event.emoji}',
            messageId: event.messageId,
            userId: event.userId,
            emoji: event.emoji,
            user: ChatUser(id: event.userId),
            createdAt: DateTime.now(),
          ),
        );
      }
    }
    final updated = List<ChatMessage>.from(list);
    updated[idx] = target.copyWith(reactions: nextReactions);
    _messages[event.conversationId] = updated;
    notifyListeners();
  }

  void _rejoinActiveConversations() {
    for (final conversation in _conversations) {
      _webSocketService.joinConversation(conversation.id);
    }
  }

  // Load conversations from API
  Future<void> loadConversations({
    bool refresh = false,
    String? module, // Optional module filter
  }) async {
    try {
      final conversations = await _httpService.getConversations(
        module: module,
        viewerUserId: _currentUserId,
      );
      log('DEBUG: Loaded ${conversations.length} conversations from API');
      for (var i = 0; i < conversations.length; i++) {
        final conv = conversations[i];
        log('DEBUG: Conversation $i: id=${conv.id}, contextId=${conv.contextId}, contextTitle=${conv.contextTitle}, otherUserId=${conv.otherUserId}');
      }
      _conversations = conversations;

      // Join all conversations in WebSocket (non-blocking — don't delay list return).
      if (_webSocketService.isConnected) {
        for (final conversation in conversations) {
          unawaited(_webSocketService.joinConversation(conversation.id));
        }
      }

      notifyListeners();
      log('Loaded ${conversations.length} conversations');
    } catch (e) {
      log('Failed to load conversations: $e');
      throw e;
    }
  }

  Future<ChatConversation> getConversation(
    String conversationId, {
    String? viewerUserId,
  }) async {
    return _httpService.getConversation(
      conversationId,
      viewerUserId: viewerUserId,
    );
  }

  // Load messages for a conversation
  Future<void> loadMessages(
    String conversationId, {
    bool refresh = false,
  }) async {
    try {
      if (refresh || _messages[conversationId] == null) {
        _messagePages[conversationId] = 1;
        _messageCursors[conversationId] = null;
        final messages = await _httpService.getMessages(
          conversationId,
          page: 1,
        );
        _messages[conversationId] = _dedupeServiceMessages(messages);
      }

      // Join conversation if connected
      if (_webSocketService.isConnected) {
        await _webSocketService.joinConversation(conversationId);
      }

      notifyListeners();
      log(
        'Loaded ${_messages[conversationId]?.length ?? 0} messages for conversation $conversationId',
      );
    } catch (e) {
      log('Failed to load messages for conversation $conversationId: $e');
      throw e;
    }
  }

  // Load earlier messages page and prepend
  Future<int> loadEarlier(String conversationId, {int limit = 50}) async {
    // Prefer cursor-based pagination when available; fall back to page-based
    final currentCursor = _messageCursors[conversationId];
    try {
      if (currentCursor != null) {
        final res = await _httpService.getMessagesCursor(
          conversationId,
          cursor: currentCursor,
          limit: limit,
        );
        final older = (res['messages'] as List<ChatMessage>);
        _messageCursors[conversationId] = res['nextCursor'] as String?;
        if (older.isNotEmpty) {
          final list = _messages[conversationId] ?? [];
          _messages[conversationId] =
              _dedupeServiceMessages([...older, ...list]);
          notifyListeners();
        }
        return older.length;
      } else {
        final nextPage = (_messagePages[conversationId] ?? 1) + 1;
        final older = await _httpService.getMessages(
          conversationId,
          page: nextPage,
          limit: limit,
        );
        _messagePages[conversationId] = nextPage;
        if (older.isNotEmpty) {
          final list = _messages[conversationId] ?? [];
          _messages[conversationId] =
              _dedupeServiceMessages([...older, ...list]);
          notifyListeners();
        }
        return older.length;
      }
    } catch (e) {
      log('Failed to load earlier for $conversationId: $e');
      return 0;
    }
  }

  // Send a message
  Future<void> sendMessage({
    required String conversationId,
    required String content,
    String? type,
    String? replyToId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Join room in background — never block the send path on join ack.
      if (_webSocketService.isConnected) {
        unawaited(ensureJoinedConversation(conversationId));
      }

      ChatMessage? sent;
      Object? wsError;

      if (_webSocketService.isConnected) {
        try {
          final result = await _webSocketService.sendMessage(
            conversationId: conversationId,
            content: content,
            type: type,
            replyToId: replyToId,
            metadata: metadata,
          );
          if (result == null) {
            throw Exception('No acknowledgement from chat server');
          }
          if (result['error'] != null) {
            throw Exception(result['error'].toString());
          }
          final success = result['success'];
          if (success == false) {
            throw Exception(
              result['message']?.toString() ?? 'Send rejected by server',
            );
          }
          final messageId = result['messageId']?.toString();
          if (messageId == null || messageId.isEmpty) {
            throw Exception('Server did not return a message id');
          }
          sent = ChatMessage(
            id: messageId,
            conversationId: conversationId,
            senderId: _currentUserId ?? '',
            content: content,
            type: type ?? 'TEXT',
            status: 'SENT',
            sender: ChatUser(
              id: _currentUserId ?? '',
              displayName: 'You',
            ),
            metadata: metadata,
            createdAt: DateTime.now(),
          );
        } catch (e) {
          wsError = e;
          log('WebSocket send failed, falling back to HTTP: $e');
        }
      }

      if (sent == null) {
        sent = await _httpService.sendMessage(
          conversationId: conversationId,
          content: content,
          type: type,
          replyToId: replyToId,
          metadata: metadata,
        );
        // HTTP create returns a bare row — fill sender for UI conversion.
        if (sent.sender.id.isEmpty && (_currentUserId?.isNotEmpty ?? false)) {
          sent = sent.copyWith(
            sender: ChatUser(
              id: _currentUserId!,
              displayName: 'You',
            ),
            senderId: sent.senderId.isNotEmpty
                ? sent.senderId
                : _currentUserId!,
          );
        }
        if (wsError != null) {
          log('HTTP fallback succeeded after WS error: $wsError');
        }
      }

      // Update service store + provider stream so sender UI always paints.
      _handleNewMessage(sent);
      _webSocketService.injectLocalMessage(sent);
    } catch (e) {
      log('Failed to send message: $e');
      rethrow;
    }
  }

  /// Join a conversation room for live receive (safe no-op when offline).
  Future<void> ensureJoinedConversation(String conversationId) async {
    if (!_webSocketService.isConnected) return;
    try {
      await _webSocketService.joinConversation(conversationId);
    } catch (e) {
      log('ensureJoinedConversation failed for $conversationId: $e');
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _httpService.deleteConversation(conversationId);
      _conversations.removeWhere((c) => c.id == conversationId);
      _messages.remove(conversationId);
      notifyListeners();
    } catch (e) {
      log('Failed to delete conversation: $e');
      throw e;
    }
  }

  // Start a direct message
  Future<ChatConversation> startDirectMessage({
    required String recipientId,
    String? initialMessage,
    String? type,
    String? contextId,
    String? contextTitle,
    String? viewerUserId,
  }) async {
    try {
      log(
        'Starting direct message to $recipientId with initialMessage: ${initialMessage != null && initialMessage.isNotEmpty}',
      );
      final conversation = await _httpService.startDirectMessage(
        recipientId: recipientId,
        initialMessage: initialMessage,
        type: type,
        contextId: contextId,
        contextTitle: contextTitle,
        viewerUserId: viewerUserId ?? _currentUserId,
      );

      // Add to conversations list
      _conversations.insert(0, conversation);

      // Join conversation
      if (_webSocketService.isConnected) {
        await _webSocketService.joinConversation(conversation.id);
      }

      notifyListeners();
      return conversation;
    } catch (e) {
      log('Failed to start direct message: $e');
      // Fallback path: attempt to explicitly create a DIRECT conversation
      try {
        if (_currentUserId == null) {
          throw Exception(
            'Cannot create conversation: missing current user id',
          );
        }

        log(
          'Attempting fallback: create conversation with participants [currentUser, recipient]',
        );
        
        // Determine sourceType from type parameter
        // For TRADE, DONATION, etc., use the type as sourceType
        // For DIRECT or null, default to GIFT for backward compatibility
        final conversationType = (type != null && type.isNotEmpty) ? type.toUpperCase() : 'DIRECT';
        final sourceType = (conversationType == 'TRADE' || 
                           conversationType == 'DONATION' || 
                           conversationType == 'SUPPORT')
            ? conversationType
            : 'GIFT'; // Default to GIFT for DIRECT conversations (backward compatibility)
        
        final created = await _httpService.createConversation(
          type: conversationType,
          title: contextTitle,
          metadata: contextId != null || contextTitle != null
              ? {
                  if (contextId != null) 'itemId': contextId,
                  if (contextTitle != null) 'itemTitle': contextTitle,
                  'sourceType': sourceType,
                }
              : null,
          participantIds: [_currentUserId!, recipientId],
        );
        
        // If we have context information, update the conversation with metadata
        if (contextId != null || contextTitle != null) {
          final metadata = <String, dynamic>{};
          if (contextId != null) {
            metadata['itemId'] = contextId;
          }
          if (contextTitle != null) {
            metadata['itemTitle'] = contextTitle;
          }
          // TODO: Add method to update conversation metadata if needed
        }

        // Optionally send the initial message after conversation creation
        if (initialMessage != null && initialMessage.trim().isNotEmpty) {
          await _httpService.sendMessage(
            conversationId: created.id,
            content: initialMessage.trim(),
            type: 'TEXT',
          );
        }

        // Insert and join
        _conversations.insert(0, created);
        if (_webSocketService.isConnected) {
          await _webSocketService.joinConversation(created.id);
        }
        notifyListeners();
        return created;
      } catch (fallbackError) {
        log('Fallback conversation creation also failed: $fallbackError');
        throw e; // surface original error upstream
      }
    }
  }

  // Mark entire conversation as read (clears unread badge)
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      await _httpService.markConversationAsRead(conversationId);
      final conversationIndex = _conversations.indexWhere((c) => c.id == conversationId);
      if (conversationIndex != -1 && _conversations[conversationIndex].unreadCount > 0) {
        _conversations[conversationIndex] = _conversations[conversationIndex].copyWith(unreadCount: 0);
        notifyListeners();
      }
    } catch (e) {
      log('Failed to mark conversation as read: $e');
      throw e;
    }
  }

  // Mark message as read
  Future<void> markMessageAsRead({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      // Use WebSocket if connected, otherwise HTTP
      if (_webSocketService.isConnected) {
        await _webSocketService.markMessageAsRead(
          conversationId: conversationId,
          messageId: messageId,
        );
      } else {
        await _httpService.markMessageAsRead(
          conversationId: conversationId,
          messageId: messageId,
        );
      }

      // Update local conversation unread count
      final conversationIndex = _conversations.indexWhere(
        (c) => c.id == conversationId,
      );
      if (conversationIndex != -1) {
        final conversation = _conversations[conversationIndex];
        if (conversation.unreadCount > 0) {
          _conversations[conversationIndex] = conversation.copyWith(
            unreadCount: 0,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      log('Failed to mark message as read: $e');
      throw e;
    }
  }

  // Typing indicators
  final TypingManager _typingManager = TypingManager();

  void startTyping(String conversationId) {
    _typingManager.startTyping(conversationId);
  }

  void stopTyping() {
    _typingManager.stopTyping();
  }

  // Search
  Future<List<ChatConversation>> searchConversations(String query) async {
    try {
      return await _httpService.searchConversations(query);
    } catch (e) {
      log('Failed to search conversations: $e');
      throw e;
    }
  }

  Future<List<ChatMessage>> searchMessages(
    String conversationId,
    String query,
  ) async {
    try {
      return await _httpService.searchMessages(conversationId, query);
    } catch (e) {
      log('Failed to search messages: $e');
      throw e;
    }
  }

  // Message reactions
  Future<void> addReaction(String messageId, String emoji) async {
    // Prefer WS path for instant rebroadcast; fall back to HTTP when offline.
    if (_webSocketService.isConnected) {
      final conversationId = _findConversationIdForMessage(messageId);
      if (conversationId != null) {
        _webSocketService.addReaction(
          conversationId: conversationId,
          messageId: messageId,
          emoji: emoji,
        );
        return;
      }
    }
    try {
      await _httpService.addReaction(messageId: messageId, emoji: emoji);
    } catch (e) {
      log('Failed to add reaction: $e');
      throw e;
    }
  }

  Future<void> removeReaction(String messageId, String emoji) async {
    if (_webSocketService.isConnected) {
      final conversationId = _findConversationIdForMessage(messageId);
      if (conversationId != null) {
        _webSocketService.removeReaction(
          conversationId: conversationId,
          messageId: messageId,
          emoji: emoji,
        );
        return;
      }
    }
    try {
      await _httpService.removeReaction(messageId: messageId, emoji: emoji);
    } catch (e) {
      log('Failed to remove reaction: $e');
      throw e;
    }
  }

  String? _findConversationIdForMessage(String messageId) {
    for (final entry in _messages.entries) {
      if (entry.value.any((m) => m.id == messageId)) return entry.key;
    }
    return null;
  }

  // Report message
  Future<void> reportMessage({
    required String messageId,
    required String reason,
    String? description,
  }) async {
    try {
      await _httpService.reportMessage(
        messageId: messageId,
        reason: reason,
        description: description,
      );
    } catch (e) {
      log('Failed to report message: $e');
      throw e;
    }
  }

  // Get total unread count
  int get totalUnreadCount {
    return _conversations.fold(
      0,
      (sum, conversation) => sum + conversation.unreadCount,
    );
  }

  // Reconnect WebSocket
  Future<void> reconnect() async {
    try {
      await _webSocketService.reconnect();
    } catch (e) {
      log('Failed to reconnect: $e');
      throw e;
    }
  }

  List<ChatMessage> _dedupeServiceMessages(List<ChatMessage> messages) {
    final byId = <String, ChatMessage>{};
    for (final m in messages) {
      if (m.id.isEmpty) continue;
      byId[m.id] = m;
    }
    final list = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  // Cleanup
  @override
  void dispose() {
    _cancelWebSocketListeners();
    _typingManager.dispose();
    _webSocketService.dispose();
    super.dispose();
  }
}

// Typing manager class stub
class TypingManager {
  void startTyping(String conversationId) {
    // TODO: Implement typing management
    print('Started typing in $conversationId');
  }

  void stopTyping() {
    // TODO: Implement typing management
    print('Stopped typing');
  }

  void dispose() {
    // TODO: Cleanup typing timers
  }
}
