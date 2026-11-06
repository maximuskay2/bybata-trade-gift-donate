import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { buildProfileSettings, normalizeFiatCurrency, normalizeCountryCode } from '../common/currency.util';
import { PrismaService } from '../common/prisma.service';
import { EmailService } from '../common/email.service';
import { KarmaService } from '../karma/karma.service';
import { KarmaPointsConfigService } from '../karma/karma-points-config.service';
import { NotificationsService } from '../notifications/notifications.service';
import { EmailEventName } from '../email/email-events';
import { TradeStatus, ReportReason, Role, NotificationType, NotificationPriority, TrustLevel, TxStatus } from '@prisma/client';
import { calculateTrustScore } from './trust-score.util';
import { KarmaEventType } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { EmailLinkRouterService } from '../shared/services/email-link-router.service';
import { sanitizeProfileLocation, countryCodeToDisplayName } from '../common/profile-location.util';
import { buildVerificationState } from './verification-state.util';
import { ScaleCacheService } from '../common/scale/scale-cache.service';
import { ScaleCacheKeys, ScaleDefaults } from '../common/scale/scale.constants';

const REPORT_REASON_MAP: Record<string, ReportReason> = {
  SPAM: ReportReason.SPAM,
  HARASSMENT: ReportReason.HARASSMENT,
  INAPPROPRIATE_CONTENT: ReportReason.INAPPROPRIATE_CONTENT,
  SCAM: ReportReason.SCAM,
  SUSPICIOUS_ACTIVITY: ReportReason.SUSPICIOUS_ACTIVITY,
  VIOLENCE: ReportReason.VIOLENCE,
  OTHER: ReportReason.OTHER,
};

@Injectable()
export class UsersService {
  constructor(
    private prisma: PrismaService,
    private email: EmailService,
    private karmaService: KarmaService,
    private karmaPointsConfig: KarmaPointsConfigService,
    private notifications: NotificationsService,
    private emailLinkRouter: EmailLinkRouterService,
    private scaleCache: ScaleCacheService,
  ) {}

  /** Drop cached /me payloads after profile mutations. */
  async invalidateMeCache(userId: string): Promise<void> {
    await this.scaleCache.delMany([
      ScaleCacheKeys.me(userId),
      ScaleCacheKeys.meLight(userId),
    ]);
  }

  /**
   * Minimal profile for login / session restore — one DB round-trip.
   * Avoids stats/karma fan-out that exhausted Postgres under concurrent logins.
   */
  async getMeLight(userId: string) {
    const cacheKey = ScaleCacheKeys.meLight(userId);
    const cached = await this.scaleCache.getJson<any>(cacheKey);
    if (cached) return cached;

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user) throw new NotFoundException();

    const payload = {
      id: user.id,
      email: user.email,
      role: user.role,
      emailVerifiedAt: user.emailVerifiedAt,
      banned: user.banned,
      bannedUntil: user.bannedUntil,
      banNote: user.banNote,
      profile: this.mapProfileForViewer(
        {
          ...user.profile,
          settings: buildProfileSettings(user.profile as any),
        },
        true,
      ),
      _light: true,
    };

