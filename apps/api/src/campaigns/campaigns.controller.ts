import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { CampaignsService } from './campaigns.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { ListingUnreadService } from '../common/listing-unread.service';
import { CampaignStatus } from '@prisma/client';

@UseGuards(JwtAuthGuard)
@Controller('v1/campaigns')
export class CampaignsController {
  constructor(
    private campaigns: CampaignsService,
    private readonly listingUnread: ListingUnreadService,
  ) {}

  @Post()
  async create(@CurrentUser() user: any, @Body() body: {
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
    endsAt?: string;
    metadata?: any;
  }) {
    const endsAt = body.endsAt ? new Date(body.endsAt) : undefined;
    return this.campaigns.createCampaign(user.sub, { ...body, endsAt });
  }

  @Get()
  async list(
    @CurrentUser() user: { sub: string },
    @Query('query') query?: string,
    @Query('category') category?: string,
    @Query('status') status?: CampaignStatus,
    @Query('founderId') founderId?: string,
    @Query('location') location?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('lon') lon?: string,
    @Query('radiusKm') radiusKm?: string,
    @Query('isUrgent') isUrgentStr?: string,
    @Query('isFeatured') isFeaturedStr?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const isUrgent = isUrgentStr === 'true' ? true : isUrgentStr === 'false' ? false : undefined;
    const isFeatured = isFeaturedStr === 'true' ? true : isFeaturedStr === 'false' ? false : undefined;
    const parsedLat = parseFloat(lat ?? '');
    const parsedLng = parseFloat(lng ?? lon ?? '');
    const parsedRadius = parseFloat(radiusKm ?? '50');

    const payload = await this.campaigns.listCampaigns({
      query,
      category,
      status,
      founderId,
      location,
      lat: Number.isFinite(parsedLat) ? parsedLat : undefined,
      lng: Number.isFinite(parsedLng) ? parsedLng : undefined,
      radiusKm: Number.isFinite(parsedRadius) ? parsedRadius : undefined,
      isUrgent,
      isFeatured,
      page,
      size,
    });
    return this.listingUnread.enrichPayload(user.sub, payload);
  }

  @Get('my-campaigns')
  async myCampaigns(
    @CurrentUser() user: any,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
    @Query('status') status?: CampaignStatus,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    return this.campaigns.getMyCampaigns(user.sub, { page, size, status });
  }

  @Get('donation-history')
  async donationHistory(
    @CurrentUser() user: any,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    return this.campaigns.getDonationHistory(user.sub, { page, size });
  }

  @Get('donations/:donationId/receipt.pdf')
  async donationReceiptPdf(
    @CurrentUser() user: any,
    @Param('donationId') donationId: string,
  ) {
    const { buffer, filename } = await this.campaigns.generateDonationReceiptPdf(
      user.sub,
      donationId,
    );
    return new StreamableFile(buffer, {
      type: 'application/pdf',
      disposition: `attachment; filename="${filename}"`,
    });
  }

  @Get('donation-receipts/:year.pdf')
  async donationYearReceiptPdf(
    @CurrentUser() user: any,
    @Param('year') yearStr: string,
  ) {
    const year = parseInt(yearStr, 10) || new Date().getFullYear();
    const { buffer, filename } = await this.campaigns.generateDonationReceiptPdfBuffer(
      user.sub,
      year,
    );
    return new StreamableFile(buffer, {
      type: 'application/pdf',
      disposition: `attachment; filename="${filename}"`,
    });
  }

  @Get(':id')
  async detail(@Param('id') id: string) {
    return this.campaigns.getCampaign(id);
  }

