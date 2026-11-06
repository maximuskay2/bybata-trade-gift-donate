import '../models/chat_message.dart';

/// Collapse duplicate rows (same message id) and keep chronological order.
List<ChatMessage> dedupeChatMessagesById(List<ChatMessage> messages) {
  final byId = <String, ChatMessage>{};
  for (final m in messages) {
    if (m.id.isEmpty) continue;
    byId[m.id] = m;
  }
  final list = byId.values.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return list;
}

/// Whether [message] was sent by the signed-in user (WhatsApp "me" side).
bool isMessageFromMe(ChatMessage message, String? currentUserId) {
  final uid = currentUserId?.trim() ?? '';
  if (uid.isNotEmpty && message.senderId.trim() == uid) return true;
  return message.isFromCurrentUser;
}

/// Same check using raw ids (e.g. when mapping API payloads in [ChatProvider]).
bool isSenderCurrentUser(String senderId, String? currentUserId) {
  final uid = currentUserId?.trim() ?? '';
  if (uid.isEmpty) return false;
  return senderId.trim() == uid;
}
