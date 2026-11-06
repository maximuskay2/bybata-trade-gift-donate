import { Injectable, ForbiddenException, NotFoundException, BadRequestException, Inject } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import type { Cache } from 'cache-manager';
import { PrismaService } from '../common/prisma.service';
import { CampaignStatus, TxStatus, Prisma, NotificationType, NotificationPriority, KarmaEventType, ListingMediaType } from '@prisma/client';
import { normalizeListingMedia } from '../common/listing-media.util';
import { enrichListingPayloadForFeed } from '../common/listing-media-url.util';
import * as crypto from 'crypto';
import { WalletService } from '../wallet/wallet.service';
import { ChatGateway } from '../chat/chat.gateway';
import { NotificationsService } from '../notifications/notifications.service';
import { NearbyListingNotifierService } from '../notifications/nearby-listing-notifier.service';
import { EmailService } from '../common/email.service';
import { EmailLinkRouterService } from '../shared/services/email-link-router.service';
import { EmailEventName } from '../email/email-events';
import { MediaService } from '../storage/media.service';
import type { MediaDomain } from '../storage/media.service';
import {
  formatDate,
  formatShortDate,
  renderReceiptDocument,
} from '../common/receipt-pdf.util';
import { ReferralsService } from '../referrals/referrals.service';
import { StorageService } from '../storage/storage.service';
import { KarmaService } from '../karma/karma.service';
import { KarmaPointsConfigService } from '../karma/karma-points-config.service';
import { calculateDonationKarmaFromConfig } from '../karma/karma-points-config';
import {
  applyListingGeoFilter,
  buildListingMetadataWithCoords,
  hasListingGeoFilter,
  ListingGeoParams,
  paginateListingItems,
  requireListingLocation,
} from '../common/listing-location.util';

/** Karma earned when donating BYC — percent of amount (default 10% → 10 BYC = 1 karma). */
export function calculateDonationKarmaReward(
  amount: number,
  percent = 10,
): number {
  return calculateDonationKarmaFromConfig(amount, percent);
}

@Injectable()
export class CampaignsService {
  constructor(
    private prisma: PrismaService,
    private wallet: WalletService,
    private chatGateway: ChatGateway,
    private notifications: NotificationsService,
    private nearbyNotifier: NearbyListingNotifierService,
    private email: EmailService,
    private emailLinkRouter: EmailLinkRouterService,
    private media: MediaService,
    private storage: StorageService,
    private referralsService: ReferralsService,
    private karmaService: KarmaService,
    private karmaPointsConfig: KarmaPointsConfigService,
    @Inject(CACHE_MANAGER) private cache: Cache,
  ) {}

  private static readonly campaignListGenKey = 'campaigns:list:generation';

  private async campaignListCacheGeneration(): Promise<number> {
    return (await this.cache.get<number>(CampaignsService.campaignListGenKey)) ?? 0;
  }

  private async bumpCampaignListCacheGeneration(): Promise<void> {
    const next = (await this.campaignListCacheGeneration()) + 1;
    await this.cache.set(CampaignsService.campaignListGenKey, next, 86_400);
  }

