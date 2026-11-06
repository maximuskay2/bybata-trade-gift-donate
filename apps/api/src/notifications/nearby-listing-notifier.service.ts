import { Injectable, Logger } from '@nestjs/common';
import { NotificationPriority, NotificationType } from '@prisma/client';
import { PrismaService } from '../common/prisma.service';
import {
  extractListingCoords,
  haversineMeters,
} from '../common/listing-location.util';
import { NotificationsService } from './notifications.service';

export type NearbyListingKind = 'trade' | 'gift' | 'campaign';

const RADIUS_METERS = 100_000; // 100 km
/** ~1.0° latitude ≈ 111 km — coarse prefilter before haversine. */
const BBOX_DEG = 1.05;
const MAX_RECIPIENTS = 200;
const CREATE_BATCH = 40;

@Injectable()
export class NearbyListingNotifierService {
  private readonly logger = new Logger(NearbyListingNotifierService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * Fan out a discovery alert to users within 100 km of the listing.
   * Fire-and-forget safe — callers should not await for UX-critical paths
   * unless they want confirmation; failures are logged only.
   */
  async notifyNearbyListing(params: {
    kind: NearbyListingKind;
    listingId: string;
    creatorId: string;
    title: string;
    locationText?: string | null;
    metadata?: unknown;
    skip?: boolean;
  }): Promise<{ notified: number }> {
    if (params.skip) return { notified: 0 };

    try {
      const coords = extractListingCoords(params.metadata);
      if (!coords) {
        this.logger.debug(
          `Nearby skip ${params.kind}/${params.listingId}: no listing coords`,
        );
        return { notified: 0 };
      }

      const recipients = await this.findNearbyUserIds(
        coords.lat,
        coords.lng,
        params.creatorId,
      );
      if (recipients.length === 0) {
        this.logger.debug(
          `Nearby skip ${params.kind}/${params.listingId}: no recipients in range`,
        );
        return { notified: 0 };
      }

      const copy = this.buildCopy(params.kind, params.title, params.locationText);
      const actionUrl = this.actionUrl(params.kind, params.listingId);
      const sourceType = `nearby_${params.kind}`;

      // createNotification persists + FCM push + realtime WS for each recipient.
      let created = 0;
      for (let i = 0; i < recipients.length; i += CREATE_BATCH) {
        const batch = recipients.slice(i, i + CREATE_BATCH);
        const results = await Promise.allSettled(
          batch.map((userId) =>
            this.notifications.createNotification({
              userId,
              type: NotificationType.NEARBY_LISTING,
              title: copy.title,
              message: copy.message,
              priority: NotificationPriority.NORMAL,
              sourceId: params.listingId,
              sourceType,
              actionUrl,
              data: {
                kind: params.kind,
                listingId: params.listingId,
                listingType: params.kind,
                ...(params.kind === 'trade' ? { tradeId: params.listingId } : {}),
                ...(params.kind === 'gift' ? { giftId: params.listingId } : {}),
                ...(params.kind === 'campaign'
                  ? { campaignId: params.listingId }
                  : {}),
              },
            }),
          ),
        );
        created += results.filter((r) => r.status === 'fulfilled').length;
      }

      this.logger.log(
        `Nearby ${params.kind}/${params.listingId}: ${created}/${recipients.length} notified`,
      );
      return { notified: created };
    } catch (error) {
      this.logger.error(
        `Nearby notify failed for ${params.kind}/${params.listingId}`,
        error as Error,
      );
      return { notified: 0 };
    }
  }

  private buildCopy(
    kind: NearbyListingKind,
    title: string,
    locationText?: string | null,
  ): { title: string; message: string } {
    const place = locationText?.trim();
    const near = place ? ` near ${place}` : ' near you';
    switch (kind) {
      case 'trade':
        return {
          title: 'New trade nearby',
          message: `"${title}" is available${near}. Open it to make an offer.`,
        };
      case 'gift':
        return {
          title: 'New gift nearby',
          message: `"${title}" was just listed${near}. Claim it if you need it.`,
        };
      case 'campaign':
        return {
          title: 'New campaign nearby',
          message: `"${title}" is raising funds${near}. Donate if you can help.`,
        };
    }
  }

  private actionUrl(kind: NearbyListingKind, id: string): string {
    switch (kind) {
      case 'trade':
        return `/trades/${id}`;
      case 'gift':
        return `/gifts/${id}`;
      case 'campaign':
        return `/campaigns/${id}`;
    }
  }

  private async findNearbyUserIds(
    lat: number,
    lng: number,
    excludeUserId: string,
  ): Promise<string[]> {
    const latMin = lat - BBOX_DEG;
    const latMax = lat + BBOX_DEG;
    // Longitude degrees shrink near poles; use a safe overestimate.
    const lngPad = BBOX_DEG / Math.max(0.2, Math.cos((lat * Math.PI) / 180));
    const lngMin = lng - lngPad;
    const lngMax = lng + lngPad;

    // Prefer users with a recent location who can receive push.
    const candidates = await this.prisma.profile.findMany({
      where: {
        userId: { not: excludeUserId },
        lastLatitude: { gte: latMin, lte: latMax },
        lastLongitude: { gte: lngMin, lte: lngMax },
        user: {
          banned: false,
          OR: [{ bannedUntil: null }, { bannedUntil: { lt: new Date() } }],
          deviceTokens: { some: {} },
        },
      },
      select: {
        userId: true,
        lastLatitude: true,
        lastLongitude: true,
      },
      take: 2000,
    });

    const scored = candidates
      .map((p) => {
        const plat = p.lastLatitude;
        const plng = p.lastLongitude;
        if (plat == null || plng == null) return null;
        const meters = haversineMeters(lat, lng, plat, plng);
        if (meters > RADIUS_METERS) return null;
        return { userId: p.userId, meters };
      })
      .filter((x): x is { userId: string; meters: number } => x != null)
      .sort((a, b) => a.meters - b.meters)
      .slice(0, MAX_RECIPIENTS);

    return scored.map((s) => s.userId);
  }
}
