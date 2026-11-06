import '../models/chat_conversation.dart';
import '../providers/chat_provider.dart';

/// Shared helpers to open chat threads without redundant list refreshes.
abstract final class ChatThreadBootstrap {
  /// Scan in-memory conversations — no network I/O.
  static ChatConversation? findInCache(
    ChatProvider provider, {
    String? contextId,
    required String partnerId,
  }) {
    return provider.findConversationInCache(
      contextId: contextId,
      partnerId: partnerId,
    );
  }

  /// existing → cache → refresh list → [createIfMissing].
  static Future<ChatConversation?> resolveConversation({
    required ChatProvider chatProvider,
    required String partnerId,
    String? contextId,
    ChatConversation? existingConversation,
    required Future<ChatConversation?> Function() createIfMissing,
  }) async {
    if (existingConversation != null) return existingConversation;

    var found = chatProvider.findConversationInCache(
      contextId: contextId,
      partnerId: partnerId,
    );
    if (found != null) return found;

    await chatProvider.refreshConversations();
    found = chatProvider.findConversationInCache(
      contextId: contextId,
      partnerId: partnerId,
    );
    if (found != null) return found;

    return createIfMissing();
  }

  /// Load messages once from the API (WS previews do not count as history).
  static Future<void> loadThreadMessages({
    required ChatProvider chatProvider,
    required String conversationId,
    ChatConversation? conversation,
  }) async {
    if (conversation != null) {
      chatProvider.upsertConversation(conversation);
    }
    await chatProvider.loadMessages(conversationId);
  }
}
