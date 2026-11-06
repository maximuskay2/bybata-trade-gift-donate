import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
  Logger,
} from '@nestjs/common';
import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsEnum,
  IsArray,
  ArrayNotEmpty,
  IsObject,
} from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { ChatService, CreateConversationDto, CreateMessageDto } from './chat.service';
import { PrismaService } from '../common/prisma.service';
import { ConversationType, ChatMessageType } from '@prisma/client';

// DTOs below must use validation decorators so that the global ValidationPipe
// (with whitelist/forbidNonWhitelisted) does not reject legitimate fields like
// `type`, `title`, `participantIds`, and `metadata` as "should not exist".
export class CreateConversationRequestDto {
  @IsEnum(ConversationType)
  type: ConversationType;

  @IsOptional()
  @IsString()
  title?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsArray()
  @ArrayNotEmpty()
  @IsString({ each: true })
  participantIds: string[];

  @IsOptional()
  @IsObject()
  metadata?: any;
}

export class CreateMessageRequestDto {
  @IsString()
  @IsNotEmpty()
  content: string;

  @IsOptional()
  @IsEnum(ChatMessageType)
  type?: ChatMessageType;

  @IsOptional()
  @IsString()
  replyToId?: string;

  @IsOptional()
  @IsObject()
  metadata?: any;
}

export class StartDirectMessageDto {
  @IsString()
  @IsNotEmpty()
  recipientId: string;

  @IsString()
  @IsOptional()
  message?: string;

  @IsOptional()
  type?: ConversationType;

  @IsString()
  @IsOptional()
  contextTitle?: string;

  @IsString()
  @IsOptional()
  contextId?: string;
}

