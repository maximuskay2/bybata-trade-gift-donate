import '../models/chat_conversation.dart';

/// Collapse inbox rows the WhatsApp way: one contact appears once.
///
/// Keeps the conversation with the latest [ChatConversation.lastActivity],
/// sums unread counts across duplicates, and sorts newest-first.
///
/// Rows with an empty [ChatConversation.otherUserId] are kept individually
/// (keyed by conversation id) so we never merge unrelated unknowns.
List<ChatConversation> dedupeConversationsByContact(
  Iterable<ChatConversation> source, {
  /// When set, only collapse within the same [ChatType] (module tabs).
  /// When null, collapse purely by contact (All tab / WhatsApp style).
  ChatType? withinType,
}) {
  final Map<String, ChatConversation> best = {};
  final Map<String, int> unread = {};

  for (final conv in source) {
    if (!conv.isActive) continue;
    if (withinType != null && conv.chatType != withinType) continue;

    final contactId = conv.otherUserId.trim();
    final key = contactId.isEmpty
        ? 'id:${conv.id}'
        : (withinType != null
            ? '${withinType.name}:$contactId'
            : contactId);

    unread[key] = (unread[key] ?? 0) + conv.unreadCount;

    final existing = best[key];
    if (existing == null ||
        conv.lastActivity.isAfter(existing.lastActivity)) {
      best[key] = conv;
    } else if (existing.otherUserName == 'Unknown' &&
        conv.otherUserName != 'Unknown') {
      // Prefer a named profile even if slightly older activity.
      best[key] = existing.copyWith(
        otherUserName: conv.otherUserName,
        otherUserAvatar: conv.otherUserAvatar.isNotEmpty
            ? conv.otherUserAvatar
            : existing.otherUserAvatar,
      );
    } else if (existing.otherUserAvatar.isEmpty &&
        conv.otherUserAvatar.isNotEmpty) {
      best[key] = existing.copyWith(otherUserAvatar: conv.otherUserAvatar);
    }
  }

  final result = best.entries.map((e) {
    final summed = unread[e.key] ?? e.value.unreadCount;
    if (summed == e.value.unreadCount) return e.value;
    return e.value.copyWith(unreadCount: summed);
  }).toList();

  result.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
  return result;
}

/// Same-contact sibling threads (excluding [primaryId]) for message merging.
List<ChatConversation> siblingConversationsForContact(
  Iterable<ChatConversation> source, {
  required String otherUserId,
  required ChatType chatType,
  required String primaryId,
}) {
  final uid = otherUserId.trim();
  if (uid.isEmpty) return const [];
  return source
      .where(
        (c) =>
            c.isActive &&
            c.id != primaryId &&
            c.otherUserId.trim() == uid &&
            c.chatType == chatType,
      )
      .toList();
}