  async createCampaign(founderId: string, data: {
    title: string;
    description?: string;
    shortDescription?: string;
    category?: string;
    goalAmount: number;
    currency?: string;
    mediaType?: string;
    mediaKeys?: string[];
    videoKey?: string;
    thumbnailKey?: string;
    tags?: string[];
    location?: string;
    isUrgent?: boolean;
    minimumDonation?: number;
    endsAt?: Date;
    metadata?: any;
    latitude?: number;
    longitude?: number;
  }) {
    // Validate goal amount
    if (data.goalAmount <= 0) {
      throw new BadRequestException('Goal amount must be greater than 0');
    }

    // Validate minimum donation if provided
    if (data.minimumDonation && data.minimumDonation <= 0) {
      throw new BadRequestException('Minimum donation must be greater than 0');
    }

    const location = requireListingLocation(data.location);

    const domain: MediaDomain = 'donations';
    const media = normalizeListingMedia({
      mediaType: data.mediaType,
      mediaKeys: data.mediaKeys,
      videoKey: data.videoKey,
    });
    let mediaKeys = media.mediaKeys;
    if (media.mediaType === ListingMediaType.IMAGE && mediaKeys.length > 0) {
      const dedup = await this.media.dedupeMediaKeys(founderId, domain, mediaKeys);
      mediaKeys = dedup.kept;
    }

    const thumbnailKey = await this.media.resolveListingThumbnailKey(
      founderId,
      domain,
      media,
      data.thumbnailKey,
    );

    const campaign = await this.prisma.campaign.create({
      data: {
        founderId,
        title: data.title,
        description: data.description,
        shortDescription: data.shortDescription,
        category: data.category,
        goalAmount: new Prisma.Decimal(data.goalAmount),
        currency: data.currency || 'BYC',
        mediaType: media.mediaType,
        mediaKeys,
        videoKey: media.videoKey,
        thumbnailKey,
        tags: data.tags || [],
        location,
        isUrgent: data.isUrgent || false,
        minimumDonation: data.minimumDonation ? new Prisma.Decimal(data.minimumDonation) : null,
        endsAt: data.endsAt,
        metadata: buildListingMetadataWithCoords(
          data.metadata,
          data.latitude,
          data.longitude,
        ) as Prisma.InputJsonValue,
      },
      include: {
        founder: {
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
        donations: {
          include: {
            donor: {
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
    });
    try {
      const founder = await this.prisma.user.findUnique({
        where: { id: founderId },
        select: { email: true, profile: { select: { displayName: true } } },
      });
      if (founder?.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.CampaignCreated,
          recipient: { email: founder.email, userId: founderId },
          vars: {
            actorName: founder.profile?.displayName || founder.email,
            campaignTitle: campaign.title,
            campaignUrl: this.emailLinkRouter.getCampaignLink(campaign.id),
          },
        });
      }
    } catch {
      // Non-blocking
    }
    await this.bumpCampaignListCacheGeneration();
    return campaign;
  }

  async listCampaigns(params: {
    query?: string;
    category?: string;
    status?: CampaignStatus;
    founderId?: string;
    location?: string;
    isUrgent?: boolean;
    isFeatured?: boolean;
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

    const listGen = await this.campaignListCacheGeneration();
    const cacheKey = `campaigns:list:g${listGen}:${JSON.stringify({
      q: params.query || '',
      category: params.category || '',
      status: params.status || '',
      founderId: params.founderId || '',
      location: params.location || '',
      lat: params.lat ?? '',
      lng: params.lng ?? '',
      radiusKm: params.radiusKm ?? '',
      isUrgent: params.isUrgent ?? '',
      isFeatured: params.isFeatured ?? '',
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

    if (params.founderId) where.founderId = params.founderId;
    if (params.category) where.category = params.category;
    if (params.status) where.status = params.status;
    if (params.isUrgent !== undefined) where.isUrgent = params.isUrgent;
    if (params.isFeatured !== undefined) where.isFeatured = params.isFeatured;
    if (params.location && !geoActive) {
      where.location = { contains: params.location, mode: 'insensitive' };
    }
    if (params.query) {
      where.OR = [
        { title: { contains: params.query, mode: 'insensitive' } },
        { description: { contains: params.query, mode: 'insensitive' } },
        { shortDescription: { contains: params.query, mode: 'insensitive' } },
        { tags: { hasSome: [params.query] } }
      ];
    }

    // Only show active campaigns by default (unless specifically filtering by status)
    if (!params.status && !params.founderId) {
      where.status = CampaignStatus.ACTIVE;
    }

    if (geoActive) {
      const rawItems = await this.prisma.campaign.findMany({
        where,
        orderBy: [
          { isFeatured: 'desc' },
          { isUrgent: 'desc' },
          { createdAt: 'desc' }
        ],
        take: 500,
        include: {
          founder: {
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
          donations: {
            select: {
              id: true,
              amount: true,
              isAnonymous: true,
              createdAt: true,
              donor: {
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
            },
            take: 3,
            orderBy: { createdAt: 'desc' }
          }
        }
      });
      const filtered = applyListingGeoFilter(rawItems, geo);
      return enrichListingPayloadForFeed(paginateListingItems(filtered, page, size));
    }

    const [total, items] = await this.prisma.$transaction([
      this.prisma.campaign.count({ where }),
      this.prisma.campaign.findMany({
        where,
        orderBy: [
          { isFeatured: 'desc' },
          { isUrgent: 'desc' },
          { createdAt: 'desc' }
        ],
        skip: (page - 1) * size,
        take: size,
        include: {
          founder: {
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
          donations: {
            select: {
              id: true,
              amount: true,
              isAnonymous: true,
              createdAt: true,
              donor: {
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
            },
            orderBy: { createdAt: 'desc' },
            take: 5
          }
        }
      })
    ]);

    const payload = enrichListingPayloadForFeed({ items, page, size, total });
    if (!geoActive) {
      const ttlSeconds = Number(process.env.CAMPAIGN_FEED_CACHE_TTL_S ?? process.env.CACHE_TTL_SECONDS ?? 30);
      await this.cache.set(cacheKey, payload, ttlSeconds);
    }

    return payload;
  }

  async getCampaign(id: string) {
    const campaign = await this.prisma.campaign.findUnique({
      where: { id },
      include: {
        founder: {
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
        donations: {
          include: {
            donor: {
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
          },
          orderBy: { createdAt: 'desc' }
        }
      }
    });

    if (!campaign) throw new NotFoundException('Campaign not found');

    // Increment view count
    await this.prisma.campaign.update({
      where: { id },
      data: { viewCount: { increment: 1 } }
    });

    const meta = (campaign.metadata as Record<string, unknown>) || {};
    const likeCount = (meta.likes as number) ?? 0;
    return { ...campaign, likeCount };
  }

  async likeCampaign(_userId: string, campaignId: string) {
    const campaign = await this.prisma.campaign.findUnique({ where: { id: campaignId } });
    if (!campaign) throw new NotFoundException('Campaign not found');
    const meta = (campaign.metadata as Record<string, any>) || {};
    const updated = await this.prisma.campaign.update({
      where: { id: campaignId },
      data: {
        metadata: {
          ...meta,
          likes: (meta.likes || 0) + 1,
        },
      },
    });
    return { success: true, likes: (updated.metadata as any)?.likes ?? 0 };
  }

  async unlikeCampaign(_userId: string, campaignId: string) {
    const campaign = await this.prisma.campaign.findUnique({ where: { id: campaignId } });
    if (!campaign) throw new NotFoundException('Campaign not found');
    const meta = (campaign.metadata as Record<string, any>) || {};
    const updated = await this.prisma.campaign.update({
      where: { id: campaignId },
      data: {
        metadata: {
          ...meta,
          likes: Math.max((meta.likes || 1) - 1, 0),
        },
      },
    });
    return { success: true, likes: (updated.metadata as any)?.likes ?? 0 };
  }

  async getCampaignComments(campaignId: string, page: number, size: number) {
    const campaign = await this.prisma.campaign.findUnique({ where: { id: campaignId } });
    if (!campaign) throw new NotFoundException('Campaign not found');
    const [total, items] = await Promise.all([
      this.prisma.campaignComment.count({ where: { campaignId, parentId: null } }),
      this.prisma.campaignComment.findMany({
        where: { campaignId, parentId: null },
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

  async addCampaignComment(userId: string, campaignId: string, content: string, parentId?: string) {
    const campaign = await this.prisma.campaign.findUnique({ where: { id: campaignId } });
    if (!campaign) throw new NotFoundException('Campaign not found');
    if (!content?.trim()) throw new BadRequestException('Comment content is required');
    const comment = await this.prisma.campaignComment.create({
      data: { campaignId, authorId: userId, content: content.trim(), parentId: parentId || null },
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

  async updateCampaignComment(userId: string, campaignId: string, commentId: string, content: string) {
    if (!content?.trim()) throw new BadRequestException('Comment content is required');
    const comment = await this.prisma.campaignComment.findUnique({ where: { id: commentId } });
    if (!comment || comment.campaignId !== campaignId) throw new NotFoundException('Comment not found');
    if (comment.authorId !== userId) throw new ForbiddenException('You can only edit your own comments');
    const updated = await this.prisma.campaignComment.update({
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

  async updateCampaign(currentUserId: string, id: string, data: {
    title?: string;
    description?: string;
    shortDescription?: string;
    category?: string;
    goalAmount?: number;
    mediaType?: string;
    mediaKeys?: string[];
    videoKey?: string | null;
    thumbnailKey?: string;
    tags?: string[];
    location?: string;
    isUrgent?: boolean;
    minimumDonation?: number;
    endsAt?: Date;
    metadata?: any;
  }) {
    const campaign = await this.prisma.campaign.findUnique({ where: { id } });
    if (!campaign) throw new NotFoundException('Campaign not found');
    if (campaign.founderId !== currentUserId) throw new ForbiddenException('Only founder can update');
    
    // Can't update completed or cancelled campaigns
    if (campaign.status === CampaignStatus.COMPLETED || campaign.status === CampaignStatus.CANCELLED) {
      throw new BadRequestException('Cannot update completed or cancelled campaign');
    }

    // Validate goal amount if provided
    if (data.goalAmount && data.goalAmount <= 0) {
      throw new BadRequestException('Goal amount must be greater than 0');
    }

    // Can't reduce goal amount below current amount if campaign is active
    if (data.goalAmount && campaign.status === CampaignStatus.ACTIVE) {
      const goalAmount = new Prisma.Decimal(data.goalAmount);
      if (goalAmount.lt(campaign.currentAmount)) {
        throw new BadRequestException('Cannot reduce goal amount below current donation amount');
      }
    }

    const payload: any = {};
    if (data.title !== undefined) payload.title = data.title;
    if (data.description !== undefined) payload.description = data.description;
    if (data.shortDescription !== undefined) payload.shortDescription = data.shortDescription;
    if (data.category !== undefined) payload.category = data.category;
    if (data.thumbnailKey !== undefined) payload.thumbnailKey = data.thumbnailKey;
    if (data.tags !== undefined) payload.tags = data.tags;
    if (data.location !== undefined) payload.location = data.location;
    if (data.isUrgent !== undefined) payload.isUrgent = data.isUrgent;
    if (data.endsAt !== undefined) payload.endsAt = data.endsAt;
    if (data.metadata !== undefined) payload.metadata = data.metadata;

    if (
      data.mediaType !== undefined ||
      data.mediaKeys !== undefined ||
      data.videoKey !== undefined
    ) {
      const domain: MediaDomain = 'donations';
      const media = normalizeListingMedia({
        mediaType: data.mediaType ?? campaign.mediaType,
        mediaKeys: data.mediaKeys ?? campaign.mediaKeys,
        videoKey: data.videoKey !== undefined ? data.videoKey : campaign.videoKey,
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
            : campaign.thumbnailKey;
      } else if (mediaKeys.length > 0 && data.thumbnailKey === undefined) {
        payload.thumbnailKey = mediaKeys[0];
      }
    }

    const updated = await this.prisma.campaign.update({
      where: { id },
      data: {
        ...payload,
        goalAmount: data.goalAmount ? new Prisma.Decimal(data.goalAmount) : undefined,
        minimumDonation: data.minimumDonation ? new Prisma.Decimal(data.minimumDonation) : undefined,
      },
      include: {
        founder: {
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
    });
    await this.bumpCampaignListCacheGeneration();
    return updated;
  }

  async updateCampaignStatus(currentUserId: string, id: string, status: CampaignStatus) {
    const campaign = await this.prisma.campaign.findUnique({ where: { id } });
    if (!campaign) throw new NotFoundException('Campaign not found');
    if (campaign.founderId !== currentUserId) throw new ForbiddenException('Only founder can update status');

    // Validate status transitions
    const validTransitions: Record<CampaignStatus, CampaignStatus[]> = {
      [CampaignStatus.DRAFT]: [CampaignStatus.ACTIVE, CampaignStatus.CANCELLED],
      [CampaignStatus.ACTIVE]: [CampaignStatus.PAUSED, CampaignStatus.COMPLETED, CampaignStatus.CANCELLED],
      [CampaignStatus.PAUSED]: [CampaignStatus.ACTIVE, CampaignStatus.CANCELLED],
      [CampaignStatus.COMPLETED]: [], // No transitions from completed
      [CampaignStatus.CANCELLED]: [], // No transitions from cancelled
      [CampaignStatus.BANNED]: [], // Admin-only restore via moderation API
    };

    if (!validTransitions[campaign.status].includes(status)) {
      throw new BadRequestException(`Invalid status transition from ${campaign.status} to ${status}`);
    }

    const updateData: any = { status };
    
    // Set timestamps based on status
    if (status === CampaignStatus.ACTIVE && campaign.status === CampaignStatus.DRAFT) {
      updateData.launchedAt = new Date();
    } else if (status === CampaignStatus.PAUSED) {
      updateData.pausedAt = new Date();
    } else if (status === CampaignStatus.COMPLETED) {
      updateData.completedAt = new Date();
    } else if (status === CampaignStatus.CANCELLED) {
      updateData.cancelledAt = new Date();
    }

    const updated = await this.prisma.campaign.update({
      where: { id },
      data: updateData,
      include: {
        founder: {
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
    });
    try {
      const founder = await this.prisma.user.findUnique({
        where: { id: updated.founderId },
        select: { email: true, profile: { select: { displayName: true } } },
      });
      if (founder?.email) {
        if (status === CampaignStatus.ACTIVE) {
          this.email.dispatchInBackground({
            eventName: EmailEventName.CampaignPublished,
            recipient: { email: founder.email, userId: updated.founderId },
            vars: {
              actorName: founder.profile?.displayName || founder.email,
              campaignTitle: updated.title,
              campaignUrl: this.emailLinkRouter.getCampaignLink(updated.id),
            },
          });
        } else if (status === CampaignStatus.PAUSED) {
          this.email.dispatchInBackground({
            eventName: EmailEventName.CampaignPaused,
            recipient: { email: founder.email, userId: updated.founderId },
            vars: {
              targetName: founder.profile?.displayName || founder.email,
              campaignTitle: updated.title,
              campaignUrl: this.emailLinkRouter.getCampaignLink(updated.id),
            },
          });
        } else if (status === CampaignStatus.CANCELLED) {
          this.email.dispatchInBackground({
            eventName: EmailEventName.CampaignRejected,
            recipient: { email: founder.email, userId: updated.founderId },
            vars: {
              actorName: founder.profile?.displayName || founder.email,
              campaignTitle: updated.title,
              reason: 'Campaign cancelled',
              supportEmail: process.env.SUPPORT_EMAIL || 'support@bybata.com',
            },
          });
        }
      }
    } catch {
      // Non-blocking
    }

    // Nearby discovery only when a campaign first goes live (DRAFT → ACTIVE).
    if (status === CampaignStatus.ACTIVE && campaign.status === CampaignStatus.DRAFT) {
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

  async donate(donorId: string, campaignId: string, data: {
    amount: number;
    currency?: string;
    isAnonymous?: boolean;
    message?: string;
    rewardTierId?: string;
    idempotencyKey?: string;
  }) {
    const campaign = await this.prisma.campaign.findUnique({ where: { id: campaignId } });
    if (!campaign) throw new NotFoundException('Campaign not found');
    if (campaign.status !== CampaignStatus.ACTIVE) {
      throw new BadRequestException('Campaign is not accepting donations');
    }

    // Validate donation amount
    if (data.amount <= 0) {
      throw new BadRequestException('Donation amount must be greater than 0');
    }

    // Check minimum donation
    if (campaign.minimumDonation && new Prisma.Decimal(data.amount).lt(campaign.minimumDonation)) {
      throw new BadRequestException(`Minimum donation amount is ${campaign.minimumDonation} ${campaign.currency}`);
    }

    // Check if campaign would exceed goal (optional - could allow over-funding)
    const newTotal = campaign.currentAmount.add(new Prisma.Decimal(data.amount));
    const pointsConfig = await this.karmaPointsConfig.getConfig();
    const karmaReward = calculateDonationKarmaFromConfig(
      data.amount,
      pointsConfig.donationKarmaPercent,
    );

    // Process donation: Debit from donor and credit to campaign wallet
    // This creates two immutable ledger entries (debit donor, credit campaign)
    const idempotencyKey =
      (typeof data.idempotencyKey === 'string' && data.idempotencyKey.trim()) ||
      `don_${campaignId}_${donorId}_${Date.now()}`;
    let walletResult: any;
    try {
      walletResult = await this.wallet.processDonation(
        donorId,
        campaignId,
        Number(data.amount),
        `Donation to ${campaign.title}`,
        idempotencyKey,
        (data as any).verificationMethod, // PIN or BIOMETRIC
        (data as any).verificationCredential // PIN value or biometric token
      );
    } catch (error) {
      void this.sendDonationFailedEmail(donorId, data.amount, campaign.title, error).catch(() => {});
      throw error;
    }

    if (walletResult?.duplicate) {
      const existingDonation = await this.prisma.donation.findFirst({
        where: { transactionHash: walletResult.debitTransactionId },
      });
      if (existingDonation) {
        return existingDonation;
      }
    }

    // Use the wallet result to get transaction IDs
    const donation = await this.prisma.$transaction(async (tx) => {
      // Create the donation record
      const donation = await tx.donation.create({
        data: {
          campaignId,
          donorId,
          amount: new Prisma.Decimal(data.amount),
          currency: 'BYC',
          isAnonymous: data.isAnonymous || false,
          message: data.message,
          karmaAwarded: karmaReward,
          status: TxStatus.SUCCESS,
          processedAt: new Date(),
          transactionHash: walletResult.debitTransactionId, // Link to wallet transaction
          metadata: {
            debitTransactionId: walletResult.debitTransactionId,
            creditTransactionId: walletResult.creditTransactionId,
            walletDonation: true,
          },
        },
        include: {
          campaign: {
            include: {
              founder: {
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
          donor: {
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

      // If reward tier selected, validate and record reward claim
      if (data.rewardTierId) {
        const tier = await tx.rewardTier.findUnique({ where: { id: data.rewardTierId } });
        if (!tier || tier.campaignId !== campaignId) {
          throw new BadRequestException('Invalid reward tier');
        }
        if (tier.status === 'SOLD_OUT') {
          throw new BadRequestException('Reward tier sold out');
        }
        // Validate minimum donation
        if (new Prisma.Decimal(data.amount).lt(tier.minimumDonation)) {
          throw new BadRequestException('Donation does not meet the reward minimum');
        }
        // Enforce limited quantity
        if (tier.limitedQuantity && tier.claimedCount >= tier.limitedQuantity) {
          throw new BadRequestException('Reward tier limit reached');
        }
        await tx.donationReward.create({
          data: {
            donationId: donation.id,
            rewardTierId: tier.id,
          },
        });
        await tx.rewardTier.update({
          where: { id: tier.id },
          data: {
            claimedCount: { increment: 1 },
            status: tier.limitedQuantity && tier.claimedCount + 1 >= tier.limitedQuantity ? 'SOLD_OUT' : undefined,
          },
        });
      }

      // Update campaign totals immediately after donation
      const updatedCampaign = await tx.campaign.update({
        where: { id: campaignId },
        data: {
          currentAmount: newTotal,
          donorCount: { increment: 1 },
          // Auto-complete if goal is reached
          ...(newTotal.gte(campaign.goalAmount) ? {
            status: CampaignStatus.COMPLETED,
            completedAt: new Date()
          } : {})
        },
      });

      // Check for milestone achievements (50%, 75%, 90%, 100%)
      const goalAmount = Number(campaign.goalAmount);
      const newAmount = Number(newTotal);
      const oldAmount = Number(campaign.currentAmount);
      const newPercentage = (newAmount / goalAmount) * 100;
      const oldPercentage = (oldAmount / goalAmount) * 100;
      const milestones = [50, 75, 90, 100];
      const reachedMilestone = milestones.find(m => newPercentage >= m && oldPercentage < m);

      return { donation, updatedCampaign, reachedMilestone };
    });

    // Return immediately; emails/notifications/karma run in the background.
    const donationRecord = donation.donation;
    const updatedCampaignData = donation.updatedCampaign;
    const reachedMilestone = donation.reachedMilestone;

    void this.runDonationSideEffects({
      donorId,
      campaignId,
      campaign,
      data,
      donationRecord,
      updatedCampaignData,
      reachedMilestone: reachedMilestone ?? undefined,
      karmaReward,
    }).catch((error) => {
      console.error('Failed donation side effects:', error);
    });

    return donationRecord;
  }

  private async sendDonationFailedEmail(
    donorId: string,
    amount: number,
    campaignTitle: string,
    error: unknown,
  ): Promise<void> {
    const donor = await this.prisma.user.findUnique({
      where: { id: donorId },
      select: { email: true, profile: { select: { displayName: true } } },
    });
    if (!donor?.email) return;
    this.email.dispatchInBackground({
      eventName: EmailEventName.DonationFailed,
      recipient: { email: donor.email, userId: donorId },
      vars: {
        actorName: donor.profile?.displayName || donor.email,
        amount,
        currency: 'BYC',
        campaignTitle,
        reason: (error as Error)?.message || 'Donation failed',
        supportEmail: process.env.SUPPORT_EMAIL || 'support@bybata.com',
      },
    });
  }

  private async runDonationSideEffects(params: {
    donorId: string;
    campaignId: string;
    campaign: { founderId: string; title: string; goalAmount: Prisma.Decimal };
    data: { amount: number; isAnonymous?: boolean };
    donationRecord: {
      id: string;
      donor: { profile?: { displayName?: string | null } | null };
    };
    updatedCampaignData: {
      status: CampaignStatus;
      currentAmount: Prisma.Decimal;
      donorCount?: number;
    };
    reachedMilestone?: number;
    karmaReward: number;
  }): Promise<void> {
    const {
      donorId,
      campaignId,
      campaign,
      data,
      donationRecord,
      updatedCampaignData,
      reachedMilestone,
      karmaReward,
    } = params;

    try {
      const donorName = donationRecord.donor.profile?.displayName || 'Someone';
      const isAnonymous = data.isAnonymous || false;
      const [founderUser, donorUser] = await Promise.all([
        this.prisma.user.findUnique({
          where: { id: campaign.founderId },
          select: { email: true, profile: { select: { displayName: true } } },
        }),
        this.prisma.user.findUnique({
          where: { id: donorId },
          select: { email: true, profile: { select: { displayName: true } } },
        }),
      ]);

      await this.notifications.createNotification({
        userId: campaign.founderId,
        type: NotificationType.DONATION_RECEIVED,
        title: 'New Donation Received!',
        message: isAnonymous
          ? `You received ${data.amount} BYC donation for "${campaign.title}"`
          : `${donorName} donated ${data.amount} BYC to "${campaign.title}"`,
        actionUrl: `/campaigns/${campaignId}`,
        sourceId: donationRecord.id,
        sourceType: 'donation',
        priority: NotificationPriority.HIGH,
        data: {
          campaignId,
          donationId: donationRecord.id,
          amount: data.amount,
          donorId: isAnonymous ? null : donorId,
          isAnonymous,
        },
      });

      await this.notifications.createNotification({
        userId: donorId,
        type: NotificationType.DONATION_RECEIVED,
        title: 'Donation Successful!',
        message: `Your donation of ${data.amount} BYC to "${campaign.title}" has been processed successfully.`,
        actionUrl: `/campaigns/${campaignId}`,
        sourceId: donationRecord.id,
        sourceType: 'donation',
        priority: NotificationPriority.NORMAL,
        data: {
          campaignId,
          donationId: donationRecord.id,
          amount: data.amount,
        },
      });

      if (reachedMilestone) {
        await this.notifications.createNotification({
          userId: campaign.founderId,
          type: NotificationType.CAMPAIGN_MILESTONE,
          title: 'Campaign Milestone Reached!',
          message: `Congratulations! Your campaign "${campaign.title}" has reached ${reachedMilestone}% of its goal.`,
          actionUrl: `/campaigns/${campaignId}`,
          sourceId: campaignId,
          sourceType: 'campaign',
          priority: NotificationPriority.HIGH,
          data: {
            campaignId,
            milestone: reachedMilestone,
            currentAmount: Number(updatedCampaignData.currentAmount),
            goalAmount: Number(campaign.goalAmount),
          },
        });
      }

      if (updatedCampaignData.status === CampaignStatus.COMPLETED) {
        await this.notifications.createNotification({
          userId: campaign.founderId,
          type: NotificationType.CAMPAIGN_COMPLETED,
          title: 'Campaign Goal Reached! 🎉',
          message: `Amazing! Your campaign "${campaign.title}" has reached its funding goal!`,
          actionUrl: `/campaigns/${campaignId}`,
          sourceId: campaignId,
          sourceType: 'campaign',
          priority: NotificationPriority.URGENT,
          data: {
            campaignId,
            currentAmount: Number(updatedCampaignData.currentAmount),
            goalAmount: Number(campaign.goalAmount),
          },
        });
      }

      if (founderUser?.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.DonationReceived,
          recipient: { email: founderUser.email, userId: campaign.founderId },
          vars: {
            targetName: founderUser.email,
            donorName: isAnonymous ? 'Anonymous' : donorName,
            amount: data.amount,
            currency: 'BYC',
            campaignTitle: campaign.title,
            campaignUrl: this.emailLinkRouter.getCampaignLink(campaignId),
          },
        });
      }

      if (donorUser?.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.DonationReceipt,
          recipient: { email: donorUser.email, userId: donorId },
          vars: {
            actorName: donorUser.profile?.displayName || donorUser.email,
            amount: data.amount,
            currency: 'BYC',
            campaignTitle: campaign.title,
            receiptId: donationRecord.id,
            campaignUrl: this.emailLinkRouter.getCampaignLink(campaignId),
          },
        });
      }

      if (reachedMilestone && founderUser?.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.CampaignMilestoneReached,
          recipient: { email: founderUser.email, userId: campaign.founderId },
          vars: {
            targetName: founderUser.email,
            campaignTitle: campaign.title,
            milestone: reachedMilestone,
            campaignUrl: this.emailLinkRouter.getCampaignLink(campaignId),
          },
        });
      }

      if (updatedCampaignData.status === CampaignStatus.COMPLETED && founderUser?.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.CampaignEnded,
          recipient: { email: founderUser.email, userId: campaign.founderId },
          vars: {
            targetName: founderUser.email,
            campaignTitle: campaign.title,
            totalRaised: Number(updatedCampaignData.currentAmount),
            campaignUrl: this.emailLinkRouter.getCampaignLink(campaignId),
          },
        });
      }
    } catch (error) {
      console.error('Failed to send donation notifications:', error);
    }

    try {
      await this.referralsService.onReferredUserFirstDonation(donorId);
    } catch {
      // Non-blocking
    }

    if (karmaReward > 0) {
      try {
        await this.karmaService.awardKarma(
          donorId,
          KarmaEventType.DONATION_MADE,
          karmaReward,
          `Donated ${data.amount} BYC to ${campaign.title}`,
          { campaignId, donationId: donationRecord.id, amount: data.amount },
          donationRecord.id,
          'donation',
        );
      } catch (error) {
        console.error('Failed to award donation karma:', error);
      }
    }

    try {
      this.chatGateway.server.emit('donation.created', {
        campaignId,
        donorId,
        amount: data.amount,
        donorCount: updatedCampaignData.donorCount,
        campaignStatus: updatedCampaignData.status,
      });
    } catch (_) {}
  }

  async createUpdate(authorId: string, campaignId: string, body: { type?: string; content?: string; mediaKeys?: string[] }) {
    const campaign = await this.prisma.campaign.findUnique({ where: { id: campaignId } });
    if (!campaign) throw new NotFoundException('Campaign not found');
    if (campaign.founderId !== authorId) throw new ForbiddenException('Only founder can post updates');
    const type = (body.type || 'TEXT').toUpperCase() as any;
    return this.prisma.campaignUpdate.create({
      data: {
        campaignId,
        authorId,
        type,
        content: body.content,
        mediaKeys: body.mediaKeys || [],
      },
    });
  }

  async listUpdates(campaignId: string) {
    return this.prisma.campaignUpdate.findMany({
      where: { campaignId },
      orderBy: { createdAt: 'desc' },
      include: {
        author: {
          select: { id: true, profile: { select: { displayName: true, avatarKey: true } } },
        },
      },
    });
  }

  async createRewardTier(userId: string, campaignId: string, body: { title: string; description?: string; minimumDonation: number; limitedQuantity?: number }) {
    const campaign = await this.prisma.campaign.findUnique({ where: { id: campaignId } });
    if (!campaign) throw new NotFoundException('Campaign not found');
    if (campaign.founderId !== userId) throw new ForbiddenException('Only founder can manage reward tiers');
    return this.prisma.rewardTier.create({
      data: {
        campaignId,
        title: body.title,
        description: body.description,
        minimumDonation: new Prisma.Decimal(body.minimumDonation),
        limitedQuantity: body.limitedQuantity,
      },
    });
  }

  async listRewardTiers(campaignId: string) {
    return this.prisma.rewardTier.findMany({
      where: { campaignId },
      orderBy: { minimumDonation: 'asc' },
    });
  }

  async updateRewardTier(userId: string, campaignId: string, tierId: string, body: { title?: string; description?: string; minimumDonation?: number; limitedQuantity?: number; status?: string }) {
    const campaign = await this.prisma.campaign.findUnique({ where: { id: campaignId } });
    if (!campaign) throw new NotFoundException('Campaign not found');
    if (campaign.founderId !== userId) throw new ForbiddenException('Only founder can manage reward tiers');
    const tier = await this.prisma.rewardTier.findUnique({ where: { id: tierId } });
    if (!tier || tier.campaignId !== campaignId) throw new NotFoundException('Reward tier not found');
    return this.prisma.rewardTier.update({
      where: { id: tierId },
      data: {
        title: body.title,
        description: body.description,
        minimumDonation: body.minimumDonation !== undefined ? new Prisma.Decimal(body.minimumDonation) : undefined,
        limitedQuantity: body.limitedQuantity,
        status: body.status ? body.status as any : undefined,
      },
    });
  }

  async deleteRewardTier(userId: string, campaignId: string, tierId: string) {
    const campaign = await this.prisma.campaign.findUnique({ where: { id: campaignId } });
    if (!campaign) throw new NotFoundException('Campaign not found');
    if (campaign.founderId !== userId) throw new ForbiddenException('Only founder can delete reward tiers');
    const tier = await this.prisma.rewardTier.findUnique({ where: { id: tierId } });
    if (!tier || tier.campaignId !== campaignId) throw new NotFoundException('Reward tier not found');
    if (tier.claimedCount > 0) throw new BadRequestException('Cannot delete a reward tier with claims');
    await this.prisma.donationReward.deleteMany({ where: { rewardTierId: tierId } });
    return this.prisma.rewardTier.delete({ where: { id: tierId } });
  }

  async deleteCampaign(userId: string, id: string) {
    const campaign = await this.prisma.campaign.findUnique({
      where: { id },
      include: { donations: { where: { status: TxStatus.SUCCESS }, take: 1 } },
    });
    if (!campaign) throw new NotFoundException('Campaign not found');
    if (campaign.founderId !== userId) throw new ForbiddenException('Only founder can delete');

    const raised = Number(campaign.currentAmount);
    if (raised > 0 || campaign.donorCount > 0 || campaign.donations.length > 0) {
      throw new BadRequestException('Cannot delete a campaign that has received donations');
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.donationReward.deleteMany({ where: { donation: { campaignId: id } } });
      await tx.donation.deleteMany({ where: { campaignId: id } });
      await tx.rewardTier.deleteMany({ where: { campaignId: id } });
      await tx.campaignUpdate.deleteMany({ where: { campaignId: id } });
      await tx.campaignComment.updateMany({ where: { campaignId: id }, data: { parentId: null } });
      await tx.campaignComment.deleteMany({ where: { campaignId: id } });
      await tx.communityPost.updateMany({ where: { linkedCampaignId: id }, data: { linkedCampaignId: null } });
      await tx.campaign.delete({ where: { id } });
    });

    await this.bumpCampaignListCacheGeneration();
    return { success: true, id };
  }

  async getMyCampaigns(userId: string, params: { page?: number; size?: number; status?: CampaignStatus }) {
    const page = Math.max(params.page ?? 1, 1);
    const size = Math.min(Math.max(params.size ?? 20, 1), 100);
    const where: any = { founderId: userId };

    if (params.status) where.status = params.status;

    const [total, items] = await this.prisma.$transaction([
      this.prisma.campaign.count({ where }),
      this.prisma.campaign.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
        include: {
          donations: {
            select: {
              id: true,
              amount: true,
              isAnonymous: true,
              createdAt: true,
              donor: {
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
            },
            orderBy: { createdAt: 'desc' },
            take: 5
          }
        }
      })
    ]);

    return { items, page, size, total };
  }

  async getDonationHistory(userId: string, params: { page?: number; size?: number }) {
    const page = Math.max(params.page ?? 1, 1);
    const size = Math.min(Math.max(params.size ?? 20, 1), 100);

    const [total, items] = await this.prisma.$transaction([
      this.prisma.donation.count({ where: { donorId: userId } }),
      this.prisma.donation.findMany({
        where: { donorId: userId },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
        include: {
          campaign: {
            include: {
              founder: {
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
      })
    ]);

    return { items, page, size, total };
  }

  async getCampaignAnalytics(campaignId: string) {
    const campaign = await this.prisma.campaign.findUnique({ where: { id: campaignId } });
    if (!campaign) throw new NotFoundException('Campaign not found');
    const totals = await this.prisma.donation.aggregate({
      where: { campaignId },
      _sum: { amount: true },
      _count: { id: true },
    });
    const recent = await this.prisma.donation.findMany({
      where: { campaignId },
      orderBy: { createdAt: 'desc' },
      take: 10,
      include: { donor: { select: { id: true, profile: { select: { displayName: true } } } } },
    });
    return {
      goalAmount: campaign.goalAmount,
      currentAmount: campaign.currentAmount,
      donorCount: campaign.donorCount,
      totalDonations: totals._count.id,
      totalAmount: totals._sum.amount,
      recent,
    };
  }

  async getCreatorAnalytics(userId: string) {
    const campaigns = await this.prisma.campaign.findMany({ where: { founderId: userId } });
    const ids = campaigns.map(c => c.id);
    const totals = await this.prisma.donation.aggregate({
      where: { campaignId: { in: ids } },
      _sum: { amount: true },
      _count: { id: true },
    });
    return {
      campaigns: campaigns.length,
      totalRaised: totals._sum.amount,
      totalDonations: totals._count.id,
    };
  }

  async getDonorAnalytics(userId: string) {
    const donations = await this.prisma.donation.findMany({
      where: { donorId: userId, status: TxStatus.SUCCESS },
      orderBy: { createdAt: 'desc' },
    });

    const totalDonations = donations.length;
    const totalAmount = donations.reduce((sum, d) => sum.plus(d.amount), new Prisma.Decimal(0));
    const campaignsSupported = new Set(donations.map(d => d.campaignId)).size;
    const totalKarma = donations.reduce((sum, d) => sum + (d.karmaAwarded ?? 0), 0);
    const averageDonation = totalDonations > 0 ? totalAmount.div(totalDonations) : new Prisma.Decimal(0);

    const byYear: Record<string, { count: number; amount: string }> = {};
    for (const d of donations) {
      const y = d.createdAt.getFullYear().toString();
      const prev = byYear[y];
      const amt = d.amount as unknown as Prisma.Decimal;
      if (!prev) {
        byYear[y] = { count: 1, amount: amt.toString() };
      } else {
        const prevDec = new Prisma.Decimal(prev.amount);
        byYear[y] = { count: prev.count + 1, amount: prevDec.plus(amt).toString() };
      }
    }

    return {
      totalDonations,
      totalAmount: totalAmount.toString(),
      campaignsSupported,
      totalKarma,
      averageDonation: averageDonation.toString(),
      byYear,
    };
  }

  /** Single donation receipt (donor or campaign founder). */
  async generateDonationReceiptPdf(userId: string, donationId: string) {
    const donation = await this.prisma.donation.findUnique({
      where: { id: donationId },
      include: {
        campaign: {
          select: {
            id: true,
            title: true,
            founderId: true,
          },
        },
        donor: {
          select: {
            id: true,
            email: true,
            profile: { select: { displayName: true } },
          },
        },
      },
    });
    if (!donation) throw new NotFoundException('Donation not found');
    if (donation.status !== TxStatus.SUCCESS) {
      throw new BadRequestException(
        'Receipt is only available for completed donations',
      );
    }
    const isDonor = donation.donorId === userId;
    const isFounder = donation.campaign.founderId === userId;
    if (!isDonor && !isFounder) {
      throw new ForbiddenException('Not allowed to access this receipt');
    }

    const donorLabel = donation.isAnonymous
      ? 'Anonymous donor'
      : donation.donor.profile?.displayName || donation.donor.email || 'Donor';
    const receiptTitle = isFounder ? 'Donation Received Receipt' : 'Donation Receipt';

    const details: { label: string; value: string; monospace?: boolean }[] = [
      { label: 'Campaign', value: donation.campaign.title },
      { label: 'Donor', value: donorLabel },
      { label: 'Receipt ID', value: donation.id, monospace: true },
      { label: 'Processed', value: formatDate(donation.processedAt ?? donation.createdAt) },
    ];
    if (donation.karmaAwarded > 0) {
      details.push({ label: 'KARMA earned', value: String(donation.karmaAwarded) });
    }
    if (donation.message) {
      details.push({ label: 'Message', value: donation.message });
    }
    if (donation.transactionHash) {
      details.push({
        label: 'Transaction reference',
        value: donation.transactionHash,
        monospace: true,
      });
    }

    return renderReceiptDocument(
      {
        title: receiptTitle,
        subtitle: isFounder
          ? 'A supporter contributed to your campaign'
          : 'Thank you for your generosity',
        receiptId: donation.id,
        issuedAt: donation.processedAt ?? donation.createdAt,
        status: donation.status,
        amount: {
          value: donation.amount.toString(),
          currency: donation.currency,
          direction: isFounder ? 'in' : 'out',
        },
        parties: isFounder
          ? [{ label: 'Donor', name: donorLabel }]
          : [{ label: 'Campaign', name: donation.campaign.title }],
        details,
        footerNote: isFounder
          ? 'This receipt confirms a donation received on your BYBATA campaign.'
          : 'This receipt confirms your donation on BYBATA. Thank you for supporting the community.',
      },
      `bybata-donation-${donation.id}.pdf`,
    );
  }

  /** Yearly donor summary PDF bytes (direct download). */
  async generateDonationReceiptPdfBuffer(userId: string, year: number) {
    const start = new Date(year, 0, 1);
    const end = new Date(year + 1, 0, 1);

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        email: true,
        profile: { select: { displayName: true } },
      },
    });

    const donations = await this.prisma.donation.findMany({
      where: {
        donorId: userId,
        status: TxStatus.SUCCESS,
        createdAt: { gte: start, lt: end },
      },
      orderBy: { createdAt: 'asc' },
      include: {
        campaign: { select: { title: true } },
      },
    });

    const total = donations.reduce((sum, d) => sum.plus(d.amount), new Prisma.Decimal(0));
    const donorName = user?.profile?.displayName || user?.email || 'Donor';

    const lineItems = donations.map((d) => ({
      date: formatShortDate(d.createdAt),
      description: d.campaign?.title ?? 'Campaign',
      amount: `${d.amount.toString()} BYC`,
    }));

    return renderReceiptDocument(
      {
        title: 'Annual Donation Summary',
        subtitle: `Tax year ${year} · ${donorName}`,
        receiptId: `BYBATA-DONATIONS-${year}`,
        issuedAt: new Date(),
        status: 'SUMMARY',
        statusTone: 'neutral',
        amount: {
          value: total.toString(),
          currency: 'BYC',
          direction: 'out',
        },
        details: [
          ...(user?.email ? [{ label: 'Email', value: user.email }] : []),
          { label: 'Tax year', value: String(year) },
          { label: 'Total donations', value: String(donations.length) },
        ],
        sections: [
          {
            title: 'Donation history',
            lineItems:
              lineItems.length > 0
                ? lineItems
                : [
                    {
                      date: '—',
                      description: 'No donations recorded for this year',
                      amount: '0 BYC',
                    },
                  ],
          },
        ],
        footerNote:
          'Annual summary of successful campaign donations made through BYBATA. ' +
          'Retain for your personal tax or accounting records as applicable in your jurisdiction.',
      },
      `bybata-donations-${year}.pdf`,
    );
  }

  /** Yearly donor summary PDF; uploads to storage and returns signed URL. */
  async generateDonationReceipt(userId: string, year: number) {
    const yearNum = year;
    const { buffer } = await this.generateDonationReceiptPdfBuffer(userId, yearNum);

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        email: true,
        profile: { select: { displayName: true } },
      },
    });
    const donorName = user?.profile?.displayName || user?.email || 'Donor';

    const donations = await this.prisma.donation.findMany({
      where: {
        donorId: userId,
        status: TxStatus.SUCCESS,
        createdAt: {
          gte: new Date(yearNum, 0, 1),
          lt: new Date(yearNum + 1, 0, 1),
        },
      },
    });
    const total = donations.reduce((sum, d) => sum.plus(d.amount), new Prisma.Decimal(0));

    const upload = await this.storage.uploadObject(
      'donations',
      userId,
      buffer,
      'application/pdf',
      'pdf',
    );

    const key = upload.key;
    const { url } = await this.storage.createDownloadUrl(key);

    if (user?.email && url) {
      this.email.dispatchInBackground({
        eventName: EmailEventName.DonationReceipt,
        recipient: { email: user.email, userId },
        vars: {
          actorName: donorName,
          amount: total.toString(),
          currency: 'BYC',
          campaignTitle: `Yearly summary ${year}`,
          receiptId: `${year}`,
          campaignUrl: url,
        },
      });
    }

    return { key, url };
  }

  async searchCampaigns(params: {
    categories: string[];
    minAmount?: number;
    maxAmount?: number;
    exactAmount?: boolean;
    page: number;
    size: number;
  }) {
    const where: any = {
      status: CampaignStatus.ACTIVE,
    };
    // Category filter
    if (params.categories && params.categories.length > 0) {
      where.category = { in: params.categories.map((c) => (c || '').toUpperCase()) };
    }
    // Amount filters
    if (params.exactAmount && typeof params.minAmount === 'number') {
      where.goalAmount = new Prisma.Decimal(params.minAmount);
    } else {
      if (typeof params.minAmount === 'number') {
        where.goalAmount = { ...(where.goalAmount || {}), gte: new Prisma.Decimal(params.minAmount) };
      }
      if (typeof params.maxAmount === 'number') {
        where.goalAmount = { ...(where.goalAmount || {}), lte: new Prisma.Decimal(params.maxAmount) };
      }
    }
    const skip = (params.page - 1) * params.size;
    const [items, total] = await this.prisma.$transaction([
      this.prisma.campaign.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: params.size,
      }),
      this.prisma.campaign.count({ where }),
    ]);
    return { items, total, page: params.page, size: params.size };
  }
}
