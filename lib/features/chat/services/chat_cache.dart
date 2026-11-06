import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/chat_conversation.dart';
import '../models/chat_message.dart';

/// Offline chat history — mirrors [ProfileCache] (Hive + JSON).
///
/// WhatsApp/Messenger style: hydrate UI from disk on launch, sync when online.
abstract final class ChatCache {
  static const String boxName = 'chat_cache';
  static const int maxMessagesPerThread = 200;

  static Future<Box<String>> _openBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<String>(boxName);
    }
    return Hive.openBox<String>(boxName);
  }

  static String _conversationsKey(String userId) => 'u:$userId:conversations';
  static String _messagesKey(String userId, String conversationId) =>
      'u:$userId:messages:$conversationId';

  static Future<List<ChatConversation>> loadConversations(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final box = await _openBox();
      final raw = box.get(_conversationsKey(userId));
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => ChatConversation.fromJson(
                Map<String, dynamic>.from(e),
                viewerUserId: userId,
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveConversations(
    String userId,
    List<ChatConversation> conversations,
  ) async {
    if (userId.isEmpty) return;
    try {
      final box = await _openBox();
      final payload = conversations.map(_conversationToCacheJson).toList();
      await box.put(_conversationsKey(userId), jsonEncode(payload));
    } catch (_) {}
  }

  static Future<List<ChatMessage>> loadMessages(
    String userId,
    String conversationId,
  ) async {
    if (userId.isEmpty || conversationId.isEmpty) return const [];
    try {
      final box = await _openBox();
      final raw = box.get(_messagesKey(userId, conversationId));
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => ChatMessage.fromJson(
                Map<String, dynamic>.from(e),
                currentUserId: userId,
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Persist thread history (keeps the newest [maxMessagesPerThread]).
  static Future<void> saveMessages(
    String userId,
    String conversationId,
    List<ChatMessage> messages,
  ) async {
    if (userId.isEmpty || conversationId.isEmpty) return;
    try {
      final box = await _openBox();
      final sorted = List<ChatMessage>.from(messages)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final clipped = sorted.length > maxMessagesPerThread
          ? sorted.sublist(sorted.length - maxMessagesPerThread)
          : sorted;
      final payload = clipped.map(_messageToCacheJson).toList();
      await box.put(
        _messagesKey(userId, conversationId),
        jsonEncode(payload),
      );
    } catch (_) {}
  }

  /// Load every cached thread for [userId] into a map.
  static Future<Map<String, List<ChatMessage>>> loadAllMessages(
    String userId,
  ) async {
    if (userId.isEmpty) return {};
    try {
      final box = await _openBox();
      final prefix = 'u:$userId:messages:';
      final out = <String, List<ChatMessage>>{};
      for (final key in box.keys) {
        final k = key.toString();
        if (!k.startsWith(prefix)) continue;
        final conversationId = k.substring(prefix.length);
        if (conversationId.isEmpty) continue;
        final msgs = await loadMessages(userId, conversationId);
        if (msgs.isNotEmpty) out[conversationId] = msgs;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> clearUser(String userId) async {
    if (userId.isEmpty) return;
    try {
      final box = await _openBox();
      final prefix = 'u:$userId:';
      final toDelete = box.keys
          .map((k) => k.toString())
          .where((k) => k.startsWith(prefix))
          .toList();
      for (final k in toDelete) {
        await box.delete(k);
      }
    } catch (_) {}
  }

  static Map<String, dynamic> _conversationToCacheJson(ChatConversation c) {
    return {
      'id': c.id,
      'otherUserId': c.otherUserId,
      'otherUserName': c.otherUserName,
      'otherUserAvatar': c.otherUserAvatar,
      // Enum name so fromJson can round-trip offline.
      'type': c.chatType.name.toUpperCase(),
      'chatType': c.chatType.name,
      'contextTitle': c.contextTitle,
      'contextId': c.contextId,
      'lastMessage':
          c.lastMessage == null ? null : _messageToCacheJson(c.lastMessage!),
      'lastActivity': c.lastActivity.toIso8601String(),
      'lastMessageAt': c.lastActivity.toIso8601String(),
      'unreadCount': c.unreadCount,
      'isActive': c.isActive,
    };
  }

  static Map<String, dynamic> _messageToCacheJson(ChatMessage m) {
    return {
      'id': m.id,
      'senderId': m.senderId,
      'senderName': m.senderName,
      'message': m.message,
      'content': m.message,
      'timestamp': m.timestamp.toIso8601String(),
      'createdAt': m.timestamp.toIso8601String(),
      'isFromCurrentUser': m.isFromCurrentUser,
      'messageType': m.messageType.name.toUpperCase(),
      'type': m.messageType.name.toUpperCase(),
      'status': m.deliveryStatus,
      'deliveryStatus': m.deliveryStatus,
      'imageUrl': m.imageUrl,
      'audioKey': m.audioKey,
      'replyTo': m.replyTo?.toJson(),
      'reactions': m.reactions.map((r) => r.toJson()).toList(),
      'metadata': m.metadata,
    };
  }
}
