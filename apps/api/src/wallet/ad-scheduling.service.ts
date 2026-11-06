import { Injectable, BadRequestException, NotFoundException, Logger } from '@nestjs/common';
import { AdMediaType, AdStatus, NotificationPriority, NotificationType, Prisma, Role } from '@prisma/client';
import { PrismaService } from '../common/prisma.service';
import { WalletService } from './wallet.service';
import { EmailService } from '../common/email.service';
import { EmailLinkRouterService } from '../shared/services/email-link-router.service';
import { EmailEventName } from '../email/email-events';
import { requireDestinationUrl } from '../common/destination-url.util';
import { mapWalletUserError } from './wallet-errors.util';
import { NotificationsService } from '../notifications/notifications.service';
import { StorageService } from '../storage/storage.service';
import { resolveAdThumbnailUrl } from '../ads/ad-media.util';

export interface AdScheduleData {
  title: string;
  description?: string;
  mediaType?: AdMediaType;
  mediaKeys?: string[];
  videoKey?: string;
  /** @deprecated use placementKeys */
  placementKey?: string;
  placementKeys?: string[];
  scheduledStart: Date;
  scheduledEnd?: Date;
  /** Total BYC charged (must equal budgetPerPlacement × placement count). */
  amount: number;
  budgetPerPlacement?: number;
  destinationUrl: string;
}

export interface UpdateAdScheduleData {
  title?: string;
  description?: string;
  mediaType?: AdMediaType;
  mediaKeys?: string[];
  videoKey?: string;
  placementKeys?: string[];
  scheduledStart?: Date;
  scheduledEnd?: Date;
  destinationUrl?: string;
}

@Injectable()
export class AdSchedulingService {
  private readonly logger = new Logger(AdSchedulingService.name);

  constructor(
    private prisma: PrismaService,
    private wallet: WalletService,
    private email: EmailService,
    private emailLinkRouter: EmailLinkRouterService,
    private notifications: NotificationsService,
    private storage: StorageService,
  ) {}

  /**
   * Schedule an advertisement
   * Creates ad purchase transaction and schedules ad
   */
  async scheduleAd(
    userId: string,
    data: AdScheduleData,
    idempotencyKey?: string
  ): Promise<{ ok: true; transactionId: string; adScheduleId: string }> {
    try {
      return await this.scheduleAdInternal(userId, data, idempotencyKey);
    } catch (error) {
      if (error instanceof BadRequestException || error instanceof NotFoundException) {
        throw error;
      }
      this.logger.error(
        `scheduleAd failed for user ${userId}:`,
        error instanceof Error ? error.stack : error,
      );
      throw mapWalletUserError(
        error,
        'We could not schedule your ad. Please try again.',
      );
    }
  }

