import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';

import '../../chat/providers/chat_provider.dart';
import 'conversational_ranker.dart';

/// Client-side unread badges from [ChatProvider] (until API batch field ships).
class ConversationalUnreadEnricher {
  ConversationalUnreadEnricher._();

  static List<RankedFeedItem> enrich(
    BuildContext context,
    List<RankedFeedItem> items,
  ) {
    ChatProvider? chat;
    try {
      chat = context.read<ChatProvider>();
    } catch (_) {
      return items;
    }

    final unreadByContext = <String, int>{};
    for (final c in chat.conversations) {
      if (c.contextId.isEmpty || c.unreadCount <= 0) continue;
      unreadByContext[c.contextId] =
          (unreadByContext[c.contextId] ?? 0) + c.unreadCount;
    }

    if (unreadByContext.isEmpty) return items;

    return items
        .map(
          (ranked) {
            final apiUnread = ranked.data.hasUnreadMessages;
            final clientUnread =
                (unreadByContext[ranked.data.id] ?? 0) > 0;
            if (!apiUnread && !clientUnread) return ranked;
            return ranked.copyWith(
              data: ranked.data.copyWith(
                hasUnreadMessages: apiUnread || clientUnread,
              ),
            );
          },
        )
        .toList();
  }
}
