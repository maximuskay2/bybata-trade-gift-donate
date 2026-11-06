import { Body, Controller, Delete, Get, Param, Patch, Post, Query, Req, Res, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AdminListingModerationService } from './admin_listing_moderation.service';
import { ListingModerationDto } from './dto/listing-moderation.dto';
import type { Response } from 'express';

@Controller('v1/admin/trades')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminTradesController {
  constructor(
    private prisma: PrismaService,
    private moderation: AdminListingModerationService,
  ) {}

  @Get()
  async list(
    @Query('status') status?: string,
    @Query('query') query?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
    @Query('sort') sort?: string,
    @Query('dir') dir?: 'asc' | 'desc',
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const where: any = {};
    if (status) where.status = status;
    if (query) {
      where.OR = [
        { title: { contains: query, mode: 'insensitive' } },
        { owner: { email: { contains: query, mode: 'insensitive' } } },
        { owner: { profile: { displayName: { contains: query, mode: 'insensitive' } } } },
      ];
    }
    const d: 'asc' | 'desc' = dir === 'asc' ? 'asc' : 'desc';
    let orderBy: any = { createdAt: d };
    if (sort === 'title') orderBy = { title: d };
    else if (sort === 'status') orderBy = { status: d };
    else if (sort === 'ownerEmail') orderBy = { owner: { email: d } };
    else if (sort === 'createdAt') orderBy = { createdAt: d };

    const [total, items] = await this.prisma.$transaction([
      this.prisma.trade.count({ where }),
      this.prisma.trade.findMany({
        where,
        include: { owner: { include: { profile: true } }, adminModeratedBy: { include: { profile: true } } },
        orderBy,
        skip: (page - 1) * size,
        take: size,
      }),
    ]);
    return { items, page, size, total };
  }

  @Get(':id/offers')
  async offers(@Param('id') id: string) {
    return this.prisma.tradeOffer.findMany({ where: { tradeId: id }, include: { bidder: { include: { profile: true } } }, orderBy: { createdAt: 'desc' } });
  }

  @Post(':id/moderate')
  async moderate(@Param('id') id: string, @Req() req: any, @Body() body: ListingModerationDto) {
    const adminId = (req.user as any)?.sub;
    return this.moderation.moderate({
      listingType: 'trade',
      listingId: id,
      adminId,
      action: body.action,
      reason: body.reason,
      notifyOwner: body.notifyOwner,
    });
  }

  @Post(':id/force-close')
  async forceClose(@Param('id') id: string) {
    return this.prisma.trade.update({ where: { id }, data: { status: 'CLOSED', closedAt: new Date() } });
  }

  @Post(':id/force-cancel')
  async forceCancel(@Param('id') id: string) {
    return this.prisma.trade.update({ where: { id }, data: { status: 'CANCELLED', cancelledAt: new Date() } });
  }

  @Post(':id/force-open')
  async forceOpen(@Param('id') id: string) {
    // Reopen a trade by setting status back to OPEN and clearing closed/cancelled timestamps
    return this.prisma.trade.update({ where: { id }, data: { status: 'OPEN', closedAt: null, cancelledAt: null } });
  }

  @Patch(':id')
  async adminUpdate(
    @Param('id') id: string,
    @Body() body: {
      title?: string;
      description?: string;
      mediaKeys?: string[];
      // category and flags are accepted but ignored here until schema/client are migrated
      category?: string;
      isNegotiable?: boolean;
      requiresPickup?: boolean;
      allowDelivery?: boolean;
      allowShipping?: boolean;
      enableBYCPromotion?: boolean;
    }
  ) {
    const data: any = {};
    if (body.title !== undefined) data.title = body.title;
    if (body.description !== undefined) data.description = body.description;
    if (body.mediaKeys !== undefined) data.mediaKeys = body.mediaKeys;
    // Optional: allow admins to set category and flags
    if (body.category !== undefined) data.category = body.category as any;
    if (body.isNegotiable !== undefined) data.isNegotiable = body.isNegotiable;
    if (body.requiresPickup !== undefined) data.requiresPickup = body.requiresPickup;
    if (body.allowDelivery !== undefined) data.allowDelivery = body.allowDelivery;
    if (body.allowShipping !== undefined) data.allowShipping = body.allowShipping;
    if (body.enableBYCPromotion !== undefined) data.enableBYCPromotion = body.enableBYCPromotion;
    return this.prisma.trade.update({ where: { id }, data });
  }

  @Delete(':id')
  async adminDelete(@Param('id') id: string) {
    // Delete trade and cascade offers if needed
    return this.prisma.trade.delete({ where: { id } });
  }

  @Get('export/csv')
  async exportCsv(@Res() res: Response) {
    const trades = await this.prisma.trade.findMany({ include: { owner: { include: { profile: true } }, acceptedOffer: true } });
    const header = ['id','title','status','ownerEmail','displayName','createdAt','closedAt','cancelledAt','acceptedOfferId'];
    const rows = [header.join(',')];
    for (const t of trades) {
      rows.push([
        t.id,
        JSON.stringify(t.title ?? ''),
        t.status,
        t.owner?.email ?? '',
        t.owner?.profile?.displayName ?? '',
        t.createdAt.toISOString(),
        t.closedAt ? t.closedAt.toISOString() : '',
        t.cancelledAt ? t.cancelledAt.toISOString() : '',
        t.acceptedOfferId ?? '',
      ].join(','));
    }
    const csv = rows.join('\n');
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="trades.csv"');
    res.send(csv);
  }
}
