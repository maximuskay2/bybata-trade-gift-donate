enum MessageType {
  text,
  image,
  file,
  location,
  system,
  tradeOffer,
  payment,
}

class ChatParticipant {
  final String id;
  final String conversationId;
  final String userId;
  final String role; // 'OWNER', 'ADMIN', 'MEMBER'
  final ChatUser user;
  final DateTime? lastReadAt;
  final String? lastReadMessageId;
  final DateTime joinedAt;
  final DateTime? leftAt;

  ChatParticipant({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.role,
    required this.user,
    this.lastReadAt,
    this.lastReadMessageId,
    required this.joinedAt,
    this.leftAt,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      userId: json['userId'] as String,
      role: json['role'] as String,
      user: ChatUser.fromJson(json['user'] as Map<String, dynamic>),
      lastReadAt: json['lastReadAt'] != null
          ? DateTime.parse(json['lastReadAt'] as String)
          : null,
      lastReadMessageId: json['lastReadMessageId'] as String?,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      leftAt: json['leftAt'] != null
          ? DateTime.parse(json['leftAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'userId': userId,
      'role': role,
      'user': user.toJson(),
      'lastReadAt': lastReadAt?.toIso8601String(),
      'lastReadMessageId': lastReadMessageId,
      'joinedAt': joinedAt.toIso8601String(),
      'leftAt': leftAt?.toIso8601String(),
    };
  }
}

class ChatUser {
  final String id;
  final String? displayName;
  final String? avatarKey;

  ChatUser({
    required this.id,
    this.displayName,
    this.avatarKey,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] is Map
        ? Map<String, dynamic>.from(json['profile'] as Map)
        : null;
    return ChatUser(
      id: json['id']?.toString() ?? '',
      // HTTP nests under profile; WebSocket often sends flat fields.
      displayName: profile?['displayName'] as String? ??
          json['displayName'] as String?,
      avatarKey: profile?['avatarKey'] as String? ??
          json['avatarKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile': {
        'displayName': displayName,
        'avatarKey': avatarKey,
      },
    };
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String type; // 'TEXT', 'IMAGE', 'FILE', etc.
  final String status; // 'SENT', 'DELIVERED', 'READ', 'FAILED'
  final ChatUser sender;
  final ChatMessage? replyTo;
  final List<ChatReaction> reactions;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.status,
    required this.sender,
    this.replyTo,
    this.reactions = const [],
    this.metadata,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final senderId =
        json['senderId']?.toString() ??
        (json['sender'] is Map ? json['sender']['id']?.toString() : null) ??
        '';
    final sender = json['sender'] is Map
        ? ChatUser.fromJson(Map<String, dynamic>.from(json['sender'] as Map))
        : ChatUser(id: senderId);

    final conversationId = json['conversationId']?.toString() ?? '';
    final id = json['id']?.toString() ?? '';

    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: json['content']?.toString() ?? '',
      type: json['type']?.toString() ?? 'TEXT',
      status: json['status']?.toString() ?? 'SENT',
      sender: sender,
      replyTo: _parseReplyTo(json['replyTo'], conversationId),
      reactions: _parseReactions(json['reactions'], id),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt']),
      deletedAt: _parseDate(json['deletedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  /// WS reply payloads are slim (`id/content/type/senderId/senderName`),
  /// while HTTP may return a nested message. Tolerate both.
  static ChatMessage? _parseReplyTo(dynamic raw, String conversationId) {
    if (raw == null) return null;
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    try {
      if (map['sender'] is Map || map['conversationId'] != null) {
        return ChatMessage.fromJson({
          ...map,
          'conversationId': map['conversationId'] ?? conversationId,
          'senderId': map['senderId'] ??
              (map['sender'] is Map ? map['sender']['id'] : null) ??
              '',
          'status': map['status'] ?? 'SENT',
          'createdAt': map['createdAt'] ?? DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {
      // Fall through to slim constructor.
    }
    final senderId = map['senderId']?.toString() ?? '';
    return ChatMessage(
      id: map['id']?.toString() ?? '',
      conversationId: conversationId,
      senderId: senderId,
      content: map['content']?.toString() ?? '',
      type: map['type']?.toString() ?? 'TEXT',
      status: 'SENT',
      sender: ChatUser(
        id: senderId,
        displayName: map['senderName']?.toString(),
      ),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  static List<ChatReaction> _parseReactions(dynamic raw, String messageId) {
    if (raw is! List) return const [];
    final out = <ChatReaction>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      try {
        if (map['user'] is Map && map['id'] != null) {
          out.add(ChatReaction.fromJson(map));
          continue;
        }
      } catch (_) {}
      final userId = map['userId']?.toString() ?? '';
      final emoji = map['emoji']?.toString() ?? '';
      if (userId.isEmpty || emoji.isEmpty) continue;
      out.add(
        ChatReaction(
          id: map['id']?.toString() ?? '${userId}_$emoji',
          messageId: map['messageId']?.toString() ?? messageId,
          userId: userId,
          emoji: emoji,
          user: map['user'] is Map
              ? ChatUser.fromJson(Map<String, dynamic>.from(map['user'] as Map))
              : ChatUser(id: userId),
          createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
        ),
      );
    }
    return out;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'content': content,
      'type': type,
      'status': status,
      'sender': sender.toJson(),
      'replyTo': replyTo?.toJson(),
      'reactions': reactions.map((r) => r.toJson()).toList(),
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    String? type,
    String? status,
    ChatUser? sender,
    ChatMessage? replyTo,
    List<ChatReaction>? reactions,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      sender: sender ?? this.sender,
      replyTo: replyTo ?? this.replyTo,
      reactions: reactions ?? this.reactions,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  bool get isDeleted => deletedAt != null;

  bool isFromUser(String userId) =>
      userId.isNotEmpty && senderId == userId;
}

class ChatReaction {
  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final ChatUser user;
  final DateTime createdAt;

  ChatReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.user,
    required this.createdAt,
  });

  factory ChatReaction.fromJson(Map<String, dynamic> json) {
    return ChatReaction(
      id: json['id'] as String,
      messageId: json['messageId'] as String,
      userId: json['userId'] as String,
      emoji: json['emoji'] as String,
      user: ChatUser.fromJson(json['user'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messageId': messageId,
      'userId': userId,
      'emoji': emoji,
      'user': user.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// Events for WebSocket communication (server -> client)
class ChatEvent {
  static const String newMessage = 'new_message';
  static const String messageRead = 'message_read';
  static const String messageDelivered = 'message_delivered';
  static const String messageReaction = 'message_reaction';
  static const String userTyping = 'user_typing';
  static const String userStatus = 'user_status';
  static const String notification = 'notification';
  static const String walletUpdate = 'wallet_update';
}

// WebSocket message types (client -> server)
class SocketMessage {
  static const String sendMessage = 'send_message';
  static const String markRead = 'mark_read';
  static const String messageDeliveredAck = 'message_delivered_ack';
  static const String typingStart = 'typing_start';
  static const String typingStop = 'typing_stop';
  static const String joinConversation = 'join_conversation';
  static const String addReaction = 'add_reaction';
  static const String removeReaction = 'remove_reaction';
}

class SendMessageData {
  final String conversationId;
  final String content;
  final String? type;
  final String? replyToId;
  final Map<String, dynamic>? metadata;

  SendMessageData({
    required this.conversationId,
    required this.content,
    this.type,
    this.replyToId,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'content': content,
      'type': type,
      'replyToId': replyToId,
      'metadata': metadata,
    };
  }
}

class MarkReadData {
  final String conversationId;
  final String messageId;

  MarkReadData({
    required this.conversationId,
    required this.messageId,
  });

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'messageId': messageId,
    };
  }
}

class TypingData {
  final String conversationId;

  TypingData({
    required this.conversationId,
  });

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
    };
  }
}

class UserTypingNotification {
  final String conversationId;
  final String userId;
  final String? displayName;
  final bool isTyping;

  UserTypingNotification({
    required this.conversationId,
    required this.userId,
    this.displayName,
    required this.isTyping,
  });

  factory UserTypingNotification.fromJson(Map<String, dynamic> json) {
    return UserTypingNotification(
      conversationId: json['conversationId'] as String,
      userId: json['userId'] as String,
      displayName: json['displayName'] as String?,
      isTyping: json['isTyping'] as bool,
    );
  }
}

class UserStatusNotification {
  final String userId;
  final String status; // 'online' or 'offline'
  final DateTime timestamp;
  final DateTime? lastSeenAt;

  UserStatusNotification({
    required this.userId,
    required this.status,
    required this.timestamp,
    this.lastSeenAt,
  });

  factory UserStatusNotification.fromJson(Map<String, dynamic> json) {
    return UserStatusNotification(
      userId: json['userId'] as String,
      status: json['status'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.tryParse(json['lastSeenAt'].toString())
          : null,
    );
  }
}

/// Server -> client notification that one or more messages reached the
/// recipient's device (double grey tick).
class MessageDeliveredNotification {
  final String conversationId;
  final List<String> messageIds;
  final String deliveredTo;
  final DateTime deliveredAt;

  MessageDeliveredNotification({
    required this.conversationId,
    required this.messageIds,
    required this.deliveredTo,
    required this.deliveredAt,
  });

  factory MessageDeliveredNotification.fromJson(Map<String, dynamic> json) {
    final rawIds = json['messageIds'] ?? json['messageId'];
    final ids = <String>[];
    if (rawIds is List) {
      ids.addAll(rawIds.map((e) => e.toString()));
    } else if (rawIds is String) {
      ids.add(rawIds);
    }
    return MessageDeliveredNotification(
      conversationId: (json['conversationId'] ?? '').toString(),
      messageIds: ids,
      deliveredTo: (json['deliveredTo'] ?? json['userId'] ?? '').toString(),
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'].toString())
          : DateTime.now(),
    );
  }
}

/// Server -> client notification that a reaction was added or removed on a
/// message within a conversation.
class MessageReactionNotification {
  final String conversationId;
  final String messageId;
  final String userId;
  final String emoji;
  final String action; // 'added' | 'removed'

  MessageReactionNotification({
    required this.conversationId,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.action,
  });

  factory MessageReactionNotification.fromJson(Map<String, dynamic> json) {
    return MessageReactionNotification(
      conversationId: (json['conversationId'] ?? '').toString(),
      messageId: (json['messageId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      emoji: (json['emoji'] ?? '').toString(),
      action: (json['action'] ?? 'added').toString(),
    );
  }
}