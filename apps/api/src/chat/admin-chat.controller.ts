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
} from '@nestjs/common';
import { AdminGuard } from '../auth/admin.guard';
import { ChatService } from './chat.service';
import { PrismaService } from '../common/prisma.service';
import { ReportStatus } from '@prisma/client';

export class UpdateReportStatusDto {
  status: ReportStatus;
  adminNote?: string;
}

export class BanUserFromChatDto {
  reason: string;
  duration?: number; // Duration in minutes, if not provided it's permanent
}

@Controller('admin/chat')
@UseGuards(AdminGuard)
export class AdminChatController {
  constructor(
    private chatService: ChatService,
    private prisma: PrismaService
  ) {}

  // Conversation management
  @Get('conversations')
  async getAllConversations(
    @Query('page') page: string = '1',
    @Query('limit') limit: string = '50'
  ) {
    return this.chatService.getAllConversations(parseInt(page), parseInt(limit));
  }

  @Get('conversations/:id')
  async getConversationDetails(@Param('id') conversationId: string) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
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
                    avatarKey: true,
                  },
                },
              },
            },
          },
        },
        messages: {
          take: 10,
          orderBy: {
            createdAt: 'desc',
          },
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
          },
        },
        _count: {
          select: {
            messages: true,
          },
        },
      },
    });

    return conversation;
  }

  @Delete('conversations/:id')
  async deleteConversation(@Param('id') conversationId: string) {
    await this.prisma.conversation.update({
      where: { id: conversationId },
      data: {
        isActive: false,
      },
    });

    return { success: true };
  }

  // Message moderation
  @Get('messages/reported')
  async getReportedMessages(
    @Query('page') page: string = '1',
    @Query('limit') limit: string = '50',
    @Query('status') status?: ReportStatus
  ) {
    return this.chatService.getReportedMessages(parseInt(page), parseInt(limit));
  }

  @Get('messages/:id')
  async getMessageDetails(@Param('id') messageId: string) {
    const message = await this.prisma.message.findUnique({
      where: { id: messageId },
      include: {
        sender: {
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
        conversation: {
          select: {
            id: true,
            type: true,
            title: true,
          },
        },
        reports: {
          include: {
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
        },
        reactions: {
          include: {
            user: {
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
      },
    });

    return message;
  }

  @Delete('messages/:id')
  async deleteMessage(@Request() req, @Param('id') messageId: string) {
    await this.prisma.message.update({
      where: { id: messageId },
      data: {
        deletedAt: new Date(),
        deletedBy: req.user.id,
      },
    });

    return { success: true };
  }

  // Report management
  @Get('reports')
  async getAllReports(
    @Query('page') page: string = '1',
    @Query('limit') limit: string = '50',
    @Query('status') status?: ReportStatus
  ) {
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const where = status ? { status } : {};

    const [reports, total] = await Promise.all([
      this.prisma.messageReport.findMany({
        where,
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
        take: parseInt(limit),
      }),
      this.prisma.messageReport.count({ where }),
    ]);

    return {
      reports,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / parseInt(limit)),
    };
  }

  @Put('reports/:id')
  async updateReportStatus(
    @Request() req,
    @Param('id') reportId: string,
    @Body() updateReportDto: UpdateReportStatusDto
  ) {
    const report = await this.prisma.messageReport.update({
      where: { id: reportId },
      data: {
        status: updateReportDto.status,
        adminNote: updateReportDto.adminNote,
        reviewedAt: new Date(),
        reviewedBy: req.user.id,
      },
    });

    return report;
  }

  // User management
  @Get('users/:id/conversations')
  async getUserChatActivity(@Param('id') userId: string) {
    const [conversationsCount, messagesCount, reportsCount] = await Promise.all([
      this.prisma.conversationParticipant.count({
        where: {
          userId,
          leftAt: null,
        },
      }),
      this.prisma.message.count({
        where: {
          senderId: userId,
          deletedAt: null,
        },
      }),
      this.prisma.messageReport.count({
        where: {
          message: {
            senderId: userId,
          },
        },
      }),
    ]);

    const recentMessages = await this.prisma.message.findMany({
      where: {
        senderId: userId,
        deletedAt: null,
      },
      include: {
        conversation: {
          select: {
            id: true,
            type: true,
            title: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 10,
    });

    return {
      conversationsCount,
      messagesCount,
      reportsCount,
      recentMessages,
    };
  }

  @Post('users/:id/ban')
  async banUserFromChat(
    @Request() req,
    @Param('id') userId: string,
    @Body() banDto: BanUserFromChatDto
  ) {
    const banUntil = banDto.duration 
      ? new Date(Date.now() + banDto.duration * 60 * 1000)
      : null;

    // Create or update user ban record
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        isChatBanned: true,
        chatBanReason: banDto.reason,
        chatBanUntil: banUntil,
        chatBannedBy: req.user.id,
        chatBannedAt: new Date(),
      },
    });

    return { 
      success: true, 
      message: `User banned from chat ${banDto.duration ? `for ${banDto.duration} minutes` : 'permanently'}` 
    };
  }

  @Delete('users/:id/ban')
  async unbanUserFromChat(@Param('id') userId: string) {
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

    return { success: true, message: 'User unbanned from chat' };
  }

  // Analytics
  @Get('analytics/overview')
  async getChatAnalytics() {
    const [
      totalConversations,
      activeConversations,
      totalMessages,
      totalReports,
      pendingReports,
      bannedUsers,
    ] = await Promise.all([
      this.prisma.conversation.count(),
      this.prisma.conversation.count({
        where: {
          isActive: true,
          lastMessageAt: {
            gte: new Date(Date.now() - 24 * 60 * 60 * 1000), // Last 24 hours
          },
        },
      }),
      this.prisma.message.count({
        where: {
          deletedAt: null,
        },
      }),
      this.prisma.messageReport.count(),
      this.prisma.messageReport.count({
        where: {
          status: ReportStatus.PENDING,
        },
      }),
      this.prisma.user.count({
        where: {
          isChatBanned: true,
        },
      }),
    ]);

    return {
      totalConversations,
      activeConversations,
      totalMessages,
      totalReports,
      pendingReports,
      bannedUsers,
    };
  }

  @Get('analytics/activity')
  async getChatActivity(@Query('days') days: string = '7') {
    const daysCount = parseInt(days);
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - daysCount);

    const messageActivity = await this.prisma.message.groupBy({
      by: ['createdAt'],
      where: {
        createdAt: {
          gte: startDate,
        },
        deletedAt: null,
      },
      _count: {
        id: true,
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    const conversationActivity = await this.prisma.conversation.groupBy({
      by: ['createdAt'],
      where: {
        createdAt: {
          gte: startDate,
        },
      },
      _count: {
        id: true,
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    return {
      messageActivity,
      conversationActivity,
    };
  }
}