import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { TradesService } from './trades.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { ListingUnreadService } from '../common/listing-unread.service';
import { TradeStatus } from '@prisma/client';

@UseGuards(JwtAuthGuard)
@Controller('v1/trades')
export class TradesController {
  constructor(
    private trades: TradesService,
    private readonly listingUnread: ListingUnreadService,
  ) {}

  @Post()
  async create(@CurrentUser() user: any, @Body() body: {
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
  }) {
    return this.trades.createTrade(user.sub, body);
  }

  @Get()
  async list(
    @CurrentUser() user: { sub: string },
    @Query('query') query?: string,
    @Query('ownerId') ownerId?: string,
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
      ownerId,
      status,
      page,
      size,
      lat: Number.isFinite(parsedLat) ? parsedLat : undefined,
      lng: Number.isFinite(parsedLng) ? parsedLng : undefined,
      radiusKm: Number.isFinite(parsedRadius) ? parsedRadius : undefined,
      location,
    });
    return this.listingUnread.enrichPayload(user.sub, payload);
  }

  @Get('similar')
  async similar(
    @Query('categoryId') categoryId?: string,
    @Query('category') category?: string,
    @Query('excludeId') excludeId?: string,
    @Query('limit') limitStr?: string,
  ) {
    const limit = Math.min(Math.max(parseInt(limitStr ?? '10', 10) || 10, 1), 50);
    const parsedCategoryId = categoryId !== undefined ? parseInt(categoryId, 10) : undefined;
    return this.trades.listSimilarTrades({
      categoryId: Number.isFinite(parsedCategoryId) ? parsedCategoryId : undefined,
      category,
      excludeId,
      limit,
    });
  }

  @Get('history/me')
  async history(@CurrentUser() user: any, @Query('page') pageStr?: string, @Query('size') sizeStr?: string) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    return this.trades.getUserTradeHistory(user.sub, page, size);
  }

  @Get(':id')
  async detail(@Param('id') id: string) {
    return this.trades.getTrade(id);
  }

  @Get(':id/comments')
  async listComments(
    @Param('id') id: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '50', 10) || 50, 1), 100);
    return this.trades.getTradeComments(id, page, size);
  }

  @Post(':id/comments')
  async addComment(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() body: { content: string; parentId?: string },
  ) {
    return this.trades.addTradeComment(user.sub, id, body.content, body.parentId);
  }

  @Patch(':id/comments/:commentId')
  async updateComment(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Param('commentId') commentId: string,
    @Body() body: { content: string },
  ) {
    return this.trades.updateTradeComment(user.sub, id, commentId, body.content);
  }

  @Post(':id/like')
  async likeTrade(@CurrentUser() user: any, @Param('id') id: string) {
    return this.trades.likeTrade(user.sub, id);
  }

  @Delete(':id/like')
  async unlikeTrade(@CurrentUser() user: any, @Param('id') id: string) {
    return this.trades.unlikeTrade(user.sub, id);
  }

  @Post(':id/publish')
  async publishDraft(@CurrentUser() user: any, @Param('id') id: string) {
    return this.trades.publishDraft(user.sub, id);
  }

  @Patch(':id')
  async update(@CurrentUser() user: any, @Param('id') id: string, @Body() body: {
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
    return this.trades.updateTrade(user.sub, id, body);
  }

  @Post(':id/close')
  async close(@CurrentUser() user: any, @Param('id') id: string) {
    return this.trades.closeTrade(user.sub, id);
  }

  @Post(':id/cancel')
  async cancel(@CurrentUser() user: any, @Param('id') id: string) {
    return this.trades.cancelTrade(user.sub, id);
  }

  @Delete(':id')
  async delete(@CurrentUser() user: any, @Param('id') id: string) {
    return this.trades.deleteTrade(user.sub, id);
  }

  @Get(':id/offers')
  async listOffers(@Param('id') id: string) {
    return this.trades.listOffers(id);
  }

  @Post(':id/offers')
  async createOffer(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body()
    body: {
      amount?: string;
      message?: string;
      offeredTradeId?: string;
      parentOfferId?: string;
      requestedTradeId?: string;
      requestedAmount?: string;
    },
  ) {
    return this.trades.createOffer(user.sub, id, body);
  }

  @Get('offers/:offerId/history')
  async getOfferHistory(@Param('offerId') offerId: string) {
    return this.trades.getOfferHistory(offerId);
  }

  @Post('offers/:offerId/accept')
  async acceptOffer(@CurrentUser() user: any, @Param('offerId') offerId: string) {
    return this.trades.acceptOffer(user.sub, offerId);
  }

  @Post('offers/:offerId/finalize')
  async finalizeOffer(@CurrentUser() user: any, @Param('offerId') offerId: string) {
    return this.trades.finalizeOffer(user.sub, offerId);
  }

  @Post('offers/:offerId/reject')
  async rejectOffer(@CurrentUser() user: any, @Param('offerId') offerId: string) {
    return this.trades.rejectOffer(user.sub, offerId);
  }

  @Post('offers/:offerId/withdraw')
  async withdrawOffer(@CurrentUser() user: any, @Param('offerId') offerId: string) {
    return this.trades.withdrawOffer(user.sub, offerId);
  }
}
