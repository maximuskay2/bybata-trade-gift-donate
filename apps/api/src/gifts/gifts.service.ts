import { Injectable, ForbiddenException, NotFoundException, BadRequestException, Inject, Logger } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import type { Cache } from 'cache-manager';
import { PrismaService } from '../common/prisma.service';
import { GiftStatus, GiftType, GiftCategory, GiftRequestStatus, Prisma, NotificationType, NotificationPriority, ListingMediaType, KarmaEventType } from '@prisma/client';
import { normalizeListingMedia } from '../common/listing-media.util';
import { enrichListingPayloadForFeed } from '../common/listing-media-url.util';
import * as crypto from 'crypto';
import { NotificationsService } from '../notifications/notifications.service';
import { NearbyListingNotifierService } from '../notifications/nearby-listing-notifier.service';
import { EmailService } from '../common/email.service';
import { EmailLinkRouterService } from '../shared/services/email-link-router.service';
import { EmailEventName } from '../email/email-events';
import { MediaService } from '../storage/media.service';
import type { MediaDomain } from '../storage/media.service';
import {
  applyListingGeoFilter,
  buildListingMetadataWithCoords,
  hasListingGeoFilter,
  ListingGeoParams,
  paginateListingItems,
  requireListingLocation,
} from '../common/listing-location.util';
import { KarmaService } from '../karma/karma.service';
import { KarmaPointsConfigService } from '../karma/karma-points-config.service';
import { clampGiftReward } from '../karma/karma-points-config';