@Controller('chat')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(
    private chatService: ChatService,
    private prisma: PrismaService,
  ) {}

  private readonly logger = new Logger(ChatController.name);

  // Conversation endpoints
  @Post('conversations')
  async createConversation(
    @Request() req,
    @Body() createConversationDto: CreateConversationRequestDto
  ) {
    const user = req.user || {};
    const userId = user.id ?? user.sub;

    const data: CreateConversationDto = {
      ...createConversationDto,
      createdBy: userId,
    };
    
    return this.chatService.createConversation(data);
  }

  @Get('conversations')
  async getUserConversations(
    @Request() req,
    @Query('page') page: string = '1',
    @Query('limit') limit: string = '50',
    @Query('module') module?: ConversationType
  ) {
    const user = req.user || {};
    const userId = user.id ?? user.sub;

    const result = await this.chatService.getUserConversations(
      userId,
      parseInt(page),
      parseInt(limit),
      module
    );

    return result;
  }

  @Get('conversations/search')
  async searchConversations(
    @Request() req,
    @Query('q') query: string
  ) {
    if (!query || query.trim().length === 0) {
      return [];
    }

    const user = req.user || {};
    const userId = user.id ?? user.sub;
    
    return this.chatService.searchConversations(userId, query.trim());
  }

  @Get('conversations/:id')
  async getConversation(
    @Request() req,
    @Param('id') conversationId: string
  ) {
    const user = req.user || {};
    const userId = user.id ?? user.sub;

    return this.chatService.getConversationById(conversationId, userId);
  }

  @Post('conversations/:id/read')
  async markConversationAsRead(
    @Request() req,
    @Param('id') conversationId: string
  ) {
    const user = req.user || {};
    const userId = user.id ?? user.sub;

    await this.chatService.markConversationAsRead(conversationId, userId);
    return { success: true };
  }

  // Message endpoints
  @Post('conversations/:id/messages')
  async createMessage(
    @Request() req,
    @Param('id') conversationId: string,
    @Body() createMessageDto: CreateMessageRequestDto
  ) {
    const user = req.user || {};
    const userId = user.id ?? user.sub;

    // Always trust the authenticated user as the sender; never let the
    // request body override senderId. Spreading the DTO first ensures that
    // any "senderId" coming from the client cannot overwrite the
    // authenticated user id.
    const data: CreateMessageDto = {
      ...createMessageDto,
      conversationId,
      senderId: userId,
    };
    
    return this.chatService.createMessage(data);
  }

  @Get('conversations/:id/messages')
  async getConversationMessages(
    @Request() req,
    @Param('id') conversationId: string,
    @Query('page') page: string = '1',
    @Query('limit') limit: string = '50'
  ) {
    const user = req.user || {};
    const userId = user.id ?? user.sub;

    return this.chatService.getConversationMessages(
      conversationId,
      userId,
      parseInt(page),
      parseInt(limit)
    );
  }

  @Get('conversations/:id/messages/search')
  async searchMessages(
    @Request() req,
    @Param('id') conversationId: string,
    @Query('q') query: string
  ) {
    if (!query || query.trim().length === 0) {
      return [];
    }

    const user = req.user || {};
    const userId = user.id ?? user.sub;
    
    return this.chatService.searchMessages(conversationId, userId, query.trim());
  }

  @Post('conversations/:conversationId/messages/:messageId/read')
  async markMessageAsRead(
    @Request() req,
    @Param('conversationId') conversationId: string,
    @Param('messageId') messageId: string
  ) {
    const user = req.user || {};
    const userId = user.id ?? user.sub;

    await this.chatService.markMessageAsRead(conversationId, userId, messageId);
    return { success: true };
  }

  // Direct messages
  @Post('direct-messages')
  async startDirectMessage(
    @Request() req,
    @Body() startDirectMessageDto: StartDirectMessageDto
  ) {
    try {
      const ts = new Date().toISOString();
      const user = req.user || {};
      const requesterId = user.id ?? user.sub;
      const headers = req?.headers || {};
      const sanitizedHeaders = {
        'content-type': headers['content-type'],
        'user-agent': headers['user-agent'],
        'authorization': headers['authorization'] ? 'Bearer ***redacted***' : undefined,
      };
      this.logger.log(`[${ts}] DM start requested`, {
        requesterId,
        payload: startDirectMessageDto,
        headers: sanitizedHeaders,
      } as any);

      // Create or get existing conversation of specified type (default DIRECT)
      const metadata =
        startDirectMessageDto.contextTitle || startDirectMessageDto.contextId
          ? {
              contextTitle: startDirectMessageDto.contextTitle,
              contextId: startDirectMessageDto.contextId,
            }
          : undefined;
      const conversation = await this.chatService.createOrGetDirectConversation(
        requesterId,
        startDirectMessageDto.recipientId,
        startDirectMessageDto.type ?? ConversationType.DIRECT,
        metadata,
      );

      // Send initial message if provided
      if (startDirectMessageDto.message) {
        const message = await this.chatService.createMessage({
          conversationId: conversation.id,
          senderId: requesterId,
          content: startDirectMessageDto.message,
          type: ChatMessageType.TEXT,
        });

        return {
          conversation,
          message,
        };
      }

      return { conversation };
    } catch (error) {
      const ts = new Date().toISOString();
      const user = req.user || {};
      const requesterId = user.id ?? user.sub;
      const details = {
        requesterId,
        payload: startDirectMessageDto,
        route: 'POST /chat/direct-messages',
      };
      this.logger.error(
        `[${ts}] Failed to start direct message: ${error?.message ?? error}`,
        error?.stack ?? undefined,
        JSON.stringify(details)
      );
      throw error;
    }
  }

  // Message reactions
  @Post('messages/:messageId/reactions')
  async addReaction(
    @Request() req,
    @Param('messageId') messageId: string,
    @Body() body: { emoji: string }
  ) {
    const user = req.user || {};
    const userId = user.id ?? user.sub;
    // Check if user can see the message (is participant of conversation)
    const message = await this.prisma.message.findUnique({
      where: { id: messageId },
      include: {
        conversation: {
          include: {
            participants: {
              where: {
                userId: userId,
                leftAt: null,
              },
            },
          },
        },
        sender: {
          select: { id: true, email: true, profile: { select: { displayName: true } } },
        },
      },
    });

    if (!message || message.conversation.participants.length === 0) {
      throw new Error('Message not found or not authorized');
    }

    // Upsert reaction (add or update existing)
    const reaction = await this.prisma.messageReaction.upsert({
      where: {
        messageId_userId_emoji: {
          messageId,
          userId: req.user.id,
          emoji: body.emoji,
        },
      },
      update: {
        createdAt: new Date(),
      },
      create: {
        messageId,
        userId: userId,
        emoji: body.emoji,
      },
    });

    // No email for reactions - existing conversation; rely on in-app notifications only
    return reaction;
  }

  @Delete('messages/:messageId/reactions/:emoji')
  async removeReaction(
    @Request() req,
    @Param('messageId') messageId: string,
    @Param('emoji') emoji: string
  ) {
    const user = req.user || {};
    const userId = user.id ?? user.sub;

    await this.prisma.messageReaction.deleteMany({
      where: {
        messageId,
        userId: userId,
        emoji,
      },
    });

    return { success: true };
  }

  @Post('messages/:messageId/report')
  async reportMessage(
    @Request() req,
    @Param('messageId') messageId: string,
    @Body() body: { reason: string; description?: string }
  ) {
    const user = req.user || {};
    const userId = user.id ?? user.sub;

    const report = await this.prisma.messageReport.create({
      data: {
        messageId,
        reporterId: userId,
        reason: body.reason as any,
        description: body.description,
      },
    });

    return report;
  }

  // Utility endpoints
  @Get('health')
  async healthCheck() {
    return { status: 'ok', service: 'chat' };
  }
}
