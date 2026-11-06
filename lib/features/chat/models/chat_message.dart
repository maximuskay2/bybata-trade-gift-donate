import 'message_reaction.dart';
import 'reply_preview.dart';
import 'tick_status.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isFromCurrentUser;
  final MessageType messageType;

  /// API [MessageStatus]: SENT, DELIVERED, READ, etc. Used for outgoing read ticks.
  final String deliveryStatus;
  final String? imageUrl;
  final String? audioKey;

  /// Quoted reply preview (set when this message replies to another).
  final ReplyPreview? replyTo;

  /// Emoji reactions attached to this message.
  final List<MessageReaction> reactions;

  final Map<String, dynamic>? metadata;

  /// True when the other party has read this message (double tick).
  bool get isReadByRecipient => deliveryStatus.toUpperCase() == 'READ';

  TickStatus get tickStatus => tickStatusFromString(deliveryStatus);

  /// Filename for document messages (stored in metadata.documentName).
  String? get documentName =>
      (metadata?['documentName'] ?? metadata?['fileName'])?.toString();

  /// Size in bytes for document messages (metadata.documentSize).
  int? get documentSizeBytes {
    final v = metadata?['documentSize'] ?? metadata?['fileSize'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Storage key for a non-audio file (for signed-URL fetch).
  String? get documentKey {
    final direct = metadata?['documentKey'] ?? metadata?['fileKey'];
    if (direct != null && direct.toString().isNotEmpty) {
      return direct.toString();
    }
    final mediaKeys = metadata?['mediaKeys'];
    if (mediaKeys is List && mediaKeys.isNotEmpty) {
      return mediaKeys.first.toString();
    }
    return null;
  }

  /// True when this FILE message is a video attachment.
  bool get isVideoAttachment => isVideoMetadata(metadata);

  /// Storage key for image/video media (mediaKeys[0] or imageUrl).
  String? get mediaStorageKey {
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl;
    final mediaKeys = metadata?['mediaKeys'];
    if (mediaKeys is List && mediaKeys.isNotEmpty) {
      return mediaKeys.first.toString();
    }
    return documentKey;
  }

  static bool isVideoMetadata(Map<String, dynamic>? meta) {
    if (meta == null) return false;
    final kind = meta['mediaKind']?.toString().toLowerCase();
    if (kind == 'video') return true;
    final mime = meta['mimeType']?.toString().toLowerCase() ?? '';
    if (mime.startsWith('video/')) return true;
    final name =
        (meta['fileName'] ?? meta['documentName'] ?? '').toString().toLowerCase();
    return name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.m4v') ||
        name.endsWith('.webm');
  }

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    required this.isFromCurrentUser,
    required this.messageType,
    this.deliveryStatus = 'SENT',
    this.imageUrl,
    this.audioKey,
    this.replyTo,
    this.reactions = const [],
    this.metadata,
  });

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final replyJson = json['replyTo'];
    final reactionsJson = json['reactions'];
    final senderId =
        (json['senderId'] ?? json['sender']?['id'] ?? '').toString();
    final fromApi = json['isFromCurrentUser'] as bool?;
    final isMe = currentUserId != null &&
            currentUserId.isNotEmpty &&
            senderId == currentUserId
        ? true
        : (fromApi ?? false);
    return ChatMessage(
      id: json['id'],
      senderId: senderId,
      senderName: json['senderName'] ?? json['sender']?['profile']?['displayName'] ?? 'Unknown',
      message: json['message'] ?? json['content'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
      isFromCurrentUser: isMe,
      messageType: _mapApiTypeToLocalType(json),
      deliveryStatus: (json['status'] ?? json['deliveryStatus'] ?? 'SENT').toString(),
      imageUrl: json['imageUrl'],
      audioKey: json['audioKey'] ?? (json['metadata'] as Map?)?['audioKey'] as String?,
      replyTo: replyJson is Map<String, dynamic> ? ReplyPreview.fromJson(replyJson) : null,
      reactions: reactionsJson is List
          ? reactionsJson
              .whereType<Map<String, dynamic>>()
              .map(MessageReaction.fromJson)
              .toList()
          : const [],
      metadata: json['metadata'],
    );
  }

  factory ChatMessage.fromText(String content, String senderId) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: senderId,
      senderName: 'Unknown',
      message: content,
      timestamp: DateTime.now(),
      isFromCurrentUser: false,
      messageType: MessageType.text,
    );
  }

  static MessageType _mapApiTypeToLocalType(dynamic json) {
    final apiType = (json is Map ? json['messageType'] ?? json['type'] : json)
        ?.toString()
        .toUpperCase()
        .replaceAll('MESSAGETYPE.', '');
    switch (apiType) {
      case 'TEXT':
        return MessageType.text;
      case 'IMAGE':
        return MessageType.image;
      case 'VIDEO':
        return MessageType.video;
      case 'VOICE':
        return MessageType.voice;
      case 'FILE':
        final meta = json is Map ? json['metadata'] : null;
        final metaMap = meta is Map
            ? Map<String, dynamic>.from(meta)
            : null;
        if (metaMap != null && metaMap['audioKey'] != null) {
          return MessageType.voice;
        }
        if (isVideoMetadata(metaMap)) return MessageType.video;
        return MessageType.file;
      case 'SYSTEM':
        return MessageType.system;
      case 'TRADE':
      case 'TRADE_OFFER':
        return MessageType.trade;
      case 'GIFT':
      case 'PAYMENT':
        return MessageType.gift;
      case 'DONATION':
        return MessageType.donation;
      default:
        return MessageType.text;
    }
  }

  int get durationSeconds {
    if (metadata == null) return 0;
    final d = metadata!['durationSeconds'];
    if (d is int) return d;
    if (d is num) return d.toInt();
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isFromCurrentUser': isFromCurrentUser,
      'messageType': messageType.toString(),
      'deliveryStatus': deliveryStatus,
      'imageUrl': imageUrl,
      'audioKey': audioKey,
      'replyTo': replyTo?.toJson(),
      'reactions': reactions.map((r) => r.toJson()).toList(),
      'metadata': metadata,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? message,
    DateTime? timestamp,
    bool? isFromCurrentUser,
    MessageType? messageType,
    String? deliveryStatus,
    String? imageUrl,
    String? audioKey,
    ReplyPreview? replyTo,
    List<MessageReaction>? reactions,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isFromCurrentUser: isFromCurrentUser ?? this.isFromCurrentUser,
      messageType: messageType ?? this.messageType,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      imageUrl: imageUrl ?? this.imageUrl,
      audioKey: audioKey ?? this.audioKey,
      replyTo: replyTo ?? this.replyTo,
      reactions: reactions ?? this.reactions,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum MessageType {
  text,
  image,
  video,
  file,
  voice,
  system,
  trade,
  gift,
  donation,
}
