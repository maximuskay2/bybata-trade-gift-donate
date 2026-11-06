import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
} from '@nestjs/websockets';
import { Logger, UseGuards } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../common/prisma.service';
import { ChatService } from './chat.service';
import { PushNotificationService, ChatNotificationData } from '../notifications/push-notification.service';

interface AuthenticatedSocket extends Socket {
  userId?: string;
  user?: any;
}

@WebSocketGateway({
  cors: {
    origin: ['http://localhost:3001', 'http://localhost:3000'],
    credentials: true,
  },
  namespace: '/chat',
  transports: ['websocket', 'polling'],
  // Add connection pooling and keep-alive configuration
  pingInterval: 25000,
  pingTimeout: 20000,
  maxHttpBufferSize: 1e6, // 1MB
})
export class ChatGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(ChatGateway.name);
  private readonly connectedUsers = new Map<string, AuthenticatedSocket>();

  constructor(
    private jwtService: JwtService,
    private prisma: PrismaService,
    private chatService: ChatService,
    private pushNotificationService: PushNotificationService,
  ) {}

  afterInit(_server: Server) {
    this.logger.debug('Chat WebSocket Gateway initialized');
  }

  async handleConnection(client: AuthenticatedSocket) {
    try {
      // Extract token from auth header or handshake
      const token = this.extractTokenFromClient(client);
      
      if (!token) {
        this.logger.debug(`Client ${client.id} connection rejected: No token`);
        client.disconnect();
        return;
      }

      // Verify JWT token
      let payload: any;
      try {
        payload = await this.jwtService.verifyAsync(token);
      } catch (error: any) {
        // Handle token expiration specifically
        if (error.name === 'TokenExpiredError' || error.name === 'JsonWebTokenError') {
          const errorType = error.name === 'TokenExpiredError' ? 'expired' : 'invalid';
          const expiredAt = error.expiredAt ? ` (expired at: ${error.expiredAt})` : '';
          this.logger.debug(
            `Client ${client.id} connection rejected: Token ${errorType}${expiredAt}`,
          );
          client.disconnect();
          return;
        }
        // Re-throw other errors to be caught by outer catch block
        throw error;
      }

      const userId = payload.sub;

      if (!userId) {
        this.logger.debug(`Client ${client.id} connection rejected: Invalid token payload`);
        client.disconnect();
        return;
      }

      // Get user details
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        include: {
          profile: {
            select: {
              displayName: true,
              avatarKey: true,
            }
          }
        }
      });

      if (!user || user.banned || user.isChatBanned) {
        this.logger.debug(`Client ${client.id} connection rejected: User not found, banned, or chat banned`);
        client.disconnect();
        return;
      }

      // Check if chat ban is temporary and still active
      if (user.isChatBanned && user.chatBanUntil && user.chatBanUntil > new Date()) {
        this.logger.debug(
          `Client ${client.id} connection rejected: User temporarily banned from chat until ${user.chatBanUntil}`,
        );
        client.disconnect();
        return;
      }

      // Remove expired temporary chat ban
      if (user.isChatBanned && user.chatBanUntil && user.chatBanUntil <= new Date()) {
        await this.prisma.user.update({
          where: { id: userId },
          data: {
            isChatBanned: false,
            chatBanReason: null,
            chatBanUntil: null,
            chatBannedBy: null,
            chatBannedAt: null,
          },
        });
        user.isChatBanned = false;
      }

      // Store authenticated client
      client.userId = userId;
      client.user = user;
      this.connectedUsers.set(userId, client);

      // Join per-user room so the gateway can target this user directly (e.g. for delivered receipts)
      client.join(`user:${userId}`);

      // Join user to their conversation rooms
      await this.joinUserConversationRooms(client);

      // Set user online status (persists lastSeenAt)
      await this.updateUserOnlineStatus(userId, true);

      // Back-fill DELIVERED status for any messages that arrived while offline
      await this.emitPendingDeliveredReceipts(userId);

      this.logger.debug(`User ${user.profile?.displayName ?? userId} (${userId}) connected`);

      // Notify other users about online status
      this.broadcastUserStatus(userId, 'online');

    } catch (error: any) {
      // Log unexpected errors (not token-related, as those are handled above)
      if (error.name !== 'TokenExpiredError' && error.name !== 'JsonWebTokenError') {
        this.logger.error(`Connection error for client ${client.id}:`, error);
      }
      // Ensure client is disconnected on any error
      if (client.connected) {
        client.disconnect();
      }
    }
  }

  async handleDisconnect(client: AuthenticatedSocket) {
    try {
      if (client.userId) {
        this.connectedUsers.delete(client.userId);

        // Persist lastSeenAt immediately on disconnect
        await this.updateUserOnlineStatus(client.userId, false);

        // Set user offline status (with a delay to handle quick reconnects)
        const userId = client.userId;
        setTimeout(async () => {
          try {
            const stillConnected = this.connectedUsers.has(userId);
            if (!stillConnected) {
              await this.broadcastUserStatus(userId, 'offline');
            }
          } catch (error) {
            this.logger.error(`Error updating offline status for user ${userId}:`, error);
          }
        }, 5000);

        this.logger.debug(`User ${client.userId} disconnected`);
      }
    } catch (error) {
      this.logger.error(`Error during disconnect for client ${client.id}:`, error);
    }
  }

  @SubscribeMessage('send_message')
  async handleSendMessage(
    @MessageBody() data: {
      conversationId: string;
      content: string;
      type?: string;
      replyToId?: string;
      metadata?: any;
    },
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    try {
      if (!client.userId) {
        return { error: 'Not authenticated' };
      }

      // Check if user is chat banned
      const user = await this.prisma.user.findUnique({
        where: { id: client.userId },
        select: { isChatBanned: true, chatBanUntil: true },
      });

      if (user?.isChatBanned) {
        // Check if temporary ban is still active
        if (!user.chatBanUntil || user.chatBanUntil > new Date()) {
          return { error: 'You are banned from chat' };
        } else {
          // Remove expired temporary ban
          await this.prisma.user.update({
            where: { id: client.userId },
            data: {
              isChatBanned: false,
              chatBanReason: null,
              chatBanUntil: null,
              chatBannedBy: null,
              chatBannedAt: null,
            },
          });
        }
      }

      // Verify user is participant of the conversation
      const participant = await this.prisma.conversationParticipant.findFirst({
        where: {
          conversationId: data.conversationId,
          userId: client.userId,
          leftAt: null,
        },
        include: {
          conversation: {
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
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      });

      if (!participant) {
        return { error: 'Not authorized to send message to this conversation' };
      }

      // Create the message
      const message = await this.chatService.createMessage({
        conversationId: data.conversationId,
        senderId: client.userId,
        content: data.content,
        type: data.type as any || 'TEXT',
        replyToId: data.replyToId,
        metadata: data.metadata,
      });

      // Get full message with relations
      const fullMessage = await this.prisma.message.findUnique({
        where: { id: message.id },
        include: {
          sender: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                }
              }
            }
          },
          replyTo: {
            select: {
              id: true,
              content: true,
              type: true,
              sender: {
                select: {
                  id: true,
                  profile: {
                    select: {
                      displayName: true,
                    }
                  }
                }
              }
            }
          },
          reactions: {
            select: {
              userId: true,
              emoji: true,
              createdAt: true,
            }
          }
        }
      });

      // Broadcast message to all conversation participants
      if (fullMessage && client.connected) {
        const roomName = `conversation:${data.conversationId}`;
        this.server.to(roomName).emit('new_message', {
          id: fullMessage.id,
          conversationId: fullMessage.conversationId,
          content: fullMessage.content,
          type: fullMessage.type,
          status: fullMessage.status,
          senderId: fullMessage.senderId,
          sender: {
            id: fullMessage.sender.id,
            displayName: fullMessage.sender.profile?.displayName,
            avatarKey: fullMessage.sender.profile?.avatarKey,
          },
          replyTo: fullMessage.replyTo ? {
            id: fullMessage.replyTo.id,
            content: fullMessage.replyTo.content,
            type: fullMessage.replyTo.type,
            senderId: fullMessage.replyTo.sender.id,
            senderName: fullMessage.replyTo.sender.profile?.displayName,
          } : null,
          reactions: fullMessage.reactions || [],
          metadata: fullMessage.metadata,
          createdAt: fullMessage.createdAt,
        });

        // Detect which participants are currently online and mark message DELIVERED to them
        const onlineRecipients = (participant.conversation.participants || [])
          .map((p: any) => p.userId)
          .filter((uid: string) => uid !== client.userId && this.connectedUsers.has(uid));

        if (onlineRecipients.length > 0) {
          try {
            await this.prisma.message.update({
              where: { id: fullMessage.id },
              data: { status: 'DELIVERED' as any },
            });
            this.server.to(`user:${client.userId}`).emit('message_delivered', {
              conversationId: fullMessage.conversationId,
              messageId: fullMessage.id,
              deliveredTo: onlineRecipients,
              deliveredAt: new Date(),
            });
          } catch (err) {
            this.logger.warn(`Failed to mark message ${fullMessage.id} delivered: ${err}`);
          }
        }
      }

      // Send push notifications to offline users
      if (fullMessage && participant.conversation.participants) {
        await this.sendPushNotificationsToOfflineUsers(
          participant.conversation.participants,
          client.userId,
          fullMessage
        );
      }

      return { success: true, messageId: message.id };

    } catch (error) {
      this.logger.error('Error sending message:', error);
      return { error: 'Failed to send message' };
    }
  }

  @SubscribeMessage('mark_read')
  async handleMarkRead(
    @MessageBody() data: { conversationId: string; messageId: string },
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    try {
      if (!client.userId) {
        return { error: 'Not authenticated' };
      }

      await this.chatService.markMessageAsRead(
        data.conversationId,
        client.userId,
        data.messageId
      );

      // Broadcast read receipt to other participants (only if client still connected)
      if (client.connected) {
        const roomName = `conversation:${data.conversationId}`;
        client.to(roomName).emit('message_read', {
          conversationId: data.conversationId,
          messageId: data.messageId,
          readBy: client.userId,
          readAt: new Date(),
        });
      }

      return { success: true };

    } catch (error) {
      this.logger.error('Error marking message as read:', error);
      return { error: 'Failed to mark message as read' };
    }
  }

  @SubscribeMessage('typing_start')
  async handleTypingStart(
    @MessageBody() data: { conversationId: string },
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    try {
      if (!client.userId) return;

      if (client.connected) {
        const roomName = `conversation:${data.conversationId}`;
        client.to(roomName).emit('user_typing', {
          conversationId: data.conversationId,
          userId: client.userId,
          displayName: client.user?.profile?.displayName,
          isTyping: true,
        });
      }
    } catch (error) {
      this.logger.error('Error handling typing start:', error);
    }
  }

  @SubscribeMessage('typing_stop')
  async handleTypingStop(
    @MessageBody() data: { conversationId: string },
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    try {
      if (!client.userId) return;

      if (client.connected) {
        const roomName = `conversation:${data.conversationId}`;
        client.to(roomName).emit('user_typing', {
          conversationId: data.conversationId,
          userId: client.userId,
          isTyping: false,
        });
      }
    } catch (error) {
      this.logger.error('Error handling typing stop:', error);
    }
  }

  @SubscribeMessage('message_delivered_ack')
  async handleMessageDeliveredAck(
    @MessageBody() data: { conversationId: string; messageIds: string[] },
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    try {
      if (!client.userId || !Array.isArray(data?.messageIds) || data.messageIds.length === 0) return;

      // Only mark SENT messages as DELIVERED (and only messages from other senders)
      await this.prisma.message.updateMany({
        where: {
          id: { in: data.messageIds },
          conversationId: data.conversationId,
          senderId: { not: client.userId },
          status: 'SENT' as any,
        },
        data: { status: 'DELIVERED' as any },
      });

      // Tell the senders (target per-user rooms)
      const rows = await this.prisma.message.findMany({
        where: { id: { in: data.messageIds } },
        select: { id: true, senderId: true, conversationId: true },
      });
      const bySender = new Map<string, string[]>();
      for (const m of rows) {
        if (!bySender.has(m.senderId)) bySender.set(m.senderId, []);
        bySender.get(m.senderId)!.push(m.id);
      }
      for (const [senderId, ids] of bySender) {
        this.server.to(`user:${senderId}`).emit('message_delivered', {
          conversationId: data.conversationId,
          messageIds: ids,
          deliveredTo: [client.userId],
          deliveredAt: new Date(),
        });
      }
    } catch (error) {
      this.logger.error('Error handling message delivered ack:', error);
    }
  }

  @SubscribeMessage('add_reaction')
  async handleAddReaction(
    @MessageBody() data: { conversationId: string; messageId: string; emoji: string },
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    try {
      if (!client.userId) return { error: 'Not authenticated' };
      if (!data?.emoji || !data?.messageId) return { error: 'Invalid payload' };

      // Verify participant
      const participant = await this.prisma.conversationParticipant.findFirst({
        where: { conversationId: data.conversationId, userId: client.userId, leftAt: null },
      });
      if (!participant) return { error: 'Not authorized' };

      const reaction = await this.prisma.messageReaction.upsert({
        where: {
          messageId_userId_emoji: {
            messageId: data.messageId,
            userId: client.userId,
            emoji: data.emoji,
          },
        },
        update: { createdAt: new Date() },
        create: {
          messageId: data.messageId,
          userId: client.userId,
          emoji: data.emoji,
        },
      });

      this.server.to(`conversation:${data.conversationId}`).emit('message_reaction', {
        action: 'add',
        conversationId: data.conversationId,
        messageId: data.messageId,
        userId: client.userId,
        emoji: data.emoji,
        createdAt: reaction.createdAt,
      });

      return { success: true };
    } catch (error) {
      this.logger.error('Error adding reaction:', error);
      return { error: 'Failed to add reaction' };
    }
  }

  @SubscribeMessage('remove_reaction')
  async handleRemoveReaction(
    @MessageBody() data: { conversationId: string; messageId: string; emoji: string },
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    try {
      if (!client.userId) return { error: 'Not authenticated' };
      if (!data?.emoji || !data?.messageId) return { error: 'Invalid payload' };

      await this.prisma.messageReaction.deleteMany({
        where: {
          messageId: data.messageId,
          userId: client.userId,
          emoji: data.emoji,
        },
      });

      this.server.to(`conversation:${data.conversationId}`).emit('message_reaction', {
        action: 'remove',
        conversationId: data.conversationId,
        messageId: data.messageId,
        userId: client.userId,
        emoji: data.emoji,
      });

      return { success: true };
    } catch (error) {
      this.logger.error('Error removing reaction:', error);
      return { error: 'Failed to remove reaction' };
    }
  }

  @SubscribeMessage('join_conversation')
  async handleJoinConversation(
    @MessageBody() data: { conversationId: string },
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    if (!client.userId) return { error: 'Not authenticated' };

    // Verify user is participant
    const participant = await this.prisma.conversationParticipant.findFirst({
      where: {
        conversationId: data.conversationId,
        userId: client.userId,
        leftAt: null,
      },
    });

    if (!participant) {
      return { error: 'Not authorized to join this conversation' };
    }

    const roomName = `conversation:${data.conversationId}`;
    client.join(roomName);

    return { success: true };
  }

  // Utility methods
  private extractTokenFromClient(client: AuthenticatedSocket): string | null {
    // Try to extract from authorization header
    const authHeader = client.handshake.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }

    // Try to extract from query params
    const token = client.handshake.query.token as string;
    if (token) {
      return token;
    }

    return null;
  }

  private async joinUserConversationRooms(client: AuthenticatedSocket) {
    const participants = await this.prisma.conversationParticipant.findMany({
      where: {
        userId: client.userId,
        leftAt: null,
      },
      select: {
        conversationId: true,
      }
    });

    for (const participant of participants) {
      const roomName = `conversation:${participant.conversationId}`;
      client.join(roomName);
    }
  }

  private async updateUserOnlineStatus(userId: string, isOnline: boolean) {
    try {
      await this.prisma.user.update({
        where: { id: userId },
        data: { lastSeenAt: new Date() } as any,
      });
    } catch (err) {
      this.logger.warn(`Failed to update lastSeenAt for ${userId}: ${err}`);
    }
  }

  private async broadcastUserStatus(userId: string, status: 'online' | 'offline') {
    let lastSeenAt: Date | null = null;
    try {
      const u = (await this.prisma.user.findUnique({
        where: { id: userId },
        select: { lastSeenAt: true } as any,
      })) as any;
      lastSeenAt = u?.lastSeenAt ?? null;
    } catch {
      // ignore
    }
    this.server.emit('user_status', {
      userId,
      status,
      lastSeenAt,
      timestamp: new Date(),
    });
  }

  /**
   * When a user comes online, back-fill DELIVERED status for SENT messages in
   * their active conversations that were sent by others while they were offline.
   * Also notifies the original senders via `message_delivered`.
   */
  private async emitPendingDeliveredReceipts(userId: string) {
    try {
      const participants = await this.prisma.conversationParticipant.findMany({
        where: { userId, leftAt: null },
        select: { conversationId: true },
      });
      if (participants.length === 0) return;
      const conversationIds = participants.map(p => p.conversationId);

      // Grab up to 200 undelivered messages from others
      const pending = await this.prisma.message.findMany({
        where: {
          conversationId: { in: conversationIds },
          senderId: { not: userId },
          status: 'SENT' as any,
          deletedAt: null,
        },
        select: { id: true, senderId: true, conversationId: true },
        take: 200,
        orderBy: { createdAt: 'desc' },
      });
      if (pending.length === 0) return;

      await this.prisma.message.updateMany({
        where: { id: { in: pending.map(m => m.id) } },
        data: { status: 'DELIVERED' as any },
      });

      // Group by sender and emit
      const grouped = new Map<string, { conversationId: string; ids: string[] }>();
      for (const m of pending) {
        const key = `${m.senderId}:${m.conversationId}`;
        if (!grouped.has(key)) grouped.set(key, { conversationId: m.conversationId, ids: [] });
        grouped.get(key)!.ids.push(m.id);
      }
      for (const [key, val] of grouped) {
        const senderId = key.split(':')[0];
        this.server.to(`user:${senderId}`).emit('message_delivered', {
          conversationId: val.conversationId,
          messageIds: val.ids,
          deliveredTo: [userId],
          deliveredAt: new Date(),
        });
      }
    } catch (err) {
      this.logger.warn(`emitPendingDeliveredReceipts failed for ${userId}: ${err}`);
    }
  }

  private async sendPushNotificationsToOfflineUsers(
    participants: any[],
    senderId: string,
    message: any
  ) {
    // Send push notifications to offline users
    for (const participant of participants) {
      if (participant.userId !== senderId) {
        const isOnline = this.connectedUsers.has(participant.userId);
        if (!isOnline) {
          const chatNotificationData: ChatNotificationData = {
            type: 'new_message',
            conversationId: message.conversationId,
            messageId: message.id,
            senderId: message.senderId,
            senderName: message.sender?.profile?.displayName || 'Someone',
            messageContent: message.content,
          };
          
          await this.pushNotificationService.sendChatNotification(
            participant.userId,
            chatNotificationData
          );
        }
      }
    }
  }

  // Public method to send notifications to connected users
  async sendNotificationToUser(userId: string, notification: any) {
    const client = this.connectedUsers.get(userId);
    if (client) {
      client.emit('notification', notification);
    }
  }

  // Public method to send wallet transaction updates
  async sendWalletUpdateToUser(userId: string, transaction: any) {
    const client = this.connectedUsers.get(userId);
    if (client) {
      client.emit('wallet_update', transaction);
    }
  }
}