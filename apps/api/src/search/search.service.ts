import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { GiftCategory, Prisma, TradeCategory } from '@prisma/client';
import {
  applyListingGeoFilter,
  hasListingGeoFilter,
  ListingGeoParams,
  paginateListingItems,
} from '../common/listing-location.util';
import { enrichListingPayloadForFeed } from '../common/listing-media-url.util';
import { ListingUnreadService } from '../common/listing-unread.service';

export interface SearchResult {
  items: any[];
  total: number;
  page: number;
  size: number;
  totalPages: number;
}

export interface SearchFilters {
  [key: string]: any;
}

@Injectable()
export class SearchService {
  constructor(
    private prisma: PrismaService,
    private readonly listingUnread: ListingUnreadService,
  ) {}

  private async enrichListingSearchResult(
    result: SearchResult,
    userId?: string,
  ): Promise<SearchResult> {
    const mediaEnriched = enrichListingPayloadForFeed(result);
    if (!userId) return mediaEnriched;
    return this.listingUnread.enrichPayload(userId, mediaEnriched);
  }

  async search(
    query: string,
    type?: string,
    page: number = 1,
    size: number = 20,
    userId?: string,
  ): Promise<SearchResult> {
    // If type is specified, use domain-specific search
    switch (type) {
      case 'trades':
        return this.searchTrades(query, {}, page, size, userId);
      case 'users':
        return this.searchUsers(query, {}, page, size);
      case 'communities':
        return this.searchCommunities(query, {}, page, size);
      case 'gifts':
        return this.searchGifts(query, {}, page, size, userId);
      case 'campaigns':
        return this.searchCampaigns(query, {}, page, size, userId);
      default:
        return this.searchAll(query, page, size, userId);
    }
  }

  private async searchAll(
    query: string,
    page: number,
    size: number,
    userId?: string,
  ): Promise<SearchResult> {
    // Perform searches across multiple domains and combine results
    const [trades, users, communities, gifts, campaigns] = await Promise.all([
      this.searchTrades(query, {}, 1, 5, userId),
      this.searchUsers(query, {}, 1, 5),
      this.searchCommunities(query, {}, 1, 5),
      this.searchGifts(query, {}, 1, 5, userId),
      this.searchCampaigns(query, {}, 1, 5, userId),
    ]);

    // Combine and sort results by relevance
    const combinedResults = [
      ...trades.items.map(item => ({ ...item, type: 'trade' })),
      ...users.items.map(item => ({ ...item, type: 'user' })),
      ...communities.items.map(item => ({ ...item, type: 'community' })),
      ...gifts.items.map(item => ({ ...item, type: 'gift' })),
      ...campaigns.items.map(item => ({ ...item, type: 'campaign' })),
    ];

    const total = combinedResults.length;
    const startIndex = (page - 1) * size;
    const endIndex = startIndex + size;
    const paginatedItems = combinedResults.slice(startIndex, endIndex);

    return this.enrichListingSearchResult(
      {
        items: paginatedItems,
        total,
        page,
        size,
        totalPages: Math.ceil(total / size),
      },
      userId,
    );
  }

