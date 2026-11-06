import 'dart:async';
import 'dart:developer';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/chat_models.dart';

class ChatWebSocketService {
  static final ChatWebSocketService _instance = ChatWebSocketService._internal();
  factory ChatWebSocketService() => _instance;
  ChatWebSocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;
  String? _authToken;
  String? _baseUrl;

  // Stream controllers for different events
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _messageReadController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeliveredController =
      StreamController<MessageDeliveredNotification>.broadcast();
  final _messageReactionController =
      StreamController<MessageReactionNotification>.broadcast();
  final _typingController = StreamController<UserTypingNotification>.broadcast();
  final _userStatusController = StreamController<UserStatusNotification>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _walletUpdateController = StreamController<Map<String, dynamic>>.broadcast();

  // Stream getters
  Stream<ChatMessage> get onNewMessage => _messageController.stream;

  /// Push a locally-created message into the same stream the UI listens to
  /// (used after send so the bubble appears even before / without a room echo).
  void injectLocalMessage(ChatMessage message) {
    if (!_messageController.isClosed) {
      _messageController.add(message);
    }
  }
  Stream<Map<String, dynamic>> get onMessageRead => _messageReadController.stream;
  Stream<MessageDeliveredNotification> get onMessageDelivered =>
      _messageDeliveredController.stream;
  Stream<MessageReactionNotification> get onMessageReaction =>
      _messageReactionController.stream;
  Stream<UserTypingNotification> get onUserTyping => _typingController.stream;
  Stream<UserStatusNotification> get onUserStatus => _userStatusController.stream;
  Stream<bool> get onConnectionChanged => _connectionController.stream;
  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;
  Stream<Map<String, dynamic>> get onWalletUpdate => _walletUpdateController.stream;

  bool get isConnected => _isConnected;
  String? get currentUserId => _currentUserId;

