import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  ParseIntPipe,
  DefaultValuePipe
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { CurrentUser } from '../auth/current-user.decorator';
import { CommunitiesService } from '../communities/communities.service';
import { PrismaService } from '../common/prisma.service';
import { 
  Role, 
  CommunityStatus, 
  PostStatus, 
  EventStatus, 
  MemberStatus,
  CommunityVisibility,
  CommunityType,
  CommunityRole,
  ExpertLevel,
  PollStatus,
  ReportStatus,
  ReportReason
} from '@prisma/client';

@Controller('v1/admin/communities')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN, Role.MODERATOR)
export class AdminCommunitiesController {
  constructor(
    private readonly communitiesService: CommunitiesService,
    private readonly prisma: PrismaService
  ) {}

  @Get()
  async getAllCommunities(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
    @Query('status') status?: string,
    @Query('query') query?: string,
    @Query('type') type?: string,
    @Query('visibility') visibility?: string,
    @Query('sort') sort?: string,
    @Query('dir') dir?: 'asc' | 'desc',
  ) {
    const skip = (page - 1) * size;
    const where: any = {};

    if (status) {
      where.status = status;
    }

    if (type) {
      where.type = type;
    }

    if (visibility) {
      where.visibility = visibility;
    }

    if (query) {
      where.OR = [
        { name: { contains: query, mode: 'insensitive' } },
        { description: { contains: query, mode: 'insensitive' } },
        { tags: { hasSome: [query] } }
      ];
    }

    const orderBy: any = {};
    if (sort) {
      orderBy[sort] = dir || 'desc';
    } else {
      orderBy.createdAt = 'desc';
    }

    const [communities, total] = await Promise.all([
      this.prisma.community.findMany({
        where,
        include: {
          createdBy: {
            include: { profile: true }
          },
          _count: {
            select: {
              members: true,
              posts: true,
              events: true,
              goals: true
            }
          }
        },
        skip,
        take: size,
        orderBy
      }),
      this.prisma.community.count({ where })
    ]);

    return {
      items: communities,
      total,
      page,
      size,
      totalPages: Math.ceil(total / size)
    };
  }

  @Get('stats')
  async getCommunityStats() {
    const [
      totalCommunities,
      activeCommunities,
      suspendedCommunities,
      publicCommunities,
      privateCommunities,
      totalPosts,
      totalEvents,
      totalMembers,
      totalPolls,
      totalReports
    ] = await Promise.all([
      this.prisma.community.count(),
      this.prisma.community.count({ where: { status: CommunityStatus.ACTIVE } }),
      this.prisma.community.count({ where: { status: CommunityStatus.SUSPENDED } }),
      this.prisma.community.count({ where: { type: CommunityType.PUBLIC } }),
      this.prisma.community.count({ where: { type: CommunityType.PRIVATE } }),
      this.prisma.communityPost.count(),
      this.prisma.communityEvent.count(),
      this.prisma.communityMember.count({ where: { status: MemberStatus.ACTIVE } }),
      this.prisma.communityPoll.count(),
      this.prisma.communityPostReport.count({ where: { status: ReportStatus.PENDING } })
    ]);

    // Get type breakdown
    const typeBreakdown = await this.prisma.community.groupBy({
      by: ['type'],
      _count: { type: true }
    });

    // Get category breakdown
    const categoryBreakdown = await this.prisma.community.groupBy({
      by: ['category'],
      _count: { category: true }
    });

    return {
      totalCommunities,
      activeCommunities,
      suspendedCommunities,
      publicCommunities,
      privateCommunities,
      totalPosts,
      totalEvents,
      totalMembers,
      totalPolls,
      totalReports,
      typeBreakdown: typeBreakdown.reduce((acc, item) => {
        acc[item.type] = item._count.type;
        return acc;
      }, {} as Record<string, number>),
      categoryBreakdown: categoryBreakdown.reduce((acc, item) => {
        acc[item.category] = item._count.category;
        return acc;
      }, {} as Record<string, number>)
    };
  }

