import { Body, Controller, Delete, Get, Param, Patch, Post, Query, Req, Res, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AdminListingModerationService } from './admin_listing_moderation.service';
import { ListingModerationDto } from './dto/listing-moderation.dto';
import { GiftStatus, GiftType, GiftCategory, GiftRequestStatus } from '@prisma/client';
import type { Response } from 'express';

@Controller('v1/admin/gifts')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminGiftsController {
  constructor(
    private prisma: PrismaService,
    private moderation: AdminListingModerationService,
  ) {}

  @Get()
  async list(
    @Query('status') status?: GiftStatus,
    @Query('type') type?: GiftType,
    @Query('category') category?: GiftCategory,
    @Query('query') query?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
    @Query('sort') sort?: string,
    @Query('dir') dir?: 'asc' | 'desc',
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const where: any = {};
    
    if (status) where.status = status;
    if (type) where.type = type;
    if (category) where.category = category;
    if (query) {
      where.OR = [
        { title: { contains: query, mode: 'insensitive' } },
        { description: { contains: query, mode: 'insensitive' } },
        { giver: { email: { contains: query, mode: 'insensitive' } } },
        { giver: { profile: { displayName: { contains: query, mode: 'insensitive' } } } },
        { tags: { hasSome: [query] } },
      ];
    }
    
    const d: 'asc' | 'desc' = dir === 'asc' ? 'asc' : 'desc';
    let orderBy: any = { createdAt: d };
    if (sort === 'title') orderBy = { title: d };
    else if (sort === 'status') orderBy = { status: d };
    else if (sort === 'type') orderBy = { type: d };
    else if (sort === 'category') orderBy = { category: d };
    else if (sort === 'karmaReward') orderBy = { karmaReward: d };
    else if (sort === 'giverEmail') orderBy = { giver: { email: d } };

    const [total, items] = await this.prisma.$transaction([
      this.prisma.gift.count({ where }),
      this.prisma.gift.findMany({
        where,
        include: { 
          giver: { include: { profile: true } },
          adminModeratedBy: { include: { profile: true } },
          claims: {
            include: {
              claimer: { include: { profile: true } }
            }
          }
        },
        orderBy,
        skip: (page - 1) * size,
        take: size,
      }),
    ]);
    
    return { items, page, size, total };
  }

  @Get('stats')
  async getStats() {
    const [
      totalGifts,
      activeGifts,
      claimedGifts,
      expiredGifts,
      totalClaims,
      pendingRequests,
      categoryBreakdown,
      typeBreakdown,
    ] = await this.prisma.$transaction([
      this.prisma.gift.count(),
      this.prisma.gift.count({ where: { status: GiftStatus.ACTIVE } }),
      this.prisma.gift.count({ where: { status: GiftStatus.CLAIMED } }),
      this.prisma.gift.count({ where: { status: GiftStatus.EXPIRED } }),
      this.prisma.giftClaim.count(),
      this.prisma.giftRequest.count({ where: { status: GiftRequestStatus.PENDING } }),
      this.prisma.gift.groupBy({
        by: ['category'],
        _count: { category: true },
        orderBy: { _count: { category: 'desc' } },
      }),
      this.prisma.gift.groupBy({
        by: ['type'],
        _count: { type: true },
        orderBy: { _count: { type: 'desc' } },
      }),
    ]);

    // Transform the grouped data into a more usable format
    const categoryBreakdownMap = categoryBreakdown.reduce((acc, item) => {
      const key = String(item.category);
      const count = (item as any)._count?.category ?? 0;
      acc[key] = count;
      return acc;
    }, {} as Record<string, number>);

    const typeBreakdownMap = typeBreakdown.reduce((acc, item) => {
      const key = String(item.type);
      const count = (item as any)._count?.type ?? 0;
      acc[key] = count;
      return acc;
    }, {} as Record<string, number>);

    return {
      totalGifts,
      activeGifts,
      claimedGifts,
      expiredGifts,
      totalClaims,
      pendingRequests,
      categoryBreakdown: categoryBreakdownMap,
      typeBreakdown: typeBreakdownMap,
    };
  }

  @Get(':id/claims')
  async getClaims(@Param('id') id: string) {
    return this.prisma.giftClaim.findMany({ 
      where: { giftId: id }, 
      include: { 
        claimer: { include: { profile: true } },
        gift: true
      }, 
      orderBy: { claimedAt: 'desc' } 
    });
  }

  @Post(':id/moderate')
  async moderate(@Param('id') id: string, @Req() req: any, @Body() body: ListingModerationDto) {
    const adminId = (req.user as any)?.sub;
    return this.moderation.moderate({
      listingType: 'gift',
      listingId: id,
      adminId,
      action: body.action,
      reason: body.reason,
      notifyOwner: body.notifyOwner,
    });
  }

  @Post(':id/force-expire')
  async forceExpire(@Param('id') id: string) {
    return this.prisma.gift.update({ 
      where: { id }, 
      data: { status: GiftStatus.EXPIRED } 
    });
  }

  @Post(':id/force-cancel')
  async forceCancel(@Param('id') id: string) {
    return this.prisma.gift.update({ 
      where: { id }, 
      data: { status: GiftStatus.CANCELLED } 
    });
  }

  @Post(':id/reactivate')
  async reactivate(@Param('id') id: string) {
    const gift = await this.prisma.gift.findUnique({ where: { id } });
    if (!gift) throw new Error('Gift not found');
    
    // Check if gift can be reactivated
    const canReactivate = gift.status === GiftStatus.EXPIRED || gift.status === GiftStatus.CANCELLED;
    if (!canReactivate) throw new Error('Gift cannot be reactivated');
    
    return this.prisma.gift.update({ 
      where: { id }, 
      data: { 
        status: GiftStatus.ACTIVE,
        expiresAt: gift.expiresAt && new Date() > gift.expiresAt 
          ? new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // Extend by 30 days
          : gift.expiresAt
      } 
    });
  }

  @Patch(':id')
  async adminUpdate(
    @Param('id') id: string,
    @Body() body: {
      title?: string;
      description?: string;
      type?: GiftType;
      category?: GiftCategory;
      mediaKeys?: string[];
      karmaReward?: number;
      maxClaims?: number;
      location?: string;
      isLocationRestricted?: boolean;
      tags?: string[];
      metadata?: any;
      expiresAt?: string;
    }
  ) {
    const data: any = {};
    if (body.title !== undefined) data.title = body.title;
    if (body.description !== undefined) data.description = body.description;
    if (body.type !== undefined) data.type = body.type;
    if (body.category !== undefined) data.category = body.category;
    if (body.mediaKeys !== undefined) data.mediaKeys = body.mediaKeys;
    if (body.karmaReward !== undefined) data.karmaReward = body.karmaReward;
    if (body.maxClaims !== undefined) data.maxClaims = body.maxClaims;
    if (body.location !== undefined) data.location = body.location;
    if (body.isLocationRestricted !== undefined) data.isLocationRestricted = body.isLocationRestricted;
    if (body.tags !== undefined) data.tags = body.tags;
    if (body.metadata !== undefined) data.metadata = body.metadata;
    if (body.expiresAt !== undefined) data.expiresAt = new Date(body.expiresAt);
    return this.prisma.gift.update({ where: { id }, data });
  }

  @Delete(':id')
  async adminDelete(@Param('id') id: string) {
    return this.prisma.gift.delete({ where: { id } });
  }

  @Get('export/csv')
  async exportCsv(@Res() res: Response) {
    const gifts = await this.prisma.gift.findMany({ 
      include: { 
        giver: { include: { profile: true } },
        claims: { include: { claimer: { include: { profile: true } } } }
      } 
    });
    
    const header = [
      'id', 'title', 'type', 'category', 'status', 'karmaReward', 'maxClaims', 'currentClaims',
      'giverEmail', 'giverName', 'location', 'isLocationRestricted',
      'createdAt', 'expiresAt', 'tags'
    ];
    const rows = [header.join(',')];
    
    for (const g of gifts) {
      rows.push([
        g.id,
        JSON.stringify(g.title ?? ''),
        g.type,
        g.category,
        g.status,
        g.karmaReward.toString(),
        g.maxClaims.toString(),
        g.currentClaims.toString(),
        g.giver?.email ?? '',
        g.giver?.profile?.displayName ?? '',
        g.location ?? '',
        g.isLocationRestricted.toString(),
        g.createdAt.toISOString(),
        g.expiresAt ? g.expiresAt.toISOString() : '',
        JSON.stringify(g.tags),
      ].join(','));
    }
    
    const csv = rows.join('\n');
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="gifts.csv"');
    res.send(csv);
  }

  @Get('analytics')
  async getAnalytics() {
    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const ninetyDaysAgo = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
    
    const [
      recentGifts,
      recentClaims,
      topGivers,
      topCategories,
      expiringGifts,
      monthlyGifts,
      avgKarmaPerGift,
      topReceivers,
    ] = await this.prisma.$transaction([
      this.prisma.gift.count({ where: { createdAt: { gte: thirtyDaysAgo } } }),
      this.prisma.giftClaim.count({ where: { claimedAt: { gte: thirtyDaysAgo } } }),
      this.prisma.gift.groupBy({
        by: ['giverId'],
        where: { createdAt: { gte: thirtyDaysAgo } },
        _count: { giverId: true },
        orderBy: { _count: { giverId: 'desc' } },
        take: 5,
      }),
      this.prisma.gift.groupBy({
        by: ['category'],
        where: { createdAt: { gte: thirtyDaysAgo } },
        _count: { category: true },
        orderBy: { _count: { category: 'desc' } },
        take: 5,
      }),
      this.prisma.gift.count({
        where: {
          status: GiftStatus.ACTIVE,
          expiresAt: { lte: sevenDaysAgo }
        }
      }),
      // Monthly gift creation trends for the last 3 months (client-side aggregation)
      this.prisma.gift.findMany({
        where: { createdAt: { gte: ninetyDaysAgo } },
        select: { createdAt: true },
        orderBy: { createdAt: 'asc' },
      }),
      // Average karma per gift
      this.prisma.gift.aggregate({
        _avg: { karmaReward: true },
      }),
      // Top receivers (most claims)
      this.prisma.giftClaim.groupBy({
        by: ['claimerId'],
        _count: { claimerId: true },
        orderBy: { _count: { claimerId: 'desc' } },
        take: 5,
      }),
    ]);

    // Format monthly data for charting
    const monthlyData = (monthlyGifts as { createdAt: Date }[]).reduce<Record<string, number>>((acc, item) => {
      const d = item.createdAt;
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`; // YYYY-MM
      acc[key] = (acc[key] ?? 0) + 1;
      return acc;
    }, {});

    return {
      recentGifts,
      recentClaims,
      topCategories,
      expiringGifts,
      claimRate: recentGifts > 0 ? (recentClaims / recentGifts * 100).toFixed(1) : '0',
      topGivers,
      monthlyTrends: monthlyData,
      avgKarmaPerGift: avgKarmaPerGift._avg.karmaReward || 0,
      topReceivers,
    };
  }

  // Gift Requests Management
  @Get('requests')
  async listRequests(
    @Query('status') status?: GiftRequestStatus,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const where: any = {};
    
    if (status) where.status = status;

    const [total, items] = await this.prisma.$transaction([
      this.prisma.giftRequest.count({ where }),
      this.prisma.giftRequest.findMany({
        where,
        include: {
          gift: {
            include: {
              giver: { include: { profile: true } }
            }
          },
          requester: { include: { profile: true } }
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
      }),
    ]);
    
    return { items, page, size, total };
  }

  @Post('requests/:id/approve')
  async approveRequestAdmin(
    @Param('id') requestId: string,
    @Body() body: { message?: string }
  ) {
    const request = await this.prisma.giftRequest.findUnique({
      where: { id: requestId },
      include: { gift: true }
    });

    if (!request) throw new Error('Request not found');
    if (request.status !== GiftRequestStatus.PENDING) {
      throw new Error('Request already processed');
    }

    const code = Math.random().toString(36).substring(2, 18);

    return this.prisma.$transaction(async (tx) => {
      await tx.giftRequest.update({
        where: { id: requestId },
        data: {
          status: GiftRequestStatus.APPROVED,
          respondedAt: new Date(),
          responseMessage: body.message || 'Approved by admin'
        }
      });

      const claim = await tx.giftClaim.create({
        data: {
          giftId: request.giftId,
          claimerId: request.requesterId,
          code,
          karmaAwarded: request.gift.karmaReward,
        }
      });

      const updatedCurrentClaims = request.gift.currentClaims + 1;
      const newStatus = updatedCurrentClaims >= request.gift.maxClaims ? GiftStatus.CLAIMED : GiftStatus.ACTIVE;

      await tx.gift.update({
        where: { id: request.giftId },
        data: { 
          currentClaims: updatedCurrentClaims,
          status: newStatus
        }
      });

      return { request, claim };
    });
  }

  @Post('requests/:id/decline')
  async declineRequestAdmin(
    @Param('id') requestId: string,
    @Body() body: { reason?: string }
  ) {
    const request = await this.prisma.giftRequest.findUnique({
      where: { id: requestId }
    });

    if (!request) throw new Error('Request not found');
    if (request.status !== GiftRequestStatus.PENDING) {
      throw new Error('Request already processed');
    }

    return this.prisma.giftRequest.update({
      where: { id: requestId },
      data: {
        status: GiftRequestStatus.DECLINED,
        respondedAt: new Date(),
        declineReason: body.reason || 'Declined by admin'
      },
      include: {
        gift: true,
        requester: { include: { profile: true } }
      }
    });
  }
}