  @Get(':id/comments')
  async listComments(
    @Param('id') id: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '50', 10) || 50, 1), 100);
    return this.campaigns.getCampaignComments(id, page, size);
  }

  @Post(':id/comments')
  async addComment(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() body: { content: string; parentId?: string },
  ) {
    return this.campaigns.addCampaignComment(user.sub, id, body.content, body.parentId);
  }

  @Patch(':id/comments/:commentId')
  async updateComment(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Param('commentId') commentId: string,
    @Body() body: { content: string },
  ) {
    return this.campaigns.updateCampaignComment(user.sub, id, commentId, body.content);
  }

  @Post(':id/like')
  async likeCampaign(@CurrentUser() user: any, @Param('id') id: string) {
    return this.campaigns.likeCampaign(user.sub, id);
  }

  @Delete(':id/like')
  async unlikeCampaign(@CurrentUser() user: any, @Param('id') id: string) {
    return this.campaigns.unlikeCampaign(user.sub, id);
  }

  @Patch(':id')
  async update(@CurrentUser() user: any, @Param('id') id: string, @Body() body: {
    title?: string;
    description?: string;
    shortDescription?: string;
    category?: string;
    goalAmount?: number;
    mediaKeys?: string[];
    thumbnailKey?: string;
    tags?: string[];
    location?: string;
    isUrgent?: boolean;
    minimumDonation?: number;
    endsAt?: string;
    metadata?: any;
  }) {
    const endsAt = body.endsAt ? new Date(body.endsAt) : undefined;
    return this.campaigns.updateCampaign(user.sub, id, { ...body, endsAt });
  }

  @Post(':id/status')
  async updateStatus(@CurrentUser() user: any, @Param('id') id: string, @Body() body: {
    status: CampaignStatus;
  }) {
    return this.campaigns.updateCampaignStatus(user.sub, id, body.status);
  }

  @Post(':id/donate')
  async donate(@CurrentUser() user: any, @Param('id') id: string, @Body() body: {
    amount: number;
    currency?: string;
    isAnonymous?: boolean;
    message?: string;
    rewardTierId?: string;
    idempotencyKey?: string;
  }) {
    return this.campaigns.donate(user.sub, id, body);
  }

  @Get(':id/analytics')
  async campaignAnalytics(@Param('id') id: string) {
    return this.campaigns.getCampaignAnalytics(id);
  }

  @Get('creator/analytics')
  async creatorAnalytics(@CurrentUser() user: any) {
    return this.campaigns.getCreatorAnalytics(user.sub);
  }

  @Get('donor/analytics')
  async donorAnalytics(@CurrentUser() user: any) {
    return this.campaigns.getDonorAnalytics(user.sub);
  }

  @Get('donation-receipts/:year')
  async donationReceipt(
    @CurrentUser() user: any,
    @Param('year') yearStr: string,
  ) {
    const year = parseInt(yearStr, 10) || new Date().getFullYear();
    return this.campaigns.generateDonationReceipt(user.sub, year);
  }

  @Get('search')
  async searchCampaigns(
    @Query('categories') categories: string | string[] | undefined,
    @Query('minAmount') minAmount?: string,
    @Query('maxAmount') maxAmount?: string,
    @Query('exactAmount') exactAmount?: string,
    @Query('page') page: string = '1',
    @Query('size') size: string = '20',
  ) {
    const categoriesArr = Array.isArray(categories)
      ? categories
      : categories
      ? [categories]
      : [];
    return this.campaigns.searchCampaigns({
      categories: categoriesArr,
      minAmount: minAmount ? Number(minAmount) : undefined,
      maxAmount: maxAmount ? Number(maxAmount) : undefined,
      exactAmount: exactAmount === 'true',
      page: Number(page) || 1,
      size: Number(size) || 20,
    });
  }

  @Post(':id/updates')
  async postUpdate(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() body: { type?: string; content?: string; mediaKeys?: string[] }
  ) {
    return this.campaigns.createUpdate(user.sub, id, body);
  }

  @Get(':id/updates')
  async listUpdates(@Param('id') id: string) {
    return this.campaigns.listUpdates(id);
  }

  @Get(':id/tiers')
  async listRewardTiers(@Param('id') id: string) {
    return this.campaigns.listRewardTiers(id);
  }

  @Post(':id/tiers')
  async createRewardTier(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() body: { title: string; description?: string; minimumDonation: number; limitedQuantity?: number }
  ) {
    return this.campaigns.createRewardTier(user.sub, id, body);
  }

  @Patch(':id/tiers/:tierId')
  async updateRewardTier(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Param('tierId') tierId: string,
    @Body() body: { title?: string; description?: string; minimumDonation?: number; limitedQuantity?: number; status?: string }
  ) {
    return this.campaigns.updateRewardTier(user.sub, id, tierId, body);
  }

  @Delete(':id/tiers/:tierId')
  async deleteRewardTier(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Param('tierId') tierId: string,
  ) {
    return this.campaigns.deleteRewardTier(user.sub, id, tierId);
  }

  @Delete(':id')
  async delete(@CurrentUser() user: any, @Param('id') id: string) {
    return this.campaigns.deleteCampaign(user.sub, id);
  }
}