    await this.scaleCache.setJson(
      cacheKey,
      payload,
      Number(process.env.ME_LIGHT_CACHE_TTL_S ?? ScaleDefaults.meLightCacheTtlSec),
    );
    return payload;
  }
  private profileUrlForUser(user: {
    profile?: { username?: string | null } | null;
  }): string {
    const username = user.profile?.username;
    if (username) {
      return this.emailLinkRouter.getProfileLink(username);
    }
    return this.emailLinkRouter.getAppOpenLink('/profile');
  }

  /** Fire-and-forget — do not block profile PATCH responses on SMTP. */
  private queueProfileUpdatedEmail(user: {
    id: string;
    email?: string | null;
    profile?: { displayName?: string | null; username?: string | null } | null;
  }): void {
    if (!user.email) return;
    this.email.dispatchInBackground({
      eventName: EmailEventName.ProfileUpdated,
      recipient: { email: user.email, userId: user.id },
      vars: {
        actorName: user.profile?.displayName || user.email,
        updatedAt: new Date().toISOString(),
        profileUrl: this.profileUrlForUser(user),
      },
    });
  }

  /** Get followers and following counts for a user */
  private async getFollowCounts(userId: string): Promise<{ followersCount: number; followingCount: number }> {
    const [followersCount, followingCount] = await Promise.all([
      this.prisma.userFollow.count({ where: { followedId: userId } }),
      this.prisma.userFollow.count({ where: { followerId: userId } }),
    ]);
    return { followersCount, followingCount };
  }

  /** Total BYC donated to campaigns (successful donations only). */
  private async getDonationGivingStats(
    userId: string,
  ): Promise<{ donatedByc: number; donatedKarma: number }> {
    const agg = await this.prisma.donation.aggregate({
      where: { donorId: userId, status: TxStatus.SUCCESS },
      _sum: { amount: true, karmaAwarded: true },
    });
    const amount = agg._sum.amount;
    const donatedByc =
      amount != null ? Math.round(Number(amount)) : 0;
    const donatedKarma = agg._sum.karmaAwarded ?? 0;
    return { donatedByc, donatedKarma };
  }

  /** Compute user stats (rating, completedTrades, totalReviews) for profile display */
  private async getUserStats(userId: string): Promise<{ averageRating: number; completedTrades: number; totalReviews: number }> {
    const [completedTradesCount, profileReviewAgg, giftRatingAgg] = await Promise.all([
      this.prisma.trade.count({ where: { ownerId: userId, status: TradeStatus.CLOSED } }),
      this.prisma.profileReview.aggregate({
        where: { revieweeId: userId },
        _avg: { rating: true },
        _count: { rating: true },
      }),
      this.prisma.giftClaim.aggregate({
        where: { gift: { giverId: userId }, rating: { not: null } },
        _avg: { rating: true },
        _count: { rating: true },
      }),
    ]);
    const prCount = profileReviewAgg._count.rating ?? 0;
    const gcCount = giftRatingAgg._count.rating ?? 0;
    const totalReviews = prCount + gcCount;
    const prAvg = profileReviewAgg._avg.rating != null ? Number(profileReviewAgg._avg.rating) : 0;
    const gcAvg = giftRatingAgg._avg.rating != null ? Number(giftRatingAgg._avg.rating) : 0;
    const averageRating = totalReviews > 0
      ? (prAvg * prCount + gcAvg * gcCount) / totalReviews
      : 0;
    return { averageRating, completedTrades: completedTradesCount, totalReviews };
  }

  /** Composite trust score from ratings, KARMA, verification, and activity. */
  private async getTrustScoreForUser(userId: string) {
    const [stats, karmaAccount, totalGifts, totalDonations, profile] =
      await Promise.all([
        this.getUserStats(userId),
        this.prisma.karmaAccount.findUnique({ where: { userId } }),
        this.prisma.gift.count({ where: { giverId: userId } }),
        this.prisma.donation.count({
          where: { donorId: userId, status: TxStatus.SUCCESS },
        }),
        this.prisma.profile.findUnique({
          where: { userId },
          select: { kycStatus: true },
        }),
      ]);

    return calculateTrustScore({
      averageRating: stats.averageRating,
      totalReviews: stats.totalReviews,
      karmaPoints: karmaAccount?.currentPoints ?? 0,
      trustLevel: karmaAccount?.trustLevel ?? TrustLevel.NEWCOMER,
      isVerified: profile?.kycStatus === 'VERIFIED',
      completedTrades: stats.completedTrades,
      totalGifts,
      totalDonations,
    });
  }

  /**
   * Batch average-rating lookup for feed / listing endpoints.
   *
   * Returns a Map<userId, averageRating> covering exactly the ids passed in.
   * Users who have never received a review/rating get 0. We group by
   * revieweeId / giverId on the aggregate queries so this is O(1) round
   * trips regardless of how many ids are requested, which is what the
   * new 3D Glass ListingCard needs to avoid per-card /users/:id calls.
   */
  async getAverageRatingsBatch(userIds: string[]): Promise<Map<string, number>> {
    const result = new Map<string, number>();
    const unique = Array.from(new Set(userIds.filter((id) => !!id)));
    if (unique.length === 0) return result;
    for (const id of unique) result.set(id, 0);

    const [profileReviewGroups] = await Promise.all([
      this.prisma.profileReview.groupBy({
        by: ['revieweeId'],
        where: { revieweeId: { in: unique } },
        _avg: { rating: true },
        _count: { rating: true },
      }),
    ]);

    // ProfileReview -> revieweeId is a scalar, groupBy works normally.
    const prByUser = new Map<string, { avg: number; count: number }>();
    for (const g of profileReviewGroups) {
      const avg = g._avg.rating != null ? Number(g._avg.rating) : 0;
      const count = g._count.rating ?? 0;
      prByUser.set(g.revieweeId, { avg, count });
    }

    // GiftClaim needs gift.giverId resolution (Prisma groupBy can't hop
    // relations), so we do a targeted scan filtered by the giverIds we
    // actually care about and tally in-memory.
    const gcByUser = new Map<string, { avg: number; count: number }>();
    try {
      const rawRatings = await this.prisma.giftClaim.findMany({
        where: { gift: { giverId: { in: unique } }, rating: { not: null } },
        select: { rating: true, gift: { select: { giverId: true } } },
      });
      const tally = new Map<string, { sum: number; count: number }>();
      for (const r of rawRatings) {
        const uid = r.gift?.giverId;
        const rating = r.rating;
        if (!uid || rating == null) continue;
        const cur = tally.get(uid) ?? { sum: 0, count: 0 };
        cur.sum += Number(rating);
        cur.count += 1;
        tally.set(uid, cur);
      }
      for (const [uid, v] of tally.entries()) {
        gcByUser.set(uid, { avg: v.count > 0 ? v.sum / v.count : 0, count: v.count });
      }
    } catch {
      // Ignore — profile reviews alone still give us a rating signal.
    }

    for (const uid of unique) {
      const pr = prByUser.get(uid) ?? { avg: 0, count: 0 };
      const gc = gcByUser.get(uid) ?? { avg: 0, count: 0 };
      const total = pr.count + gc.count;
      const avg = total > 0 ? (pr.avg * pr.count + gc.avg * gc.count) / total : 0;
      result.set(uid, avg);
    }
    return result;
  }

  private mapProfileForViewer(profile: Record<string, any> | null | undefined, isOwner = false) {
    if (!profile) return profile;
    const showLocation = profile.showLocation !== false;
    const rawLocation = showLocation || isOwner ? profile.location : null;
    const location =
      sanitizeProfileLocation(rawLocation) ??
      (showLocation || isOwner ? countryCodeToDisplayName(profile.countryCode) : null);
    return {
      ...profile,
      location,
    };
  }

  async getMe(userId: string) {
    const cacheKey = ScaleCacheKeys.me(userId);
    const cached = await this.scaleCache.getJson<any>(cacheKey);
    if (cached) return cached;

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user) throw new NotFoundException();

    // Keep enrichment light: avoid nested Promise.all fans that open many
    // connections at once (was exhausting Railway Postgres under load).
    let stats = {
      averageRating: 0,
      completedTrades: 0,
      totalReviews: 0,
    };
    let followCounts = { followersCount: 0, followingCount: 0 };
    let donationGiving = { donatedByc: 0, donatedKarma: 0 };
    let trustScore: ReturnType<typeof calculateTrustScore> = calculateTrustScore({
      averageRating: 0,
      totalReviews: 0,
      karmaPoints: 0,
      trustLevel: TrustLevel.NEWCOMER,
      isVerified: false,
      completedTrades: 0,
      totalGifts: 0,
      totalDonations: 0,
    });
    let karmaAccount: { currentPoints: number; trustLevel: TrustLevel } | null =
      null;
    let verification: any = null;

    try {
      const [s, f, d, k, giftCount, donationCount] = await Promise.all([
        this.getUserStats(userId),
        this.getFollowCounts(userId),
        this.getDonationGivingStats(userId),
        this.prisma.karmaAccount.findUnique({ where: { userId } }),
        this.prisma.gift.count({ where: { giverId: userId } }),
        this.prisma.donation.count({
          where: { donorId: userId, status: TxStatus.SUCCESS },
        }),
      ]);
      stats = s;
      followCounts = f;
      donationGiving = d;
      karmaAccount = k;
      trustScore = calculateTrustScore({
        averageRating: s.averageRating,
        totalReviews: s.totalReviews,
        karmaPoints: k?.currentPoints ?? 0,
        trustLevel: k?.trustLevel ?? TrustLevel.NEWCOMER,
        isVerified: user.profile?.kycStatus === 'VERIFIED',
        completedTrades: s.completedTrades,
        totalGifts: giftCount,
        totalDonations: donationCount,
      });
    } catch (err) {
      // Keep login working; enrichment can catch up on next profile load.
      // eslint-disable-next-line no-console
      console.warn(`[getMe] enrichment failed for ${userId}:`, err);
    }

    try {
      verification = await this.getVerificationStateForUser(userId);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn(`[getMe] verification state failed for ${userId}:`, err);
    }

    // Map profile privacy settings to settings object for frontend
    const profileWithSettings = this.mapProfileForViewer({
      ...user.profile,
      averageRating: stats.averageRating,
      completedTrades: stats.completedTrades,
      totalReviews: stats.totalReviews,
      rating: stats.averageRating, // Alias for user_profile_screen
      followersCount: followCounts.followersCount,
      followingCount: followCounts.followingCount,
      donatedByc: donationGiving.donatedByc,
      donatedKarma: donationGiving.donatedKarma,
      karmaPoints: karmaAccount?.currentPoints ?? 0,
      trustLevel: karmaAccount?.trustLevel ?? TrustLevel.NEWCOMER,
      trustScore: trustScore.score,
      trustScoreNormalized: trustScore.normalized,
      trustScoreDetail: trustScore,
      settings: buildProfileSettings(user.profile as any),
      verification,
    }, true);

    const payload = {
      id: user.id,
      email: user.email,
      role: user.role,
      emailVerifiedAt: user.emailVerifiedAt,
      banned: user.banned,
      bannedUntil: user.bannedUntil,
      banNote: user.banNote,
      profile: profileWithSettings,
    };

    await this.scaleCache.setJson(
      cacheKey,
      payload,
      Number(process.env.ME_CACHE_TTL_S ?? ScaleDefaults.meCacheTtlSec),
    );
    return payload;
  }

  async updateMe(
    userId: string,
    body: {
      displayName?: string;
      username?: string;
      bio?: string;
      phone?: string;
      avatarKey?: string;
      isProfilePublic?: boolean;
      showEmail?: boolean;
      showPhone?: boolean;
      showLocation?: boolean;
      allowDirectMessages?: boolean;
      preferredFiatCurrency?: string;
      countryCode?: string;
      timezone?: string;
      location?: string;
    },
  ) {
    const data: any = {};
    const fiat = normalizeFiatCurrency(body.preferredFiatCurrency);
    const country = normalizeCountryCode(body.countryCode);
    if (
      body.displayName !== undefined ||
      body.username !== undefined ||
      body.bio !== undefined ||
      body.phone !== undefined ||
      body.avatarKey !== undefined ||
      body.isProfilePublic !== undefined ||
      body.showEmail !== undefined ||
      body.showPhone !== undefined ||
      body.showLocation !== undefined ||
      body.allowDirectMessages !== undefined ||
      fiat !== undefined ||
      country !== undefined ||
      body.timezone !== undefined ||
      body.location !== undefined
    ) {
      let normalizedUsername: string | undefined;
      if (body.username !== undefined) {
        normalizedUsername = this.normalizeUsername(body.username);
        this.validateUsername(normalizedUsername);
        const existing = await this.prisma.profile.findFirst({
          where: {
            username: { equals: normalizedUsername, mode: 'insensitive' },
            userId: { not: userId },
          },
          select: { id: true },
        });
        if (existing) throw new BadRequestException('Username already in use');
      }
      data.profile = { update: { 
        ...('displayName' in body ? { displayName: body.displayName } : {}), 
        ...('username' in body ? { username: normalizedUsername } : {}),
        ...('bio' in body ? { bio: body.bio } : {}), 
        ...('phone' in body ? { phone: body.phone } : {}), 
        ...('avatarKey' in body ? { avatarKey: body.avatarKey } : {}),
        ...('isProfilePublic' in body ? { isProfilePublic: body.isProfilePublic } : {}),
        ...('showEmail' in body ? { showEmail: body.showEmail } : {}),
        ...('showPhone' in body ? { showPhone: body.showPhone } : {}),
        ...('showLocation' in body ? { showLocation: body.showLocation } : {}),
        ...('allowDirectMessages' in body ? { allowDirectMessages: body.allowDirectMessages } : {}),
        ...(fiat !== undefined ? { preferredFiatCurrency: fiat } : {}),
        ...(country !== undefined ? { countryCode: country } : {}),
        ...('timezone' in body && body.timezone !== undefined ? { timezone: body.timezone } : {}),
        ...('location' in body && body.location !== undefined
            ? { location: sanitizeProfileLocation(body.location) }
            : {}),
      } };
    }
    const user = await this.prisma.user.update({ where: { id: userId }, data, include: { profile: true } });

    this.queueProfileUpdatedEmail(user);
    await this.invalidateMeCache(userId);
    
    // Map profile privacy settings to settings object for frontend
    const profileWithSettings = {
      ...user.profile,
      settings: buildProfileSettings(user.profile as any),
    };

    return { id: user.id, email: user.email, role: user.role, emailVerifiedAt: user.emailVerifiedAt, profile: profileWithSettings };
  }

  /**
   * Persist last known device coordinates for nearby listing alerts.
   * Coordinates are not exposed on public profiles.
   */
  async updateMyLocation(
    userId: string,
    latitude?: number,
    longitude?: number,
  ) {
    const lat = Number(latitude);
    const lng = Number(longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      throw new BadRequestException('latitude and longitude are required');
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw new BadRequestException('Invalid coordinates');
    }
    // Reject null island noise
    if (lat === 0 && lng === 0) {
      throw new BadRequestException('Invalid coordinates');
    }

    await this.prisma.profile.update({
      where: { userId },
      data: {
        lastLatitude: lat,
        lastLongitude: lng,
        lastLocationAt: new Date(),
      },
    });
    await this.invalidateMeCache(userId);
    return { ok: true };
  }

  /**
   * Aggregate recent user activity across trades, gifts, donations, karma, and wallet.
   */
  async getMyActivity(
    userId: string,
    page: number,
    size: number,
    typeFilter?: string,
  ) {
    const perSource = Math.min(Math.max(size * 2, 40), 80);
    const type = (typeFilter ?? '').trim().toLowerCase();

    const [
      tradesOwned,
      offersMade,
      giftsGiven,
      giftsClaimed,
      donations,
      karmaEvents,
      achievements,
      communities,
    ] = await Promise.all([
      this.prisma.trade.findMany({
        where: { ownerId: userId },
        orderBy: { createdAt: 'desc' },
        take: perSource,
        select: {
          id: true,
          title: true,
          status: true,
          createdAt: true,
          closedAt: true,
        },
      }),
      this.prisma.tradeOffer.findMany({
        where: { bidderId: userId },
        orderBy: { createdAt: 'desc' },
        take: perSource,
        select: {
          id: true,
          status: true,
          createdAt: true,
          trade: { select: { id: true, title: true } },
        },
      }),
      this.prisma.gift.findMany({
        where: { giverId: userId },
        orderBy: { createdAt: 'desc' },
        take: perSource,
        select: { id: true, title: true, status: true, createdAt: true },
      }),
      this.prisma.giftClaim.findMany({
        where: { claimerId: userId },
        orderBy: { createdAt: 'desc' },
        take: perSource,
        select: {
          id: true,
          createdAt: true,
          completedAt: true,
          karmaAwarded: true,
          gift: { select: { id: true, title: true } },
        },
      }),
      this.prisma.donation.findMany({
        where: { donorId: userId },
        orderBy: { createdAt: 'desc' },
        take: perSource,
        select: {
          id: true,
          amount: true,
          status: true,
          karmaAwarded: true,
          createdAt: true,
          campaign: { select: { id: true, title: true } },
        },
      }),
      this.prisma.karmaEvent.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: perSource,
        select: {
          id: true,
          type: true,
          points: true,
          reason: true,
          createdAt: true,
          sourceId: true,
        },
      }),
      this.prisma.userAchievement.findMany({
        where: { userId },
        orderBy: { unlockedAt: 'desc' },
        take: perSource,
        select: {
          id: true,
          unlockedAt: true,
          achievement: {
            select: { id: true, name: true, description: true, pointsReward: true },
          },
        },
      }),
      this.prisma.communityMember.findMany({
        where: { userId },
        orderBy: { joinedAt: 'desc' },
        take: perSource,
        select: {
          id: true,
          joinedAt: true,
          community: { select: { id: true, name: true } },
        },
      }),
    ]);

    type ActivityItem = {
      id: string;
      userId: string;
      type: string;
      status: string;
      title: string;
      description: string;
      metadata: Record<string, unknown>;
      relatedUserId?: string | null;
      relatedItemId?: string | null;
      karmaPoints?: number | null;
      createdAt: Date;
      completedAt?: Date | null;
    };

    const items: ActivityItem[] = [];

    for (const t of tradesOwned) {
      const completed = t.status === 'CLOSED';
      items.push({
        id: `trade_${t.id}`,
        userId,
        type: 'trade',
        status: completed ? 'completed' : t.status === 'CANCELLED' ? 'cancelled' : 'pending',
        title: completed ? 'Trade completed' : 'Trade listed',
        description: t.title,
        metadata: { tradeId: t.id, status: t.status },
        relatedItemId: t.id,
        createdAt: t.createdAt,
        completedAt: t.closedAt,
      });
    }

    for (const o of offersMade) {
      const st = String(o.status).toUpperCase();
      items.push({
        id: `offer_${o.id}`,
        userId,
        type: 'trade',
        status:
          st === 'ACCEPTED' || st === 'FINALIZED' || st === 'ACCEPTED_AWAITING_FINALIZATION'
            ? 'completed'
            : st === 'REJECTED' || st === 'WITHDRAWN'
              ? 'cancelled'
              : 'pending',
        title: 'Trade offer',
        description: o.trade?.title
          ? `Offer on "${o.trade.title}"`
          : 'You made a trade offer',
        metadata: { offerId: o.id, tradeId: o.trade?.id, status: o.status },
        relatedItemId: o.trade?.id ?? o.id,
        createdAt: o.createdAt,
        completedAt: null,
      });
    }

    for (const g of giftsGiven) {
      const st = String(g.status).toUpperCase();
      items.push({
        id: `gift_given_${g.id}`,
        userId,
        type: 'gift',
        status: st === 'CLAIMED' || st === 'EXPIRED' ? 'completed' : st === 'CANCELLED' ? 'cancelled' : 'pending',
        title: 'Gift listed',
        description: g.title,
        metadata: { giftId: g.id, status: g.status },
        relatedItemId: g.id,
        createdAt: g.createdAt,
        completedAt: null,
      });
    }

    for (const c of giftsClaimed) {
      items.push({
        id: `gift_claim_${c.id}`,
        userId,
        type: 'gift',
        status: 'completed',
        title: 'Gift claimed',
        description: c.gift?.title ? `Claimed "${c.gift.title}"` : 'You claimed a gift',
        metadata: { giftId: c.gift?.id, claimId: c.id },
        relatedItemId: c.gift?.id ?? c.id,
        karmaPoints: c.karmaAwarded ?? null,
        createdAt: c.createdAt,
        completedAt: c.completedAt,
      });
    }

    for (const d of donations) {
      const amount = d.amount?.toString?.() ?? String(d.amount);
      const ok = String(d.status).toUpperCase() === 'SUCCESS';
      items.push({
        id: `donation_${d.id}`,
        userId,
        type: 'donation',
        status: ok ? 'completed' : String(d.status).toUpperCase() === 'FAILED' ? 'failed' : 'pending',
        title: 'Donation made',
        description: d.campaign?.title
          ? `Donated ${amount} BYC to "${d.campaign.title}"`
          : `Donated ${amount} BYC`,
        metadata: { donationId: d.id, campaignId: d.campaign?.id, amount },
        relatedItemId: d.campaign?.id ?? d.id,
        karmaPoints: d.karmaAwarded ?? null,
        createdAt: d.createdAt,
        completedAt: ok ? d.createdAt : null,
      });
    }

    for (const k of karmaEvents) {
      const isAchievement = String(k.type).includes('ACHIEVEMENT');
      items.push({
        id: `karma_${k.id}`,
        userId,
        type: isAchievement ? 'achievement' : 'karma',
        status: 'completed',
        title: isAchievement ? 'Achievement progress' : 'Karma earned',
        description: k.reason || `${k.points} karma (${k.type})`,
        metadata: { karmaEventId: k.id, eventType: k.type },
        relatedItemId: k.sourceId,
        karmaPoints: k.points,
        createdAt: k.createdAt,
        completedAt: k.createdAt,
      });
    }

    for (const a of achievements) {
      items.push({
        id: `achievement_${a.id}`,
        userId,
        type: 'achievement',
        status: 'completed',
        title: 'Achievement unlocked',
        description: a.achievement?.name || 'New achievement',
        metadata: { achievementId: a.achievement?.id },
        relatedItemId: a.achievement?.id,
        karmaPoints: a.achievement?.pointsReward ?? null,
        createdAt: a.unlockedAt ?? new Date(),
        completedAt: a.unlockedAt,
      });
    }

    for (const m of communities) {
      items.push({
        id: `community_${m.id}`,
        userId,
        type: 'community',
        status: 'completed',
        title: 'Joined community',
        description: m.community?.name
          ? `Joined ${m.community.name}`
          : 'Joined a community',
        metadata: { communityId: m.community?.id },
        relatedItemId: m.community?.id,
        createdAt: m.joinedAt,
        completedAt: m.joinedAt,
      });
    }

    let filtered = items;
    if (type) {
      filtered = items.filter((i) => i.type === type);
    }

    filtered.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
    const total = filtered.length;
    const pages = Math.max(1, Math.ceil(total / size));
    const start = (page - 1) * size;
    const pageItems = filtered.slice(start, start + size).map((i) => ({
      ...i,
      createdAt: i.createdAt.toISOString(),
      completedAt: i.completedAt ? i.completedAt.toISOString() : null,
    }));

    return {
      items: pageItems,
      pagination: { page, size, total, pages },
    };
  }

  async getUserById(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    const [stats, followCounts, donationGiving, trustScore, karmaAccount] = await Promise.all([
      this.getUserStats(userId),
      this.getFollowCounts(userId),
      this.getDonationGivingStats(userId),
      this.getTrustScoreForUser(userId),
      this.prisma.karmaAccount.findUnique({ where: { userId } }),
    ]);
    // Map profile privacy settings to settings object for frontend
    const profileWithSettings = this.mapProfileForViewer({
      ...user.profile,
      averageRating: stats.averageRating,
      completedTrades: stats.completedTrades,
      totalReviews: stats.totalReviews,
      rating: stats.averageRating, // Alias for user_profile_screen
      followersCount: followCounts.followersCount,
      followingCount: followCounts.followingCount,
      donatedByc: donationGiving.donatedByc,
      donatedKarma: donationGiving.donatedKarma,
      karmaPoints: karmaAccount?.currentPoints ?? 0,
      trustLevel: karmaAccount?.trustLevel ?? TrustLevel.NEWCOMER,
      trustScore: trustScore.score,
      trustScoreNormalized: trustScore.normalized,
      trustScoreDetail: trustScore,
      settings: buildProfileSettings(user.profile as any),
    });

    return { id: user.id, email: user.email, role: user.role, profile: profileWithSettings };
  }

  async searchUsers(q: string, page: number, size: number) {
    const where: any = {};
    if (q && q.trim().length > 0) {
      where.OR = [
        { email: { contains: q, mode: 'insensitive' } },
        { profile: { displayName: { contains: q, mode: 'insensitive' } } },
        { profile: { username: { contains: q, mode: 'insensitive' } } },
      ];
    }
    const [total, items] = await this.prisma.$transaction([
      this.prisma.user.count({ where }),
      this.prisma.user.findMany({
        where,
        include: { profile: true },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
      }),
    ]);
    return {
      items: items.map((u) => ({ id: u.id, email: u.email, displayName: u.profile?.displayName, username: u.profile?.username })),
      page,
      size,
      total,
    };
  }

  async isUsernameAvailable(username: string) {
    const normalized = this.normalizeUsername(username);
    this.validateUsername(normalized);
    const existing = await this.prisma.profile.findFirst({
      where: { username: { equals: normalized, mode: 'insensitive' } },
      select: { id: true },
    });
    return { available: !existing, username: normalized };
  }

  async getUserByUsername(username: string) {
    const normalized = this.normalizeUsername(username);
    const user = await this.prisma.user.findFirst({
      where: { profile: { username: { equals: normalized, mode: 'insensitive' } } },
      include: { profile: true },
    });
    if (!user) throw new NotFoundException('User not found');
    return { id: user.id, email: user.email, displayName: user.profile?.displayName, username: user.profile?.username };
  }

  private normalizeUsername(input: string) {
    return input.trim().replace(/^@/, '').toLowerCase();
  }

  private validateUsername(username: string) {
    if (!/^[a-z0-9_]{3,20}$/.test(username)) {
      throw new BadRequestException(
        'Username must be 3-20 characters and contain only letters, numbers, or underscores',
      );
    }
  }

  private async comparePassword(plain: string, hash: string) {
    return bcrypt.compare(plain, hash);
  }

  private async hashPassword(password: string) {
    return bcrypt.hash(password, 10);
  }

  async changePassword(userId: string, currentPassword: string, newPassword: string) {
    // Get user with password hash
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, passwordHash: true }
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Verify current password
    const isValid = await this.comparePassword(currentPassword, user.passwordHash);
    if (!isValid) {
      throw new BadRequestException('Current password is incorrect');
    }

    // Hash new password
    const newHash = await this.hashPassword(newPassword);

    // Update password
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newHash }
    });

    return { success: true };
  }

  async deleteAccount(userId: string) {
    // Check if user exists
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const supportEmail = process.env.SUPPORT_EMAIL || 'support@bybata.com';
    const displayName = user.profile?.displayName || user.email || 'there';
    const nowIso = new Date().toISOString();

    try {
      if (user.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.AuthAccountDeleteRequest,
          recipient: { email: user.email, userId },
          vars: {
            displayName,
            requestedAt: nowIso,
            supportEmail,
          },
        });
        this.email.dispatchInBackground({
          eventName: EmailEventName.AuthAccountDeletedConfirm,
          recipient: { email: user.email, userId },
          vars: {
            displayName,
            deletedAt: nowIso,
            supportEmail,
          },
        });
      }
    } catch {
      // Non-blocking
    }

    // Delete user and all related data (cascade delete)
    await this.prisma.user.delete({
      where: { id: userId }
    });

    return { success: true };
  }

  async updatePrivacySettings(userId: string, settings: { isProfilePublic?: boolean; showEmail?: boolean; showPhone?: boolean; showLocation?: boolean; allowDirectMessages?: boolean }) {
    const data: any = {};
    if (settings.isProfilePublic !== undefined || settings.showEmail !== undefined || settings.showPhone !== undefined || settings.showLocation !== undefined || settings.allowDirectMessages !== undefined) {
      data.profile = { update: { 
        ...('isProfilePublic' in settings ? { isProfilePublic: settings.isProfilePublic } : {}),
        ...('showEmail' in settings ? { showEmail: settings.showEmail } : {}),
        ...('showPhone' in settings ? { showPhone: settings.showPhone } : {}),
        ...('showLocation' in settings ? { showLocation: settings.showLocation } : {}),
        ...('allowDirectMessages' in settings ? { allowDirectMessages: settings.allowDirectMessages } : {})
      } };
    }
    
    const user = await this.prisma.user.update({ where: { id: userId }, data, include: { profile: true } });

    this.queueProfileUpdatedEmail(user);
    
    // Map profile privacy settings to settings object for frontend
    const profileWithSettings = {
      ...user.profile,
      settings: buildProfileSettings(user.profile as any),
    };
    
    return { id: user.id, email: user.email, role: user.role, profile: profileWithSettings };
  }

  async getVerificationStateForUser(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user?.profile) {
      return buildVerificationState({ emailVerifiedAt: null }, {}, []);
    }
    const documents = await this.prisma.verificationDocument.findMany({
      where: { userId },
      orderBy: { uploadedAt: 'desc' },
    });
    const latestByType = new Map<string, (typeof documents)[number]>();
    for (const doc of documents) {
      if (!latestByType.has(doc.type)) latestByType.set(doc.type, doc);
    }
    return buildVerificationState(
      user,
      user.profile,
      Array.from(latestByType.values()),
    );
  }

  async registerVerificationDocument(
    userId: string,
    type: string,
    documentKey: string,
    fileName?: string,
  ) {
    const existing = await this.prisma.verificationDocument.findFirst({
      where: { userId, type },
      orderBy: { createdAt: 'desc' },
    });
    if (existing && ['PENDING', 'DRAFT'].includes(existing.status)) {
      return this.prisma.verificationDocument.update({
        where: { id: existing.id },
        data: {
          documentKey,
          fileName: fileName ?? existing.fileName,
          status: 'PENDING',
        },
      });
    }
    return this.prisma.verificationDocument.create({
      data: {
        userId,
        type,
        documentKey,
        fileName: fileName ?? `${type}_document_${Date.now()}`,
        status: 'PENDING',
      },
    });
  }

  async submitVerification(userId: string, documents: Record<string, string>) {
    for (const [type, documentKey] of Object.entries(documents)) {
      await this.registerVerificationDocument(userId, type, documentKey);
    }

    const user = await this.prisma.user.update({
      where: { id: userId },
      data: {
        profile: {
          update: {
            kycStatus: 'PENDING',
          },
        },
      },
      include: { profile: true },
    });

    try {
      if (user.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.VerificationSubmitted,
          recipient: { email: user.email, userId },
          vars: {
            actorName: user.profile?.displayName || user.email,
            submittedAt: new Date().toISOString(),
          },
        });
      }
    } catch {
      // Non-blocking
    }

    await this.invalidateMeCache(userId);

    // Map profile privacy settings to settings object for frontend
    const profileWithSettings = {
      ...user.profile,
      settings: buildProfileSettings(user.profile as any),
      verification: await this.getVerificationStateForUser(userId),
    };

    return { id: user.id, email: user.email, role: user.role, profile: profileWithSettings };
  }

  async getVerificationDocuments(userId: string) {
    return this.prisma.verificationDocument.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getVerificationDocument(userId: string, documentId: string) {
    return this.prisma.verificationDocument.findUnique({
      where: { id: documentId, userId },
    });
  }

  // Get active sessions for a user
  async getActiveSessions(userId: string) {
    const sessions = await this.prisma.session.findMany({
      where: {
        userId,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    return sessions.map((s) => ({
      id: s.id,
      createdAt: s.createdAt,
      expiresAt: s.expiresAt,
      isActive: s.expiresAt > new Date(),
      userAgent: (s as any).userAgent || null,
      ipAddress: (s as any).ipAddress || null,
    }));
  }

  // Revoke a specific session
  async revokeSession(userId: string, sessionId: string) {
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
    });

    if (!session || session.userId !== userId) {
      throw new NotFoundException('Session not found');
    }

    await this.prisma.session.delete({
      where: { id: sessionId },
    });

    return { success: true };
  }

  // Revoke all sessions except current
  async revokeAllOtherSessions(userId: string, currentSessionId: string) {
    await this.prisma.session.deleteMany({
      where: {
        userId,
        id: { not: currentSessionId },
      },
    });

    return { success: true };
  }

  // Block a user
  async blockUser(blockerId: string, blockedId: string, reason?: string) {
    if (blockerId === blockedId) {
      throw new BadRequestException('Cannot block yourself');
    }

    // Check if already blocked
    const existing = await this.prisma.userBlock.findUnique({
      where: {
        blockerId_blockedId: {
          blockerId,
          blockedId,
        },
      },
    });

    if (existing) {
      return { success: true, message: 'User already blocked' };
    }

    await this.prisma.userBlock.create({
      data: {
        blockerId,
        blockedId,
        reason,
      },
    });

    return { success: true };
  }

  // Unblock a user
  async unblockUser(blockerId: string, blockedId: string) {
    await this.prisma.userBlock.deleteMany({
      where: {
        blockerId,
        blockedId,
      },
    });

    return { success: true };
  }

  // Get blocked users list
  async getBlockedUsers(userId: string) {
    const blocks = await this.prisma.userBlock.findMany({
      where: { blockerId: userId },
      include: {
        blocked: {
          include: { profile: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return blocks.map((b) => ({
      id: b.id,
      blockedUser: {
        id: b.blocked.id,
        email: b.blocked.email,
        displayName: b.blocked.profile?.displayName,
        avatarKey: b.blocked.profile?.avatarKey,
      },
      reason: b.reason,
      blockedAt: b.createdAt,
    }));
  }

  // Check if user is blocked
  async isUserBlocked(blockerId: string, blockedId: string): Promise<boolean> {
    const block = await this.prisma.userBlock.findUnique({
      where: {
        blockerId_blockedId: {
          blockerId,
          blockedId,
        },
      },
    });

    return !!block;
  }

  // --- Follow / Followers ---

  async isFollowing(followerId: string, followedId: string): Promise<boolean> {
    const follow = await this.prisma.userFollow.findUnique({
      where: {
        followerId_followedId: { followerId, followedId },
      },
    });
    return !!follow;
  }

  async follow(followerId: string, followedId: string) {
    if (followerId === followedId) {
      throw new BadRequestException('Cannot follow yourself');
    }
    const target = await this.prisma.user.findUnique({ where: { id: followedId } });
    if (!target) throw new NotFoundException('User not found');
    const existing = await this.prisma.userFollow.findUnique({
      where: { followerId_followedId: { followerId, followedId } },
    });
    if (existing) return { success: true, isFollowing: true };
    await this.prisma.userFollow.create({
      data: { followerId, followedId },
    });
    return { success: true, isFollowing: true };
  }

  async unfollow(followerId: string, followedId: string) {
    await this.prisma.userFollow.deleteMany({
      where: { followerId, followedId },
    });
    return { success: true, isFollowing: false };
  }

  async getFollowers(userId: string, page: number, size: number) {
    const [total, items] = await this.prisma.$transaction([
      this.prisma.userFollow.count({ where: { followedId: userId } }),
      this.prisma.userFollow.findMany({
        where: { followedId: userId },
        include: {
          follower: { include: { profile: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
      }),
    ]);
    return {
      items: items.map((f) => ({
        id: f.follower.id,
        displayName: f.follower.profile?.displayName ?? f.follower.email,
        username: f.follower.profile?.username,
        avatarKey: f.follower.profile?.avatarKey,
        followedAt: f.createdAt,
      })),
      page,
      size,
      total,
    };
  }

  async getFollowing(userId: string, page: number, size: number) {
    const [total, items] = await this.prisma.$transaction([
      this.prisma.userFollow.count({ where: { followerId: userId } }),
      this.prisma.userFollow.findMany({
        where: { followerId: userId },
        include: {
          followed: { include: { profile: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
      }),
    ]);
    return {
      items: items.map((f) => ({
        id: f.followed.id,
        displayName: f.followed.profile?.displayName ?? f.followed.email,
        username: f.followed.profile?.username,
        avatarKey: f.followed.profile?.avatarKey,
        followedAt: f.createdAt,
      })),
      page,
      size,
      total,
    };
  }

  async getProfileReviews(userId: string, page: number, size: number) {
    const [profileReviews, giftClaims] = await Promise.all([
      this.prisma.profileReview.findMany({
        where: { revieweeId: userId },
        include: { reviewer: { include: { profile: true } } },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.giftClaim.findMany({
        where: { gift: { giverId: userId }, rating: { not: null } },
        include: { claimer: { include: { profile: true } } },
        orderBy: { claimedAt: 'desc' },
      }),
    ]);

    const prItems = profileReviews.map((r) => ({
      reviewer: r.reviewer.profile?.displayName ?? r.reviewer.email,
      reviewerId: r.reviewerId,
      avatarKey: r.reviewer.profile?.avatarKey,
      rating: r.rating,
      comment: r.comment,
      sourceType: r.sourceType,
      createdAt: r.createdAt,
    }));

    const gcItems = giftClaims.map((c) => ({
      reviewer: c.claimer.profile?.displayName ?? c.claimer.email,
      reviewerId: c.claimerId,
      avatarKey: c.claimer.profile?.avatarKey,
      rating: c.rating ?? 0,
      comment: c.reviewComment,
      sourceType: 'GIFT',
      createdAt: c.claimedAt,
    }));

    const allItems = [...prItems, ...gcItems]
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    const total = allItems.length;
    const items = allItems.slice((page - 1) * size, page * size);

    return { items, page, size, total };
  }

  async likeProfile(likerId: string, likedId: string) {
    if (likerId === likedId) throw new BadRequestException('Cannot like your own profile');
    const target = await this.prisma.user.findUnique({ where: { id: likedId } });
    if (!target) throw new NotFoundException('User not found');
    const existing = await this.prisma.profileLike.findUnique({
      where: { likedId_likerId: { likedId, likerId } },
    });
    if (existing) return { success: true, isLiked: true };
    await this.prisma.profileLike.create({ data: { likedId, likerId } });
    const profileLikePoints = (await this.karmaPointsConfig.getConfig()).profileLike;
    if (profileLikePoints > 0) {
      await this.karmaService.awardKarma(
        likedId,
        KarmaEventType.PROFILE_LIKED,
        profileLikePoints,
        'Profile received a like',
        { likerId },
        likerId,
        'profile_like',
      );
    }
    return { success: true, isLiked: true };
  }

  async unlikeProfile(likerId: string, likedId: string) {
    await this.prisma.profileLike.deleteMany({ where: { likedId, likerId } });
    return { success: true, isLiked: false };
  }

  async isProfileLiked(likerId: string, likedId: string) {
    const like = await this.prisma.profileLike.findUnique({
      where: { likedId_likerId: { likedId, likerId } },
    });
    return { isLiked: !!like };
  }

  async reportUser(reporterId: string, reportedUserId: string, reasonStr: string, details?: string) {
    if (reporterId === reportedUserId) throw new BadRequestException('Cannot report yourself');
    const reportedUser = await this.prisma.user.findUnique({ where: { id: reportedUserId }, include: { profile: true } });
    if (!reportedUser) throw new NotFoundException('User not found');
    const reason = REPORT_REASON_MAP[reasonStr?.toUpperCase()] ?? ReportReason.OTHER;
    const report = await this.prisma.userReport.create({
      data: { reporterId, reportedUserId, reason, details: details?.trim() || null },
      include: { reporter: { include: { profile: true } }, reportedUser: { include: { profile: true } } },
    });
    const admins = await this.prisma.user.findMany({ where: { role: Role.ADMIN }, select: { id: true } });
    const reporterName = (report.reporter.profile as any)?.displayName ?? report.reporter.email;
    const reportedName = (report.reportedUser.profile as any)?.displayName ?? report.reportedUser.email;
    for (const admin of admins) {
      try {
        await this.notifications.createNotification({
          userId: admin.id,
          type: NotificationType.SYSTEM_ANNOUNCEMENT,
          title: 'New User Report',
          message: `${reporterName} reported ${reportedName} for ${reason}.`,
          data: { reportId: report.id, reportedUserId, reporterId },
          actionUrl: `/reports?highlight=${report.id}`,
          sourceId: report.id,
          sourceType: 'USER_REPORT',
          priority: NotificationPriority.HIGH,
        });
      } catch (_) {}
    }
    return { ok: true, reportId: report.id, message: 'Report submitted. Our team will review it.' };
  }

  async createAppeal(userId: string, reason: string, reportId?: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    if (!user.banned) throw new BadRequestException('Your account is not suspended or banned. Appeals are only for restricted accounts.');
    const appeal = await this.prisma.userAppeal.create({
      data: { userId, reason: reason.trim(), reportId: reportId || null },
    });
    return { ok: true, appealId: appeal.id, message: 'Appeal submitted. We will review it shortly.' };
  }
}
