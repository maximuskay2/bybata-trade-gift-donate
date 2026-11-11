import { Injectable, ForbiddenException, NotFoundException, BadRequestException, ConflictException, HttpException, HttpStatus, Inject, Logger } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import type { Cache } from 'cache-manager';
import { PrismaService } from '../common/prisma.service';
import { TradeStatus, OfferStatus, MessageType, Prisma, TradeCategory, NotificationType, NotificationPriority, ListingMediaType, KarmaEventType } from '@prisma/client';
import { normalizeListingMedia } from '../common/listing-media.util';
import { enrichListingPayloadForFeed } from '../common/listing-media-url.util';
import { NotificationsService } from '../notifications/notifications.service';
import { NearbyListingNotifierService } from '../notifications/nearby-listing-notifier.service';
import { EmailService } from '../common/email.service';
import { EmailLinkRouterService } from '../shared/services/email-link-router.service';
import { EmailEventName } from '../email/email-events';
import { MediaService } from '../storage/media.service';
import type { MediaDomain } from '../storage/media.service';
import { KarmaService } from '../karma/karma.service';
import { KarmaPointsConfigService } from '../karma/karma-points-config.service';
import { TradeTopUpService } from '../trade-topup/trade-topup.service';
import {
  applyListingGeoFilter,
  buildListingMetadataWithCoords,
  hasListingGeoFilter,
  ListingGeoParams,
  paginateListingItems,
  requireListingLocation,
} from '../common/listing-location.util';
@Injectable()
export class TradesService {
  private readonly logger = new Logger(TradesService.name);

  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private nearbyNotifier: NearbyListingNotifierService,
    private email: EmailService,
    private emailLinkRouter: EmailLinkRouterService,
    private media: MediaService,
    private karmaService: KarmaService,
    private karmaPointsConfig: KarmaPointsConfigService,
    private topUps: TradeTopUpService,
    @Inject(CACHE_MANAGER) private cache: Cache,
  ) {}

  private static readonly tradeListGenKey = 'trades:list:generation';

  private async tradeListCacheGeneration(): Promise<number> {
    return (await this.cache.get<number>(TradesService.tradeListGenKey)) ?? 0;
  }

  private async bumpTradeListCacheGeneration(): Promise<void> {
    const next = (await this.tradeListCacheGeneration()) + 1;
    await this.cache.set(TradesService.tradeListGenKey, next, 86_400);
  }

  private normalizeCategory(category?: string): TradeCategory | undefined {
    if (!category) return undefined;
    const normalized = category.toString().toUpperCase().replace(/\s+/g, '_');
    switch (normalized) {
      case 'ELECTRONICS':
        return TradeCategory.ELECTRONICS;
      case 'BOOKS':
        return TradeCategory.BOOKS;
      case 'CLOTHING':
        return TradeCategory.CLOTHING;
      case 'FASHION':
        return TradeCategory.FASHION;
      case 'HOME_GARDEN':
      case 'HOMEGARDEN':
        return TradeCategory.HOME_GARDEN;
      case 'SPORTS':
        return TradeCategory.SPORTS;
      case 'TOOLS':
        return TradeCategory.TOOLS;
      case 'AUTOMOTIVE':
        return TradeCategory.AUTOMOTIVE;
      case 'COLLECTIBLES':
        return TradeCategory.COLLECTIBLES;
      case 'OTHERS':
        return TradeCategory.OTHERS;
      default:
        return undefined;
    }
  }

  private categoryFromId(categoryId?: number): TradeCategory | undefined {
    if (categoryId === undefined || Number.isNaN(categoryId)) return undefined;
    const map: TradeCategory[] = [
      TradeCategory.ELECTRONICS,
      TradeCategory.BOOKS,
      TradeCategory.CLOTHING,
      TradeCategory.FASHION,
      TradeCategory.HOME_GARDEN,
      TradeCategory.SPORTS,
      TradeCategory.TOOLS,
      TradeCategory.AUTOMOTIVE,
      TradeCategory.COLLECTIBLES,
      TradeCategory.OTHERS,
    ];
    return map[categoryId];
  }

  /**
   * Who proposed the terms in this offer row (owner counter vs bidder item/cash offer).
   */
  private getOfferAuthorUserId(
    offer: {
      bidderId: string;
      requestedTradeId?: string | null;
      requestedAmount?: { toString(): string } | null;
    },
    tradeOwnerId: string,
  ): string {
    const hasOwnerCounterTerms =
      !!offer.requestedTradeId ||
      (offer.requestedAmount != null && offer.requestedAmount.toString() !== '');
    if (hasOwnerCounterTerms) {
      return tradeOwnerId;
    }
    return offer.bidderId;
  }

  /** OPEN trades accept new offers; counter-offers may also use trades already IN_OFFER. */
  private isTradeEligibleForOffer(status: TradeStatus, isCounterOffer: boolean): boolean {
    if (status === TradeStatus.CANCELLED || status === TradeStatus.CLOSED) {
      return false;
    }
    if (status === TradeStatus.OPEN) return true;
    return isCounterOffer && status === TradeStatus.IN_OFFER;
  }

  /**
   * Reserve a trade for an offer (OPEN → IN_OFFER). For counter-offers, a trade
   * already IN_OFFER from the parent negotiation is left as-is.
   */
  private async reserveTradeForOfferInTx(
    tx: Prisma.TransactionClient,
    tradeId: string,
    isCounterOffer: boolean,
    unavailableMessage: string,
  ): Promise<void> {
    const trade = await tx.trade.findUnique({ where: { id: tradeId } });
    if (!trade || !this.isTradeEligibleForOffer(trade.status, isCounterOffer)) {
      throw new BadRequestException(unavailableMessage);
    }
    if (trade.status === TradeStatus.IN_OFFER) {
      return;
    }
    const updated = await tx.trade.updateMany({
      where: { id: tradeId, status: TradeStatus.OPEN },
      data: { status: TradeStatus.IN_OFFER },
    });
    if (updated.count === 0) {
      const again = await tx.trade.findUnique({ where: { id: tradeId } });
      if (isCounterOffer && again?.status === TradeStatus.IN_OFFER) {
        return;
      }
      throw new BadRequestException(unavailableMessage);
    }
  }

  async createTrade(ownerId: string, data: {
    title: string;
    description?: string;
    mediaType?: string;
    mediaKeys?: string[];
    videoKey?: string;
    thumbnailKey?: string;
    category?: string;
    isNegotiable?: boolean;
    requiresPickup?: boolean;
    allowDelivery?: boolean;
    allowShipping?: boolean;
    enableBYCPromotion?: boolean;
    location?: string;
    latitude?: number;
    longitude?: number;
    status?: 'DRAFT' | 'OPEN';
    isSeedingListing?: boolean;
  }) {
    const domain: MediaDomain = 'trades';
    const media = normalizeListingMedia({
      mediaType: data.mediaType,
      mediaKeys: data.mediaKeys,
      videoKey: data.videoKey,
    });
    let mediaKeys = media.mediaKeys;
    if (media.mediaType === ListingMediaType.IMAGE && mediaKeys.length > 0) {
      const dedup = await this.media.dedupeMediaKeys(ownerId, domain, mediaKeys);
      mediaKeys = dedup.kept;
    }
    const thumbnailKey = await this.media.resolveListingThumbnailKey(
      ownerId,
      domain,
      media,
      data.thumbnailKey,
    );
    const createData: any = {
      ownerId,
      title: data.title,
      description: data.description,
      mediaType: media.mediaType,
      mediaKeys,
      videoKey: media.videoKey,
      thumbnailKey,
    };
    createData.location = requireListingLocation(data.location);
    const geoMeta = buildListingMetadataWithCoords(
      data.isSeedingListing ? { isSeedingListing: true } : undefined,
      data.latitude,
      data.longitude,
    );
    if (Object.keys(geoMeta).length > 0) {
      createData.metadata = geoMeta as Prisma.InputJsonValue;
    }
    // Forward new fields with safe defaults; cast to any to avoid type conflicts during client refresh
    if (data.category !== undefined) createData.category = data.category ?? 'OTHERS';
    if (data.isNegotiable !== undefined) createData.isNegotiable = data.isNegotiable ?? true;
    if (data.requiresPickup !== undefined) createData.requiresPickup = data.requiresPickup ?? true;
    if (data.allowDelivery !== undefined) createData.allowDelivery = data.allowDelivery ?? false;
    if (data.allowShipping !== undefined) createData.allowShipping = data.allowShipping ?? false;
    if (data.enableBYCPromotion !== undefined) createData.enableBYCPromotion = data.enableBYCPromotion ?? false;
    if (data.status === 'DRAFT') createData.status = TradeStatus.DRAFT;
    const trade = await this.prisma.trade.create({ data: createData as any });

    if (data.isSeedingListing && data.status !== 'DRAFT') {
      try {
        const seedingPoints = (await this.karmaPointsConfig.getConfig()).seedingBonus;
        await this.karmaService.awardKarma(
          ownerId,
          KarmaEventType.MANUAL_ADJUSTMENT,
          seedingPoints,
          'Ecosystem seeding trade listing bonus',
          { tradeId: trade.id, isSeedingListing: true },
          trade.id,
          'trade',
        );
      } catch (error) {
        this.logger.error('Failed to award seeding karma for trade', error);
      }
    }

    await this.bumpTradeListCacheGeneration();

    if (trade.status === TradeStatus.OPEN && !data.isSeedingListing) {
      void this.nearbyNotifier.notifyNearbyListing({
        kind: 'trade',
        listingId: trade.id,
        creatorId: ownerId,
        title: trade.title,
        locationText: trade.location,
        metadata: trade.metadata,
      });
    }

    return trade;
  }

  async listTrades(params: {
    query?: string;
    ownerId?: string;
    status?: TradeStatus;
    page?: number;
    size?: number;
    lat?: number;
    lng?: number;
    radiusKm?: number;
    location?: string;
  }) {
    const page = Math.max(params.page ?? 1, 1);
    const size = Math.min(Math.max(params.size ?? 20, 1), 100);
    const geo: ListingGeoParams = {
      lat: params.lat,
      lng: params.lng,
      radiusKm: params.radiusKm,
      location: params.location,
    };
    const geoActive = hasListingGeoFilter(geo);

    // Build a stable cache key for this feed query.
    const listGen = await this.tradeListCacheGeneration();
    const cacheKey = `trades:list:g${listGen}:${JSON.stringify({
      q: params.query || '',
      ownerId: params.ownerId || '',
      status: params.status || '',
      lat: params.lat ?? '',
      lng: params.lng ?? '',
      radiusKm: params.radiusKm ?? '',
      location: params.location || '',
      page,
      size,
    })}`;

    // Try cache first (skip when geo filtering — results are user-specific)
    if (!geoActive) {
      const cached = await this.cache.get<{ items: any[]; page: number; size: number; total: number }>(cacheKey);
      if (cached) {
        return enrichListingPayloadForFeed(cached);
      }
    }

    const where: any = {};
    if (params.ownerId) where.ownerId = params.ownerId;
    if (params.status) where.status = params.status;
    else if (!params.ownerId) where.status = TradeStatus.OPEN;
    if (params.query) {
      where.OR = [
        { title: { contains: params.query, mode: 'insensitive' } },
        { description: { contains: params.query, mode: 'insensitive' } },
      ];
    }

    if (geoActive) {
      const rawItems = await this.prisma.trade.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: 500,
        include: {
          owner: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                  bio: true,
                  kycStatus: true,
                },
              },
            },
          },
        },
      });
      const filtered = applyListingGeoFilter(rawItems, geo);
      return enrichListingPayloadForFeed(paginateListingItems(filtered, page, size));
    }

    const [total, items] = await this.prisma.$transaction([
      this.prisma.trade.count({ where }),
      this.prisma.trade.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
        include: {
          owner: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                  bio: true,
                  kycStatus: true,
                },
              },
            },
          },
        },
      }),
    ]);
    const payload = enrichListingPayloadForFeed({ items, page, size, total });

    // Cache the result for a short period. TTL can be tuned via env.
    if (!geoActive) {
      const ttlSeconds = Number(process.env.TRADE_FEED_CACHE_TTL_S ?? process.env.CACHE_TTL_SECONDS ?? 30);
      await this.cache.set(cacheKey, payload, ttlSeconds);
    }

    return payload;
  }

  async listSimilarTrades(params: {
    categoryId?: number;
    category?: string;
    excludeId?: string;
    limit: number;
  }) {
    const category =
      this.categoryFromId(params.categoryId) ?? this.normalizeCategory(params.category);

    const where: Prisma.TradeWhereInput = {
      status: TradeStatus.OPEN,
      ...(category ? { category } : {}),
      ...(params.excludeId ? { id: { not: params.excludeId } } : {}),
    };

    const items = await this.prisma.trade.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: params.limit,
      include: {
        owner: {
          select: {
            id: true,
            profile: {
              select: {
                displayName: true,
                avatarKey: true,
                bio: true,
              },
            },
          },
        },
      },
    });

    return { items };
  }

  async getTrade(id: string) {
    const trade = await this.prisma.trade.findUnique({
      where: { id },
      include: {
        offers: {
          include: {
            offeredTrade: {
              include: {
                owner: {
                  select: {
                    id: true,
                    profile: {
                      select: {
                        displayName: true,
                        avatarKey: true,
                        kycStatus: true,
                      },
                    },
                  },
                },
              },
            },
            bidder: {
              select: {
                id: true,
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
        acceptedOffer: {
          include: {
            offeredTrade: {
              include: {
                owner: {
                  select: {
                    id: true,
                    profile: {
                      select: {
                        displayName: true,
                        avatarKey: true,
                        kycStatus: true,
                      },
                    },
                  },
                },
              },
            },
          },
        },
        owner: {
          select: {
            id: true,
            profile: {
              select: {
                displayName: true,
                avatarKey: true,
                bio: true,
              },
            },
          },
        },
      },
    });
    if (!trade) throw new NotFoundException('Trade not found');
    const meta = (trade.metadata as Record<string, unknown>) || {};
    const likeCount = (meta.likes as number) ?? 0;
    return { ...trade, likeCount, favoriteCount: likeCount };
  }

  async likeTrade(_userId: string, tradeId: string) {
    const trade = await this.prisma.trade.findUnique({ where: { id: tradeId } });
    if (!trade) throw new NotFoundException('Trade not found');
    const meta = (trade.metadata as Record<string, any>) || {};
    const updated = await this.prisma.trade.update({
      where: { id: tradeId },
      data: {
        metadata: {
          ...meta,
          likes: (meta.likes || 0) + 1,
        },
      },
    });
    return { success: true, likes: (updated.metadata as any)?.likes ?? 0 };
  }

  async unlikeTrade(_userId: string, tradeId: string) {
    const trade = await this.prisma.trade.findUnique({ where: { id: tradeId } });
    if (!trade) throw new NotFoundException('Trade not found');
    const meta = (trade.metadata as Record<string, any>) || {};
    const updated = await this.prisma.trade.update({
      where: { id: tradeId },
      data: {
        metadata: {
          ...meta,
          likes: Math.max((meta.likes || 1) - 1, 0),
        },
      },
    });
    return { success: true, likes: (updated.metadata as any)?.likes ?? 0 };
  }

  async getTradeComments(tradeId: string, page: number, size: number) {
    const trade = await this.prisma.trade.findUnique({ where: { id: tradeId } });
    if (!trade) throw new NotFoundException('Trade not found');
    const [total, items] = await Promise.all([
      this.prisma.tradeComment.count({ where: { tradeId, parentId: null } }),
      this.prisma.tradeComment.findMany({
        where: { tradeId, parentId: null },
        include: {
          author: { include: { profile: { select: { displayName: true, avatarKey: true } } } },
          replies: {
            include: { author: { include: { profile: { select: { displayName: true, avatarKey: true } } } } },
            orderBy: { createdAt: 'asc' },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
      }),
    ]);
    const comments = items.map((c) => ({
      id: c.id,
      content: c.content,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
      userName: (c.author.profile as any)?.displayName ?? c.author.email,
      authorId: c.authorId,
      avatarKey: (c.author.profile as any)?.avatarKey,
      replyCount: c.replies.length,
      replies: c.replies.map((r) => ({
        id: r.id,
        content: r.content,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        userName: (r.author.profile as any)?.displayName ?? r.author.email,
        authorId: r.authorId,
      })),
    }));
    return { comments, page, size, total };
  }

  async addTradeComment(userId: string, tradeId: string, content: string, parentId?: string) {
    const trade = await this.prisma.trade.findUnique({ where: { id: tradeId } });
    if (!trade) throw new NotFoundException('Trade not found');
    if (!content?.trim()) throw new BadRequestException('Comment content is required');
    const comment = await this.prisma.tradeComment.create({
      data: { tradeId, authorId: userId, content: content.trim(), parentId: parentId || null },
      include: { author: { include: { profile: { select: { displayName: true, avatarKey: true } } } } },
    });
    return {
      id: comment.id,
      content: comment.content,
      createdAt: comment.createdAt,
      updatedAt: comment.updatedAt,
      userName: (comment.author.profile as any)?.displayName ?? comment.author.email,
      authorId: comment.authorId,
      avatarKey: (comment.author.profile as any)?.avatarKey,
    };
  }

  async updateTradeComment(userId: string, tradeId: string, commentId: string, content: string) {
    if (!content?.trim()) throw new BadRequestException('Comment content is required');
    const comment = await this.prisma.tradeComment.findUnique({ where: { id: commentId } });
    if (!comment || comment.tradeId !== tradeId) throw new NotFoundException('Comment not found');
    if (comment.authorId !== userId) throw new ForbiddenException('You can only edit your own comments');
    const updated = await this.prisma.tradeComment.update({
      where: { id: commentId },
      data: { content: content.trim() },
      include: { author: { include: { profile: { select: { displayName: true, avatarKey: true } } } } },
    });
    return {
      id: updated.id,
      content: updated.content,
      createdAt: updated.createdAt,
      updatedAt: updated.updatedAt,
      userName: (updated.author.profile as any)?.displayName ?? updated.author.email,
      authorId: updated.authorId,
      avatarKey: (updated.author.profile as any)?.avatarKey,
    };
  }

  async updateTrade(currentUserId: string, id: string, data: {
    title?: string;
    description?: string;
    mediaType?: string;
    mediaKeys?: string[];
    videoKey?: string | null;
    thumbnailKey?: string | null;
    category?: string;
    isNegotiable?: boolean;
    requiresPickup?: boolean;
    allowDelivery?: boolean;
    allowShipping?: boolean;
    enableBYCPromotion?: boolean;
  }) {
    const trade = await this.prisma.trade.findUnique({ where: { id } });
    if (!trade) throw new NotFoundException('Trade not found');
    if (trade.ownerId !== currentUserId) throw new ForbiddenException('Only owner can update');
    if (trade.status !== TradeStatus.OPEN && trade.status !== TradeStatus.DRAFT) throw new BadRequestException('Cannot update non-open or non-draft trade');
    const payload: any = {};
    if (data.title !== undefined) payload.title = data.title;
    if (data.description !== undefined) payload.description = data.description;
    if (
      data.mediaType !== undefined ||
      data.mediaKeys !== undefined ||
      data.videoKey !== undefined ||
      data.thumbnailKey !== undefined
    ) {
      const domain: MediaDomain = 'trades';
      const media = normalizeListingMedia({
        mediaType: data.mediaType ?? trade.mediaType,
        mediaKeys: data.mediaKeys ?? trade.mediaKeys,
        videoKey: data.videoKey !== undefined ? data.videoKey : trade.videoKey,
      });
      let mediaKeys = media.mediaKeys;
      if (media.mediaType === ListingMediaType.IMAGE && mediaKeys.length > 0) {
        const dedup = await this.media.dedupeMediaKeys(currentUserId, domain, mediaKeys);
        mediaKeys = dedup.kept;
      }
      payload.mediaType = media.mediaType;
      payload.mediaKeys = mediaKeys;
      payload.videoKey = media.videoKey;
      if (media.mediaType === ListingMediaType.VIDEO) {
        payload.thumbnailKey =
          data.thumbnailKey !== undefined
            ? data.thumbnailKey?.trim() || null
            : trade.thumbnailKey;
      } else if (media.mediaType === ListingMediaType.IMAGE) {
        payload.thumbnailKey = mediaKeys[0] ?? null;
      }
    }
    if (data.category !== undefined) payload.category = data.category;
    if (data.isNegotiable !== undefined) payload.isNegotiable = data.isNegotiable;
    if (data.requiresPickup !== undefined) payload.requiresPickup = data.requiresPickup;
    if (data.allowDelivery !== undefined) payload.allowDelivery = data.allowDelivery;
    if (data.allowShipping !== undefined) payload.allowShipping = data.allowShipping;
    if (data.enableBYCPromotion !== undefined) payload.enableBYCPromotion = data.enableBYCPromotion;
    const updated = await this.prisma.trade.update({ where: { id }, data: payload as any });
    await this.bumpTradeListCacheGeneration();
    return updated;
  }

  async publishDraft(currentUserId: string, id: string) {
    const trade = await this.prisma.trade.findUnique({ where: { id } });
    if (!trade) throw new NotFoundException('Trade not found');
    if (trade.ownerId !== currentUserId) throw new ForbiddenException('Only owner can publish');
    if (trade.status !== TradeStatus.DRAFT) throw new BadRequestException('Only draft trades can be published');
    const published = await this.prisma.trade.update({ where: { id }, data: { status: TradeStatus.OPEN } });
    await this.bumpTradeListCacheGeneration();
    const meta = published.metadata as Record<string, unknown> | null;
    const isSeeding = meta?.isSeedingListing === true;
    if (!isSeeding) {
      void this.nearbyNotifier.notifyNearbyListing({
        kind: 'trade',
        listingId: published.id,
        creatorId: published.ownerId,
        title: published.title,
        locationText: published.location,
        metadata: published.metadata,
      });
    }
    return published;
  }

  async closeTrade(currentUserId: string, id: string) {
    const trade = await this.prisma.trade.findUnique({ where: { id } });
    if (!trade) throw new NotFoundException('Trade not found');
    if (trade.ownerId !== currentUserId) throw new ForbiddenException('Only owner can close');
    if (trade.status !== TradeStatus.OPEN) throw new BadRequestException('Trade not open');
    return this.prisma.trade.update({ where: { id }, data: { status: TradeStatus.CLOSED, closedAt: new Date() } });
  }

  async cancelTrade(currentUserId: string, id: string) {
    const trade = await this.prisma.trade.findUnique({ where: { id } });
    if (!trade) throw new NotFoundException('Trade not found');
    if (trade.ownerId !== currentUserId) throw new ForbiddenException('Only owner can cancel');
    if (
      trade.status !== TradeStatus.OPEN &&
      trade.status !== TradeStatus.DRAFT &&
      trade.status !== TradeStatus.IN_OFFER
    ) {
      throw new BadRequestException('Only open, draft, or in-offer trades can be cancelled');
    }
    const updated = await this.prisma.trade.update({ where: { id }, data: { status: TradeStatus.CANCELLED, cancelledAt: new Date() } });
    try {
      const owner = await this.prisma.user.findUnique({
        where: { id: currentUserId },
        select: { email: true, profile: { select: { displayName: true } } },
      });
      const offers = await this.prisma.tradeOffer.findMany({
        where: { tradeId: id },
        select: { bidderId: true },
      });
      const bidders = Array.from(new Set(offers.map((o) => o.bidderId)));
      await Promise.all(
        bidders.map(async (bidderId) => {
          const bidder = await this.prisma.user.findUnique({ where: { id: bidderId }, select: { email: true } });
          if (bidder?.email) {
            this.email.dispatchInBackground({
              eventName: EmailEventName.TradeCanceled,
              recipient: { email: bidder.email, userId: bidderId },
              vars: {
                actorName: owner?.profile?.displayName || owner?.email || 'Owner',
                targetName: bidder.email,
                tradeTitle: trade.title,
                canceledBy: owner?.profile?.displayName || owner?.email || 'Owner',
                tradeUrl: this.emailLinkRouter.getTradeLink(id),
              },
            });
          }
        }),
      );
    } catch {
      // Non-blocking
    }
    await this.bumpTradeListCacheGeneration();
    await this.refundTopUps(id, 'trade_cancelled');
    return updated;
  }

  async disputeTrade(currentUserId: string, id: string, reason?: string) {
    const trade = await this.prisma.trade.findUnique({
      where: { id },
      include: { offers: { select: { bidderId: true } } },
    });
    if (!trade) throw new NotFoundException('Trade not found');
    const isBidder = trade.offers.some((offer) => offer.bidderId === currentUserId);
    if (trade.ownerId !== currentUserId && !isBidder) {
      throw new ForbiddenException('Only the people in this trade can dispute it');
    }
    const refunds = await this.refundTopUps(id, 'trade_disputed');
    return {
      ok: true,
      tradeId: id,
      reason: reason?.trim().slice(0, 500) || null,
      refunds,
    };
  }

  async deleteTrade(currentUserId: string, id: string) {
    const trade = await this.prisma.trade.findUnique({
      where: { id },
      include: { offers: true },
    });
    if (!trade) throw new NotFoundException('Trade not found');
    if (trade.ownerId !== currentUserId) throw new ForbiddenException('Only owner can delete');

    if (trade.status !== TradeStatus.DRAFT && trade.status !== TradeStatus.OPEN) {
      throw new BadRequestException('Only draft or open trades can be deleted');
    }

    const activeOfferStatuses: OfferStatus[] = [
      OfferStatus.PENDING,
      OfferStatus.ACCEPTED,
      OfferStatus.ACCEPTED_AWAITING_FINALIZATION,
    ];

    const activeOnTrade = trade.offers.filter((o) => activeOfferStatuses.includes(o.status));
    if (activeOnTrade.length > 0) {
      throw new BadRequestException('Cannot delete a trade with active offers or negotiations');
    }

    const referencedInOffers = await this.prisma.tradeOffer.count({
      where: {
        status: { in: activeOfferStatuses },
        OR: [{ offeredTradeId: id }, { requestedTradeId: id }],
      },
    });
    if (referencedInOffers > 0) {
      throw new BadRequestException('Cannot delete a trade that is part of an active swap offer');
    }

    await this.prisma.$transaction(async (tx) => {
      const negotiations = await tx.negotiation.findMany({ where: { tradeId: id }, select: { id: true } });
      if (negotiations.length > 0) {
        await tx.negotiationMessage.deleteMany({
          where: { negotiationId: { in: negotiations.map((n) => n.id) } },
        });
        await tx.negotiation.deleteMany({ where: { tradeId: id } });
      }

      const offerIds = trade.offers.map((o) => o.id);
      if (offerIds.length > 0) {
        await tx.trade.updateMany({
          where: { acceptedOfferId: { in: offerIds } },
          data: { acceptedOfferId: null },
        });
      }

      await tx.tradeOffer.updateMany({ where: { offeredTradeId: id }, data: { offeredTradeId: null } });
      await tx.tradeOffer.updateMany({ where: { requestedTradeId: id }, data: { requestedTradeId: null } });
      await tx.tradeOffer.deleteMany({ where: { tradeId: id } });
      await tx.tradeComment.updateMany({ where: { tradeId: id }, data: { parentId: null } });
      await tx.tradeComment.deleteMany({ where: { tradeId: id } });
      await tx.communityPost.updateMany({ where: { linkedTradeId: id }, data: { linkedTradeId: null } });
      await tx.trade.delete({ where: { id } });
    });

    await this.bumpTradeListCacheGeneration();
    return { success: true, id };
  }

  /**
   * Offers the user sent (as bidder) or received (as trade owner).
   * Does not depend on the public OPEN feed, so IN_OFFER trades still appear.
   */
  async listMyOffers(userId: string, page = 1, size = 50) {
    const normalizedPage = Math.max(page ?? 1, 1);
    const normalizedSize = Math.min(Math.max(size ?? 50, 1), 100);
    const where: Prisma.TradeOfferWhereInput = {
      parentOfferId: null,
      OR: [{ bidderId: userId }, { trade: { ownerId: userId } }],
    };
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.tradeOffer.count({ where }),
      this.prisma.tradeOffer.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (normalizedPage - 1) * normalizedSize,
        take: normalizedSize,
        include: {
          trade: {
            include: {
              owner: {
                select: {
                  id: true,
                  profile: { select: { displayName: true, avatarKey: true } },
                },
              },
            },
          },
          offeredTrade: {
            include: {
              owner: {
                select: {
                  id: true,
                  profile: { select: { displayName: true, avatarKey: true } },
                },
              },
            },
          },
          bidder: {
            select: {
              id: true,
              profile: { select: { displayName: true, avatarKey: true } },
            },
          },
        },
      }),
    ]);

    const items = rows.map((row) => {
      const direction = row.bidderId === userId ? 'sent' : 'received';
      return {
        ...row,
        direction,
        tradeId: row.tradeId,
        tradeTitle: row.trade?.title ?? 'Trade',
        ownerId: row.trade?.ownerId,
        ownerName:
          row.trade?.owner?.profile?.displayName ??
          row.trade?.owner?.id ??
          'Owner',
        bidderName:
          row.bidder?.profile?.displayName ?? row.bidder?.id ?? 'User',
      };
    });

    return {
      items,
      page: normalizedPage,
      size: normalizedSize,
      total,
    };
  }

  async listOffers(tradeId: string) {
    await this.ensureTrade(tradeId);
    return this.prisma.tradeOffer.findMany({
      where: { tradeId, parentOfferId: null }, // Only return top-level offers (not counter-offers)
      orderBy: { createdAt: 'desc' },
      include: {
        offeredTrade: {
          include: {
            owner: {
              select: {
                id: true,
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
        bidder: {
          select: {
            id: true,
            profile: {
              select: {
                displayName: true,
                avatarKey: true,
              },
            },
          },
        },
        counterOffers: {
          include: {
            offeredTrade: {
              include: {
                owner: {
                  select: {
                    id: true,
                    profile: {
                      select: {
                        displayName: true,
                        avatarKey: true,
                        kycStatus: true,
                      },
                    },
                  },
                },
              },
            },
            bidder: {
              select: {
                id: true,
                profile: {
                  select: {
                    displayName: true,
                    avatarKey: true,
                  },
                },
              },
            },
          },
          orderBy: { createdAt: 'asc' },
        },
      },
    });
  }

  /** Shared relations for offer timeline (listing + items + parties). */
  private offerHistoryInclude() {
    const ownerSelect = {
      select: {
        id: true,
        profile: {
          select: {
            displayName: true,
            avatarKey: true,
            kycStatus: true,
          },
        },
      },
    };
    const tradeWithOwner = { include: { owner: ownerSelect } };
    return {
      trade: tradeWithOwner,
      offeredTrade: tradeWithOwner,
      requestedTrade: tradeWithOwner,
      bidder: {
        select: {
          id: true,
          profile: {
            select: {
              displayName: true,
              avatarKey: true,
            },
          },
        },
      },
    };
  }

  /** Load one offer node and all counter-offers recursively (any depth). */
  private async loadOfferSubtree(offerId: string): Promise<any | null> {
    const offer = await this.prisma.tradeOffer.findUnique({
      where: { id: offerId },
      include: this.offerHistoryInclude(),
    });
    if (!offer) return null;
    const children = await this.prisma.tradeOffer.findMany({
      where: { parentOfferId: offerId },
      orderBy: { createdAt: 'asc' },
    });
    const counterOffers: any[] = [];
    for (const child of children) {
      const subtree = await this.loadOfferSubtree(child.id);
      if (subtree) counterOffers.push(subtree);
    }
    return { ...offer, counterOffers };
  }

  private async resolveRootOfferId(offerId: string): Promise<string> {
    let currentId = offerId;
    for (let depth = 0; depth < 50; depth++) {
      const row = await this.prisma.tradeOffer.findUnique({
        where: { id: currentId },
        select: { parentOfferId: true },
      });
      if (!row?.parentOfferId) return currentId;
      currentId = row.parentOfferId;
    }
    return currentId;
  }

  /**
   * Get the complete offer history for a specific offer, including all counter-offers
   */
  async getOfferHistory(offerId: string) {
    const rootId = await this.resolveRootOfferId(offerId);
    const rootOffer = await this.loadOfferSubtree(rootId);
    if (!rootOffer) {
      throw new NotFoundException('Offer not found');
    }

    const timeline: any[] = [];
    const buildTimeline = (off: any, depth: number = 0) => {
      timeline.push({
        ...off,
        depth,
        isCounterOffer: !!off.parentOfferId,
        requestedAmount:
          off.requestedAmount != null ? off.requestedAmount.toString() : null,
      });
      if (off.counterOffers?.length) {
        for (const counter of off.counterOffers) {
          buildTimeline(counter, depth + 1);
        }
      }
    };
    buildTimeline(rootOffer);

    return {
      rootOffer,
      timeline: timeline.sort(
        (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
      ),
    };
  }

  async createOffer(
    currentUserId: string,
    tradeId: string,
    data: {
      amount?: string;
      message?: string;
      offeredTradeId?: string;
      parentOfferId?: string;
      requestedTradeId?: string;
      requestedAmount?: string;
    },
  ) {
    const trade = await this.ensureTrade(tradeId);
    const isOwner = trade.ownerId === currentUserId;

    // Target trade must be fully available
    if (trade.status === TradeStatus.CANCELLED || trade.status === TradeStatus.CLOSED) {
      throw new BadRequestException('Trade not open');
    }

    let isOwnerCounterOffer = false;
    let parentOffer: any = null;
    const isCounterOffer = !!data.parentOfferId;

    // If this is a counter-offer, validate the parent offer
    if (data.parentOfferId) {
      parentOffer = await this.prisma.tradeOffer.findUnique({
        where: { id: data.parentOfferId },
        include: { trade: true },
      });

      if (!parentOffer) {
        throw new NotFoundException('Parent offer not found');
      }

      if (parentOffer.tradeId !== tradeId) {
        throw new BadRequestException('Counter-offer must be for the same trade as the parent offer');
      }

      if (parentOffer.status !== OfferStatus.PENDING) {
        throw new BadRequestException('Can only create counter-offers to pending offers');
      }

      const parentAuthorId = this.getOfferAuthorUserId(
        parentOffer,
        parentOffer.trade.ownerId,
      );
      if (currentUserId === parentAuthorId) {
        throw new ForbiddenException('Cannot counter-offer your own offer');
      }

      const rootId = await this.resolveRootOfferId(data.parentOfferId);
      const rootOffer = await this.prisma.tradeOffer.findUnique({
        where: { id: rootId },
        select: { bidderId: true },
      });
      const originalBidderId = rootOffer?.bidderId;
      if (
        currentUserId !== parentOffer.trade.ownerId &&
        currentUserId !== originalBidderId
      ) {
        throw new ForbiddenException('Not a party to this negotiation');
      }

      isOwnerCounterOffer =
        currentUserId === parentOffer.trade.ownerId &&
        (!!data.requestedTradeId || !!data.requestedAmount);
    }

    // Owner cannot bid on own trade (except when making a counter-offer)
    if (isOwner && !isOwnerCounterOffer) {
      throw new ForbiddenException('Owner cannot bid on own trade');
    }

    // Owner counter-offer: requestedTradeId and/or requestedAmount (pick from counterparty's items or ask for cash)
    if (isOwnerCounterOffer) {
      if (!data.requestedTradeId && !data.requestedAmount) {
        throw new BadRequestException('Provide requestedTradeId (item you want) or requestedAmount (cash you want)');
      }
      if (data.requestedTradeId) {
        const requestedTrade = await this.prisma.trade.findUnique({
          where: { id: data.requestedTradeId },
        });
        if (!requestedTrade) throw new NotFoundException('Requested trade not found');
        if (requestedTrade.ownerId !== parentOffer.bidderId) {
          throw new ForbiddenException('Requested trade must be owned by the person who made the offer');
        }
        if (!this.isTradeEligibleForOffer(requestedTrade.status, isCounterOffer)) {
          throw new BadRequestException('Requested trade must be available (OPEN or in active negotiation)');
        }
      }
      if (data.requestedAmount) {
        const amt = parseFloat(data.requestedAmount);
        if (isNaN(amt) || amt <= 0) {
          throw new BadRequestException('Requested amount must be a positive number');
        }
      }
      // Create owner counter-offer: owner offers their trade for bidder's requested item and/or cash
      const offer = await this.prisma.$transaction(async (tx) => {
        await this.reserveTradeForOfferInTx(
          tx,
          tradeId,
          true,
          'Trade is no longer available for offers',
        );
        const requestedId = data.requestedTradeId;
        if (requestedId) {
          await this.reserveTradeForOfferInTx(
            tx,
            requestedId,
            true,
            'Requested trade is no longer available',
          );
        }
        return tx.tradeOffer.create({
          data: {
            tradeId,
            bidderId: currentUserId,
            offeredTradeId: tradeId,
            message: data.message,
            parentOfferId: data.parentOfferId,
            requestedTradeId: data.requestedTradeId,
            requestedAmount: data.requestedAmount
              ? new (require('@prisma/client').Prisma.Decimal)(data.requestedAmount)
              : undefined,
          },
          include: {
            offeredTrade: true,
            requestedTrade: true,
            bidder: { select: { id: true, profile: { select: { displayName: true, avatarKey: true } } } },
            parentOffer: {
              include: {
                bidder: { select: { id: true, profile: { select: { displayName: true, avatarKey: true } } } },
              },
            },
          },
        });
      });
      if (parentOffer) {
        const notifyUserId = this.getOfferAuthorUserId(
          parentOffer,
          parentOffer.trade.ownerId,
        );
        await this.notifications.notifyCounterOffer(
          tradeId,
          (offer.bidder as any)?.profile?.displayName ?? 'Someone',
          notifyUserId,
          offer.id,
          data.parentOfferId!,
        );
      }
      return offer;
    }

    // Bidder offer or bidder counter-offer: amount OR offeredTradeId
    if (!data.amount && !data.offeredTradeId) {
      throw new BadRequestException('Either amount or offeredTradeId must be provided');
    }
    if (data.amount && data.offeredTradeId) {
      throw new BadRequestException('Cannot provide both amount and offeredTradeId. Choose one.');
    }

    // If offeredTradeId is provided, validate the offered trade
    if (data.offeredTradeId) {
      const offeredTrade = await this.prisma.trade.findUnique({
        where: { id: data.offeredTradeId },
      });

      if (!offeredTrade) {
        throw new NotFoundException('Offered trade not found');
      }

      if (offeredTrade.ownerId !== currentUserId) {
        throw new ForbiddenException('You can only offer trades that you own');
      }

      if (!this.isTradeEligibleForOffer(offeredTrade.status, isCounterOffer)) {
        throw new BadRequestException('Offered trade must be available (OPEN or in active negotiation)');
      }

      if (offeredTrade.id === tradeId) {
        throw new BadRequestException('Cannot offer the same trade for itself');
      }

      // Check for duplicate: user already has a pending offer for this trade with the same item
      const existingOffer = await this.prisma.tradeOffer.findFirst({
        where: {
          tradeId,
          bidderId: currentUserId,
          offeredTradeId: data.offeredTradeId,
          status: OfferStatus.PENDING,
          parentOfferId: null, // Only check top-level offers, not counter-offers
        },
      });
      if (existingOffer) {
        throw new HttpException(
          {
            message: 'You already have a pending offer for this trade with the same item.',
            code: 'DUPLICATE_OFFER',
            existingOfferId: existingOffer.id,
          },
          HttpStatus.BAD_REQUEST,
        );
      }
    }

    // For cash offers, also check duplicate (same trade, same bidder, pending cash offer)
    if (data.amount && !data.parentOfferId) {
      const existingCashOffer = await this.prisma.tradeOffer.findFirst({
        where: {
          tradeId,
          bidderId: currentUserId,
          status: OfferStatus.PENDING,
          parentOfferId: null,
          offeredTradeId: null,
        },
      });
      if (existingCashOffer) {
        throw new HttpException(
          {
            message: 'You already have a pending offer for this trade.',
            code: 'DUPLICATE_OFFER',
            existingOfferId: existingCashOffer.id,
          },
          HttpStatus.BAD_REQUEST,
        );
      }
    }

    // For item-for-item offers we need to atomically mark both trades as participating in an offer
    const offer = await this.prisma.$transaction(async (tx) => {
      if (data.offeredTradeId) {
        await this.reserveTradeForOfferInTx(
          tx,
          tradeId,
          isCounterOffer,
          'One of the trades is no longer available for offers',
        );
        await this.reserveTradeForOfferInTx(
          tx,
          data.offeredTradeId,
          isCounterOffer,
          'One of the trades is no longer available for offers',
        );
      }

      return tx.tradeOffer.create({
        data: {
          tradeId,
          bidderId: currentUserId,
          amount: data.amount ? (new (require('@prisma/client').Prisma.Decimal)(data.amount)) : undefined,
          offeredTradeId: data.offeredTradeId,
          message: data.message,
          parentOfferId: data.parentOfferId,
        },
      include: {
        offeredTrade: {
          include: {
            owner: {
              select: {
                id: true,
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
        bidder: {
          select: {
            id: true,
            profile: {
              select: {
                displayName: true,
                avatarKey: true,
              },
            },
          },
        },
        parentOffer: {
          include: {
            bidder: {
              select: {
                id: true,
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
      },
      });
    });

    // Cash offer amounts are informational only (barter / arrange payment off-platform).
    // No wallet lock or escrow.

    try {
      const bidder = await this.prisma.user.findUnique({
        where: { id: currentUserId },
        include: { profile: { select: { displayName: true } } },
      });
      const bidderName = bidder?.profile?.displayName ?? bidder?.email ?? 'Someone';
      
      if (data.parentOfferId) {
        // Counter-offer notification - notify the original offerer
        const parentOffer = await this.prisma.tradeOffer.findUnique({
          where: { id: data.parentOfferId },
          include: { bidder: true },
        });
        
        if (parentOffer) {
          const notifyUserId = this.getOfferAuthorUserId(
            parentOffer,
            trade.ownerId,
          );
          await this.notifications.notifyCounterOffer(
            tradeId,
            bidderName,
            notifyUserId,
            offer.id,
            data.parentOfferId,
          );
          try {
            const target = await this.prisma.user.findUnique({ where: { id: notifyUserId } });
            if (target?.email) {
              this.email.dispatchInBackground({
                eventName: EmailEventName.TradeCounterOfferReceived,
                recipient: { email: target.email, userId: target.id },
                vars: {
                  targetName: target.email,
                  actorName: bidderName,
                  tradeTitle: trade.title,
                  counterOfferSummary: offer.message || 'Counter offer',
                  tradeUrl: this.emailLinkRouter.getTradeLink(tradeId),
                },
              });
            }
          } catch {
            // Non-blocking
          }
        }
      } else {
        // Regular offer notification
        await this.notifications.notifyTradeOffer(tradeId, bidderName, trade.ownerId, offer.id);
        try {
          const owner = await this.prisma.user.findUnique({ where: { id: trade.ownerId } });
          if (owner?.email) {
            this.email.dispatchInBackground({
              eventName: EmailEventName.TradeRequestReceived,
              recipient: { email: owner.email, userId: owner.id },
              vars: {
                targetName: owner.email,
                actorName: bidderName,
                tradeTitle: trade.title,
                tradeId,
                tradeUrl: this.emailLinkRouter.getTradeLink(tradeId),
              },
            });
          }
        } catch {
          // Non-blocking
        }
      }
    } catch (e) {
      // Non-blocking: notification failures shouldn't break offer creation
    }

    return offer;
  }

  async acceptOffer(currentUserId: string, offerId: string) {
    const offer = await this.prisma.tradeOffer.findUnique({ 
      where: { id: offerId },
      include: { offeredTrade: true },
    });
    if (!offer) throw new NotFoundException('Offer not found');
    const trade = await this.prisma.trade.findUnique({ where: { id: offer.tradeId } });
    if (!trade) throw new NotFoundException('Trade not found');
    if (trade.ownerId !== currentUserId) throw new ForbiddenException('Only owner can accept');
    if (trade.status === TradeStatus.CLOSED || trade.status === TradeStatus.CANCELLED) {
      throw new BadRequestException('Trade no longer available');
    }
    if (trade.status !== TradeStatus.IN_OFFER && trade.status !== TradeStatus.OPEN) {
      throw new BadRequestException('Trade must be OPEN or IN_OFFER');
    }
    if (offer.status !== OfferStatus.PENDING) {
      throw new ConflictException('Offer no longer pending');
    }

    const isItemForItem = !!offer.offeredTradeId;

    // TWO-STEP FLOW: Owner accepts, awaiting offerer finalization
    const result = await this.prisma.$transaction(async (tx) => {
      // Keep both trades locked (IN_OFFER status) - do NOT close yet
      // This ensures items remain locked until finalization
      
      // Mark offer as accepted but awaiting finalization
      await tx.tradeOffer.update({ 
        where: { id: offer.id }, 
        data: { status: OfferStatus.ACCEPTED_AWAITING_FINALIZATION } 
      });

      // Reject all other pending offers for the target trade
      await tx.tradeOffer.updateMany({ 
        where: { 
          tradeId: trade.id, 
          NOT: { id: offer.id }, 
          status: OfferStatus.PENDING 
        }, 
        data: { status: OfferStatus.REJECTED } 
      });

      // If item-for-item, reject other offers for the offered trade too
      if (isItemForItem && offer.offeredTradeId) {
        await tx.tradeOffer.updateMany({ 
          where: { 
            tradeId: offer.offeredTradeId, 
            NOT: { id: offer.id }, 
            status: OfferStatus.PENDING 
          }, 
          data: { status: OfferStatus.REJECTED } 
        });
      }

      // Ensure negotiation exists
      await this.ensureNegotiationForOfferTx(tx, offer.id);
      
      return trade;
    });

    // Notify bidder about acceptance (non-blocking)
    try {
      const owner = await this.prisma.user.findUnique({ 
        where: { id: currentUserId },
        include: { profile: { select: { displayName: true } } },
      });
      const ownerName = owner?.profile?.displayName ?? owner?.email ?? 'Owner';
      await this.notifications.notifyTradeAccepted(offer.tradeId, ownerName, offer.bidderId, offer.id);
      try {
        const bidder = await this.prisma.user.findUnique({ where: { id: offer.bidderId } });
        if (bidder?.email) {
          this.email.dispatchInBackground({
            eventName: EmailEventName.TradeRequestAccepted,
            recipient: { email: bidder.email, userId: bidder.id },
            vars: {
              actorName: ownerName,
              targetName: bidder.email,
              tradeTitle: trade.title,
              tradeId: offer.tradeId,
              tradeUrl: this.emailLinkRouter.getTradeLink(offer.tradeId),
            },
          });
        }
      } catch {
        // Non-blocking
      }
    } catch (e) {
      // swallow notification error
    }

    return result;
  }

  async finalizeOffer(currentUserId: string, offerId: string) {
    const offer = await this.prisma.tradeOffer.findUnique({ 
      where: { id: offerId },
      include: { offeredTrade: true, trade: true },
    });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.bidderId !== currentUserId) throw new ForbiddenException('Only the offerer can finalize');
    if (offer.status !== OfferStatus.ACCEPTED_AWAITING_FINALIZATION) {
      throw new BadRequestException('Offer must be accepted before finalization');
    }

    const trade = offer.trade;
    const isItemForItem = !!offer.offeredTradeId;

    const result = await this.prisma.$transaction(async (tx) => {
      // Close target trade and mark finalized offer
      const updatedTrade = await tx.trade.update({ 
        where: { id: trade.id }, 
        data: { 
          status: TradeStatus.CLOSED, 
          closedAt: new Date(), 
          acceptedOfferId: offer.id 
        } 
      });

      // If this is an item-for-item offer, close the offered trade as well
      if (isItemForItem && offer.offeredTradeId) {
        const offeredTrade = await tx.trade.findUnique({ 
          where: { id: offer.offeredTradeId } 
        });
        
        if (offeredTrade && (offeredTrade.status === TradeStatus.OPEN || offeredTrade.status === TradeStatus.IN_OFFER)) {
          // Close the offered trade
          await tx.trade.update({ 
            where: { id: offer.offeredTradeId }, 
            data: { 
              status: TradeStatus.CLOSED, 
              closedAt: new Date(),
              acceptedOfferId: offer.id, // Link to the same offer
            } 
          });
        }
      }

      // Mark offer as finalized
      await tx.tradeOffer.update({ 
        where: { id: offer.id }, 
        data: { status: OfferStatus.FINALIZED } 
      });
      
      return updatedTrade;
    });

    // Send completion emails
    try {
      const [owner, bidder] = await Promise.all([
        this.prisma.user.findUnique({ 
          where: { id: trade.ownerId },
          include: { profile: { select: { displayName: true } } }
        }),
        this.prisma.user.findUnique({ 
          where: { id: offer.bidderId },
          include: { profile: { select: { displayName: true } } }
        }),
      ]);

      const ownerName = owner?.profile?.displayName ?? owner?.email ?? 'Owner';
      const bidderName = bidder?.profile?.displayName ?? bidder?.email ?? 'Bidder';

      // Email to owner
      if (owner?.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.TradeCompleted,
          recipient: { email: owner.email, userId: owner.id },
          vars: {
            actorName: bidderName,
            targetName: ownerName,
            tradeTitle: trade.title,
            tradeId: trade.id,
            completedAt: new Date().toISOString(),
            tradeUrl: this.emailLinkRouter.getTradeLink(trade.id),
          },
        });
      }

      // Email to bidder
      if (bidder?.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.TradeCompleted,
          recipient: { email: bidder.email, userId: bidder.id },
          vars: {
            actorName: ownerName,
            targetName: bidderName,
            tradeTitle: trade.title,
            tradeId: trade.id,
            completedAt: new Date().toISOString(),
            tradeUrl: this.emailLinkRouter.getTradeLink(trade.id),
          },
        });
      }
    } catch {
      // Non-blocking
    }

    return result;
  }

  async rejectOffer(currentUserId: string, offerId: string) {
    const offer = await this.prisma.tradeOffer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    const trade = await this.prisma.trade.findUnique({ where: { id: offer.tradeId } });
    if (!trade) throw new NotFoundException('Trade not found');
    if (trade.ownerId !== currentUserId) throw new ForbiddenException('Only owner can reject');
    if (trade.status === TradeStatus.CANCELLED || trade.status === TradeStatus.CLOSED) {
      throw new BadRequestException('Trade no longer available');
    }
    if (offer.status !== OfferStatus.PENDING) {
      throw new ConflictException('Offer no longer pending');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const result = await tx.tradeOffer.update({ where: { id: offer.id }, data: { status: OfferStatus.REJECTED } });

      // If this was an item-for-item offer, release any IN_OFFER locks on both
      // the target and offered trades so they can be used again.
      if (offer.offeredTradeId) {
        const [lockedTarget, lockedOffered] = await Promise.all([
          tx.trade.findUnique({ where: { id: offer.tradeId } }),
          tx.trade.findUnique({ where: { id: offer.offeredTradeId } }),
        ]);

        const updates: Promise<any>[] = [];
        if (lockedTarget && lockedTarget.status === TradeStatus.IN_OFFER) {
          updates.push(tx.trade.update({ where: { id: lockedTarget.id }, data: { status: TradeStatus.OPEN } }));
        }
        if (lockedOffered && lockedOffered.status === TradeStatus.IN_OFFER) {
          updates.push(tx.trade.update({ where: { id: lockedOffered.id }, data: { status: TradeStatus.OPEN } }));
        }
        if (updates.length) {
          await Promise.all(updates);
        }
      }

      return result;
    });

    try {
      const [owner, bidder] = await Promise.all([
        this.prisma.user.findUnique({ where: { id: trade.ownerId }, select: { email: true, profile: { select: { displayName: true } } } }),
        this.prisma.user.findUnique({ where: { id: offer.bidderId }, select: { email: true } }),
      ]);
      const ownerName = owner?.profile?.displayName || owner?.email || 'Owner';
      await this.notifications.notifyTradeRejected(trade.id, ownerName, offer.bidderId, offer.id);
      if (bidder?.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.TradeRequestRejected,
          recipient: { email: bidder.email, userId: offer.bidderId },
          vars: {
            actorName: ownerName,
            targetName: bidder.email,
            tradeTitle: trade.title,
            tradeId: trade.id,
            tradeUrl: this.emailLinkRouter.getTradeLink(trade.id),
          },
        });
      }
    } catch {
      // Non-blocking
    }

    await this.refundTopUpsForOffer(offer.id, 'offer_rejected');
    return updated;
  }

  async withdrawOffer(currentUserId: string, offerId: string) {
    const offer = await this.prisma.tradeOffer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.bidderId !== currentUserId) throw new ForbiddenException('Only bidder can withdraw');
    const trade = await this.prisma.trade.findUnique({ where: { id: offer.tradeId } });
    if (!trade) throw new NotFoundException('Trade not found');
    if (trade.status === TradeStatus.CANCELLED || trade.status === TradeStatus.CLOSED) {
      throw new BadRequestException('Trade no longer available');
    }
    // Item-for-item offers lock listings as IN_OFFER until resolved; withdrawal must still work.
    if (trade.status !== TradeStatus.OPEN && trade.status !== TradeStatus.IN_OFFER) {
      throw new BadRequestException('Trade is not open');
    }
    if (offer.status !== OfferStatus.PENDING) {
      throw new ConflictException('Offer no longer pending');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const result = await tx.tradeOffer.update({ where: { id: offer.id }, data: { status: OfferStatus.WITHDRAWN } });

      // Release IN_OFFER locks on the target listing when this was the active negotiation.
      if (trade.status === TradeStatus.IN_OFFER) {
        const otherPending = await tx.tradeOffer.count({
          where: {
            tradeId: offer.tradeId,
            status: OfferStatus.PENDING,
            id: { not: offer.id },
          },
        });
        if (otherPending === 0) {
          await tx.trade.update({
            where: { id: offer.tradeId },
            data: { status: TradeStatus.OPEN },
          });
        }
      }

      // If this was an item-for-item offer, release any IN_OFFER locks on both
      // the target and offered trades so they can be used again.
      if (offer.offeredTradeId) {
        const lockedOffered = await tx.trade.findUnique({
          where: { id: offer.offeredTradeId },
        });
        if (lockedOffered && lockedOffered.status === TradeStatus.IN_OFFER) {
          await tx.trade.update({
            where: { id: lockedOffered.id },
            data: { status: TradeStatus.OPEN },
          });
        }
      }

      return result;
    });

    await this.refundTopUpsForOffer(offer.id, 'offer_withdrawn');
    return updated;
  }

  /**
   * Auto-withdraw PENDING offers with no activity since cutoff.
   * Used by cron job (TRADE_INACTIVITY_DAYS, default 3).
   */
  async autoWithdrawStaleOffers(cutoff: Date): Promise<number> {
    const offers = await this.prisma.tradeOffer.findMany({
      where: {
        status: OfferStatus.PENDING,
        updatedAt: { lte: cutoff },
        trade: { status: TradeStatus.OPEN },
      },
      select: { id: true, bidderId: true },
      take: 500,
    });
    let count = 0;
    for (const offer of offers) {
      try {
        await this.withdrawOffer(offer.bidderId, offer.id);
        count++;
      } catch (e) {
        this.logger.warn(`Auto-withdraw failed for offer ${offer.id}: ${e}`);
      }
    }
    return count;
  }

  async listMessages(currentUserId: string, offerId: string) {
    const negotiation = await this.ensureNegotiationForOffer(offerId);
    await this.ensureParticipant(currentUserId, negotiation);
    return this.prisma.negotiationMessage.findMany({ where: { negotiationId: negotiation.id }, orderBy: { createdAt: 'asc' } });
  }

  async postMessage(currentUserId: string, offerId: string, content: string, messageType: MessageType = MessageType.REGULAR, proposalData?: any) {
    if (!content?.trim()) throw new BadRequestException('Empty message');
    const negotiation = await this.ensureNegotiationForOffer(offerId);
    await this.ensureParticipant(currentUserId, negotiation);

    // Validate proposal data for proposal/counter-offer messages
    if ((messageType === MessageType.PROPOSAL || messageType === MessageType.COUNTER_OFFER) && !proposalData) {
      throw new BadRequestException('Proposal data required for proposal messages');
    }

    const [message] = await this.prisma.$transaction([
      this.prisma.negotiationMessage.create({
        data: {
          negotiationId: negotiation.id,
          senderId: currentUserId,
          content,
          messageType,
          proposalData: proposalData || undefined,
        },
      }),
      // Touch offer so updatedAt reflects last activity (used for auto-withdraw after inactivity)
      this.prisma.tradeOffer.update({ where: { id: offerId }, data: {} }),
    ]);
    if (messageType === MessageType.DISPUTE_REPORT) {
      await this.refundTopUps(negotiation.tradeId, 'trade_disputed');
    }
    return message;
  }

  private async refundTopUps(tradeId: string, reason: string) {
    try {
      return await this.topUps.refundCapturedForTrade(tradeId, reason);
    } catch (error) {
      this.logger.error(`Trade top-up refund failed for ${tradeId}: ${(error as Error).message}`);
      throw error;
    }
  }

  private async refundTopUpsForOffer(offerId: string, reason: string) {
    try {
      return await this.topUps.refundCapturedForOffer(offerId, reason);
    } catch (error) {
      this.logger.error(`Trade top-up refund failed for offer ${offerId}: ${(error as Error).message}`);
      throw error;
    }
  }

  private async ensureTrade(id: string) {
    const trade = await this.prisma.trade.findUnique({ where: { id } });
    if (!trade) throw new NotFoundException('Trade not found');
    return trade;
  }

  private async ensureNegotiationForOffer(offerId: string) {
    const offer = await this.prisma.tradeOffer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    let negotiation = await this.prisma.negotiation.findUnique({ where: { offerId: offer.id } });
    if (!negotiation) {
      const trade = await this.prisma.trade.findUnique({ where: { id: offer.tradeId } });
      if (!trade) throw new NotFoundException('Trade not found');
      negotiation = await this.prisma.negotiation.create({ data: { offerId: offer.id, tradeId: offer.tradeId, ownerId: trade.ownerId, bidderId: offer.bidderId } });
    }
    return negotiation;
  }

  private async ensureNegotiationForOfferTx(tx: Prisma.TransactionClient, offerId: string) {
    const existing = await tx.negotiation.findUnique({ where: { offerId } });
    if (existing) return existing;
    const offer = await tx.tradeOffer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    const trade = await tx.trade.findUnique({ where: { id: offer.tradeId } });
    if (!trade) throw new NotFoundException('Trade not found');
    return tx.negotiation.create({ data: { offerId: offer.id, tradeId: offer.tradeId, ownerId: trade.ownerId, bidderId: offer.bidderId } });
  }

  private async ensureParticipant(userId: string, negotiation: { ownerId: string; bidderId: string }) {
    if (negotiation.ownerId !== userId && negotiation.bidderId !== userId) {
      throw new ForbiddenException('Not a participant');
    }
  }

  /**
   * Combined trade history for a user:
   *  - Trades they own which are CLOSED or CANCELLED
   *  - Trades where they were the bidder on an ACCEPTED offer
   */
  async getUserTradeHistory(userId: string, page = 1, size = 20) {
    const normalizedPage = Math.max(page ?? 1, 1);
    const normalizedSize = Math.min(Math.max(size ?? 20, 1), 100);

    // Owned trades (closed/cancelled)
    const ownedWhere: Prisma.TradeWhereInput = {
      ownerId: userId,
      status: { in: [TradeStatus.CLOSED, TradeStatus.CANCELLED] },
    };

    // Trades where user was bidder on an accepted offer
    const bidderOffers = await this.prisma.tradeOffer.findMany({
      where: {
        bidderId: userId,
        status: OfferStatus.ACCEPTED,
      },
      select: { tradeId: true },
    });
    const bidderTradeIds = Array.from(new Set(bidderOffers.map((o) => o.tradeId)));

    const bidderWhere: Prisma.TradeWhereInput | undefined =
      bidderTradeIds.length > 0
        ? {
            id: { in: bidderTradeIds },
          }
        : undefined;

    const [ownedTotal, ownedItems] = await this.prisma.$transaction([
      this.prisma.trade.count({ where: ownedWhere }),
      this.prisma.trade.findMany({
        where: ownedWhere,
        orderBy: { createdAt: 'desc' },
        include: {
          owner: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                  bio: true,
                  kycStatus: true,
                },
              },
            },
          },
        },
      }),
    ]);

    let bidderItems: any[] = [];
    if (bidderWhere) {
      bidderItems = await this.prisma.trade.findMany({
        where: bidderWhere,
        orderBy: { createdAt: 'desc' },
        include: {
          owner: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                  bio: true,
                  kycStatus: true,
                },
              },
            },
          },
        },
      });
    }

    // Merge owned + bidder trades, track whether the user was owner and/or bidder
    type HistoryEntry = { trade: any; isOwner: boolean; isBidder: boolean };
    const roleMap = new Map<string, HistoryEntry>();

    (ownedItems as any[]).forEach((t) => {
      const existing = roleMap.get(t.id) ?? { trade: t, isOwner: false, isBidder: false };
      existing.trade = t;
      existing.isOwner = true;
      roleMap.set(t.id, existing);
    });

    (bidderItems as any[]).forEach((t) => {
      const existing = roleMap.get(t.id) ?? { trade: t, isOwner: false, isBidder: false };
      existing.trade = t;
      existing.isBidder = true;
      roleMap.set(t.id, existing);
    });

    const merged = Array.from(roleMap.values())
      .map((entry) => {
        const role = entry.isOwner && entry.isBidder
          ? 'OWNER_BIDDER'
          : entry.isOwner
          ? 'OWNER'
          : 'BIDDER';
        return {
          ...entry.trade,
          historyRole: role,
        };
      })
      .sort(
        (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
      );

    const start = (normalizedPage - 1) * normalizedSize;
    const pagedItems = merged.slice(start, start + normalizedSize);

    return {
      items: pagedItems,
      page: normalizedPage,
      size: normalizedSize,
      total: merged.length,
      ownedTotal,
    };
  }
}
