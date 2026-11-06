import { Injectable } from '@nestjs/common';
import { PrismaService } from './prisma.service';

/**
 * Batch-enriches browse/search listing rows with `hasUnreadMessages`
 * when the viewer has unread chat messages on a conversation tied via
 * `conversation.metadata.itemId`.
 */
@Injectable()
export class ListingUnreadService {
  constructor(private readonly prisma: PrismaService) {}

  async getUnreadListingIds(
    userId: string,
    listingIds: string[],
  ): Promise<Set<string>> {
    const unique = [
      ...new Set(
        listingIds.filter((id) => typeof id === 'string' && id.length > 0),
      ),
    ];
    if (!unique.length) return new Set();

    // Prefer a single containment filter over N JSON-path OR clauses —
    // large OR trees on metadata have caused 500s on browse endpoints.
    const conversations = await this.prisma.conversation.findMany({
      where: {
        isActive: true,
        participants: {
          some: { userId, leftAt: null },
        },
        OR: unique.map((id) => ({
          metadata: {
            path: ['itemId'],
            equals: id,
          },
        })),
      },
      select: {
        id: true,
        metadata: true,
        participants: {
          where: { userId },
          select: { lastReadAt: true },
        },
      },
      take: Math.min(unique.length * 3, 200),
    });

    if (!conversations.length) return new Set();

    const unreadIds = new Set<string>();
    const conversationIds = conversations.map((c) => c.id);
    const lastReadByConversation = new Map<string, Date>();
    for (const conversation of conversations) {
      const participant = conversation.participants[0];
      lastReadByConversation.set(
        conversation.id,
        participant?.lastReadAt ?? new Date(0),
      );
    }

    // Batch unread counts instead of one query per conversation.
    const unreadMessages = await this.prisma.message.findMany({
      where: {
        conversationId: { in: conversationIds },
        senderId: { not: userId },
      },
      select: {
        conversationId: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 500,
    });

    const hasUnreadByConversation = new Set<string>();
    for (const message of unreadMessages) {
      if (hasUnreadByConversation.has(message.conversationId)) continue;
      const lastReadAt =
        lastReadByConversation.get(message.conversationId) ?? new Date(0);
      if (message.createdAt > lastReadAt) {
        hasUnreadByConversation.add(message.conversationId);
      }
    }

    for (const conversation of conversations) {
      if (!hasUnreadByConversation.has(conversation.id)) continue;
      const meta = conversation.metadata as Record<string, unknown> | null;
      const itemId = meta?.itemId?.toString();
      if (itemId) unreadIds.add(itemId);
    }

    return unreadIds;
  }

  async enrichPayload<T extends { items: Array<{ id?: string }> }>(
    userId: string | undefined,
    payload: T,
  ): Promise<T> {
    if (!userId || !payload?.items?.length) return payload;

    try {
      const listingIds = payload.items
        .map((item) => item?.id)
        .filter((id): id is string => typeof id === 'string' && id.length > 0);

      const unreadIds = await this.getUnreadListingIds(userId, listingIds);

      return {
        ...payload,
        items: payload.items.map((item) => ({
          ...item,
          hasUnreadMessages: item.id ? unreadIds.has(item.id) : false,
        })),
      } as T;
    } catch (error) {
      // Never fail browse/list feeds because unread enrichment broke
      // (e.g. JSON-path query issues on conversation.metadata).
      console.error('[ListingUnreadService] enrichPayload failed:', error);
      return payload;
    }
  }
}
