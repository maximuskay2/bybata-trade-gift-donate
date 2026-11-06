import { BadRequestException, Body, Controller, Get, NotFoundException, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { AdStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { EmailService } from '../common/email.service';
import { EmailLinkRouterService } from '../shared/services/email-link-router.service';
import { EmailEventName } from '../email/email-events';
import { AdSchedulingService } from '../wallet/ad-scheduling.service';
import { CurrentUser } from '../auth/current-user.decorator';

@Controller('v1/admin/ads')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminAdsController {
  constructor(
    private prisma: PrismaService,
    private email: EmailService,
    private emailLinkRouter: EmailLinkRouterService,
    private adScheduling: AdSchedulingService,
  ) {}

  /** Create a feed ad (same flow as the mobile app — debits admin wallet, pending review). */
  @Post('schedules')
  async createSchedule(
    @CurrentUser() user: { sub: string },
    @Body()
    body: {
      title: string;
      description?: string;
      mediaType?: 'IMAGE' | 'VIDEO';
      mediaKeys?: string[];
      videoKey?: string;
      placementKey?: string;
      placementKeys?: string[];
      scheduledStart: string;
      scheduledEnd?: string;
      amount: number;
      destinationUrl: string;
      idempotencyKey?: string;
    },
  ) {
    return this.adScheduling.scheduleAd(
      user.sub,
      {
        title: body.title,
        description: body.description,
        mediaType: body.mediaType as any,
        mediaKeys: body.mediaKeys,
        videoKey: body.videoKey,
        placementKey: body.placementKey,
        placementKeys: body.placementKeys,
        destinationUrl: body.destinationUrl,
        scheduledStart: new Date(body.scheduledStart),
        scheduledEnd: body.scheduledEnd ? new Date(body.scheduledEnd) : undefined,
        amount: Number(body.amount),
      },
      body.idempotencyKey,
    );
  }

  @Get('stats')
  async scheduleStats() {
    const now = new Date();
    const endingSoonCutoff = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    const [grouped, total, endingSoon, pendingReview] = await Promise.all([
      this.prisma.adSchedule.groupBy({
        by: ['status'],
        _count: { _all: true },
      }),
      this.prisma.adSchedule.count(),
      this.prisma.adSchedule.count({
        where: {
          status: { in: [AdStatus.ACTIVE, AdStatus.SCHEDULED] },
          scheduledEnd: { not: null, lte: endingSoonCutoff, gte: now },
        },
      }),
      this.prisma.adSchedule.count({ where: { status: AdStatus.PENDING_REVIEW } }),
    ]);
    const byStatus: Record<string, number> = {};
    for (const row of grouped) {
      byStatus[row.status] = row._count._all;
    }
    return {
      total,
      pendingReview,
      endingSoon,
      byStatus,
      live: (byStatus[AdStatus.ACTIVE] ?? 0) + (byStatus[AdStatus.SCHEDULED] ?? 0),
      finished:
        (byStatus[AdStatus.EXPIRED] ?? 0) +
        (byStatus[AdStatus.CANCELLED] ?? 0) +
        (byStatus[AdStatus.REJECTED] ?? 0),
    };
  }

  @Get('schedules')
  async listSchedules(
    @Query('status') status?: string,
    @Query('q') q?: string,
    @Query('lifecycle') lifecycle?: string,
  ) {
    const now = new Date();
    const endingSoonCutoff = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    const where: Prisma.AdScheduleWhereInput = {};

    if (status) {
      where.status = status as AdStatus;
    }

    const lifecycleKey = lifecycle?.trim().toLowerCase();
    if (lifecycleKey === 'ending_soon') {
      where.status = { in: [AdStatus.ACTIVE, AdStatus.SCHEDULED] };
      where.scheduledEnd = { not: null, lte: endingSoonCutoff, gte: now };
    } else if (lifecycleKey === 'live') {
      where.status = { in: [AdStatus.ACTIVE, AdStatus.SCHEDULED, AdStatus.PAUSED] };
    } else if (lifecycleKey === 'finished') {
      where.status = { in: [AdStatus.EXPIRED, AdStatus.CANCELLED, AdStatus.REJECTED] };
    } else if (lifecycleKey === 'pending') {
      where.status = AdStatus.PENDING_REVIEW;
    }

    const search = q?.trim();
    if (search) {
      where.OR = [
        { title: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
        { destinationUrl: { contains: search, mode: 'insensitive' } },
        { user: { email: { contains: search, mode: 'insensitive' } } },
      ];
    }

    const rows = await this.prisma.adSchedule.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            profile: { select: { displayName: true } },
          },
        },
        transaction: { select: { id: true, amount: true, status: true, createdAt: true } },
      },
    });

    return rows.map((ad) => this.enrichScheduleRow(ad, now, endingSoonCutoff));
  }

  @Get('schedules/:id')
  async getSchedule(@Param('id') id: string) {
    const now = new Date();
    const endingSoonCutoff = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    const ad = await this.prisma.adSchedule.findUnique({
      where: { id },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            profile: { select: { displayName: true } },
          },
        },
        transaction: true,
      },
    });
    if (!ad) {
      throw new NotFoundException('Ad schedule not found');
    }
    return this.enrichScheduleRow(ad, now, endingSoonCutoff);
  }

  private enrichScheduleRow(
    ad: {
      id: string;
      title: string;
      description: string | null;
      status: AdStatus;
      mediaType: string;
      mediaKeys: string[];
      videoKey: string | null;
      placementKey: string | null;
      placementKeys: string[];
      destinationUrl: string | null;
      scheduledStart: Date;
      scheduledEnd: Date | null;
      viewCount: number;
      clickCount: number;
      createdAt: Date;
      updatedAt: Date;
      userId: string;
      user?: { id: string; email: string; profile?: { displayName: string | null } | null } | null;
      transaction?: { amount: unknown } | null;
    },
    now: Date,
    endingSoonCutoff: Date,
  ) {
    const msToEnd =
      ad.scheduledEnd != null ? ad.scheduledEnd.getTime() - now.getTime() : null;
    const daysRemaining =
      msToEnd != null ? Math.max(0, Math.ceil(msToEnd / (24 * 60 * 60 * 1000))) : null;

    let lifecycleLabel: string = ad.status;
    if (ad.status === AdStatus.PENDING_REVIEW) {
      lifecycleLabel = 'Awaiting review';
    } else if (
      (ad.status === AdStatus.ACTIVE || ad.status === AdStatus.SCHEDULED) &&
      ad.scheduledEnd &&
      ad.scheduledEnd <= endingSoonCutoff &&
      ad.scheduledEnd >= now
    ) {
      lifecycleLabel = 'Ending soon';
    } else if (ad.status === AdStatus.ACTIVE) {
      lifecycleLabel = 'Running';
    } else if (ad.status === AdStatus.SCHEDULED && ad.scheduledStart > now) {
      lifecycleLabel = 'Scheduled';
    } else if (ad.status === AdStatus.EXPIRED) {
      lifecycleLabel = 'Finished';
    }

    const views = ad.viewCount ?? 0;
    const clicks = ad.clickCount ?? 0;
    const cost = ad.transaction?.amount != null ? Number(ad.transaction.amount) : null;

    const renewEligibleStatuses: AdStatus[] = [
      AdStatus.EXPIRED,
      AdStatus.CANCELLED,
      AdStatus.REJECTED,
      AdStatus.PAUSED,
    ];
    const renewEligible = renewEligibleStatuses.includes(ad.status);

    return {
      ...ad,
      lifecycleLabel,
      daysRemaining,
      costBYC: cost,
      clickThroughRate: views > 0 ? Math.round((clicks / views) * 1000) / 10 : 0,
      renewEligible,
      userDisplayName: ad.user?.profile?.displayName ?? ad.user?.email ?? ad.userId,
    };
  }

  @Patch('schedules/:id')
  async updateSchedule(
    @Param('id') id: string,
    @Body()
    body: {
      title?: string;
      description?: string;
      mediaType?: 'IMAGE' | 'VIDEO';
      mediaKeys?: string[];
      videoKey?: string;
      placementKeys?: string[];
      scheduledStart?: string;
      scheduledEnd?: string;
      destinationUrl?: string;
    },
  ) {
    return this.adScheduling.updateAdSchedule(
      id,
      {
        title: body.title,
        description: body.description,
        mediaType: body.mediaType as any,
        mediaKeys: body.mediaKeys,
        videoKey: body.videoKey,
        placementKeys: body.placementKeys,
        destinationUrl: body.destinationUrl,
        scheduledStart: body.scheduledStart
          ? new Date(body.scheduledStart)
          : undefined,
        scheduledEnd: body.scheduledEnd
          ? new Date(body.scheduledEnd)
          : undefined,
      },
      { isAdmin: true },
    );
  }

  @Patch('schedules/:id/review')
  async reviewSchedule(
    @Param('id') id: string,
    @Body() body: { decision: 'approve' | 'reject' }
  ) {
    const schedule = await this.prisma.adSchedule.findUnique({
      where: { id },
      include: { user: { select: { id: true, email: true, profile: { select: { displayName: true } } } } },
    });
    if (!schedule) {
      throw new NotFoundException('Ad schedule not found');
    }
    if (schedule.status !== AdStatus.PENDING_REVIEW) {
      throw new BadRequestException(
        `Only pending ads can be reviewed (current status: ${schedule.status})`,
      );
    }
    const now = new Date();
    if (body.decision === 'reject') {
      await this.prisma.adSchedule.update({ where: { id }, data: { status: AdStatus.REJECTED } });
      try {
        if (schedule.user?.email) {
          this.email.dispatchInBackground({
            eventName: EmailEventName.AdRejected,
            recipient: { email: schedule.user.email, userId: schedule.user.id },
            vars: {
              actorName: schedule.user.profile?.displayName || schedule.user.email,
              adTitle: schedule.title,
              reason: 'Rejected by admin review',
            },
          });
        }
      } catch {
        // Non-blocking
      }
      return { ok: true, status: AdStatus.REJECTED };
    }
    const status = schedule.scheduledStart <= now ? AdStatus.ACTIVE : AdStatus.SCHEDULED;
    await this.prisma.adSchedule.update({ where: { id }, data: { status } });
    try {
      if (schedule.user?.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.AdApproved,
          recipient: { email: schedule.user.email, userId: schedule.user.id },
          vars: {
            actorName: schedule.user.profile?.displayName || schedule.user.email,
            adTitle: schedule.title,
            startDate: schedule.scheduledStart.toISOString(),
            adUrl: this.emailLinkRouter.getAppOpenLink(`/ads/${schedule.id}`),
          },
        });
      }
    } catch {
      // Non-blocking
    }
    return { ok: true, status };
  }
}
