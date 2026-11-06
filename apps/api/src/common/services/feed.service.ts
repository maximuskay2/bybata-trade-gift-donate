import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { StorageService } from '../../storage/storage.service';
import { UsersService } from '../../users/users.service';
import {
  GetHomeFeedDto,
  FeedItemDto,
  HomeFeedResponseDto,
  FeedSourceType,
  IntentType,
  IntentSubType,
} from '../dto/feed.dto';
import { buildListingMediaUrl } from '../listing-media-url.util';

@Injectable()
export class FeedService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly users: UsersService,
  ) {}

  async getHomeFeed(dto: GetHomeFeedDto): Promise<HomeFeedResponseDto> {
    const { intentType, intentSubType, page = 1, size = 20 } = dto;
    const skip = (page - 1) * size;

    // Build filter conditions based on intentType and intentSubType
    const shouldIncludeTrades = 
      (!intentType && !intentSubType) || 
      intentType === IntentType.OFFER ||
      intentSubType === IntentSubType.TRADE;

    const shouldIncludeGifts = 
      (!intentType && !intentSubType) || 
      intentType === IntentType.OFFER ||
      intentSubType === IntentSubType.GIVE;

    const shouldIncludePosts = 
      (!intentType && !intentSubType) || 
      intentType === IntentType.ASK ||
      intentSubType === IntentSubType.REQUEST;

    const shouldIncludeCampaigns = 
      (!intentType && !intentSubType) || 
      intentType === IntentType.ASK ||
      intentSubType === IntentSubType.HELP_CAMPAIGN;

    // Fetch from all sources in parallel
    const [trades, gifts, posts, campaigns] = await Promise.all([
      // Fetch Trades (Offer-Trade)
      shouldIncludeTrades
        ? this.prisma.trade.findMany({
            where: { status: 'OPEN' },
            include: {
              owner: {
                include: { profile: true },
              },
            },
            orderBy: { createdAt: 'desc' },
            take: size * 2, // Fetch more for aggregation
          })
        : Promise.resolve([]),

      // Fetch Gifts (Offer-Give)
      shouldIncludeGifts
        ? this.prisma.gift.findMany({
            where: { status: 'ACTIVE' },
            include: {
              giver: {
                include: { profile: true },
              },
            },
            orderBy: { createdAt: 'desc' },
            take: size * 2,
          })
        : Promise.resolve([]),

      // Fetch CommunityPosts (Ask-Request)
      shouldIncludePosts
        ? this.prisma.communityPost.findMany({
            where: {
              status: 'ACTIVE',
            },
            include: {
              author: {
                include: { profile: true },
              },
            },
            orderBy: { createdAt: 'desc' },
            take: size * 2,
          })
        : Promise.resolve([]),

      // Fetch Campaigns (Ask-Help Campaign)
      shouldIncludeCampaigns
        ? this.prisma.campaign.findMany({
            where: {
              status: 'ACTIVE',
            },
            include: {
              founder: {
                include: { profile: true },
              },
            },
            orderBy: { createdAt: 'desc' },
            take: size * 2,
          })
        : Promise.resolve([]),
    ]);

    // Map to FeedItemDto and resolve image URLs.
    //
    // Batch-compute owner averageRating across every source so the new
    // 3D Glass ListingCard can show stars without per-card round trips.
    const ownerIds: string[] = [];
    for (const t of trades) if (t?.owner?.id) ownerIds.push(t.owner.id);
    for (const g of gifts) if (g?.giver?.id) ownerIds.push(g.giver.id);
    for (const p of posts) if (p?.author?.id) ownerIds.push(p.author.id);
    for (const c of campaigns) if (c?.founder?.id) ownerIds.push(c.founder.id);
    const ratingByUser = await this.users.getAverageRatingsBatch(ownerIds);

    const tradeFeedItems = await Promise.all(
      trades.map((trade) => this.mapTradeToFeedItem(trade, ratingByUser)),
    );
    const giftFeedItems = await Promise.all(
      gifts.map((gift) => this.mapGiftToFeedItem(gift, ratingByUser)),
    );
    const postFeedItems = await Promise.all(
      posts.map((post) => this.mapPostToFeedItem(post, ratingByUser)),
    );
    const campaignFeedItems = await Promise.all(
      campaigns.map((campaign) => this.mapCampaignToFeedItem(campaign, ratingByUser)),
    );

    // Combine all items
    const allItems = [
      ...tradeFeedItems,
      ...giftFeedItems,
      ...postFeedItems,
      ...campaignFeedItems,
    ];

    // Sort by createdAt DESC
    allItems.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

    // Paginate
    const totalCount = allItems.length;
    const paginatedItems = allItems.slice(skip, skip + size);

    return {
      items: paginatedItems,
      total: totalCount,
      page,
      size,
      totalPages: Math.ceil(totalCount / size),
    };
  }

  private async mapTradeToFeedItem(
    trade: any,
    ratingByUser?: Map<string, number>,
  ): Promise<FeedItemDto> {
    const imageKey = trade.thumbnailKey || trade.mediaKeys?.[0];
    const avatarKey = trade.owner.profile?.avatarKey;
    const ownerId = trade.owner?.id as string | undefined;

    return {
      id: trade.id,
      sourceType: FeedSourceType.TRADE,
      intentType: IntentType.OFFER,
      intentSubType: IntentSubType.TRADE,
      title: trade.title,
      summary: trade.description || '',
      imageUrl: imageKey ? this.resolveImageUrl(imageKey) : undefined,
      category: trade.category ? String(trade.category) : null,
      createdAt: trade.createdAt,
      author: {
        id: trade.owner.id,
        name: trade.owner.profile?.displayName || trade.owner.email,
        avatar: avatarKey ? this.resolveImageUrl(avatarKey) : undefined,
        averageRating: ownerId ? ratingByUser?.get(ownerId) ?? 0 : 0,
      },
      status: trade.status,
    };
  }

  private async mapGiftToFeedItem(
    gift: any,
    ratingByUser?: Map<string, number>,
  ): Promise<FeedItemDto> {
    const imageKey = gift.thumbnailKey || gift.mediaKeys?.[0];
    const avatarKey = gift.giver.profile?.avatarKey;
    const giverId = gift.giver?.id as string | undefined;

    return {
      id: gift.id,
      sourceType: FeedSourceType.GIFT,
      intentType: IntentType.OFFER,
      intentSubType: IntentSubType.GIVE,
      title: gift.title,
      summary: gift.description || '',
      imageUrl: imageKey ? this.resolveImageUrl(imageKey) : undefined,
      location: gift.location,
      category: gift.category ? String(gift.category) : null,
      createdAt: gift.createdAt,
      author: {
        id: gift.giver.id,
        name: gift.giver.profile?.displayName || gift.giver.email,
        avatar: avatarKey ? this.resolveImageUrl(avatarKey) : undefined,
        averageRating: giverId ? ratingByUser?.get(giverId) ?? 0 : 0,
      },
      status: gift.status,
    };
  }

  private async mapPostToFeedItem(
    post: any,
    ratingByUser?: Map<string, number>,
  ): Promise<FeedItemDto> {
    const imageKey = post.mediaKeys?.[0];
    const avatarKey = post.author.profile?.avatarKey;
    const authorId = post.author?.id as string | undefined;

    return {
      id: post.id,
      sourceType: FeedSourceType.POST,
      intentType: post.intentType || IntentType.ASK,
      intentSubType: post.intentSubType || IntentSubType.REQUEST,
      title: post.title || 'Request',
      summary: post.content,
      imageUrl: imageKey ? this.resolveImageUrl(imageKey) : undefined,
      category: post.category ? String(post.category) : null,
      createdAt: post.createdAt,
      author: {
        id: post.author.id,
        name: post.author.profile?.displayName || post.author.email,
        avatar: avatarKey ? this.resolveImageUrl(avatarKey) : undefined,
        averageRating: authorId ? ratingByUser?.get(authorId) ?? 0 : 0,
      },
      status: post.status,
      metadata: post.metadata,
    };
  }

  private async mapCampaignToFeedItem(
    campaign: any,
    ratingByUser?: Map<string, number>,
  ): Promise<FeedItemDto> {
    const imageKey = campaign.thumbnailKey || campaign.mediaKeys?.[0];
    const avatarKey = campaign.founder.profile?.avatarKey;
    const founderId = campaign.founder?.id as string | undefined;

    return {
      id: campaign.id,
      sourceType: FeedSourceType.CAMPAIGN,
      intentType: IntentType.ASK,
      intentSubType: IntentSubType.HELP_CAMPAIGN,
      title: campaign.title,
      summary: campaign.shortDescription || campaign.description || '',
      imageUrl: imageKey ? this.resolveImageUrl(imageKey) : undefined,
      location: campaign.location,
      category: campaign.category ? String(campaign.category) : null,
      createdAt: campaign.createdAt,
      author: {
        id: campaign.founder.id,
        name: campaign.founder.profile?.displayName || campaign.founder.email,
        avatar: avatarKey ? this.resolveImageUrl(avatarKey) : undefined,
        averageRating: founderId ? ratingByUser?.get(founderId) ?? 0 : 0,
      },
      status: campaign.status,
      metadata: {
        goalAmount: campaign.goalAmount,
        currentAmount: campaign.currentAmount,
        currency: campaign.currency,
      },
    };
  }

  private resolveImageUrl(key: string): string | undefined {
    return buildListingMediaUrl(key) ?? undefined;
  }
}
