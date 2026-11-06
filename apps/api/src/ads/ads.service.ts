import { Injectable } from '@nestjs/common';
import { AdStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../common/prisma.service';
import { StorageService } from '../storage/storage.service';
import { resolveAdThumbnailUrl } from './ad-media.util';
import { placementMatchFilter } from './ad-placement.util';

export type PlacementAdDto = {
  id: string;
  kind: 'schedule' | 'boost';
  title: string;
  description: string | null;
  mediaType: 'IMAGE' | 'VIDEO';
  mediaKeys: string[];
  videoKey: string | null;
  /** Resolved URL for feed cards (works without extra client round-trips). */
  thumbnailUrl: string | null;
  placementKey: string | null;
  placementKeys: string[];
  /** External link for scheduled ads; boosts use in-app listing navigation. */
  destinationUrl: string | null;
  referenceType?: string | null;
  referenceId?: string | null;
  scheduledStart?: Date | null;
  scheduledEnd?: Date | null;
};

@Injectable()
export class AdsService {
  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
  ) {}

  private async enrichPlacementAd(
    ad: Omit<PlacementAdDto, 'thumbnailUrl'>,
  ): Promise<PlacementAdDto> {
    const thumbnailUrl = await resolveAdThumbnailUrl(
      this.storage,
      ad.mediaType,
      ad.mediaKeys,
      ad.videoKey,
    );
    return { ...ad, thumbnailUrl };
  }

  async listActiveAdsByPlacement(placementKey: string): Promise<PlacementAdDto[]> {
    const now = new Date();

    // Promote due schedules so feeds stay in sync even between cron ticks.
    await this.prisma.adSchedule.updateMany({
      where: {
        status: AdStatus.SCHEDULED,
        scheduledStart: { lte: now },
      },
      data: { status: AdStatus.ACTIVE },
    });

    const where = {
      status: { in: [AdStatus.ACTIVE, AdStatus.SCHEDULED] },
      scheduledStart: { lte: now },
      OR: [{ scheduledEnd: null }, { scheduledEnd: { gte: now } }],
      AND: [placementMatchFilter(placementKey)],
      destinationUrl: { not: null },
    } as Prisma.AdScheduleWhereInput;
    const select = {
      id: true,
      title: true,
      description: true,
      mediaType: true,
      mediaKeys: true,
      videoKey: true,
      placementKey: true,
      placementKeys: true,
      destinationUrl: true,
      scheduledStart: true,
      scheduledEnd: true,
    } as Prisma.AdScheduleSelect;

    const [schedules, boosts] = await Promise.all([
      this.prisma.adSchedule.findMany({
        where,
        orderBy: { scheduledStart: 'desc' },
        select,
      }),
      this.listActiveBoostAds(placementKey, now),
    ]);

    const scheduleDtos: PlacementAdDto[] = await Promise.all(
      schedules
        .filter((s) => s.destinationUrl)
        .map((s) =>
          this.enrichPlacementAd({
            id: s.id,
            kind: 'schedule' as const,
            title: s.title,
            description: s.description,
            mediaType: s.mediaType,
            mediaKeys: s.mediaKeys ?? [],
            videoKey: s.videoKey,
            placementKey: s.placementKey,
            placementKeys: s.placementKeys ?? [],
            destinationUrl: s.destinationUrl!,
            scheduledStart: s.scheduledStart,
            scheduledEnd: s.scheduledEnd,
          }),
        ),
    );

    const enrichedBoosts = await Promise.all(
      boosts.map((b) => this.enrichPlacementAd(b)),
    );

    return [...enrichedBoosts, ...scheduleDtos];
  }

  private async listActiveBoostAds(
    placementKey: string,
    now: Date,
  ): Promise<PlacementAdDto[]> {
    const boosts = await this.prisma.boostPurchase.findMany({
      where: {
        placementKey,
        status: 'ACTIVE',
        endsAt: { gte: now },
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });

    const results: PlacementAdDto[] = [];
    for (const boost of boosts) {
      if (!this.isBoostActiveNow(boost, now)) continue;
      const listing = await this.resolveBoostListing(
        boost.referenceType,
        boost.referenceId,
      );
      if (!listing) continue;
      results.push({
        id: boost.id,
        kind: 'boost',
        title: listing.title,
        description: listing.description,
        mediaType: 'IMAGE',
        mediaKeys: listing.mediaKeys ?? [],
        videoKey: null,
        thumbnailUrl: null,
        placementKey: boost.placementKey,
        placementKeys: [boost.placementKey],
        destinationUrl: null,
        referenceType: boost.referenceType,
        referenceId: boost.referenceId,
        scheduledStart: boost.startsAt,
        scheduledEnd: boost.endsAt,
      });
    }
    return results;
  }

  private isBoostActiveNow(
    boost: { boostDates?: string[]; endsAt: Date },
    at: Date,
  ): boolean {
    if (at > boost.endsAt) return false;
    const dates = boost.boostDates;
    if (dates && dates.length > 0) {
      return dates.includes(at.toISOString().slice(0, 10));
    }
    return boost.endsAt >= at;
  }

  private async resolveBoostListing(
    referenceType: string,
    referenceId: string,
  ): Promise<{ title: string; description: string | null; mediaKeys: string[] } | null> {
    const type = referenceType.toLowerCase();
    if (type === 'trade') {
      const trade = await this.prisma.trade.findUnique({
        where: { id: referenceId },
        select: { title: true, description: true, mediaKeys: true },
      });
      return trade;
    }
    if (type === 'gift') {
      const gift = await this.prisma.gift.findUnique({
        where: { id: referenceId },
        select: { title: true, description: true, mediaKeys: true },
      });
      return gift;
    }
    if (type === 'campaign' || type === 'donation') {
      const campaign = await this.prisma.campaign.findUnique({
        where: { id: referenceId },
        select: { title: true, description: true, mediaKeys: true },
      });
      return campaign;
    }
    return null;
  }

  async trackBoostView(boostId: string): Promise<void> {
    await this.prisma.boostPurchase.update({
      where: { id: boostId },
      data: { viewCount: { increment: 1 } },
    });
  }

  async trackBoostClick(boostId: string): Promise<void> {
    await this.prisma.boostPurchase.update({
      where: { id: boostId },
      data: { clickCount: { increment: 1 } },
    });
  }
}
