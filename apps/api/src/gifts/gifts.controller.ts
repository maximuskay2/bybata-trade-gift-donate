import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards, Delete } from '@nestjs/common';
import { GiftsService } from './gifts.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { ListingUnreadService } from '../common/listing-unread.service';
import { GiftStatus, GiftType, GiftCategory, GiftRequestStatus } from '@prisma/client';

@UseGuards(JwtAuthGuard)
@Controller('v1/gifts')
export class GiftsController {
  constructor(
    private gifts: GiftsService,
    private readonly listingUnread: ListingUnreadService,
  ) {}

  @Post()
  async create(@CurrentUser() user: any, @Body() body: {
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
    expiresAt?: string;
  }) {
    const expiresAt = body.expiresAt ? new Date(body.expiresAt) : undefined;
    return this.gifts.createGift(user.sub, { ...body, expiresAt });
  }

  @Get()
  async list(
    @CurrentUser() user: { sub: string },
    @Query('query') query?: string,
    @Query('category') category?: GiftCategory,
    @Query('type') type?: GiftType,
    @Query('status') status?: GiftStatus,
    @Query('giverId') giverId?: string,
    @Query('location') location?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('lon') lon?: string,
    @Query('radiusKm') radiusKm?: string,
    @Query('minKarma') minKarmaStr?: string,
    @Query('maxKarma') maxKarmaStr?: string,
    @Query('sortBy') sortBy?: string,
    @Query('sortOrder') sortOrder?: 'asc' | 'desc',
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const minKarma = minKarmaStr ? parseInt(minKarmaStr, 10) : undefined;
    const maxKarma = maxKarmaStr ? parseInt(maxKarmaStr, 10) : undefined;
    const parsedLat = parseFloat(lat ?? '');
    const parsedLng = parseFloat(lng ?? lon ?? '');
    const parsedRadius = parseFloat(radiusKm ?? '50');
    
    const payload = await this.gifts.listGifts({ 
      query, 
      category, 
      type,
      status,
      giverId,
      location,
      lat: Number.isFinite(parsedLat) ? parsedLat : undefined,
      lng: Number.isFinite(parsedLng) ? parsedLng : undefined,
      radiusKm: Number.isFinite(parsedRadius) ? parsedRadius : undefined,
      minKarma,
      maxKarma,
      sortBy,
      sortOrder,
      page, 
      size 
    });
    return this.listingUnread.enrichPayload(user.sub, payload);
  }

  @Get('my-gifts')
  async myGifts(
    @CurrentUser() user: any,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
    @Query('status') status?: GiftStatus,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    return this.gifts.getMyGifts(user.sub, { page, size, status });
  }

  @Get('history')
  async history(
    @CurrentUser() user: any,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    return this.gifts.getGiftHistory(user.sub, { page, size });
  }

  // Gift Request endpoints - MUST be before :id route!
  @Get('requests')
  async listRequests(
    @CurrentUser() user: any,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
    @Query('status') status?: GiftRequestStatus,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    return this.gifts.listGiftRequests(user.sub, { page, size, status });
  }

  @Post('requests/:id/approve')
  async approveRequest(
    @CurrentUser() user: any,
    @Param('id') requestId: string,
    @Body() body: { message?: string }
  ) {
    return this.gifts.approveGiftRequest(user.sub, requestId, body.message);
  }

  @Post('requests/:id/decline')
  async declineRequest(
    @CurrentUser() user: any,
    @Param('id') requestId: string,
    @Body() body: { reason?: string }
  ) {
    return this.gifts.declineGiftRequest(user.sub, requestId, body.reason);
  }

  @Get(':id/similar')
  async similar(@Param('id') id: string, @Query('limit') limitStr?: string) {
    const limit = Math.min(Math.max(parseInt(limitStr ?? '8', 10) || 8, 1), 20);
    return this.gifts.getSimilarGifts(id, limit);
  }

  @Get(':id')
  async detail(@Param('id') id: string) {
    return this.gifts.getGift(id);
  }

  @Get('analytics/user')
  async getUserAnalytics(@CurrentUser() user: any) {
    return this.gifts.getUserGiftAnalytics(user.sub);
  }

  @Get('recommendations')
  async getRecommendations(@CurrentUser() user: any) {
    return this.gifts.getRecommendedGifts(user.sub);
  }

  @Get(':id/comments')
  async listComments(
    @Param('id') id: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '50', 10) || 50, 1), 100);
    return this.gifts.getGiftComments(id, page, size);
  }

  @Post(':id/share')
  async shareGift(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() body: { platform: string; message?: string }
  ) {
    return this.gifts.shareGift(user.sub, id, body.platform, body.message);
  }

  @Post(':id/view')
  async incrementView(@Param('id') id: string) {
    return this.gifts.incrementGiftView(id);
  }

  @Post(':id/comments')
  async addComment(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() body: { content: string; parentId?: string }
  ) {
    return this.gifts.addComment(user.sub, id, body.content, body.parentId);
  }

  @Patch(':id/comments/:commentId')
  async updateComment(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Param('commentId') commentId: string,
    @Body() body: { content: string },
  ) {
    return this.gifts.updateComment(user.sub, id, commentId, body.content);
  }

  @Post(':id/like')
  async likeGift(
    @CurrentUser() user: any,
    @Param('id') id: string
  ) {
    return this.gifts.likeGift(user.sub, id);
  }

  @Delete(':id/like')
  async unlikeGift(
    @CurrentUser() user: any,
    @Param('id') id: string
  ) {
    return this.gifts.unlikeGift(user.sub, id);
  }

  @Patch(':id')
  async update(@CurrentUser() user: any, @Param('id') id: string, @Body() body: {
    title?: string;
    description?: string;
    mediaType?: string;
    mediaKeys?: string[];
    videoKey?: string;
    karmaReward?: number;
    maxClaims?: number;
    location?: string;
    tags?: string[];
    isChainGift?: boolean;
    chainParentId?: string | null;
    expiresAt?: string;
  }) {
    const expiresAt = body.expiresAt ? new Date(body.expiresAt) : undefined;
    return this.gifts.updateGift(user.sub, id, { ...body, expiresAt });
  }

  @Post(':id/cancel')
  async cancel(@CurrentUser() user: any, @Param('id') id: string) {
    return this.gifts.cancelGift(user.sub, id);
  }

  @Delete(':id')
  async delete(@CurrentUser() user: any, @Param('id') id: string) {
    return this.gifts.deleteGift(user.sub, id);
  }

  @Post(':id/claim')
  async claim(@CurrentUser() user: any, @Param('id') id: string, @Body() body: { claimCode?: string; message?: string }) {
    return this.gifts.claimGift(user.sub, id, body.claimCode, body.message);
  }
}