  private async scheduleAdInternal(
    userId: string,
    data: AdScheduleData,
    idempotencyKey?: string
  ): Promise<{ ok: true; transactionId: string; adScheduleId: string }> {
    if (data.amount <= 0) {
      throw new BadRequestException('Ad amount must be positive');
    }

    if (data.scheduledStart < new Date()) {
      throw new BadRequestException('Scheduled start time must be in the future');
    }

    if (data.scheduledEnd && data.scheduledEnd <= data.scheduledStart) {
      throw new BadRequestException('Scheduled end time must be after start time');
    }

    const placementKeys = [
      ...new Set(
        (data.placementKeys?.length
          ? data.placementKeys
          : data.placementKey
            ? [data.placementKey]
            : []
        ).map((k) => k.trim()).filter(Boolean),
      ),
    ];
    if (placementKeys.length === 0) {
      throw new BadRequestException('At least one placement is required');
    }

    const destinationUrl = requireDestinationUrl(data.destinationUrl);
    const media = this.normalizeAdMedia(data);

    const placements = await this.prisma.adPlacement.findMany({
      where: { key: { in: placementKeys }, active: true },
    });
    if (placements.length !== placementKeys.length) {
      throw new BadRequestException('One or more placements are invalid or inactive');
    }

    const durationDays = data.scheduledEnd
      ? Math.max(
          1,
          Math.floor(
            (data.scheduledEnd.getTime() - data.scheduledStart.getTime()) /
              (1000 * 60 * 60 * 24),
          ),
        )
      : 7;
    const pricing = await this.wallet.getAdPricingRates();
    let expectedTotal = 0;
    for (const key of placementKeys) {
      expectedTotal += this.dailyRateForPlacement(key, pricing) * durationDays;
    }
    if (Math.abs(expectedTotal - data.amount) > 0.01) {
      throw new BadRequestException(
        `Total budget must be ${expectedTotal.toFixed(2)} BYC (${placementKeys.length} placement(s) × ${durationDays} day(s))`,
      );
    }

    // Purchase ad (debit BYC)
    const purchaseResult = await this.wallet.purchaseAdvert(
      userId,
      data.amount,
      {
        title: data.title,
        duration: data.scheduledEnd
          ? Math.floor((data.scheduledEnd.getTime() - data.scheduledStart.getTime()) / (1000 * 60 * 60 * 24)) // days
          : 7, // Default 7 days
        type: 'scheduled',
      },
      idempotencyKey
    );

    // Create ad schedule record
    const adSchedule = await this.prisma.adSchedule.create({
      data: {
        userId,
        transactionId: purchaseResult.transactionId,
        title: data.title,
        description: data.description,
        mediaType: media.mediaType,
        mediaKeys: media.mediaKeys,
        videoKey: media.videoKey,
        placementKey: placementKeys[0],
        placementKeys,
        destinationUrl,
        scheduledStart: data.scheduledStart,
        scheduledEnd: data.scheduledEnd,
        status: AdStatus.PENDING_REVIEW,
      },
    });

    this.logger.log(`Ad scheduled for user ${userId}, transaction: ${purchaseResult.transactionId}`);

    try {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { email: true, profile: { select: { displayName: true } } },
      });
      if (user?.email) {
        await this.email.dispatch({
          eventName: EmailEventName.AdSubmitted,
          recipient: { email: user.email, userId },
          vars: {
            actorName: user.profile?.displayName || user.email,
            adTitle: adSchedule.title,
            adId: adSchedule.id,
          },
        });
      }
    } catch {
      // Non-blocking
    }

    try {
      const admins = await this.prisma.user.findMany({
        where: { role: Role.ADMIN },
        select: { id: true },
      });
      for (const admin of admins) {
        await this.notifications.createNotification({
          userId: admin.id,
          type: NotificationType.SYSTEM_ANNOUNCEMENT,
          title: 'Ad pending review',
          message: `New ad "${adSchedule.title}" is waiting for approval.`,
          data: { adScheduleId: adSchedule.id },
          actionUrl: '/ads-review',
          sourceId: adSchedule.id,
          sourceType: 'AD_SCHEDULE',
          priority: NotificationPriority.HIGH,
        });
      }
    } catch {
      // Non-blocking
    }

    return {
      ok: true,
      transactionId: purchaseResult.transactionId,
      adScheduleId: adSchedule.id,
    };
  }

  private static readonly EDITABLE_AD_STATUSES: readonly AdStatus[] = [
    AdStatus.PENDING_REVIEW,
    AdStatus.REJECTED,
    AdStatus.SCHEDULED,
    AdStatus.PAUSED,
    AdStatus.ACTIVE,
  ];

  private static readonly STATUSES_REQUIRING_REVIEW: readonly AdStatus[] = [
    AdStatus.REJECTED,
    AdStatus.SCHEDULED,
    AdStatus.PAUSED,
    AdStatus.ACTIVE,
  ];

  /**
   * Update ad creative, schedule, or placements. Edits to live/rejected ads return to pending review.
   */
  async updateAdSchedule(
    adScheduleId: string,
    data: UpdateAdScheduleData,
    options: { userId?: string; isAdmin?: boolean },
  ): Promise<{ ok: true; status: AdStatus }> {
    const adSchedule = await this.prisma.adSchedule.findUnique({
      where: { id: adScheduleId },
    });
    if (!adSchedule) {
      throw new NotFoundException('Ad schedule not found');
    }
    if (!options.isAdmin && adSchedule.userId !== options.userId) {
      throw new BadRequestException('Not authorized to update this ad');
    }
    if (!AdSchedulingService.EDITABLE_AD_STATUSES.includes(adSchedule.status)) {
      throw new BadRequestException(
        `Cannot edit an ad with status ${adSchedule.status}`,
      );
    }

    const hasUpdate = Object.values(data).some((v) => v !== undefined);
    if (!hasUpdate) {
      throw new BadRequestException('No fields to update');
    }

    const isLiveOrPaused =
      adSchedule.status === AdStatus.ACTIVE ||
      adSchedule.status === AdStatus.PAUSED;

    if (
      isLiveOrPaused &&
      (data.placementKeys !== undefined ||
        data.scheduledStart !== undefined ||
        data.scheduledEnd !== undefined)
    ) {
      throw new BadRequestException(
        'Pause or wait until the ad finishes before changing schedule or placements. You can still edit title, description, link, and media.',
      );
    }

    const updatePayload: Prisma.AdScheduleUpdateInput = {};

    if (data.title !== undefined) {
      const title = data.title.trim();
      if (!title) throw new BadRequestException('Title is required');
      updatePayload.title = title;
    }

    if (data.description !== undefined) {
      updatePayload.description = data.description.trim() || null;
    }

    if (data.destinationUrl !== undefined) {
      updatePayload.destinationUrl = requireDestinationUrl(data.destinationUrl);
    }

    if (
      data.mediaType !== undefined ||
      data.mediaKeys !== undefined ||
      data.videoKey !== undefined
    ) {
      const media = this.normalizeAdMedia({
        mediaType: data.mediaType ?? adSchedule.mediaType,
        mediaKeys: data.mediaKeys ?? adSchedule.mediaKeys,
        videoKey: data.videoKey ?? adSchedule.videoKey ?? undefined,
      });
      updatePayload.mediaType = media.mediaType;
      updatePayload.mediaKeys = media.mediaKeys;
      updatePayload.videoKey = media.videoKey;
    }

    if (data.placementKeys !== undefined) {
      const placementKeys = [
        ...new Set(
          data.placementKeys.map((k) => k.trim()).filter(Boolean),
        ),
      ];
      if (placementKeys.length === 0) {
        throw new BadRequestException('At least one placement is required');
      }
      const placements = await this.prisma.adPlacement.findMany({
        where: { key: { in: placementKeys }, active: true },
      });
      if (placements.length !== placementKeys.length) {
        throw new BadRequestException(
          'One or more placements are invalid or inactive',
        );
      }
      updatePayload.placementKeys = placementKeys;
      updatePayload.placementKey = placementKeys[0];
    }

    if (data.scheduledStart !== undefined) {
      if (data.scheduledStart < new Date()) {
        throw new BadRequestException('Scheduled start must be in the future');
      }
      updatePayload.scheduledStart = data.scheduledStart;
    }

    if (data.scheduledEnd !== undefined) {
      const start = data.scheduledStart ?? adSchedule.scheduledStart;
      if (data.scheduledEnd <= start) {
        throw new BadRequestException(
          'Scheduled end must be after start time',
        );
      }
      updatePayload.scheduledEnd = data.scheduledEnd;
    }

    let nextStatus = adSchedule.status;
    if (
      AdSchedulingService.STATUSES_REQUIRING_REVIEW.includes(adSchedule.status)
    ) {
      nextStatus = AdStatus.PENDING_REVIEW;
      updatePayload.status = nextStatus;
    }

    await this.prisma.adSchedule.update({
      where: { id: adScheduleId },
      data: updatePayload,
    });

    if (nextStatus === AdStatus.PENDING_REVIEW) {
      try {
        const admins = await this.prisma.user.findMany({
          where: { role: Role.ADMIN },
          select: { id: true },
        });
        const title =
          (updatePayload.title as string | undefined) ?? adSchedule.title;
        for (const admin of admins) {
          await this.notifications.createNotification({
            userId: admin.id,
            type: NotificationType.SYSTEM_ANNOUNCEMENT,
            title: 'Ad updated — pending review',
            message: `Ad "${title}" was edited and needs approval again.`,
            data: { adScheduleId },
            actionUrl: '/ads-review',
            sourceId: adScheduleId,
            sourceType: 'AD_SCHEDULE',
            priority: NotificationPriority.HIGH,
          });
        }
      } catch {
        // Non-blocking
      }
    }

    this.logger.log(`Ad schedule updated: ${adScheduleId} -> status ${nextStatus}`);
    return { ok: true, status: nextStatus };
  }

  /**
   * Get scheduled ads for user
   */
  async getScheduledAds(userId: string, status?: string): Promise<any[]> {
    const where: Prisma.AdScheduleWhereInput = {
      userId,
      ...(status ? { status: status as AdStatus } : {}),
    } as Prisma.AdScheduleWhereInput;
    const rows = await this.prisma.adSchedule.findMany({
      where,
      orderBy: { scheduledStart: 'asc' },
      include: {
        transaction: true,
      },
    });

    return Promise.all(
      rows.map(async (row) => {
        const thumbnailUrl = await resolveAdThumbnailUrl(
          this.storage,
          row.mediaType,
          row.mediaKeys ?? [],
          row.videoKey,
        );
        return { ...row, thumbnailUrl };
      }),
    );
  }

  /** User-initiated status changes (admin approval is separate). */
  private static readonly USER_AD_STATUS_TRANSITIONS: Partial<
    Record<AdStatus, readonly AdStatus[]>
  > = {
    [AdStatus.PENDING_REVIEW]: [AdStatus.CANCELLED],
    [AdStatus.SCHEDULED]: [AdStatus.CANCELLED],
    [AdStatus.ACTIVE]: [AdStatus.PAUSED, AdStatus.CANCELLED],
    [AdStatus.PAUSED]: [AdStatus.ACTIVE, AdStatus.CANCELLED],
  };

  /**
   * Update ad schedule status (pause, cancel — not self-approve).
   */
  async updateAdStatus(
    userId: string,
    adScheduleId: string,
    status: AdStatus
  ): Promise<void> {
    const adSchedule = await this.prisma.adSchedule.findUnique({
      where: { id: adScheduleId },
    });
    if (!adSchedule) {
      throw new NotFoundException('Ad schedule not found');
    }
    if (adSchedule.userId !== userId) {
      throw new BadRequestException('Not authorized to update this ad');
    }

    const allowed =
      AdSchedulingService.USER_AD_STATUS_TRANSITIONS[adSchedule.status];
    if (!allowed?.includes(status)) {
      if (adSchedule.status === AdStatus.PENDING_REVIEW) {
        throw new BadRequestException(
          'This ad is awaiting admin review. You can cancel it, but cannot publish it until approved.',
        );
      }
      if (
        adSchedule.status === AdStatus.REJECTED ||
        adSchedule.status === AdStatus.EXPIRED ||
        adSchedule.status === AdStatus.CANCELLED
      ) {
        throw new BadRequestException(
          `Cannot change status of a ${adSchedule.status.toLowerCase()} ad.`,
        );
      }
      throw new BadRequestException(
        `Cannot change ad status from ${adSchedule.status} to ${status}.`,
      );
    }

    await this.prisma.adSchedule.update({
      where: { id: adScheduleId },
      data: { status },
    });
    this.logger.log(`Ad status updated: ${adScheduleId} -> ${status}`);
  }

  async listActiveAdsByPlacement(placementKey: string): Promise<any[]> {
    const now = new Date();
    const where = {
      status: AdStatus.ACTIVE,
      scheduledStart: { lte: now },
      OR: [
        { scheduledEnd: null },
        { scheduledEnd: { gte: now } },
      ],
      AND: [
        {
          OR: [
            { placementKey },
            { placementKeys: { has: placementKey } },
          ],
        },
      ],
    } as Prisma.AdScheduleWhereInput;
    return this.prisma.adSchedule.findMany({
      where,
      orderBy: { scheduledStart: 'desc' },
    });
  }

  /**
   * Track ad view
   */
  async trackAdView(adScheduleId: string): Promise<void> {
    await this.prisma.adSchedule.update({
      where: { id: adScheduleId },
      data: {
        viewCount: { increment: 1 },
      },
    });
    this.logger.debug(`Ad view tracked: ${adScheduleId}`);
  }

  /**
   * Track ad click
   */
  async trackAdClick(adScheduleId: string): Promise<void> {
    await this.prisma.adSchedule.update({
      where: { id: adScheduleId },
      data: {
        clickCount: { increment: 1 },
      },
    });
    this.logger.debug(`Ad click tracked: ${adScheduleId}`);
  }

  /**
   * Get ad performance metrics
   */
  async getAdPerformance(adScheduleId: string, userId: string): Promise<any> {
    const adSchedule = await this.prisma.adSchedule.findUnique({
      where: { id: adScheduleId },
      include: { transaction: true },
    });
    if (!adSchedule || adSchedule.userId !== userId) {
      throw new NotFoundException('Ad schedule not found');
    }
    return {
      viewCount: adSchedule.viewCount,
      clickCount: adSchedule.clickCount,
      clickThroughRate: adSchedule.viewCount > 0 
        ? (adSchedule.clickCount / adSchedule.viewCount) * 100 
        : 0,
      cost: Number(adSchedule.transaction.amount),
      status: adSchedule.status,
      scheduledStart: adSchedule.scheduledStart,
      scheduledEnd: adSchedule.scheduledEnd,
    };
  }

  /**
   * Process scheduled ads (cron job)
   * Activates ads that should start and expires ads that should end
   */
  async processScheduledAds(): Promise<void> {
    const now = new Date();
    const toActivate = await this.prisma.adSchedule.findMany({
      where: {
        status: AdStatus.SCHEDULED,
        scheduledStart: { lte: now },
      },
      include: { user: { select: { id: true, email: true, profile: { select: { displayName: true } } } } },
    });
    
    const expiring = await this.prisma.adSchedule.findMany({
      where: {
        status: AdStatus.ACTIVE,
        scheduledEnd: { lte: now },
      },
      include: { user: { select: { id: true, email: true, profile: { select: { displayName: true } } } }, transaction: true },
    });

    // Activate scheduled ads
    await this.prisma.adSchedule.updateMany({
      where: {
        status: AdStatus.SCHEDULED,
        scheduledStart: { lte: now },
      },
      data: {
        status: AdStatus.ACTIVE,
      },
    });

    // Expire active ads
    await this.prisma.adSchedule.updateMany({
      where: {
        status: AdStatus.ACTIVE,
        scheduledEnd: { lte: now },
      },
      data: {
        status: AdStatus.EXPIRED,
      },
    });

    for (const ad of expiring) {
      try {
        if (ad.user?.email) {
          await this.email.dispatch({
            eventName: EmailEventName.AdEnded,
            recipient: { email: ad.user.email, userId: ad.user.id },
            vars: {
              actorName: ad.user.profile?.displayName || ad.user.email,
              adTitle: ad.title,
              spent: Number((ad.transaction as any)?.amount ?? 0),
              adUrl: this.emailLinkRouter.getWebLink(`/ads/${ad.id}`),
            },
          });
        }
      } catch {
        // Non-blocking
      }
    }

    for (const ad of toActivate) {
      try {
        if (ad.user?.email) {
          await this.email.dispatch({
            eventName: EmailEventName.AdStarted,
            recipient: { email: ad.user.email, userId: ad.user.id },
            vars: {
              actorName: ad.user.profile?.displayName || ad.user.email,
              adTitle: ad.title,
              startDate: ad.scheduledStart.toISOString(),
              adUrl: this.emailLinkRouter.getWebLink(`/ads/${ad.id}`),
            },
          });
        }
      } catch {
        // Non-blocking
      }
    }

    this.logger.log(`Processed scheduled ads`);
  }

  /** Image ads use mediaKeys (max 5); video ads use a single videoKey — never both. */
  normalizeAdMedia(data: {
    mediaType?: AdMediaType;
    mediaKeys?: string[];
    videoKey?: string;
  }): { mediaType: AdMediaType; mediaKeys: string[]; videoKey: string | null } {
    const mediaType = data.mediaType ?? AdMediaType.IMAGE;
    const videoKey = data.videoKey?.trim() || null;
    const mediaKeys = (data.mediaKeys ?? []).map((k) => k.trim()).filter(Boolean);

    if (mediaType === AdMediaType.VIDEO) {
      if (!videoKey) {
        throw new BadRequestException('A video file is required for video ads');
      }
      if (mediaKeys.length > 0) {
        throw new BadRequestException('Video ads cannot include images');
      }
      return { mediaType: AdMediaType.VIDEO, mediaKeys: [], videoKey };
    }

    if (videoKey) {
      throw new BadRequestException('Image ads cannot include a video');
    }
    if (mediaKeys.length > 5) {
      throw new BadRequestException('Maximum 5 images allowed per ad');
    }
    return { mediaType: AdMediaType.IMAGE, mediaKeys, videoKey: null };
  }

  private dailyRateForPlacement(
    key: string,
    pricing: {
      tradeBycPerDay: number;
      giftBycPerDay: number;
      donationBycPerDay: number;
      normalBycPerDay: number;
    },
  ): number {
    const k = key.toLowerCase();
    if (k.includes('trade')) return pricing.tradeBycPerDay;
    if (k.includes('gift')) return pricing.giftBycPerDay;
    if (k.includes('donation') || k.includes('campaign')) {
      return pricing.donationBycPerDay;
    }
    return pricing.normalBycPerDay;
  }
}