  Future<void> connect({
    required String baseUrl,
    required String authToken,
    required String userId,
  }) async {
    if (_isConnected && _socket != null) {
      log('WebSocket already connected');
      return;
    }

    _authToken = authToken;
    _currentUserId = userId;
    _baseUrl = baseUrl;

    try {
      // Configure socket options
      _socket = IO.io('$baseUrl/chat', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'extraHeaders': {
          'authorization': 'Bearer $authToken',
        },
        'query': {
          'token': authToken,
        },
      });

      // Set up event listeners
      _setupEventListeners();

      // Connect to server
      _socket!.connect();

      log('Attempting to connect to WebSocket: $baseUrl/chat');
    } catch (e) {
      log('Error connecting to WebSocket: $e');
      rethrow;
    }
  }

  void _setupEventListeners() {
    if (_socket == null) return;

    // Connection events
    _socket!.onConnect((_) {
      log('WebSocket connected successfully');
      _isConnected = true;
      _connectionController.add(true);
    });

    _socket!.onDisconnect((_) {
      log('WebSocket disconnected');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onConnectError((error) {
      log('WebSocket connection error: $error');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onError((error) {
      log('WebSocket error: $error');
    });

    // Chat events
    _socket!.on(ChatEvent.newMessage, (data) {
      try {
        final map = data is Map
            ? Map<String, dynamic>.from(data)
            : (data is List && data.isNotEmpty && data.first is Map)
                ? Map<String, dynamic>.from(data.first as Map)
                : null;
        if (map == null) {
          log('Received new_message with unexpected payload: $data');
          return;
        }
        final message = ChatMessage.fromJson(map);
        _messageController.add(message);
        log('Received new message: ${message.content}');

        // Emit to onNotification for in-app notification when message is from another user
        if (_currentUserId != null &&
            message.senderId != _currentUserId &&
            message.senderId.isNotEmpty) {
          final content = message.content.length > 100
              ? '${message.content.substring(0, 100)}...'
              : message.content;
          _notificationController.add({
            'id': message.id,
            'title': message.sender.displayName ?? 'Someone',
            'message': content,
            'type': 'SYSTEM_ANNOUNCEMENT',
            'sourceType': 'chat_message',
            'sourceId': message.id,
            'actionUrl': '/chat/${message.conversationId}',
            'conversationId': message.conversationId,
          });
        }
      } catch (e, st) {
        log('Error parsing new message: $e\n$st');
      }
    });

    _socket!.on(ChatEvent.messageRead, (data) {
      try {
        _messageReadController.add(data as Map<String, dynamic>);
        log('Message read event received');
      } catch (e) {
        log('Error parsing message read event: $e');
      }
    });

    _socket!.on(ChatEvent.messageDelivered, (data) {
      try {
        final delivered = MessageDeliveredNotification.fromJson(
          data as Map<String, dynamic>,
        );
        _messageDeliveredController.add(delivered);
        log('Message delivered event: ${delivered.messageIds}');
      } catch (e) {
        log('Error parsing message delivered event: $e');
      }
    });

    _socket!.on(ChatEvent.messageReaction, (data) {
      try {
        final reaction = MessageReactionNotification.fromJson(
          data as Map<String, dynamic>,
        );
        _messageReactionController.add(reaction);
        log(
          'Message reaction event: ${reaction.action} ${reaction.emoji} on ${reaction.messageId}',
        );
      } catch (e) {
        log('Error parsing message reaction event: $e');
      }
    });

    _socket!.on(ChatEvent.userTyping, (data) {
      try {
        final typing = UserTypingNotification.fromJson(data as Map<String, dynamic>);
        _typingController.add(typing);
        log('User typing event: ${typing.userId} - ${typing.isTyping}');
      } catch (e) {
        log('Error parsing typing event: $e');
      }
    });

    _socket!.on(ChatEvent.userStatus, (data) {
      try {
        final status = UserStatusNotification.fromJson(data as Map<String, dynamic>);
        _userStatusController.add(status);
        log('User status event: ${status.userId} - ${status.status}');
      } catch (e) {
        log('Error parsing user status event: $e');
      }
    });

    _socket!.on(ChatEvent.notification, (data) {
      try {
        _notificationController.add(data as Map<String, dynamic>);
        log('Notification received');
      } catch (e) {
        log('Error parsing notification: $e');
      }
    });

    _socket!.on(ChatEvent.walletUpdate, (data) {
      try {
        _walletUpdateController.add(data as Map<String, dynamic>);
        log('Wallet update received');
      } catch (e) {
        log('Error parsing wallet update: $e');
      }
    });
  }

  // Send message
  Future<Map<String, dynamic>?> sendMessage({
    required String conversationId,
    required String content,
    String? type,
    String? replyToId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isConnected || _socket == null) {
      throw Exception('WebSocket not connected');
    }

    final data = SendMessageData(
      conversationId: conversationId,
      content: content,
      type: type,
      replyToId: replyToId,
      metadata: metadata,
    );

    final completer = Completer<Map<String, dynamic>?>();

    _socket!.emitWithAck(SocketMessage.sendMessage, data.toJson(),
        ack: (response) {
      if (!completer.isCompleted) {
        completer.complete(_normalizeAck(response));
      }
    });

    final result = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        log('Send message ack timed out');
        throw TimeoutException('Chat send timed out');
      },
    );
    log('Send message result: $result');
    return result;
  }

  Map<String, dynamic>? _normalizeAck(dynamic response) {
    if (response == null) return null;
    if (response is List && response.isNotEmpty) {
      return _normalizeAck(response.first);
    }
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return {'raw': response};
  }

  // Mark message as read
  Future<Map<String, dynamic>?> markMessageAsRead({
    required String conversationId,
    required String messageId,
  }) async {
    if (!_isConnected || _socket == null) {
      throw Exception('WebSocket not connected');
    }

    final data = MarkReadData(
      conversationId: conversationId,
      messageId: messageId,
    );

    final completer = Completer<Map<String, dynamic>?>();
    
    _socket!.emitWithAck(SocketMessage.markRead, data.toJson(), ack: (response) {
      completer.complete(response as Map<String, dynamic>?);
    });

    final result = await completer.future;
    log('Mark read result: $result');
    return result;
  }

  /// Fire-and-forget ack that tells the server this message was delivered to
  /// this device (drives the double grey tick on the sender's UI).
  void ackMessageDelivered({
    required String conversationId,
    required String messageId,
  }) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit(SocketMessage.messageDeliveredAck, {
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  /// Add an emoji reaction to a message (optimistic — server rebroadcasts).
  void addReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit(SocketMessage.addReaction, {
      'conversationId': conversationId,
      'messageId': messageId,
      'emoji': emoji,
    });
  }

  /// Remove an emoji reaction from a message.
  void removeReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit(SocketMessage.removeReaction, {
      'conversationId': conversationId,
      'messageId': messageId,
      'emoji': emoji,
    });
  }

  // Start typing indicator
  void startTyping(String conversationId) {
    if (!_isConnected || _socket == null) return;

    final data = TypingData(conversationId: conversationId);
    _socket!.emit(SocketMessage.typingStart, data.toJson());
    log('Started typing in conversation: $conversationId');
  }

  // Stop typing indicator
  void stopTyping(String conversationId) {
    if (!_isConnected || _socket == null) return;

    final data = TypingData(conversationId: conversationId);
    _socket!.emit(SocketMessage.typingStop, data.toJson());
    log('Stopped typing in conversation: $conversationId');
  }

  // Join conversation room
  Future<Map<String, dynamic>?> joinConversation(String conversationId) async {
    if (!_isConnected || _socket == null) {
      throw Exception('WebSocket not connected');
    }

    final completer = Completer<Map<String, dynamic>?>();

    _socket!.emitWithAck(
      SocketMessage.joinConversation,
      {'conversationId': conversationId},
      ack: (response) {
        if (!completer.isCompleted) {
          completer.complete(_normalizeAck(response));
        }
      },
    );

    final result = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        log('Join conversation ack timed out for $conversationId');
        return null;
      },
    );
    log('Join conversation result: $result');
    return result;
  }

  // Reconnect with exponential backoff
  Future<void> reconnect() async {
    if (_isConnected) return;

    log('Attempting to reconnect...');
    disconnect();

    await Future.delayed(const Duration(seconds: 2));

    if (_authToken != null && _currentUserId != null && _baseUrl != null) {
      await connect(
        baseUrl: _baseUrl!,
        authToken: _authToken!,
        userId: _currentUserId!,
      );
    }
  }

  // Disconnect from WebSocket
  void disconnect() {
    log('Disconnecting WebSocket');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _currentUserId = null;
    _authToken = null;
    _connectionController.add(false);
  }

  // Clean up resources
  void dispose() {
    disconnect();
    _messageController.close();
    _messageReadController.close();
    _messageDeliveredController.close();
    _messageReactionController.close();
    _typingController.close();
    _userStatusController.close();
    _connectionController.close();
    _notificationController.close();
    _walletUpdateController.close();
  }
}

// Helper class for managing typing indicators with auto-stop
class TypingManager {
  Timer? _typingTimer;
  String? _currentConversationId;
  final ChatWebSocketService _webSocket = ChatWebSocketService();
  
  static const Duration _typingTimeout = Duration(seconds: 3);

  void startTyping(String conversationId) {
    // If we're already typing in a different conversation, stop that first
    if (_currentConversationId != null && _currentConversationId != conversationId) {
      stopTyping();
    }

    _currentConversationId = conversationId;
    _webSocket.startTyping(conversationId);

    // Reset the timer
    _typingTimer?.cancel();
    _typingTimer = Timer(_typingTimeout, () {
      stopTyping();
    });
  }

  void stopTyping() {
    if (_currentConversationId != null) {
      _webSocket.stopTyping(_currentConversationId!);
      _typingTimer?.cancel();
      _typingTimer = null;
      _currentConversationId = null;
    }
  }

  void dispose() {
    stopTyping();
  }
}