  async searchTrades(
    query: string,
    filters: SearchFilters,
    page: number,
    size: number,
    userId?: string,
  ): Promise<SearchResult> {
    const geo: ListingGeoParams = {
      lat: filters.lat,
      lng: filters.lng,
      radiusKm: filters.radiusKm,
      location: filters.location,
    };
    const geoActive = hasListingGeoFilter(geo);

    const where: Prisma.TradeWhereInput = {
      status: filters.status || 'OPEN',
      ...this.textFilter(query, filters.keywords, ['title', 'description']),
      ...this.enumCategoryFilter(filters, TradeCategory),
      ...(filters.location && !geoActive && {
        location: { contains: filters.location, mode: 'insensitive' },
      }),
    };

    if (geoActive) {
      const raw = await this.prisma.trade.findMany({
        where,
        include: {
          owner: {
            select: {
              id: true,
              email: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                },
              },
            },
          },
          _count: {
            select: {
              offers: true,
            },
          },
        },
        orderBy: [{ createdAt: 'desc' }],
        take: 500,
      });
      const filtered = applyListingGeoFilter(raw, geo);
      const paged = paginateListingItems(filtered, page, size);
      return this.enrichListingSearchResult(
        {
          items: paged.items,
          total: paged.total,
          page: paged.page,
          size: paged.size,
          totalPages: Math.ceil(paged.total / size),
        },
        userId,
      );
    }

    const [trades, total] = await Promise.all([
      this.prisma.trade.findMany({
        where,
        include: {
          owner: {
            select: {
              id: true,
              email: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                },
              },
            },
          },
          _count: {
            select: {
              offers: true,
            },
          },
        },
        orderBy: [
          { createdAt: 'desc' },
        ],
        skip: (page - 1) * size,
        take: size,
      }),
      this.prisma.trade.count({ where }),
    ]);

    return this.enrichListingSearchResult(
      {
        items: trades,
        total,
        page,
        size,
        totalPages: Math.ceil(total / size),
      },
      userId,
    );
  }

  async searchUsers(query: string, filters: SearchFilters, page: number, size: number): Promise<SearchResult> {
    const where: Prisma.UserWhereInput = {
      banned: false,
      OR: [
        { profile: { username: { contains: query, mode: 'insensitive' } } },
        { profile: { displayName: { contains: query, mode: 'insensitive' } } },
      ],
      ...(typeof filters.verified === 'boolean' && {
        emailVerifiedAt: filters.verified ? { not: null } : null,
      }),
    };

    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        select: {
          id: true,
          email: true,
          emailVerifiedAt: true,
          createdAt: true,
          profile: {
            select: {
              displayName: true,
              username: true,
              avatarKey: true,
              bio: true,
              kycStatus: true,
            },
          },
          karmaAccount: {
            select: {
              currentPoints: true,
              level: true,
              trustLevel: true,
            },
          },
        },
        orderBy: [
          { createdAt: 'desc' },
        ],
        skip: (page - 1) * size,
        take: size,
      }),
      this.prisma.user.count({ where }),
    ]);

    return {
      items: users,
      total,
      page,
      size,
      totalPages: Math.ceil(total / size),
    };
  }

  async searchCommunities(query: string, filters: SearchFilters, page: number, size: number): Promise<SearchResult> {
    const where: Prisma.CommunityWhereInput = {
      status: 'ACTIVE',
      OR: [
        { name: { contains: query, mode: 'insensitive' } },
        { description: { contains: query, mode: 'insensitive' } },
        { shortDescription: { contains: query, mode: 'insensitive' } },
      ],
      ...(filters.type && { type: filters.type }),
      ...(filters.category && { category: filters.category }),
    };

    const [communities, total] = await Promise.all([
      this.prisma.community.findMany({
        where,
        include: {
          createdBy: {
            select: {
              id: true,
              email: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                },
              },
            },
          },
        },
        orderBy: [
          { memberCount: 'desc' },
          { createdAt: 'desc' },
        ],
        skip: (page - 1) * size,
        take: size,
      }),
      this.prisma.community.count({ where }),
    ]);

    return {
      items: communities,
      total,
      page,
      size,
      totalPages: Math.ceil(total / size),
    };
  }

  async searchGifts(
    query: string,
    filters: SearchFilters,
    page: number,
    size: number,
    userId?: string,
  ): Promise<SearchResult> {
    const geo: ListingGeoParams = {
      lat: filters.lat,
      lng: filters.lng,
      radiusKm: filters.radiusKm,
      location: filters.location,
    };
    const geoActive = hasListingGeoFilter(geo);

    const where: Prisma.GiftWhereInput = {
      status: 'ACTIVE',
      ...this.textFilter(query, filters.keywords, ['title', 'description']),
      ...(filters.type && { type: filters.type }),
      ...this.enumCategoryFilter(filters, GiftCategory),
      ...(filters.location && !geoActive && { location: { contains: filters.location, mode: 'insensitive' } }),
    };

    if (geoActive) {
      const raw = await this.prisma.gift.findMany({
        where,
        include: {
          giver: {
            select: {
              id: true,
              email: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                },
              },
            },
          },
        },
        orderBy: [{ createdAt: 'desc' }],
        take: 500,
      });
      const filtered = applyListingGeoFilter(raw, geo);
      const paged = paginateListingItems(filtered, page, size);
      return this.enrichListingSearchResult(
        {
          items: paged.items,
          total: paged.total,
          page: paged.page,
          size: paged.size,
          totalPages: Math.ceil(paged.total / size),
        },
        userId,
      );
    }

    const [gifts, total] = await Promise.all([
      this.prisma.gift.findMany({
        where,
        include: {
          giver: {
            select: {
              id: true,
              email: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                },
              },
            },
          },
        },
        orderBy: [
          { createdAt: 'desc' },
        ],
        skip: (page - 1) * size,
        take: size,
      }),
      this.prisma.gift.count({ where }),
    ]);

    return this.enrichListingSearchResult(
      {
        items: gifts,
        total,
        page,
        size,
        totalPages: Math.ceil(total / size),
      },
      userId,
    );
  }

  async searchCampaigns(
    query: string,
    filters: SearchFilters,
    page: number,
    size: number,
    userId?: string,
  ): Promise<SearchResult> {
    const geo: ListingGeoParams = {
      lat: filters.lat,
      lng: filters.lng,
      radiusKm: filters.radiusKm,
      location: filters.location,
    };
    const geoActive = hasListingGeoFilter(geo);

    const where: Prisma.CampaignWhereInput = {
      status: filters.status || 'ACTIVE',
      ...this.textFilter(query, filters.keywords, ['title', 'description', 'shortDescription']),
      ...this.campaignCategoryFilter(filters),
      ...(typeof filters.urgent === 'boolean' && { isUrgent: filters.urgent }),
      ...(filters.location && !geoActive && {
        location: { contains: filters.location, mode: 'insensitive' },
      }),
    };

    if (geoActive) {
      const raw = await this.prisma.campaign.findMany({
        where,
        include: {
          founder: {
            select: {
              id: true,
              email: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                },
              },
            },
          },
        },
        orderBy: [
          { isUrgent: 'desc' },
          { isFeatured: 'desc' },
          { createdAt: 'desc' },
        ],
        take: 500,
      });
      const filtered = applyListingGeoFilter(raw, geo);
      const paged = paginateListingItems(filtered, page, size);
      return this.enrichListingSearchResult(
        {
          items: paged.items,
          total: paged.total,
          page: paged.page,
          size: paged.size,
          totalPages: Math.ceil(paged.total / size),
        },
        userId,
      );
    }

    const [campaigns, total] = await Promise.all([
      this.prisma.campaign.findMany({
        where,
        include: {
          founder: {
            select: {
              id: true,
              email: true,
              profile: {
                select: {
                  displayName: true,
                  avatarKey: true,
                },
              },
            },
          },
        },
        orderBy: [
          { isUrgent: 'desc' },
          { isFeatured: 'desc' },
          { createdAt: 'desc' },
        ],
        skip: (page - 1) * size,
        take: size,
      }),
      this.prisma.campaign.count({ where }),
    ]);

    return this.enrichListingSearchResult(
      {
        items: campaigns,
        total,
        page,
        size,
        totalPages: Math.ceil(total / size),
      },
      userId,
    );
  }

  async getSearchSuggestions(query: string, type?: string) {
    const suggestions: Array<{ text: string; type: string }> = [];

    if (!type || type === 'trades') {
      const trades = await this.prisma.trade.findMany({
        where: {
          status: 'OPEN',
          title: { contains: query, mode: 'insensitive' },
        },
        select: { title: true },
        take: 5,
      });
      suggestions.push(...trades.map(t => ({ text: t.title, type: 'trade' })));
    }

    if (!type || type === 'communities') {
      const communities = await this.prisma.community.findMany({
        where: {
          status: 'ACTIVE',
          name: { contains: query, mode: 'insensitive' },
        },
        select: { name: true },
        take: 5,
      });
      suggestions.push(...communities.map(c => ({ text: c.name, type: 'community' })));
    }

    if (!type || type === 'gifts') {
      const gifts = await this.prisma.gift.findMany({
        where: {
          status: 'ACTIVE',
          title: { contains: query, mode: 'insensitive' },
        },
        select: { title: true },
        take: 5,
      });
      suggestions.push(...gifts.map(g => ({ text: g.title, type: 'gift' })));
    }

    if (!type || type === 'campaigns') {
      const campaigns = await this.prisma.campaign.findMany({
        where: {
          status: 'ACTIVE',
          title: { contains: query, mode: 'insensitive' },
        },
        select: { title: true },
        take: 5,
      });
      suggestions.push(...campaigns.map(c => ({ text: c.title, type: 'campaign' })));
    }

    return {
      suggestions: suggestions.slice(0, 10),
    };
  }

  /** Title/description match for the query plus any intent keywords. */
  private textFilter(
    query: string,
    keywords: unknown,
    fields: string[],
  ): { OR?: Array<Record<string, { contains: string; mode: 'insensitive' }>> } {
    const terms = new Set<string>();
    const trimmed = query.trim();
    if (trimmed.length >= 2) terms.add(trimmed);
    if (Array.isArray(keywords)) {
      for (const keyword of keywords) {
        if (typeof keyword !== 'string') continue;
        const value = keyword.trim();
        if (value.length >= 2) terms.add(value);
      }
    }
    if (terms.size === 0) return {};
    const OR: Array<Record<string, { contains: string; mode: 'insensitive' }>> = [];
    for (const term of terms) {
      for (const field of fields) {
        OR.push({ [field]: { contains: term, mode: 'insensitive' as const } });
      }
    }
    return { OR };
  }

  private enumCategoryFilter<T extends string>(
    filters: SearchFilters,
    allowed: Record<string, T>,
  ): { category?: T | { in: T[] } } {
    const picked = this.pickEnums(filters, allowed);
    if (picked.length === 1) return { category: picked[0] };
    if (picked.length > 1) return { category: { in: picked } };
    return {};
  }

  private campaignCategoryFilter(filters: SearchFilters): Prisma.CampaignWhereInput {
    const labels = this.categoryLabels(filters);
    if (labels.length === 1) {
      return { category: { contains: labels[0], mode: 'insensitive' } };
    }
    if (labels.length > 1) {
      return {
        AND: [
          {
            OR: labels.map((label) => ({
              category: { contains: label, mode: 'insensitive' as const },
            })),
          },
        ],
      };
    }
    return {};
  }

  private pickEnums<T extends string>(filters: SearchFilters, allowed: Record<string, T>): T[] {
    const known = new Set(Object.values(allowed));
    const out: T[] = [];
    for (const label of this.categoryLabels(filters)) {
      const match = [...known].find((value) => value.toLowerCase() === label.toLowerCase());
      if (match && !out.includes(match)) out.push(match);
    }
    return out;
  }

  private categoryLabels(filters: SearchFilters): string[] {
    const labels: string[] = [];
    if (Array.isArray(filters.categories)) {
      for (const value of filters.categories) {
        if (typeof value === 'string' && value.trim()) labels.push(value.trim());
      }
    }
    if (typeof filters.category === 'string' && filters.category.trim()) {
      labels.push(filters.category.trim());
    }
    return labels;
  }
}