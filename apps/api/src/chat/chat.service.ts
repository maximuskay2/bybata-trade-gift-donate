import { Injectable, NotFoundException, ForbiddenException, Logger } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { Prisma, ChatMessageType, MessageStatus, ConversationType, ParticipantRole, NotificationType, NotificationPriority } from '@prisma/client';
import { NotificationsService } from '../notifications/notifications.service';

export interface CreateConversationDto {
  type: ConversationType;
  title?: string;
  description?: string;
  metadata?: Record<string, unknown>;
  participantIds: string[];
  createdBy: string;
}

export interface CreateMessageDto {
  conversationId: string;
  senderId: string;
  content: string;
  type?: ChatMessageType;
  replyToId?: string;
  metadata?: any;
}

@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);

  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  /** Shape a conversation for the mobile client: other party + unread count. */
  private async enrichConversationForUser<T extends { id: string; participants: Array<{ userId: string; lastReadAt?: Date | null }> }>(
    conversation: T,
    userId: string,
  ) {
    const participant = conversation.participants.find((p) => p.userId === userId);
    const unreadCount = await this.prisma.message.count({
      where: {
        conversationId: conversation.id,
        createdAt: {
          gt: participant?.lastReadAt || new Date(0),
        },
        senderId: {
          not: userId,
        },
      },
    });

    return {
      ...conversation,
      unreadCount,
      otherParticipants: conversation.participants.filter((p) => p.userId !== userId),
    };
  }

  // Conversation management
  async createConversation(data: CreateConversationDto) {
    const conversation = await this.prisma.$transaction(async (tx) => {
      // Create conversation
      const conversation = await tx.conversation.create({
        data: {
          type: data.type,
          title: data.title,
          description: data.description,
          metadata: JSON.parse(JSON.stringify(data.metadata ?? {})) as Prisma.InputJsonValue,
        },
      });

      // Add participants
      const participants = data.participantIds.map((userId, index) => ({
        conversationId: conversation.id,
        userId,
        role: userId === data.createdBy ? ParticipantRole.OWNER : ParticipantRole.MEMBER,
      }));

      await tx.conversationParticipant.createMany({
        data: participants,
      });

      return conversation;
    });
    // Chat notifications: use only push and in-app, no email
    return conversation;
  }

  async getUserConversations(
    userId: string,
    page: number = 1,
    limit: number = 50,
    module?: ConversationType
  ) {
    const skip = (page - 1) * limit;

    // Build where clause with optional module filtering
    const whereClause: Prisma.ConversationWhereInput = {
      participants: {
        some: {
          userId,
          leftAt: null,
        },
      },
      isActive: true,
    };

    // Filter by conversation type if module is specified
    if (module) {
      whereClause.type = module;
    }

    const [conversations, total] = await Promise.all([
      this.prisma.conversation.findMany({
        where: whereClause,
        include: {
          participants: {
            where: { leftAt: null },
            include: {
              user: {
                select: {
                  id: true,
                  profile: {
                    select: {
                      displayName: true,
                      avatarKey: true,
                    },
                  },
                },
              },
            },
          },
          _count: {
            select: {
              messages: true,
            },
          },
        },
        orderBy: {
          lastMessageAt: 'desc',
        },
        skip,
        take: limit,
      }),
      this.prisma.conversation.count({
        where: whereClause,
      }),
    ]);

    // Get unread counts for each conversation
    const conversationsWithUnread = await Promise.all(
      conversations.map((conversation) =>
        this.enrichConversationForUser(conversation, userId),
      ),
    );

    return {
      conversations: conversationsWithUnread,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getConversationById(conversationId: string, userId: string) {
    // Verify user is a participant
    const participant = await this.prisma.conversationParticipant.findFirst({
      where: {
        conversationId,
        userId,
        leftAt: null,
      },
    });

    if (!participant) {
      throw new ForbiddenException('Not authorized to view this conversation');
    }

    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: {
        participants: {
          where: { leftAt: null },
          include: {
            user: {
              select: {
                id: true,
                profile: {
                  select: {
                    displayName: true,
                    avatarKey: true,
                  },
                },
              },
            },
          },
        },
      },
    });

    if (!conversation) {
      throw new NotFoundException('Conversation not found');
    }

    return this.enrichConversationForUser(conversation, userId);
  }

  // Message management
  async createMessage(data: CreateMessageDto) {
    const message = await this.prisma.$transaction(async (tx) => {
      // Defensive logging to track bad payloads
      this.logger.log(`createMessage called`, {
        conversationId: data.conversationId,
        senderId: data.senderId,
        hasContent: !!data.content,
        type: data.type,
      } as any);

      if (!data.senderId) {
        // If we ever reach here, something upstream failed to attach the
        // authenticated user ID. Surface a clear error instead of letting
        // Prisma complain with a confusing validation error.
        this.logger.error(
          `createMessage invoked without senderId for conversation ${data.conversationId}`,
        );
        throw new ForbiddenException('Missing sender for chat message');
      }

      // Verify user is participant
      const participant = await tx.conversationParticipant.findFirst({
        where: {
          conversationId: data.conversationId,
          userId: data.senderId,
          leftAt: null,
        },
      });

      if (!participant) {
        throw new ForbiddenException('Not authorized to send message to this conversation');
      }

      // Create message
      const message = await tx.message.create({
        data: {
          conversationId: data.conversationId,
          senderId: data.senderId,
          content: data.content,
          type: data.type || ChatMessageType.TEXT,
          status: MessageStatus.SENT,
          replyToId: data.replyToId,
          metadata: data.metadata,
        },
      });

      // Update conversation last message info
      await tx.conversation.update({
        where: { id: data.conversationId },
        data: {
          lastMessageAt: message.createdAt,
          lastMessage: data.content.length > 100 ? data.content.substring(0, 100) + '...' : data.content,
          lastMessageBy: data.senderId,
        },
      });

      return message;
    });
    try {
      const conversation = await this.prisma.conversation.findUnique({
        where: { id: data.conversationId },
        include: {
          participants: {
            where: { leftAt: null, userId: { not: data.senderId } },
            include: { user: { select: { id: true, email: true, profile: { select: { displayName: true } } } } },
          },
        },
      });
      const sender = await this.prisma.user.findUnique({
        where: { id: data.senderId },
        select: { email: true, profile: { select: { displayName: true } } },
      });
      const actorName = sender?.profile?.displayName || sender?.email || 'Someone';
      const messageCount = await this.prisma.message.count({
        where: { conversationId: data.conversationId },
      });
      const isFirstMessage = messageCount === 1;
      if (conversation?.participants?.length) {
        await Promise.all(
          conversation.participants.map((p) =>
            this.notifications.createNotification({
              userId: p.user.id,
              type: NotificationType.SYSTEM_ANNOUNCEMENT,
              title: `Message from ${actorName}`,
              message: data.content.length > 100 ? `${data.content.substring(0, 100)}...` : data.content,
              actionUrl: `/chat/${data.conversationId}`,
              sourceId: message.id,
              sourceType: 'chat_message',
              priority: NotificationPriority.HIGH,
              data: { conversationId: data.conversationId, type: 'CHAT' },
            }),
          ),
        );
      }
      await this.notifyMentions(message, data.content);
    } catch {
      // Non-blocking
    }
    return message;
  }

  private async notifyMentions(message: any, content: string) {
    const usernames = new Set<string>();
    const regex = /@([a-zA-Z0-9_]{3,20})/g;
    let match: RegExpExecArray | null = null;
    while ((match = regex.exec(content)) !== null) {
      usernames.add(match[1].toLowerCase());
    }
    if (usernames.size === 0) return;

    const users = await this.prisma.user.findMany({
      where: { profile: { username: { in: Array.from(usernames), mode: 'insensitive' } } },
      select: { id: true, profile: { select: { displayName: true, username: true } } },
    });
    const sender = await this.prisma.user.findUnique({
      where: { id: message.senderId },
      select: { profile: { select: { displayName: true } } },
    });
    const actorName = sender?.profile?.displayName || 'Someone';
    const snippet = content.length > 100 ? `${content.slice(0, 100)}...` : content;
    await Promise.all(
      users
        .filter((u) => u.id !== message.senderId)
        .map((u) =>
          this.notifications.createNotification({
            userId: u.id,
            type: NotificationType.SYSTEM_ANNOUNCEMENT,
            title: `${actorName} mentioned you`,
            message: snippet,
            actionUrl: `/chat/${message.conversationId}`,
            sourceId: message.id,
            sourceType: 'chat_message',
            priority: NotificationPriority.HIGH,
            data: { conversationId: message.conversationId, type: 'CHAT' },
          }),
        ),
    );
  }

  async getConversationMessages(
    conversationId: string,
    userId: string,
    page: number = 1,
    limit: number = 50
  ) {
    // Verify user is participant
    const participant = await this.prisma.conversationParticipant.findFirst({
      where: {
        conversationId,
        userId,
        leftAt: null,
      },
    });

    if (!participant) {
      throw new ForbiddenException('Not authorized to view messages in this conversation');
    }

    const skip = (page - 1) * limit;

    const [messages, total] = await Promise.all([
      this.prisma.message.findMany({
        where: {
          conversationId,
          deletedAt: null,
        },
        include: {
          sender: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                },
              },
            },
          },
          replyTo: {
            select: {
              id: true,
              content: true,
              sender: {
                select: {
                  profile: {
                    select: {
                      displayName: true,
                    },
                  },
                },
              },
            },
          },
          reactions: {
            include: {
              user: {
                select: {
                  id: true,
                  profile: {
                    select: {
                      displayName: true,
                    },
                  },
                },
              },
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        skip,
        take: limit,
      }),
      this.prisma.message.count({
        where: {
          conversationId,
          deletedAt: null,
        },
      }),
    ]);

    return {
      messages: messages.reverse(), // Return in chronological order
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async markMessageAsRead(conversationId: string, userId: string, messageId: string) {
    // Update participant's last read message
    await this.prisma.conversationParticipant.updateMany({
      where: {
        conversationId,
        userId,
      },
      data: {
        lastReadAt: new Date(),
        lastReadMessageId: messageId,
      },
    });
  }

  async markConversationAsRead(conversationId: string, userId: string) {
    // Get latest message in conversation
    const latestMessage = await this.prisma.message.findFirst({
      where: {
        conversationId,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    if (latestMessage) {
      await this.markMessageAsRead(conversationId, userId, latestMessage.id);
    }
  }

  // Search functionality
  async searchConversations(userId: string, query: string) {
    const results = await this.prisma.conversation.findMany({
      where: {
        participants: {
          some: {
            userId,
            leftAt: null,
          },
        },
        isActive: true,
        OR: [
          {
            title: {
              contains: query,
              mode: 'insensitive',
            },
          },
          {
            participants: {
              some: {
                user: {
                  profile: {
                    displayName: {
                      contains: query,
                      mode: 'insensitive',
                    },
                  },
                },
              },
            },
          },
        ],
      },
      include: {
        participants: {
          where: { leftAt: null },
          include: {
            user: {
              select: {
                id: true,
                profile: {
                  select: {
                    displayName: true,
                    avatarKey: true,
                  },
                },
              },
            },
          },
        },
      },
      take: 10,
    });

    return Promise.all(
      results.map((conversation) =>
        this.enrichConversationForUser(conversation, userId),
      ),
    );
  }

  async searchMessages(conversationId: string, userId: string, query: string) {
    // Verify user is participant
    const participant = await this.prisma.conversationParticipant.findFirst({
      where: {
        conversationId,
        userId,
        leftAt: null,
      },
    });

    if (!participant) {
      throw new ForbiddenException('Not authorized to search messages in this conversation');
    }

    return this.prisma.message.findMany({
      where: {
        conversationId,
        content: {
          contains: query,
          mode: 'insensitive',
        },
        deletedAt: null,
      },
      include: {
        sender: {
          select: {
            id: true,
            profile: {
              select: {
                displayName: true,
                avatarKey: true,
              },
            },
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 20,
    });
  }

  // Direct message helper
  async createOrGetDirectConversation(
    userId1: string,
    userId2: string,
    type: ConversationType = ConversationType.DIRECT,
    metadata?: { contextTitle?: string; contextId?: string },
  ) {
    this.logger.log(
      `createOrGetDirectConversation called with userId1=${userId1}, userId2=${userId2}, type=${type}`,
    );
    try {
      // Check if direct conversation already exists between these two users
      const existingConversations = await this.prisma.conversation.findMany({
        where: {
          type,
          AND: [
            {
              participants: {
                some: {
                  userId: userId1,
                  leftAt: null,
                },
              },
            },
            {
              participants: {
                some: {
                  userId: userId2,
                  leftAt: null,
                },
              },
            },
          ],
        },
        include: {
          participants: {
            where: {
              leftAt: null,
            },
            include: {
              user: {
                select: {
                  id: true,
                  email: true,
                  profile: {
                    select: {
                      displayName: true,
                      avatarKey: true,
                    },
                  },
                },
              },
            },
          },
        },
      });

      this.logger.log(
        `Found ${existingConversations.length} existing conversations for users [${userId1}, ${userId2}] of type ${type}`,
      );

      // Find conversation with exactly these two participants
      const existingConversation = existingConversations.find(
        (conv) => conv.participants.length === 2,
      );

      if (existingConversation) {
        this.logger.log(
          `Reusing existing conversation id=${existingConversation.id} participants=${existingConversation.participants.map(p => p.userId).join(',')}`,
        );
        // Update with metadata if provided and existing has none (e.g. gift context)
        if (metadata?.contextId || metadata?.contextTitle) {
          const existingMeta = (existingConversation.metadata as Record<string, unknown>) ?? {};
          if (!existingMeta.itemId && !existingMeta.itemTitle) {
            await this.prisma.conversation.update({
              where: { id: existingConversation.id },
              data: {
                title: metadata.contextTitle ?? existingConversation.title,
                metadata: JSON.parse(
                  JSON.stringify({
                    ...existingMeta,
                    itemId: metadata.contextId,
                    itemTitle: metadata.contextTitle,
                    sourceType: metadata.contextTitle?.toLowerCase().includes('gift') ? 'GIFT' : existingMeta.sourceType,
                  }),
                ) as Prisma.InputJsonValue,
              },
            });
            existingConversation.title = metadata.contextTitle ?? existingConversation.title;
            existingConversation.metadata = {
              ...existingMeta,
              itemId: metadata.contextId,
              itemTitle: metadata.contextTitle,
              sourceType: metadata.contextTitle?.toLowerCase().includes('gift') ? 'GIFT' : existingMeta.sourceType,
            } as any;
          }
        }
        return this.enrichConversationForUser(existingConversation, userId1);
      }

      this.logger.log('No existing DM found, creating new conversation');
      // Create new conversation of specified type
      const created = await this.createConversation({
        type,
        title: metadata?.contextTitle,
        metadata:
          metadata?.contextId || metadata?.contextTitle
            ? {
                itemId: metadata?.contextId,
                itemTitle: metadata?.contextTitle,
                sourceType: metadata?.contextTitle?.toLowerCase().includes('gift')
                  ? 'GIFT'
                  : undefined,
              }
            : undefined,
        participantIds: [userId1, userId2],
        createdBy: userId1,
      });
      this.logger.log(`Created new conversation id=${created.id}`);
      const withParticipants = await this.prisma.conversation.findUnique({
        where: { id: created.id },
        include: {
          participants: {
            where: { leftAt: null },
            include: {
              user: {
                select: {
                  id: true,
                  profile: {
                    select: {
                      displayName: true,
                      avatarKey: true,
                    },
                  },
                },
              },
            },
          },
        },
      });
      if (!withParticipants) {
        throw new NotFoundException('Conversation not found after create');
      }
      return this.enrichConversationForUser(withParticipants, userId1);
    } catch (error) {
      this.logger.error(
        `Error in createOrGetDirectConversation for users [${userId1}, ${userId2}] of type ${type}: ${error?.message || error}`,
        error?.stack,
      );
      throw error;
    }
  }

  // Admin functions
  async getAllConversations(page: number = 1, limit: number = 50) {
    const skip = (page - 1) * limit;

    const [conversations, total] = await Promise.all([
      this.prisma.conversation.findMany({
        include: {
          participants: {
            include: {
              user: {
                select: {
                  id: true,
                  email: true,
                  profile: {
                    select: {
                      displayName: true,
                    },
                  },
                },
              },
            },
          },
          _count: {
            select: {
              messages: true,
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        skip,
        take: limit,
      }),
      this.prisma.conversation.count(),
    ]);

    return {
      conversations,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getReportedMessages(page: number = 1, limit: number = 50) {
    const skip = (page - 1) * limit;

    const [reports, total] = await Promise.all([
      this.prisma.messageReport.findMany({
        include: {
          message: {
            include: {
              sender: {
                select: {
                  id: true,
                  email: true,
                  profile: {
                    select: {
                      displayName: true,
                    },
                  },
                },
              },
              conversation: {
                select: {
                  id: true,
                  type: true,
                  title: true,
                },
              },
            },
          },
          reporter: {
            select: {
              id: true,
              email: true,
              profile: {
                select: {
                  displayName: true,
                },
              },
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        skip,
        take: limit,
      }),
      this.prisma.messageReport.count(),
    ]);

    return {
      reports,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }
}