@Injectable()
export class GiftsService {
  private readonly logger = new Logger(GiftsService.name);

  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private nearbyNotifier: NearbyListingNotifierService,
    private email: EmailService,
    private emailLinkRouter: EmailLinkRouterService,
    private media: MediaService,
    private karmaService: KarmaService,
    private karmaPointsConfig: KarmaPointsConfigService,
    @Inject(CACHE_MANAGER) private cache: Cache,
  ) {}

  private static readonly giftListGenKey = 'gifts:list:generation';

  private async giftListCacheGeneration(): Promise<number> {
    return (await this.cache.get<number>(GiftsService.giftListGenKey)) ?? 0;
  }

  private async bumpGiftListCacheGeneration(): Promise<void> {
    const next = (await this.giftListCacheGeneration()) + 1;
    await this.cache.set(GiftsService.giftListGenKey, next, 86_400);
  }

  async createGift(giverId: string, data: {
    title: string;
    description?: string;
    type?: GiftType;
    category?: GiftCategory;
    mediaType?: string;
    mediaKeys?: string[];
    videoKey?: string;
    thumbnailKey?: string;
    karmaReward?: number;
    maxClaims?: number;
    location?: string;
    isLocationRestricted?: boolean;
    isChainGift?: boolean;
    chainParentId?: string;
    targetUserId?: string;
    targetCriteria?: any;
    minimumKarmaLevel?: string;
    tags?: string[];
    metadata?: any;
    latitude?: number;
    longitude?: number;
    expiresAt?: Date;
    isSeedingListing?: boolean;
  }) {
    // Validate targeted gift has target
    if (data.type === GiftType.TARGETED && !data.targetUserId && !data.targetCriteria) {
      throw new BadRequestException('Targeted gifts must specify a target user or criteria');
    }

    const location = requireListingLocation(data.location);

    // Generate unique gift code for claiming
    const giftCode = this.generateGiftCode();

    const domain: MediaDomain = 'gifts';
    const media = normalizeListingMedia({
      mediaType: data.mediaType,
      mediaKeys: data.mediaKeys,
      videoKey: data.videoKey,
    });
    let mediaKeys = media.mediaKeys;
    if (media.mediaType === ListingMediaType.IMAGE && mediaKeys.length > 0) {
      const dedup = await this.media.dedupeMediaKeys(giverId, domain, mediaKeys);
      mediaKeys = dedup.kept;
    }

    const pointsConfig = await this.karmaPointsConfig.getConfig();
    const karmaReward = clampGiftReward(data.karmaReward, pointsConfig);

    const thumbnailKey = await this.media.resolveListingThumbnailKey(
      giverId,
      domain,
      media,
      data.thumbnailKey,
    );

    const gift = await this.prisma.gift.create({
      data: {
        giverId,
        title: data.title,
        description: data.description,
        type: data.type || GiftType.RANDOM,
        category: data.category || GiftCategory.OTHERS,
        mediaType: media.mediaType,
        mediaKeys,
        videoKey: media.videoKey,
        thumbnailKey,
        karmaReward,
        maxClaims: data.maxClaims || 1,
        location,
        isLocationRestricted: data.isLocationRestricted || false,
        targetUserId: data.targetUserId,
        targetCriteria: data.targetCriteria,
        minimumKarmaLevel: data.minimumKarmaLevel,
        tags: data.tags || [],
        metadata: buildListingMetadataWithCoords(
          {
            ...(data.metadata ?? {}),
            ...(data.isSeedingListing ? { isSeedingListing: true } : {}),
          },
          data.latitude,
          data.longitude,
        ) as Prisma.InputJsonValue,
        expiresAt: data.expiresAt,
        isChainGift: data.isChainGift ?? false,
        chainParentId: data.chainParentId ?? null,
      },
      include: {
        giver: {
          select: {
            id: true,
            profile: {
              select: {
                displayName: true,
                avatarKey: true,
                bio: true
              }
            }
          }
        },
        targetUser: {
          select: {
            id: true,
            profile: {
              select: {
                displayName: true,
                avatarKey: true
              }
            }
          }
        }
      }
    });

    if (data.isSeedingListing) {
      try {
        const seedingPoints = (await this.karmaPointsConfig.getConfig()).seedingBonus;
        await this.karmaService.awardKarma(
          giverId,
          KarmaEventType.MANUAL_ADJUSTMENT,
          seedingPoints,
          'Ecosystem seeding gift listing bonus',
          { giftId: gift.id, isSeedingListing: true },
          gift.id,
          'gift',
        );
      } catch (error) {
        this.logger.error('Failed to award seeding karma for gift', error);
      }
    }

    await this.bumpGiftListCacheGeneration();

    // Public gifts only — skip seeding / targeted one-to-one gifts.
    const isTargeted = gift.type === GiftType.TARGETED;
    if (!data.isSeedingListing && !isTargeted) {
      void this.nearbyNotifier.notifyNearbyListing({
        kind: 'gift',
        listingId: gift.id,
        creatorId: giverId,
        title: gift.title,
        locationText: gift.location,
        metadata: gift.metadata,
      });
    }

    return gift;
  }

  async listGifts(params: { 
    query?: string; 
    category?: GiftCategory; 
    type?: GiftType;
    status?: GiftStatus;
    giverId?: string;
    location?: string;
    minKarma?: number;
    maxKarma?: number;
    sortBy?: string;
    sortOrder?: 'asc' | 'desc';
    page?: number; 
    size?: number;
    lat?: number;
    lng?: number;
    radiusKm?: number;
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

    const listGen = await this.giftListCacheGeneration();
    const cacheKey = `gifts:list:g${listGen}:${JSON.stringify({
      q: params.query || '',
      category: params.category || '',
      type: params.type || '',
      status: params.status || '',
      giverId: params.giverId || '',
      location: params.location || '',
      lat: params.lat ?? '',
      lng: params.lng ?? '',
      radiusKm: params.radiusKm ?? '',
      minKarma: params.minKarma ?? '',
      maxKarma: params.maxKarma ?? '',
      sortBy: params.sortBy || '',
      sortOrder: params.sortOrder || '',
      page,
      size,
    })}`;

    if (!geoActive) {
      const cached = await this.cache.get<{ items: any[]; page: number; size: number; total: number }>(cacheKey);
      if (cached) {
        return enrichListingPayloadForFeed(cached);
      }
    }

    const where: any = {};

    if (params.giverId) where.giverId = params.giverId;
    if (params.category) where.category = params.category;
    if (params.type) where.type = params.type;
    if (params.status) where.status = params.status;
    
    // Build search filters with proper OR combination
    const searchFilters: any[] = [];
    if (params.location && !geoActive) {
      searchFilters.push({
        OR: [
          { location: { contains: params.location, mode: 'insensitive' } },
          { isLocationRestricted: false }
        ]
      });
    }
    if (params.query) {
      searchFilters.push({
        OR: [
          { title: { contains: params.query, mode: 'insensitive' } },
          { description: { contains: params.query, mode: 'insensitive' } },
          { tags: { hasSome: [params.query] } }
        ]
      });
    }

    // Karma filtering
    if (params.minKarma !== undefined) {
      where.karmaReward = { gte: params.minKarma };
    }
    if (params.maxKarma !== undefined) {
      where.karmaReward = where.karmaReward 
        ? { ...where.karmaReward, lte: params.maxKarma }
        : { lte: params.maxKarma };
    }

    // Build AND conditions array
    const andConditions: any[] = [];

    // Filter out expired gifts by default
    if (!params.status) {
      andConditions.push({
        OR: [
          { expiresAt: null },
          { expiresAt: { gt: new Date() } }
        ]
      });
      andConditions.push({ status: GiftStatus.ACTIVE });
    }
    
    // Add search filters to AND conditions
    if (searchFilters.length > 0) {
      andConditions.push(...searchFilters);
    }

    // Apply all AND conditions
    if (andConditions.length > 0) {
      where.AND = andConditions;
    }

    // Sorting
    let orderBy: any = { createdAt: 'desc' };
    if (params.sortBy) {
      const orderDirection = params.sortOrder === 'asc' ? 'asc' : 'desc';
      switch (params.sortBy) {
        case 'karma':
          orderBy = { karmaReward: orderDirection };
          break;
        case 'claims':
          orderBy = { currentClaims: orderDirection };
          break;
        case 'expiresAt':
          orderBy = { expiresAt: orderDirection };
          break;
        default:
          orderBy = { createdAt: orderDirection };
      }
    }

    if (geoActive) {
      const rawItems = await this.prisma.gift.findMany({
        where,
        orderBy,
        take: 500,
        include: {
          giver: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                  bio: true
                }
              }
            }
          },
          claims: {
            select: {
              id: true,
              claimerId: true,
              claimedAt: true
            }
          }
        }
      });
      const filtered = applyListingGeoFilter(rawItems, geo);
      return enrichListingPayloadForFeed(paginateListingItems(filtered, page, size));
    }

    const [total, items] = await this.prisma.$transaction([
      this.prisma.gift.count({ where }),
      this.prisma.gift.findMany({ 
        where, 
        orderBy,
        skip: (page - 1) * size, 
        take: size,
        include: {
          giver: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                  bio: true
                }
              }
            }
          },
          claims: {
            select: {
              id: true,
              claimerId: true,
              claimedAt: true
            }
          }
        }
      }),
    ]);

    const payload = enrichListingPayloadForFeed({ items, page, size, total });
    if (!geoActive) {
      const ttlSeconds = Number(process.env.GIFT_FEED_CACHE_TTL_S ?? process.env.CACHE_TTL_SECONDS ?? 30);
      await this.cache.set(cacheKey, payload, ttlSeconds);
    }

    return payload;
  }

  async getGift(id: string) {
    const [gift, requestCount, likeCount] = await Promise.all([
      this.prisma.gift.findUnique({ 
        where: { id }, 
        include: { 
          giver: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                  bio: true
                }
              }
            }
          },
          targetUser: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true
                }
              }
            }
          },
          claims: {
            include: {
              claimer: {
                select: {
                  id: true,
                  profile: {
                    select: {
                      displayName: true,
                      avatarKey: true
                    }
                  }
                }
              }
            }
          }
        } 
      }),
      this.prisma.giftRequest.count({ where: { giftId: id } }),
      this.prisma.giftLike.count({ where: { giftId: id } }),
    ]);
    if (!gift) throw new NotFoundException('Gift not found');
    
    // Check if gift is expired and update status
    if (gift.expiresAt && new Date() > gift.expiresAt && gift.status === GiftStatus.ACTIVE) {
      await this.prisma.gift.update({
        where: { id },
        data: { status: GiftStatus.EXPIRED }
      });
      gift.status = GiftStatus.EXPIRED;
    }

    const meta = (gift.metadata as Record<string, unknown>) || {};
    const viewCount = (meta.viewCount as number) ?? 0;
    const metadataLikes = (meta.likes as number) ?? 0;
    return {
      ...gift,
      viewCount,
      likeCount: likeCount > 0 ? likeCount : metadataLikes,
      requestCount,
    };
  }

  async incrementGiftView(id: string) {
    const gift = await this.prisma.gift.findUnique({ where: { id } });
    if (!gift) throw new NotFoundException('Gift not found');
    const meta = (gift.metadata as Record<string, unknown>) || {};
    const current = (meta.viewCount as number) ?? 0;
    await this.prisma.gift.update({
      where: { id },
      data: {
        metadata: { ...meta, viewCount: current + 1 },
      },
    });
    return { viewCount: current + 1 };
  }

  async updateGift(currentUserId: string, id: string, data: {
    title?: string;
    description?: string;
    mediaType?: string;
    mediaKeys?: string[];
    videoKey?: string | null;
    thumbnailKey?: string | null;
    karmaReward?: number;
    maxClaims?: number;
    location?: string;
    tags?: string[];
    isChainGift?: boolean;
    chainParentId?: string | null;
    expiresAt?: Date;
  }) {
    const gift = await this.prisma.gift.findUnique({ where: { id } });
    if (!gift) throw new NotFoundException('Gift not found');
    if (gift.giverId !== currentUserId) throw new ForbiddenException('Only giver can update');
    if (gift.status !== GiftStatus.ACTIVE) throw new BadRequestException('Cannot update non-active gift');
    if (gift.currentClaims > 0) throw new BadRequestException('Cannot update gift that has been claimed');

    const payload: any = { ...data };
    delete payload.mediaType;
    delete payload.mediaKeys;
    delete payload.videoKey;
    delete payload.thumbnailKey;
    if (
      data.mediaType !== undefined ||
      data.mediaKeys !== undefined ||
      data.videoKey !== undefined ||
      data.thumbnailKey !== undefined
    ) {
      const domain: MediaDomain = 'gifts';
      const media = normalizeListingMedia({
        mediaType: data.mediaType ?? gift.mediaType,
        mediaKeys: data.mediaKeys ?? gift.mediaKeys,
        videoKey: data.videoKey !== undefined ? data.videoKey : gift.videoKey,
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
            : gift.thumbnailKey;
      } else if (media.mediaType === ListingMediaType.IMAGE) {
        payload.thumbnailKey = mediaKeys[0] ?? null;
      }
    }

    return this.prisma.gift.update({ 
      where: { id }, 
      data: payload,
      include: {
        giver: {
          select: {
            id: true,
            profile: {
              select: {
                displayName: true,
                avatarKey: true,
                bio: true
              }
            }
          }
        }
      }
    }).then(async (updated) => {
      await this.bumpGiftListCacheGeneration();
      return updated;
    });
  }

  async cancelGift(currentUserId: string, id: string) {
    const gift = await this.prisma.gift.findUnique({ where: { id } });
    if (!gift) throw new NotFoundException('Gift not found');
    if (gift.giverId !== currentUserId) throw new ForbiddenException('Only giver can cancel');
    if (gift.status !== GiftStatus.ACTIVE) throw new BadRequestException('Gift not active');
    if (gift.currentClaims > 0) throw new BadRequestException('Cannot cancel gift that has been claimed');

    const cancelled = await this.prisma.gift.update({ 
      where: { id }, 
      data: { status: GiftStatus.CANCELLED } 
    });
    await this.bumpGiftListCacheGeneration();
    return cancelled;
  }

  async deleteGift(currentUserId: string, id: string) {
    const gift = await this.prisma.gift.findUnique({
      where: { id },
      include: {
        claims: true,
        requests: true,
      },
    });
    if (!gift) throw new NotFoundException('Gift not found');
    if (gift.giverId !== currentUserId) throw new ForbiddenException('Only giver can delete');
    if (gift.status !== GiftStatus.ACTIVE) {
      throw new BadRequestException('Only active gifts can be deleted');
    }
    if (gift.currentClaims > 0 || gift.claims.length > 0) {
      throw new BadRequestException('Cannot delete a gift that has already been given');
    }

    const blockingRequest = gift.requests.find(
      (r) => r.status === GiftRequestStatus.PENDING || r.status === GiftRequestStatus.APPROVED,
    );
    if (blockingRequest) {
      throw new BadRequestException('Cannot delete a gift with pending or approved requests');
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.giftLike.deleteMany({ where: { giftId: id } });
      // Break reply chains before bulk delete (parentId FK has no cascade).
      await tx.giftComment.updateMany({ where: { giftId: id }, data: { parentId: null } });
      await tx.giftComment.deleteMany({ where: { giftId: id } });
      await tx.giftClaimBlock.deleteMany({ where: { giftId: id } });
      await tx.giftRequest.deleteMany({ where: { giftId: id } });
      await tx.giftClaim.deleteMany({ where: { giftId: id } });
      await tx.communityPost.updateMany({ where: { linkedGiftId: id }, data: { linkedGiftId: null } });
      await tx.gift.updateMany({ where: { chainParentId: id }, data: { chainParentId: null } });
      await tx.gift.delete({ where: { id } });
    });

    await this.bumpGiftListCacheGeneration();
    return { success: true, id };
  }

  async claimGift(claimerId: string, giftId: string, claimCode?: string, message?: string) {
    const gift = await this.prisma.gift.findUnique({ 
      where: { id: giftId },
      include: { 
        giver: true,
        claims: true 
      }
    });

    if (!gift) throw new NotFoundException('Gift not found');
    if (gift.giverId === claimerId) throw new ForbiddenException('Cannot claim own gift');
    if (gift.status !== GiftStatus.ACTIVE) throw new BadRequestException('Gift not available');
    if (gift.expiresAt && new Date() > gift.expiresAt) {
      await this.prisma.gift.update({
        where: { id: giftId },
        data: { status: GiftStatus.EXPIRED }
      });
      throw new BadRequestException('Gift has expired');
    }
    if (gift.currentClaims >= gift.maxClaims) throw new BadRequestException('Gift fully claimed');

    // Check if user is blocked from claiming this gift
    const block = await this.prisma.giftClaimBlock.findUnique({
      where: {
        giftId_userId: {
          giftId,
          userId: claimerId
        }
      }
    });

    if (block && new Date() < block.blockedUntil) {
      const daysRemaining = Math.ceil((block.blockedUntil.getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24));
      throw new BadRequestException(`You are blocked from claiming this gift. Please wait ${daysRemaining} more day(s). Reason: ${block.reason || 'Previous claim was declined'}`);
    }

    // Clean up expired block if exists
    if (block && new Date() >= block.blockedUntil) {
      await this.prisma.giftClaimBlock.delete({ where: { id: block.id } });
    }

    // Check if user already has a pending request for this gift
    const existingRequest = await this.prisma.giftRequest.findFirst({
      where: {
        giftId,
        requesterId: claimerId,
        status: GiftRequestStatus.PENDING
      }
    });
    if (existingRequest) throw new BadRequestException('Request already pending for this gift');

    // Enforce single pending claim per user across all gifts
    const otherPending = await this.prisma.giftRequest.findFirst({
      where: {
        requesterId: claimerId,
        status: GiftRequestStatus.PENDING,
        giftId: { not: giftId },
      }
    });
    if (otherPending) {
      throw new BadRequestException('You already have a pending gift claim. Please wait until it is approved or declined.');
    }

    // Check if user already claimed this gift
    const existingClaim = gift.claims.find(claim => claim.claimerId === claimerId);
    if (existingClaim) throw new BadRequestException('Gift already claimed by user');

    // For targeted gifts, check eligibility
    if (gift.type === GiftType.TARGETED) {
      if (gift.targetUserId && gift.targetUserId !== claimerId) {
        throw new ForbiddenException('Gift is targeted to another user');
      }
    }

    // Create a pending gift request instead of instant claim
    const request = await this.prisma.giftRequest.create({
      data: {
        giftId,
        requesterId: claimerId,
        message,
        status: GiftRequestStatus.PENDING,
      },
      include: {
        gift: {
          include: {
            giver: {
              select: {
                id: true,
                email: true,
                profile: {
                  select: {
                    displayName: true,
                    avatarKey: true
                  }
                }
              }
            }
          }
        },
        requester: {
          select: {
            id: true,
            profile: {
              select: {
                displayName: true,
                avatarKey: true
              }
            }
          }
        }
      }
    });

    try {
      const requesterName = request.requester?.profile?.displayName || 'Someone';
      await this.notifications.createNotification({
        userId: request.gift.giver.id,
        type: NotificationType.GIFT_RECEIVED,
        title: 'New Gift Request',
        message: `${requesterName} requested your gift "${request.gift.title}"`,
        actionUrl: '/gifting/requests',
        sourceId: request.giftId,
        sourceType: 'gift_request',
        priority: NotificationPriority.HIGH,
        data: {
          giftId: request.giftId,
          requestId: request.id,
          kind: 'gift_request',
        },
      });
      const giverEmail = request.gift.giver?.email;
      if (giverEmail) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.GiftOfferReceived,
          recipient: { email: giverEmail, userId: request.gift.giver.id },
          vars: {
            targetName: giverEmail,
            actorName: requesterName,
            giftTitle: request.gift.title,
            giftUrl: this.emailLinkRouter.getGiftLink(request.giftId),
          },
        });
      }
    } catch {
      // Non-blocking
    }

    return request;
  }

  async getMyGifts(userId: string, params: { page?: number; size?: number; status?: GiftStatus }) {
    const page = Math.max(params.page ?? 1, 1);
    const size = Math.min(Math.max(params.size ?? 20, 1), 100);
    const where: any = { giverId: userId };
    
    if (params.status) where.status = params.status;

    const [total, items] = await this.prisma.$transaction([
      this.prisma.gift.count({ where }),
      this.prisma.gift.findMany({ 
        where, 
        orderBy: { createdAt: 'desc' }, 
        skip: (page - 1) * size, 
        take: size,
        include: {
          claims: {
            include: {
              claimer: {
                select: {
                  id: true,
                  profile: {
                    select: {
                      displayName: true,
                      avatarKey: true
                    }
                  }
                }
              }
            }
          }
        }
      }),
    ]);

    return { items, page, size, total };
  }

  async getGiftHistory(userId: string, params: { page?: number; size?: number }) {
    const page = Math.max(params.page ?? 1, 1);
    const size = Math.min(Math.max(params.size ?? 20, 1), 100);

    // Get both gifts claimed by user AND gifts given by user that have been claimed
    const [claimedGifts, givenGifts] = await this.prisma.$transaction([
      // Gifts this user has claimed
      this.prisma.giftClaim.findMany({ 
        where: { claimerId: userId }, 
        orderBy: { claimedAt: 'desc' },
        include: {
          gift: {
            include: {
              giver: {
                select: {
                  id: true,
                  profile: {
                    select: {
                      displayName: true,
                      avatarKey: true
                    }
                  }
                }
              }
            }
          },
          claimer: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true
                }
              }
            }
          }
        }
      }),
      // Gifts this user has given that have been claimed
      this.prisma.giftClaim.findMany({ 
        where: { 
          gift: { giverId: userId }
        }, 
        orderBy: { claimedAt: 'desc' },
        include: {
          gift: {
            include: {
              giver: {
                select: {
                  id: true,
                  profile: {
                    select: {
                      displayName: true,
                      avatarKey: true
                    }
                  }
                }
              }
            }
          },
          claimer: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true
                }
              }
            }
          }
        }
      }),
    ]);

    // Combine and deduplicate (in case user claimed their own gift)
    const allClaims = [...claimedGifts, ...givenGifts];
    const uniqueClaims = Array.from(
      new Map(allClaims.map(claim => [claim.id, claim])).values()
    );

    // Sort by claimed date descending
    uniqueClaims.sort((a, b) => b.claimedAt.getTime() - a.claimedAt.getTime());

    // Paginate
    const total = uniqueClaims.length;
    const items = uniqueClaims.slice((page - 1) * size, page * size);

    return { items, page, size, total };
  }

  private generateGiftCode(): string {
    return crypto.randomBytes(8).toString('hex').toUpperCase();
  }

  private generateClaimCode(): string {
    return crypto.randomBytes(16).toString('hex');
  }

  // Gift Request Management Methods
  async listGiftRequests(userId: string, params: { page?: number; size?: number; status?: GiftRequestStatus }) {
    const page = Math.max(params.page ?? 1, 1);
    const size = Math.min(Math.max(params.size ?? 20, 1), 100);
    
    // Fetch requests made by user AND requests for user's gifts
    // We need to get all gifts owned by this user first
    const userGifts = await this.prisma.gift.findMany({
      where: { giverId: userId },
      select: { id: true }
    });
    const userGiftIds = userGifts.map(g => g.id);

    // Build where clause
    const orConditions: any[] = [
      { requesterId: userId }, // Requests made by user
    ];
    
    if (userGiftIds.length > 0) {
      orConditions.push({ giftId: { in: userGiftIds } }); // Requests for user's gifts
    }

    const where: any = {
      OR: orConditions
    };
    
    if (params.status) {
      where.status = params.status;
    }

    const [total, items] = await this.prisma.$transaction([
      this.prisma.giftRequest.count({ where }),
      this.prisma.giftRequest.findMany({ 
        where, 
        orderBy: { createdAt: 'desc' }, 
        skip: (page - 1) * size, 
        take: size,
        include: {
          gift: {
            include: {
              giver: {
                select: {
                  id: true,
                  profile: {
                    select: {
                      displayName: true,
                      avatarKey: true
                    }
                  }
                }
              }
            }
          },
          requester: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true
                }
              }
            }
          }
        }
      }),
    ]);

    return { items, page, size, total };
  }

  async approveGiftRequest(currentUserId: string, requestId: string, responseMessage?: string) {
    const request = await this.prisma.giftRequest.findUnique({
      where: { id: requestId },
      include: {
        gift: {
          include: { giver: { include: { profile: true } } }
        },
        requester: true
      }
    });

    if (!request) throw new NotFoundException('Gift request not found');
    if (request.gift.giverId !== currentUserId) throw new ForbiddenException('Only gift owner can approve');
    if (request.status !== GiftRequestStatus.PENDING) throw new BadRequestException('Request already processed');

    // Check if gift is still available
    if (request.gift.status !== GiftStatus.ACTIVE) {
      throw new BadRequestException('Gift is no longer available');
    }
    if (request.gift.currentClaims >= request.gift.maxClaims) {
      throw new BadRequestException('Gift already fully claimed');
    }

    const code = this.generateClaimCode();

    return this.prisma.$transaction(async (tx) => {
      // Update request status
      await tx.giftRequest.update({
        where: { id: requestId },
        data: {
          status: GiftRequestStatus.APPROVED,
          respondedAt: new Date(),
          responseMessage
        }
      });

      // Create the claim
      const claim = await tx.giftClaim.create({
        data: {
          giftId: request.giftId,
          claimerId: request.requesterId,
          code,
          karmaAwarded: request.gift.karmaReward,
        },
        include: {
          gift: {
            include: {
              giver: {
                select: {
                  id: true,
                  profile: {
                    select: {
                      displayName: true,
                      avatarKey: true
                    }
                  }
                }
              }
            }
          },
          claimer: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true
                }
              }
            }
          }
        }
      });

      // Update gift claim count and status
      const updatedCurrentClaims = request.gift.currentClaims + 1;
      const newStatus = updatedCurrentClaims >= request.gift.maxClaims ? GiftStatus.CLAIMED : GiftStatus.ACTIVE;

      await tx.gift.update({
        where: { id: request.giftId },
        data: { 
          currentClaims: updatedCurrentClaims,
          status: newStatus
        }
      });

      // Award karma to claimer when claim is approved
      try {
        const giftKarma = request.gift.karmaReward;
        if (giftKarma > 0) {
          await this.karmaService.awardKarma(
            request.requesterId,
            KarmaEventType.GIFT_CLAIMED,
            giftKarma,
            `Claimed gift "${request.gift.title}"`,
            { giftId: request.giftId, claimId: claim.id },
            claim.id,
            'gift_claim',
          );
        }
      } catch (error) {
        this.logger.error('Failed to award gift claim karma', error);
      }

      try {
        const giverName = request.gift.giver?.profile?.displayName || 'Someone';
        await this.notifications.createNotification({
          userId: request.requesterId,
          type: NotificationType.GIFT_CLAIMED,
          title: 'Gift Claim Approved',
          message: `${giverName} approved your claim for "${request.gift.title}"`,
          actionUrl: `/gifts/${request.giftId}`,
          sourceId: request.giftId,
          sourceType: 'gift',
          priority: NotificationPriority.HIGH,
          data: { giftId: request.giftId, claimId: claim.id },
        });
        const requester = await this.prisma.user.findUnique({ where: { id: request.requesterId } });
        if (requester?.email) {
          this.email.dispatchInBackground({
            eventName: EmailEventName.GiftAccepted,
            recipient: { email: requester.email, userId: requester.id },
            vars: {
              actorName: giverName,
              targetName: requester.email,
              giftTitle: request.gift.title,
              giftUrl: this.emailLinkRouter.getGiftLink(request.giftId),
            },
          });
          this.email.dispatchInBackground({
            eventName: EmailEventName.GiftClaimed,
            recipient: { email: requester.email, userId: requester.id },
            vars: {
              actorName: giverName,
              targetName: requester.email,
              giftTitle: request.gift.title,
              claimedAt: new Date().toISOString(),
              giftUrl: this.emailLinkRouter.getGiftLink(request.giftId),
            },
          });
        }
      } catch {
        // Non-blocking
      }

      return { request, claim, code };
    });
  }

  async declineGiftRequest(currentUserId: string, requestId: string, declineReason?: string) {
    const request = await this.prisma.giftRequest.findUnique({
      where: { id: requestId },
      include: {
        gift: {
          include: { giver: { include: { profile: true } } }
        }
      }
    });

    if (!request) throw new NotFoundException('Gift request not found');
    if (request.gift.giverId !== currentUserId) throw new ForbiddenException('Only gift owner can decline');
    if (request.status !== GiftRequestStatus.PENDING) throw new BadRequestException('Request already processed');

    return this.prisma.$transaction(async (tx) => {
      // Update request status
      const updated = await tx.giftRequest.update({
        where: { id: requestId },
        data: {
          status: GiftRequestStatus.DECLINED,
          respondedAt: new Date(),
          declineReason
        },
        include: {
          gift: {
            include: {
              giver: {
                select: {
                  id: true,
                  profile: {
                    select: {
                      displayName: true,
                      avatarKey: true
                    }
                  }
                }
              }
            }
          },
          requester: {
            select: {
              id: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true
                }
              }
            }
          }
        }
      });

      // Create 7-day block for the requester
      const blockedUntil = new Date();
      blockedUntil.setDate(blockedUntil.getDate() + 7);

      await tx.giftClaimBlock.upsert({
        where: {
          giftId_userId: {
            giftId: request.giftId,
            userId: request.requesterId
          }
        },
        create: {
          giftId: request.giftId,
          userId: request.requesterId,
          blockedUntil,
          reason: declineReason || 'Your claim was declined by the gift owner'
        },
        update: {
          blockedUntil,
          reason: declineReason || 'Your claim was declined by the gift owner'
        }
      });

      try {
        const giverName = request.gift.giver?.profile?.displayName || 'Someone';
        await this.notifications.createNotification({
          userId: request.requesterId,
          type: NotificationType.GIFT_RECEIVED,
          title: 'Gift Request Declined',
          message: `${giverName} declined your request for "${request.gift.title}"`,
          actionUrl: `/gifts/${request.giftId}`,
          sourceId: request.giftId,
          sourceType: 'gift',
          priority: NotificationPriority.NORMAL,
          data: { giftId: request.giftId, requestId: request.id, kind: 'gift_request' },
        });
      } catch {
        // Non-blocking
      }

      return updated;
    });
  }

  /**
   * Expire PENDING gift requests older than the cutoff date (e.g. 2 days).
   * Called by cron job when owner does not approve/decline within the timeout.
   */
  async expireStaleGiftRequests(cutoff: Date): Promise<number> {
    const stale = await this.prisma.giftRequest.findMany({
      where: {
        status: GiftRequestStatus.PENDING,
        createdAt: { lt: cutoff },
      },
      include: {
        gift: { include: { giver: { select: { profile: { select: { displayName: true } } } } } },
      },
    });

    if (stale.length === 0) return 0;

    await this.prisma.giftRequest.updateMany({
      where: {
        id: { in: stale.map((r) => r.id) },
      },
      data: {
        status: GiftRequestStatus.EXPIRED,
        respondedAt: new Date(),
      },
    });

    for (const req of stale) {
      try {
        const giverName = (req.gift.giver?.profile as any)?.displayName || 'The gift owner';
        await this.notifications.createNotification({
          userId: req.requesterId,
          type: NotificationType.GIFT_EXPIRED,
          title: 'Gift Request Expired',
          message: `Your request for "${req.gift.title}" expired. ${giverName} did not respond within the time limit.`,
          actionUrl: `/gifts/${req.giftId}`,
          sourceId: req.giftId,
          sourceType: 'gift',
          priority: NotificationPriority.NORMAL,
          data: { giftId: req.giftId, requestId: req.id, kind: 'gift_request' },
        });
      } catch {
        // Non-blocking
      }
    }

    return stale.length;
  }

  async shareGift(userId: string, giftId: string, platform: string, message?: string) {
    // Increment share count for the gift
    const gift = await this.prisma.gift.findUnique({
      where: { id: giftId }
    });

    if (!gift) {
      throw new NotFoundException('Gift not found');
    }

    // In a real implementation, this would integrate with social platforms
    // For now, we'll just increment a share counter in metadata
    const currentMetadata = gift.metadata as Record<string, any> || {};
    const shareCounts = currentMetadata.shareCounts || {};
    shareCounts[platform] = (shareCounts[platform] || 0) + 1;
    
    const updatedGift = await this.prisma.gift.update({
      where: { id: giftId },
      data: {
        metadata: {
          ...currentMetadata,
          shareCounts
        }
      }
    });

    return {
      success: true,
      message: `Gift shared on ${platform}`,
      gift: updatedGift
    };
  }

  async getGiftComments(giftId: string, page: number, size: number) {
    const gift = await this.prisma.gift.findUnique({ where: { id: giftId } });
    if (!gift) throw new NotFoundException('Gift not found');
    const [total, items] = await Promise.all([
      this.prisma.giftComment.count({ where: { giftId, parentId: null } }),
      this.prisma.giftComment.findMany({
        where: { giftId, parentId: null },
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

  async addComment(userId: string, giftId: string, content: string, parentId?: string) {
    const gift = await this.prisma.gift.findUnique({ where: { id: giftId } });
    if (!gift) throw new NotFoundException('Gift not found');
    if (!content?.trim()) throw new BadRequestException('Comment content is required');
    const comment = await this.prisma.giftComment.create({
      data: { giftId, authorId: userId, content: content.trim(), parentId: parentId || null },
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

  async updateComment(userId: string, giftId: string, commentId: string, content: string) {
    if (!content?.trim()) throw new BadRequestException('Comment content is required');
    const comment = await this.prisma.giftComment.findUnique({ where: { id: commentId } });
    if (!comment || comment.giftId !== giftId) throw new NotFoundException('Comment not found');
    if (comment.authorId !== userId) throw new ForbiddenException('You can only edit your own comments');
    const updated = await this.prisma.giftComment.update({
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

  async likeGift(userId: string, giftId: string) {
    // Verify gift exists
    const gift = await this.prisma.gift.findUnique({
      where: { id: giftId }
    });

    if (!gift) {
      throw new NotFoundException('Gift not found');
    }
    // Increment like count on gift metadata only
    const updated = await this.prisma.gift.update({
      where: { id: giftId },
      data: {
        metadata: {
          ...(gift.metadata as Record<string, any> || {}),
          likes: ((gift.metadata as Record<string, any>)?.likes || 0) + 1
        }
      }
    });
    return { success: true, likes: (updated.metadata as any)?.likes ?? 0 };
  }

  async unlikeGift(userId: string, giftId: string) {
    // Verify gift exists
    const gift = await this.prisma.gift.findUnique({
      where: { id: giftId }
    });

    if (!gift) {
      throw new NotFoundException('Gift not found');
    }
    // Decrement like count on gift metadata only
    const updated = await this.prisma.gift.update({
      where: { id: giftId },
      data: {
        metadata: {
          ...(gift.metadata as Record<string, any> || {}),
          likes: Math.max(((gift.metadata as Record<string, any>)?.likes || 1) - 1, 0)
        }
      }
    });
    return { success: true, likes: (updated.metadata as any)?.likes ?? 0 };
  }

  async getSimilarGifts(giftId: string, limit = 8) {
    const gift = await this.prisma.gift.findUnique({
      where: { id: giftId },
      select: { category: true, type: true, giverId: true },
    });
    if (!gift) return [];
    const similar = await this.prisma.gift.findMany({
      where: {
        id: { not: giftId },
        status: GiftStatus.ACTIVE,
        category: gift.category,
        type: gift.type,
        OR: [
          { expiresAt: null },
          { expiresAt: { gt: new Date() } },
        ],
      },
      take: limit,
      orderBy: [{ currentClaims: 'desc' }, { createdAt: 'desc' }],
      include: {
        giver: {
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
        claims: {
          select: { id: true, claimerId: true, claimedAt: true },
        },
      },
    });
    return similar;
  }

  async getRecommendedGifts(userId: string) {
    // Get user's gift history to understand preferences
    const userClaims = await this.prisma.giftClaim.findMany({
      where: { claimerId: userId },
      include: { gift: true }
    });

    // Get user's created gifts
    const userGifts = await this.prisma.gift.findMany({
      where: { giverId: userId }
    });

    // Extract preferred categories and types
    const claimedCategories = userClaims.map(c => c.gift.category);
    const claimedTypes = userClaims.map(c => c.gift.type);
    const givenCategories = userGifts.map(g => g.category);
    const givenTypes = userGifts.map(g => g.type);

    // Combine and count preferences
    const categoryPreferences = [...claimedCategories, ...givenCategories]
      .reduce((acc, category) => {
        acc[category] = (acc[category] || 0) + 1;
        return acc;
      }, {} as Record<string, number>);

    const typePreferences = [...claimedTypes, ...givenTypes]
      .reduce((acc, type) => {
        acc[type] = (acc[type] || 0) + 1;
        return acc;
      }, {} as Record<string, number>);

    // Find top preferences
    const topCategories = Object.entries(categoryPreferences)
      .sort(([,a], [,b]) => b - a)
      .slice(0, 3)
      .map(([category]) => category);

    const topTypes = Object.entries(typePreferences)
      .sort(([,a], [,b]) => b - a)
      .slice(0, 3)
      .map(([type]) => type);

    // Build recommendation query
    const where: any = {
      status: 'ACTIVE',
      giverId: { not: userId }, // Don't recommend user's own gifts
      OR: [
        { category: { in: topCategories } },
        { type: { in: topTypes } }
      ]
    };

    // Get recommended gifts
    const recommendations = await this.prisma.gift.findMany({
      where,
      take: 10,
      orderBy: [
        { currentClaims: 'desc' }, // Popular gifts first
        { createdAt: 'desc' }       // Recent gifts second
      ],
      include: {
        giver: {
          select: {
            id: true,
            profile: {
              select: {
                displayName: true,
                avatarKey: true,
                bio: true
              }
            }
          }
        },
        claims: {
          select: {
            id: true,
            claimerId: true,
            claimedAt: true
          }
        }
      }
    });

    return recommendations;
  }

  async getUserGiftAnalytics(userId: string) {
    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    
    const [
      totalGiftsGiven,
      totalGiftsReceived,
      totalKarmaEarned,
      avgRating,
      categoryBreakdown,
      monthlyGifts,
    ] = await this.prisma.$transaction([
      // Total gifts given by user
      this.prisma.gift.count({
        where: { giverId: userId }
      }),
      // Total gifts received by user
      this.prisma.giftClaim.count({
        where: { claimerId: userId }
      }),
      // Total karma earned by user
      this.prisma.giftClaim.aggregate({
        _sum: { karmaAwarded: true },
        where: { claimerId: userId }
      }),
      // Average rating of gifts given by user
      this.prisma.giftClaim.aggregate({
        _avg: { rating: true },
        where: { gift: { giverId: userId } }
      }),
      // Category breakdown of gifts given
      this.prisma.gift.groupBy({
        by: ['category'],
        where: { giverId: userId },
        _count: { category: true },
        orderBy: { _count: { category: 'desc' } },
      }),
      // Monthly gifts given in the last 30 days
      this.prisma.gift.groupBy({
        by: ['createdAt'],
        where: { 
          giverId: userId,
          createdAt: { gte: thirtyDaysAgo }
        },
        _count: true,
        orderBy: { createdAt: 'asc' },
      }),
    ]);

    // Format the data for the frontend
    const categoryBreakdownMap = categoryBreakdown.reduce((acc, item) => {
      acc[item.category] = (item._count as { category: number }).category;
      return acc;
    }, {} as Record<string, number>);

    const monthlyGiftsMap = monthlyGifts.reduce((acc, item) => {
      const dateStr = new Date(item.createdAt).toISOString().split('T')[0];
      acc[dateStr] = item._count as number;
      return acc;
    }, {} as Record<string, number>);

    return {
      totalGiftsGiven,
      totalGiftsReceived,
      totalKarmaEarned: totalKarmaEarned._sum.karmaAwarded || 0,
      averageRating: avgRating._avg.rating || 0,
      totalViews: 0, // TODO: Implement view tracking
      totalRequests: 0, // TODO: Implement request tracking
      categoryBreakdown: categoryBreakdownMap,
      monthlyGifts: monthlyGiftsMap,
    };
  }
}