  @Put(':id/status')
  async updateCommunityStatus(
    @Param('id') communityId: string,
    @Body() body: { status: CommunityStatus; reason?: string },
    @CurrentUser() user: any
  ) {
    const community = await this.prisma.community.update({
      where: { id: communityId },
      data: { status: body.status },
      include: {
        createdBy: { include: { profile: true } },
        _count: { select: { members: true, posts: true, events: true } }
      }
    });

    // Log admin action
    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: 'COMMUNITY_STATUS_UPDATE',
        ip: null,
        ua: null
      }
    });

    return community;
  }

  @Put(':id/ban')
  async banCommunity(
    @Param('id') communityId: string,
    @Body() body: { reason: string },
    @CurrentUser() user: any
  ) {
    const community = await this.prisma.community.update({
      where: { id: communityId },
      data: { status: CommunityStatus.SUSPENDED }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: 'COMMUNITY_BANNED',
        ip: null,
        ua: null
      }
    });

    return community;
  }

  @Put(':id/unban')
  async unbanCommunity(
    @Param('id') communityId: string,
    @CurrentUser() user: any
  ) {
    const community = await this.prisma.community.update({
      where: { id: communityId },
      data: { status: CommunityStatus.ACTIVE }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: 'COMMUNITY_UNBANNED',
        ip: null,
        ua: null
      }
    });

    return community;
  }

  @Put(':id/feature')
  async featureCommunity(
    @Param('id') communityId: string,
    @Body() body: { featured: boolean },
    @CurrentUser() user: any
  ) {
    const community = await this.prisma.community.update({
      where: { id: communityId },
      data: { isFeatured: body.featured }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: body.featured ? 'COMMUNITY_FEATURED' : 'COMMUNITY_UNFEATURED',
        ip: null,
        ua: null
      }
    });

    return community;
  }

  @Put(':id/verify')
  async verifyCommunity(
    @Param('id') communityId: string,
    @Body() body: { verified: boolean },
    @CurrentUser() user: any
  ) {
    const community = await this.prisma.community.update({
      where: { id: communityId },
      data: { isVerified: body.verified }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: body.verified ? 'COMMUNITY_VERIFIED' : 'COMMUNITY_UNVERIFIED',
        ip: null,
        ua: null
      }
    });

    return community;
  }

  @Patch(':id')
  async adminUpdateCommunity(
    @Param('id') id: string,
    @Body() body: {
      name?: string;
      description?: string;
      shortDescription?: string;
      category?: string;
      type?: string;
      visibility?: string;
      requiresApproval?: boolean;
      mediaKeys?: string[];
      avatarKey?: string;
      bannerKey?: string;
      tags?: string[];
      rules?: string;
      location?: string;
      center_latitude?: number;
      center_longitude?: number;
      isVerified?: boolean;
      isFeatured?: boolean;
      settings?: any;
      impactTracker?: any;
      metadata?: any;
    }
  ) {
    const data: any = {};
    if (body.name !== undefined) data.name = body.name;
    if (body.description !== undefined) data.description = body.description;
    if (body.shortDescription !== undefined) data.shortDescription = body.shortDescription;
    if (body.category !== undefined) data.category = body.category;
    if (body.type !== undefined) data.type = body.type;
    if (body.visibility !== undefined) data.visibility = body.visibility;
    if (body.requiresApproval !== undefined) data.requiresApproval = body.requiresApproval;
    if (body.mediaKeys !== undefined) data.mediaKeys = body.mediaKeys;
    if (body.avatarKey !== undefined) data.avatarKey = body.avatarKey;
    if (body.bannerKey !== undefined) data.bannerKey = body.bannerKey;
    if (body.tags !== undefined) data.tags = body.tags;
    if (body.rules !== undefined) data.rules = body.rules;
    if (body.location !== undefined) data.location = body.location;
    if (body.center_latitude !== undefined) data.center_latitude = body.center_latitude;
    if (body.center_longitude !== undefined) data.center_longitude = body.center_longitude;
    if (body.isVerified !== undefined) data.isVerified = body.isVerified;
    if (body.isFeatured !== undefined) data.isFeatured = body.isFeatured;
    if (body.settings !== undefined) data.settings = body.settings;
    if (body.impactTracker !== undefined) data.impactTracker = body.impactTracker;
    if (body.metadata !== undefined) data.metadata = body.metadata;
    return this.prisma.community.update({ where: { id }, data });
  }

  @Delete(':id')
  async adminDeleteCommunity(@Param('id') id: string) {
    // Cascade delete related records to avoid FK errors
    const posts = await this.prisma.communityPost.findMany({ where: { communityId: id }, select: { id: true } });
    const postIds = posts.map(p => p.id);
    const events = await this.prisma.communityEvent.findMany({ where: { communityId: id }, select: { id: true } });
    const eventIds = events.map(e => e.id);
    const polls = await this.prisma.communityPoll.findMany({ where: { postId: { in: postIds } }, select: { id: true } });
    const pollIds = polls.map(p => p.id);

    await this.prisma.$transaction([
      // Delete poll votes and options
      this.prisma.communityPollVote.deleteMany({ where: { pollId: { in: pollIds } } }),
      this.prisma.communityPollOption.deleteMany({ where: { pollId: { in: pollIds } } }),
      this.prisma.communityPoll.deleteMany({ where: { id: { in: pollIds } } }),
      // Delete post reports and comment likes
      this.prisma.communityPostReport.deleteMany({ where: { postId: { in: postIds } } }),
      this.prisma.communityPostCommentLike.deleteMany({ where: { commentId: { in: await this.prisma.communityPostComment.findMany({ where: { postId: { in: postIds } }, select: { id: true } }).then(comments => comments.map(c => c.id)) } } }),
      this.prisma.communityPostComment.deleteMany({ where: { postId: { in: postIds } } }),
      this.prisma.communityPostLike.deleteMany({ where: { postId: { in: postIds } } }),
      this.prisma.communityPost.deleteMany({ where: { id: { in: postIds } } }),
      // Delete events
      this.prisma.communityEventAttendee.deleteMany({ where: { eventId: { in: eventIds } } }),
      this.prisma.communityEvent.deleteMany({ where: { id: { in: eventIds } } }),
      // Delete goals and members
      this.prisma.communityGoal.deleteMany({ where: { communityId: id } }),
      this.prisma.communityMember.deleteMany({ where: { communityId: id } }),
      this.prisma.community.delete({ where: { id } })
    ]);
    return { success: true };
  }

  // Post Moderation
  @Get(':id/posts')
  async getCommunityPosts(
    @Param('id') communityId: string,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
    @Query('status') status?: string,
  ) {
    const skip = (page - 1) * size;
    const where: any = { communityId };

    if (status) {
      where.status = status;
    }

    const [posts, total] = await Promise.all([
      this.prisma.communityPost.findMany({
        where,
        include: {
          author: { include: { profile: true } },
          community: true,
          _count: { select: { likes: true, comments: true } }
        },
        skip,
        take: size,
        orderBy: { createdAt: 'desc' }
      }),
      this.prisma.communityPost.count({ where })
    ]);

    return { items: posts, total, page, size };
  }

  @Put('posts/:postId/status')
  async updatePostStatus(
    @Param('postId') postId: string,
    @Body() body: { status: PostStatus; reason?: string },
    @CurrentUser() user: any
  ) {
    const post = await this.prisma.communityPost.update({
      where: { id: postId },
      data: { status: body.status }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: 'POST_STATUS_UPDATE',
        ip: null,
        ua: null
      }
    });

    return post;
  }

  @Delete('posts/:postId')
  async deletePost(
    @Param('postId') postId: string,
    @CurrentUser() user: any
  ) {
    const post = await this.prisma.communityPost.update({
      where: { id: postId },
      data: { status: PostStatus.DELETED }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: 'POST_DELETED',
        ip: null,
        ua: null
      }
    });

    return { success: true };
  }

  // Event Moderation  
  @Get(':id/events')
  async getCommunityEvents(
    @Param('id') communityId: string,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
  ) {
    const skip = (page - 1) * size;
    const [events, total] = await Promise.all([
      this.prisma.communityEvent.findMany({
        where: { communityId },
        include: {
          organizer: { include: { profile: true } },
          community: true,
          _count: { select: { attendees: true } }
        },
        skip,
        take: size,
        orderBy: { startDate: 'desc' }
      }),
      this.prisma.communityEvent.count({ where: { communityId } })
    ]);

    return { items: events, total, page, size };
  }

  @Put('events/:eventId/status')
  async updateEventStatus(
    @Param('eventId') eventId: string,
    @Body() body: { status: EventStatus; reason?: string },
    @CurrentUser() user: any
  ) {
    const event = await this.prisma.communityEvent.update({
      where: { id: eventId },
      data: { status: body.status }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: 'EVENT_STATUS_UPDATE',
        ip: null,
        ua: null
      }
    });

    return event;
  }

  // Member Management
  @Get(':id/members')
  async getCommunityMembers(
    @Param('id') communityId: string,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
    @Query('status') status?: string,
  ) {
    const skip = (page - 1) * size;
    const where: any = { communityId };

    if (status) {
      where.status = status;
    }

    const [members, total] = await Promise.all([
      this.prisma.communityMember.findMany({
        where,
        include: {
          user: { include: { profile: true } },
          community: true
        },
        skip,
        take: size,
        orderBy: { joinedAt: 'desc' }
      }),
      this.prisma.communityMember.count({ where })
    ]);

    return { items: members, total, page, size };
  }

  @Post(':id/members/:memberId/ban')
  async banMember(
    @Param('id') communityId: string,
    @Param('memberId') memberId: string,
    @Body() body: { reason: string },
    @CurrentUser() user: any
  ) {
    const member = await this.prisma.communityMember.update({
      where: { id: memberId },
      data: {
        status: MemberStatus.BANNED,
        bannedAt: new Date(),
        banReason: body.reason
      }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: 'MEMBER_BANNED',
        ip: null,
        ua: null
      }
    });

    return member;
  }

  @Post(':id/members/:memberId/unban')
  async unbanMember(
    @Param('id') communityId: string,
    @Param('memberId') memberId: string,
    @CurrentUser() user: any
  ) {
    const member = await this.prisma.communityMember.update({
      where: { id: memberId },
      data: {
        status: MemberStatus.ACTIVE,
        bannedAt: null,
        banReason: null
      }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: 'MEMBER_UNBANNED',
        ip: null,
        ua: null
      }
    });

    return member;
  }

  // Poll Management
  @Get('polls')
  async getAllPolls(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
    @Query('status') status?: string,
  ) {
    const skip = (page - 1) * size;
    const where: any = {};
    if (status) {
      where.status = status;
    }

    const [polls, total] = await Promise.all([
      this.prisma.communityPoll.findMany({
        where,
        include: {
          post: {
            include: {
              author: { include: { profile: true } },
              community: true
            }
          },
          options: true,
          _count: { select: { votes: true } }
        },
        skip,
        take: size,
        orderBy: { createdAt: 'desc' }
      }),
      this.prisma.communityPoll.count({ where })
    ]);

    return { items: polls, total, page, size };
  }

  @Put('polls/:pollId/status')
  async updatePollStatus(
    @Param('pollId') pollId: string,
    @Body() body: { status: PollStatus },
    @CurrentUser() user: any
  ) {
    const poll = await this.prisma.communityPoll.update({
      where: { id: pollId },
      data: { status: body.status }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: 'POLL_STATUS_UPDATE',
        ip: null,
        ua: null
      }
    });

    return poll;
  }

  // Reports Management
  @Get('reports')
  async getReports(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
    @Query('status') status?: string,
    @Query('reason') reason?: string,
  ) {
    const skip = (page - 1) * size;
    const where: any = {};

    if (status) {
      where.status = status;
    }

    if (reason) {
      where.reason = reason;
    }

    const [reports, total] = await Promise.all([
      this.prisma.communityPostReport.findMany({
        where,
        include: {
          post: {
            include: {
              author: { include: { profile: true } },
              community: true
            }
          },
          comment: {
            include: {
              author: { include: { profile: true } }
            }
          },
          reporter: { include: { profile: true } }
        },
        skip,
        take: size,
        orderBy: { createdAt: 'desc' }
      }),
      this.prisma.communityPostReport.count({ where })
    ]);

    return { items: reports, total, page, size };
  }

  @Put('reports/:reportId/resolve')
  async resolveReport(
    @Param('reportId') reportId: string,
    @Body() body: { status: ReportStatus; adminNote?: string },
    @CurrentUser() user: any
  ) {
    const report = await this.prisma.communityPostReport.update({
      where: { id: reportId },
      data: {
        status: body.status,
        reviewedBy: user.sub,
        reviewedAt: new Date(),
        adminNote: body.adminNote
      }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: 'REPORT_RESOLVED',
        ip: null,
        ua: null
      }
    });

    return report;
  }

  // Goals Management
  @Get(':id/goals')
  async getCommunityGoals(
    @Param('id') communityId: string,
  ) {
    const goals = await this.prisma.communityGoal.findMany({
      where: { communityId },
      orderBy: { createdAt: 'desc' }
    });

    return { items: goals };
  }

  @Post(':id/goals')
  async createGoal(
    @Param('id') communityId: string,
    @Body() body: { title: string; description?: string; targetDate?: string },
    @CurrentUser() user: any
  ) {
    const goal = await this.prisma.communityGoal.create({
      data: {
        communityId,
        title: body.title,
        description: body.description,
        targetDate: body.targetDate ? new Date(body.targetDate) : null
      }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: 'COMMUNITY_GOAL_CREATED',
        ip: null,
        ua: null
      }
    });

    return goal;
  }

  @Put('goals/:goalId')
  async updateGoal(
    @Param('goalId') goalId: string,
    @Body() body: { title?: string; description?: string; targetDate?: string; isCompleted?: boolean },
    @CurrentUser() user: any
  ) {
    const data: any = {};
    if (body.title !== undefined) data.title = body.title;
    if (body.description !== undefined) data.description = body.description;
    if (body.targetDate !== undefined) data.targetDate = body.targetDate ? new Date(body.targetDate) : null;
    if (body.isCompleted !== undefined) {
      data.isCompleted = body.isCompleted;
      if (body.isCompleted) {
        data.completedAt = new Date();
      } else {
        data.completedAt = null;
      }
    }

    const goal = await this.prisma.communityGoal.update({
      where: { id: goalId },
      data
    });

    return goal;
  }

  @Delete('goals/:goalId')
  async deleteGoal(
    @Param('goalId') goalId: string,
    @CurrentUser() user: any
  ) {
    await this.prisma.communityGoal.delete({
      where: { id: goalId }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: 'COMMUNITY_GOAL_DELETED',
        ip: null,
        ua: null
      }
    });

    return { success: true };
  }

  // Member Expert Level Management
  @Put(':id/members/:memberId/expert-level')
  async updateMemberExpertLevel(
    @Param('id') communityId: string,
    @Param('memberId') memberId: string,
    @Body() body: { expertLevel: ExpertLevel },
    @CurrentUser() user: any
  ) {
    const member = await this.prisma.communityMember.update({
      where: { id: memberId },
      data: { expertLevel: body.expertLevel }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: 'MEMBER_EXPERT_LEVEL_UPDATED',
        ip: null,
        ua: null
      }
    });

    return member;
  }

  @Put(':id/members/:memberId/role')
  async updateMemberRole(
    @Param('id') communityId: string,
    @Param('memberId') memberId: string,
    @Body() body: { role: CommunityRole },
    @CurrentUser() user: any
  ) {
    const member = await this.prisma.communityMember.update({
      where: { id: memberId },
      data: { role: body.role }
    });

    await this.prisma.auditLog.create({
      data: {
        userId: user.sub,
        type: 'MEMBER_ROLE_UPDATED',
        ip: null,
        ua: null
      }
    });

    return member;
  }

  @Get('reported-content')
  async getReportedContent(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
    @Query('type') type?: string,
  ) {
    const skip = (page - 1) * size;
    const where: any = { status: PostStatus.FLAGGED };
    
    const [posts, reports, postsCount, reportsCount] = await Promise.all([
      this.prisma.communityPost.findMany({
        where,
        include: {
          author: { include: { profile: true } },
          community: true
        },
        skip,
        take: size,
        orderBy: { updatedAt: 'desc' }
      }),
      this.prisma.communityPostReport.findMany({
        where: { status: ReportStatus.PENDING },
        include: {
          post: {
            include: {
              author: { include: { profile: true } },
              community: true
            }
          },
          comment: {
            include: {
              author: { include: { profile: true } }
            }
          },
          reporter: { include: { profile: true } }
        },
        skip,
        take: size,
        orderBy: { createdAt: 'desc' }
      }),
      this.prisma.communityPost.count({ where }),
      this.prisma.communityPostReport.count({ where: { status: ReportStatus.PENDING } })
    ]);

    const total = postsCount + reportsCount;
    const items = [
      ...posts.map(p => {
        const { type: _, ...rest } = p as any;
        return { itemType: 'post' as const, ...rest };
      }),
      ...reports.map(r => {
        const { type: _, ...rest } = r as any;
        return { itemType: 'report' as const, ...rest };
      })
    ];

    return { 
      items,
      total,
      page,
      size 
    };
  }
}
