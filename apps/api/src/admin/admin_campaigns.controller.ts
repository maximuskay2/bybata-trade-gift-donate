import { Controller, Get, Param, Post, Query, Res, UseGuards, Body, Patch, Delete, Req } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { EmailService } from '../common/email.service';
import { EmailLinkRouterService } from '../shared/services/email-link-router.service';
import { EmailEventName } from '../email/email-events';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AdminListingModerationService } from './admin_listing_moderation.service';
import { ListingModerationDto } from './dto/listing-moderation.dto';
import { NearbyListingNotifierService } from '../notifications/nearby-listing-notifier.service';
import { CampaignStatus } from '@prisma/client';
import type { Response } from 'express';

@Controller('v1/admin/campaigns')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminCampaignsController {
  constructor(
    private prisma: PrismaService,
    private email: EmailService,
    private emailLinkRouter: EmailLinkRouterService,
    private moderation: AdminListingModerationService,
    private nearbyNotifier: NearbyListingNotifierService,
  ) {}

  @Get()
  async list(
    @Query('status') status?: CampaignStatus,
    @Query('category') category?: string,
    @Query('query') query?: string,
    @Query('isUrgent') isUrgentStr?: string,
    @Query('isFeatured') isFeaturedStr?: string,
    @Query('isVerified') isVerifiedStr?: string,
    @Query('founderId') founderId?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
    @Query('sort') sort?: string,
    @Query('dir') dir?: 'asc' | 'desc',
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const where: any = {};

    if (status) where.status = status;
    if (category) where.category = category;
    if (founderId) where.founderId = founderId;
    if (isUrgentStr === 'true') where.isUrgent = true;
    if (isUrgentStr === 'false') where.isUrgent = false;
    if (isFeaturedStr === 'true') where.isFeatured = true;
    if (isFeaturedStr === 'false') where.isFeatured = false;
    if (isVerifiedStr === 'true') where.isVerified = true;
    if (isVerifiedStr === 'false') where.isVerified = false;

    if (query) {
      where.OR = [
        { title: { contains: query, mode: 'insensitive' } },
        { description: { contains: query, mode: 'insensitive' } },
        { founder: { email: { contains: query, mode: 'insensitive' } } },
        { founder: { profile: { displayName: { contains: query, mode: 'insensitive' } } } },
        { tags: { hasSome: [query] } },
      ];
    }

    const d: 'asc' | 'desc' = dir === 'asc' ? 'asc' : 'desc';
    let orderBy: any = { createdAt: d };
    if (sort === 'title') orderBy = { title: d };
    else if (sort === 'status') orderBy = { status: d };
    else if (sort === 'goalAmount') orderBy = { goalAmount: d };
    else if (sort === 'currentAmount') orderBy = { currentAmount: d };
    else if (sort === 'donorCount') orderBy = { donorCount: d };
    else if (sort === 'viewCount') orderBy = { viewCount: d };
    else if (sort === 'founderEmail') orderBy = { founder: { email: d } };

    const [total, items] = await this.prisma.$transaction([
      this.prisma.campaign.count({ where }),
      this.prisma.campaign.findMany({
        where,
        include: {
          founder: { include: { profile: true } },
          adminModeratedBy: { include: { profile: true } },
          donations: {
            include: {
              donor: { include: { profile: true } }
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
      totalCampaigns,
      activeCampaigns,
      completedCampaigns,
      pausedCampaigns,
      draftCampaigns,
      totalDonations,
      totalDonationAmount,
    ] = await this.prisma.$transaction([
      this.prisma.campaign.count(),
      this.prisma.campaign.count({ where: { status: CampaignStatus.ACTIVE } }),
      this.prisma.campaign.count({ where: { status: CampaignStatus.COMPLETED } }),
      this.prisma.campaign.count({ where: { status: CampaignStatus.PAUSED } }),
      this.prisma.campaign.count({ where: { status: CampaignStatus.DRAFT } }),
      this.prisma.donation.count(),
      this.prisma.donation.aggregate({
        _sum: { amount: true },
        where: { status: 'SUCCESS' }
      }),
    ]);

    return {
      totalCampaigns,
      activeCampaigns,
      completedCampaigns,
      pausedCampaigns,
      draftCampaigns,
      totalDonations,
      totalDonationAmount: totalDonationAmount._sum.amount || 0,
    };
  }

  @Get('donations')
  async getDonations(
    @Query('campaignId') campaignId?: string,
    @Query('donorId') donorId?: string,
    @Query('status') status?: string,
    @Query('isAnonymous') isAnonymousStr?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
    @Query('sort') sort?: string,
    @Query('dir') dir?: 'asc' | 'desc',
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const where: any = {};

    if (campaignId) where.campaignId = campaignId;
    if (donorId) where.donorId = donorId;
    if (status) where.status = status;
    if (isAnonymousStr === 'true') where.isAnonymous = true;
    if (isAnonymousStr === 'false') where.isAnonymous = false;

    const d: 'asc' | 'desc' = dir === 'asc' ? 'asc' : 'desc';
    let orderBy: any = { createdAt: d };
    if (sort === 'amount') orderBy = { amount: d };
    else if (sort === 'status') orderBy = { status: d };
    else if (sort === 'karmaAwarded') orderBy = { karmaAwarded: d };

    const [total, items] = await this.prisma.$transaction([
      this.prisma.donation.count({ where }),
      this.prisma.donation.findMany({
        where,
        include: {
          campaign: {
            include: {
              founder: { include: { profile: true } }
            }
          },
          donor: { include: { profile: true } }
        },
        orderBy,
        skip: (page - 1) * size,
        take: size,
      }),
    ]);

    return { items, page, size, total };
  }

  @Get(':id/donations')
  async getCampaignDonations(@Param('id') id: string) {
    return this.prisma.donation.findMany({
      where: { campaignId: id },
      include: {
        donor: { include: { profile: true } },
        campaign: true
      },
      orderBy: { createdAt: 'desc' }
    });
  }

  @Post(':id/moderate')
  async moderate(@Param('id') id: string, @Req() req: any, @Body() body: ListingModerationDto) {
    const adminId = (req.user as any)?.sub;
    return this.moderation.moderate({
      listingType: 'campaign',
      listingId: id,
      adminId,
      action: body.action,
      reason: body.reason,
      notifyOwner: body.notifyOwner,
    });
  }

  @Post(':id/feature')
  async toggleFeature(@Param('id') id: string, @Body() body: { featured: boolean }) {
    return this.prisma.campaign.update({
      where: { id },
      data: { isFeatured: body.featured }
    });
  }

  @Post(':id/verify')
  async toggleVerify(@Param('id') id: string, @Body() body: { verified: boolean }) {
    const updated = await this.prisma.campaign.update({
      where: { id },
      data: { isVerified: body.verified }
    });
    try {
      if (body.verified) {
        const founder = await this.prisma.user.findUnique({
          where: { id: updated.founderId },
          select: { email: true, profile: { select: { displayName: true } } },
        });
        if (founder?.email) {
          this.email.dispatchInBackground({
            eventName: EmailEventName.CampaignApproved,
            recipient: { email: founder.email, userId: updated.founderId },
            vars: {
              actorName: founder.profile?.displayName || founder.email,
              campaignTitle: updated.title,
              campaignUrl: this.emailLinkRouter.getCampaignLink(updated.id),
            },
          });
        }
      }
    } catch {
      // Non-blocking
    }
    return updated;
  }

  @Post(':id/force-status')
  async forceStatus(@Param('id') id: string, @Body() body: { status: CampaignStatus }) {
    const updateData: any = { status: body.status };

    // Set appropriate timestamps
    if (body.status === CampaignStatus.ACTIVE) {
      updateData.launchedAt = new Date();
    } else if (body.status === CampaignStatus.PAUSED) {
      updateData.pausedAt = new Date();
    } else if (body.status === CampaignStatus.COMPLETED) {
      updateData.completedAt = new Date();
    } else if (body.status === CampaignStatus.CANCELLED) {
      updateData.cancelledAt = new Date();
    }

    const prior = await this.prisma.campaign.findUnique({
      where: { id },
      select: { status: true },
    });
    const updated = await this.prisma.campaign.update({
      where: { id },
      data: updateData
    });
    try {
      const founder = await this.prisma.user.findUnique({
        where: { id: updated.founderId },
        select: { email: true, profile: { select: { displayName: true } } },
      });
      if (founder?.email && body.status === CampaignStatus.CANCELLED) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.CampaignRejected,
          recipient: { email: founder.email, userId: updated.founderId },
          vars: {
            actorName: founder.profile?.displayName || founder.email,
            campaignTitle: updated.title,
            reason: 'Campaign status set to cancelled by admin',
            supportEmail: process.env.SUPPORT_EMAIL || 'support@bybata.com',
          },
        });
      }
    } catch {
      // Non-blocking
    }
    if (
      body.status === CampaignStatus.ACTIVE &&
      prior?.status !== CampaignStatus.ACTIVE
    ) {
      void this.nearbyNotifier.notifyNearbyListing({
        kind: 'campaign',
        listingId: updated.id,
        creatorId: updated.founderId,
        title: updated.title,
        locationText: updated.location,
        metadata: updated.metadata,
      });
    }
    return updated;
  }

  @Patch(':id')
  async adminUpdate(
    @Param('id') id: string,
    @Body() body: {
      title?: string;
      description?: string;
      shortDescription?: string;
      category?: string;
      goalAmount?: number;
      currency?: string;
      mediaKeys?: string[];
      thumbnailKey?: string;
      tags?: string[];
      location?: string;
      isUrgent?: boolean;
      minimumDonation?: number;
      endsAt?: string;
      metadata?: any;
    }
  ) {
    const data: any = {};
    if (body.title !== undefined) data.title = body.title;
    if (body.description !== undefined) data.description = body.description;
    if (body.shortDescription !== undefined) data.shortDescription = body.shortDescription;
    if (body.category !== undefined) data.category = body.category;
    if (body.goalAmount !== undefined) data.goalAmount = body.goalAmount;
    if (body.currency !== undefined) data.currency = body.currency;
    if (body.mediaKeys !== undefined) data.mediaKeys = body.mediaKeys;
    if (body.thumbnailKey !== undefined) data.thumbnailKey = body.thumbnailKey;
    if (body.tags !== undefined) data.tags = body.tags;
    if (body.location !== undefined) data.location = body.location;
    if (body.isUrgent !== undefined) data.isUrgent = body.isUrgent;
    if (body.minimumDonation !== undefined) data.minimumDonation = body.minimumDonation;
    if (body.endsAt !== undefined) data.endsAt = new Date(body.endsAt);
    if (body.metadata !== undefined) data.metadata = body.metadata;
    return this.prisma.campaign.update({ where: { id }, data });
  }

  @Delete(':id')
  async adminDelete(@Param('id') id: string) {
    return this.prisma.campaign.delete({ where: { id } });
  }

  @Get('export/csv')
  async exportCsv(@Res() res: Response) {
    const campaigns = await this.prisma.campaign.findMany({
      include: {
        founder: { include: { profile: true } },
        donations: { include: { donor: { include: { profile: true } } } }
      }
    });

    const header = [
      'id', 'title', 'status', 'category', 'goalAmount', 'currentAmount', 'currency',
      'donorCount', 'viewCount', 'shareCount', 'isUrgent', 'isFeatured', 'isVerified',
      'founderEmail', 'founderName', 'location', 'createdAt', 'launchedAt', 'completedAt',
      'tags'
    ];
    const rows = [header.join(',')];

    for (const c of campaigns) {
      rows.push([
        c.id,
        JSON.stringify(c.title ?? ''),
        c.status,
        c.category ?? '',
        c.goalAmount.toString(),
        c.currentAmount.toString(),
        c.currency,
        c.donorCount.toString(),
        c.viewCount.toString(),
        c.shareCount.toString(),
        c.isUrgent.toString(),
        c.isFeatured.toString(),
        c.isVerified.toString(),
        c.founder?.email ?? '',
        c.founder?.profile?.displayName ?? '',
        c.location ?? '',
        c.createdAt.toISOString(),
        c.launchedAt ? c.launchedAt.toISOString() : '',
        c.completedAt ? c.completedAt.toISOString() : '',
        JSON.stringify(c.tags),
      ].join(','));
    }

    const csv = rows.join('\n');
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="campaigns.csv"');
    res.send(csv);
  }

  @Get('analytics')
  async getAnalytics() {
    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    const [
      recentCampaigns,
      recentDonations,
      topCategories,
      topFounders,
      urgentCampaigns,
      averageDonation,
    ] = await this.prisma.$transaction([
      this.prisma.campaign.count({ where: { createdAt: { gte: thirtyDaysAgo } } }),
      this.prisma.donation.count({ where: { createdAt: { gte: thirtyDaysAgo } } }),
      this.prisma.campaign.groupBy({
        by: ['category'],
        where: { createdAt: { gte: thirtyDaysAgo } },
        _count: { category: true },
        orderBy: { _count: { category: 'desc' } },
        take: 5,
      }),
      this.prisma.campaign.groupBy({
        by: ['founderId'],
        where: { createdAt: { gte: thirtyDaysAgo } },
        _count: { founderId: true },
        orderBy: { _count: { founderId: 'desc' } },
        take: 5,
      }),
      this.prisma.campaign.count({
        where: {
          status: CampaignStatus.ACTIVE,
          isUrgent: true
        }
      }),
      this.prisma.donation.aggregate({
        _avg: { amount: true },
        where: {
          createdAt: { gte: thirtyDaysAgo },
          status: 'SUCCESS'
        }
      }),
    ]);

    return {
      recentCampaigns,
      recentDonations,
      topCategories,
      urgentCampaigns,
      averageDonation: averageDonation._avg.amount || 0,
      conversionRate: recentCampaigns > 0 ? (recentDonations / recentCampaigns * 100).toFixed(1) : '0',
    };
  }
}