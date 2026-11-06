import { Controller, Get, Param, Query } from '@nestjs/common';
import { TradesService } from '../trades/trades.service';
import { GiftsService } from '../gifts/gifts.service';
import { CampaignsService } from '../campaigns/campaigns.service';
import { CommunitiesService } from '../communities/communities.service';
import { UsersService } from '../users/users.service';
import { TradeStatus } from '@prisma/client';
import { GiftStatus, GiftType, GiftCategory } from '@prisma/client';
import { CampaignStatus } from '@prisma/client';

@Controller('v1/public/browse')
export class PublicBrowseController {
  constructor(
    private trades: TradesService,
    private gifts: GiftsService,
    private campaigns: CampaignsService,
    private communities: CommunitiesService,
    private users: UsersService,
  ) {}

  /**
   * Attach `ownerAverageRating` to each item in a browse list response.
   *
   * The new 3D Glass ListingCard on Home/Browse needs a star rating per
   * card. Rather than make the Flutter client fan out `/users/:id` calls
   * (N+1), we compute averages for the owner/giver/founder of every item
   * in one batch query and splice the value onto the raw payload. The
   * caller passes the relation key (`owner` | `giver` | `founder`) since
   * each service returns items with a different relation name.
   */
  private async enrichWithOwnerRating<
    T extends { items: any[]; page: number; size: number; total: number },
  >(payload: T, ownerKey: 'owner' | 'giver' | 'founder'): Promise<T> {
    if (!payload || !Array.isArray(payload.items) || payload.items.length === 0) {
      return payload;
    }
    const ids: string[] = [];
    for (const it of payload.items) {
      const oid = it?.[ownerKey]?.id;
      if (typeof oid === 'string' && oid) ids.push(oid);
    }
    if (ids.length === 0) return payload;
    const ratings = await this.users.getAverageRatingsBatch(ids);
    for (const it of payload.items) {
      const oid = it?.[ownerKey]?.id;
      it.ownerAverageRating = oid ? ratings.get(oid) ?? 0 : 0;
    }
    return payload;
  }

  @Get('trades')
  async listTrades(
    @Query('query') query?: string,
    @Query('status') statusStr?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('lon') lon?: string,
    @Query('radiusKm') radiusKm?: string,
    @Query('location') location?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const status = statusStr ? (statusStr as TradeStatus) : undefined;
    const parsedLat = parseFloat(lat ?? '');
    const parsedLng = parseFloat(lng ?? lon ?? '');
    const parsedRadius = parseFloat(radiusKm ?? '50');
    const payload = await this.trades.listTrades({
      query,
      status,
      page,
      size,
      lat: Number.isFinite(parsedLat) ? parsedLat : undefined,
      lng: Number.isFinite(parsedLng) ? parsedLng : undefined,
      radiusKm: Number.isFinite(parsedRadius) ? parsedRadius : undefined,
      location,
    });
    return this.enrichWithOwnerRating(payload as any, 'owner');
  }

  @Get('gifts')
  async listGifts(
    @Query('query') query?: string,
    @Query('category') category?: GiftCategory,
    @Query('type') type?: GiftType,
    @Query('status') status?: GiftStatus,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('lon') lon?: string,
    @Query('radiusKm') radiusKm?: string,
    @Query('location') location?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const parsedLat = parseFloat(lat ?? '');
    const parsedLng = parseFloat(lng ?? lon ?? '');
    const parsedRadius = parseFloat(radiusKm ?? '50');
    const payload = await this.gifts.listGifts({
      query,
      category,
      type,
      status,
      page,
      size,
      lat: Number.isFinite(parsedLat) ? parsedLat : undefined,
      lng: Number.isFinite(parsedLng) ? parsedLng : undefined,
      radiusKm: Number.isFinite(parsedRadius) ? parsedRadius : undefined,
      location,
    });
    return this.enrichWithOwnerRating(payload as any, 'giver');
  }

  @Get('gifts/:id')
  async getGift(@Param('id') id: string) {
    // Public, unguarded gift detail. Mirrors the authenticated
    // GET /v1/gifts/:id (which is JWT-gated) so that browse-home visitors
    // can open a gift card without being forced to sign in first.
    return this.gifts.getGift(id);
  }

  @Get('trades/:id')
  async getTrade(@Param('id') id: string) {
    return this.trades.getTrade(id);
  }

  @Get('campaigns/:id')
  async getCampaign(@Param('id') id: string) {
    return this.campaigns.getCampaign(id);
  }

  @Get('campaigns')
  async listCampaigns(
    @Query('query') query?: string,
    @Query('category') category?: string,
    @Query('status') status?: CampaignStatus,
    @Query('isUrgent') isUrgentStr?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('lon') lon?: string,
    @Query('radiusKm') radiusKm?: string,
    @Query('location') location?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const isUrgent = isUrgentStr === 'true' ? true : isUrgentStr === 'false' ? false : undefined;
    const parsedLat = parseFloat(lat ?? '');
    const parsedLng = parseFloat(lng ?? lon ?? '');
    const parsedRadius = parseFloat(radiusKm ?? '50');
    const payload = await this.campaigns.listCampaigns({
      query,
      category,
      status,
      isUrgent,
      page,
      size,
      lat: Number.isFinite(parsedLat) ? parsedLat : undefined,
      lng: Number.isFinite(parsedLng) ? parsedLng : undefined,
      radiusKm: Number.isFinite(parsedRadius) ? parsedRadius : undefined,
      location,
    });
    return this.enrichWithOwnerRating(payload as any, 'founder');
  }

  @Get('communities')
  async listCommunities(
    @Query('type') type?: string,
    @Query('category') category?: string,
    @Query('search') search?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    return this.communities.getCommunities(page, size, category, type as any, search);
  }
}
