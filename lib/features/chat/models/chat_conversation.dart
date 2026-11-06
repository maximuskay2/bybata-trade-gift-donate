import 'chat_message.dart';

class ChatConversation {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;
  final ChatType chatType;
  final String
  contextTitle; // Trade item, gift, donation campaign, community name
  final String contextId;
  final ChatMessage? lastMessage;
  final DateTime lastActivity;
  final int unreadCount;
  final bool isActive;

  ChatConversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
    required this.chatType,
    required this.contextTitle,
    required this.contextId,
    this.lastMessage,
    required this.lastActivity,
    this.unreadCount = 0,
    this.isActive = true,
  });

  factory ChatConversation.fromJson(
    Map<String, dynamic> json, {
    String? viewerUserId,
  }) {
    // Handle API response format — prefer otherParticipants; never pick self.
    final otherParticipantsRaw = json['otherParticipants'];
    final participantsRaw = json['participants'];
    dynamic otherParticipant;

    if (otherParticipantsRaw is List && otherParticipantsRaw.isNotEmpty) {
      otherParticipant = otherParticipantsRaw.first;
    } else if (participantsRaw is List && participantsRaw.isNotEmpty) {
      if (viewerUserId != null && viewerUserId.isNotEmpty) {
        for (final entry in participantsRaw) {
          if (entry is! Map) continue;
          final uid = entry['userId']?.toString() ??
              entry['user']?['id']?.toString();
          if (uid != null && uid != viewerUserId) {
            otherParticipant = entry;
            break;
          }
        }
      }
      otherParticipant ??= participantsRaw.first;
    }
    final metadata = json['metadata'] as Map<String, dynamic>?;
    final contextTitle = json['title'] ?? json['contextTitle'] ?? metadata?['itemTitle']?.toString() ?? '';
    final contextId = json['contextId'] ?? metadata?['itemId']?.toString() ?? '';
    // Use metadata.sourceType for gift chats (backend stores GIFT in metadata, type stays DIRECT)
    final sourceType = metadata?['sourceType']?.toString().toUpperCase();
    final typeRaw = json['type'] ?? json['chatType'];
    var chatType = sourceType == 'GIFT'
        ? ChatType.gifting
        : _mapApiTypeToLocalType(typeRaw?.toString());
    if ((chatType == ChatType.community || chatType == ChatType.direct) && contextTitle.toLowerCase().contains('gift')) {
      chatType = ChatType.gifting;
    }

    return ChatConversation(
      id: json['id'],
      otherUserId:
          otherParticipant?['user']?['id'] ?? json['otherUserId'] ?? '',
      otherUserName:
          otherParticipant?['user']?['profile']?['displayName'] ??
          json['otherUserName'] ??
          'Unknown',
      otherUserAvatar:
          otherParticipant?['user']?['profile']?['avatarKey'] ??
          json['otherUserAvatar'] ??
          '',
      chatType: chatType,
      contextTitle: contextTitle,
      contextId: contextId,
      lastMessage: json['lastMessage'] != null
          ? (json['lastMessage'] is String
                ? ChatMessage.fromText(
                    json['lastMessage'],
                    json['lastMessageBy'] ?? '',
                  )
                : ChatMessage.fromJson(json['lastMessage']))
          : null,
      lastActivity: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString()) ??
              DateTime.now()
          : DateTime.tryParse(json['lastActivity']?.toString() ?? '') ??
              DateTime.now(),
      unreadCount: json['unreadCount'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }

  static ChatType _mapApiTypeToLocalType(String? apiType) {
    final normalized = apiType
        ?.toUpperCase()
        .replaceAll('CHATTYPE.', '')
        .replaceAll(' ', '_');
    switch (normalized) {
      case 'TRADE':
        return ChatType.trade;
      case 'DIRECT':
        return ChatType.direct;
      case 'GIFT':
      case 'GIFTING':
        return ChatType.gifting;
      case 'GROUP':
      case 'COMMUNITY':
        return ChatType.community;
      case 'SUPPORT':
      case 'DONATION':
        return ChatType.donation;
      default:
        return ChatType.community;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      'otherUserAvatar': otherUserAvatar,
      'chatType': chatType.toString(),
      'contextTitle': contextTitle,
      'contextId': contextId,
      'lastMessage': lastMessage?.toJson(),
      'lastActivity': lastActivity.toIso8601String(),
      'unreadCount': unreadCount,
      'isActive': isActive,
    };
  }

  ChatConversation copyWith({
    String? id,
    String? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
    ChatType? chatType,
    String? contextTitle,
    String? contextId,
    ChatMessage? lastMessage,
    DateTime? lastActivity,
    int? unreadCount,
    bool? isActive,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      chatType: chatType ?? this.chatType,
      contextTitle: contextTitle ?? this.contextTitle,
      contextId: contextId ?? this.contextId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastActivity: lastActivity ?? this.lastActivity,
      unreadCount: unreadCount ?? this.unreadCount,
      isActive: isActive ?? this.isActive,
    );
  }
}

enum ChatType { trade, gifting, donation, community, direct }
