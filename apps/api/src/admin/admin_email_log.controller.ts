import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('v1/admin/email/logs')
export class AdminEmailLogController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(
    @Query('page') page = '1',
    @Query('pageSize') pageSize = '20',
    @Query('status') status?: string,
    @Query('provider') provider?: string,
    @Query('recipientEmail') recipientEmail?: string,
    @Query('eventName') eventName?: string,
  ) {
    const pageNum = Math.max(parseInt(page, 10) || 1, 1);
    const sizeNum = Math.min(Math.max(parseInt(pageSize, 10) || 20, 1), 100);

    const where: any = {};
    if (status) where.status = status;
    if (provider) where.provider = provider;
    if (recipientEmail) where.recipientEmail = { contains: recipientEmail, mode: 'insensitive' };
    if (eventName) where.eventName = { contains: eventName, mode: 'insensitive' };

    const [items, total] = await Promise.all([
      (this.prisma as any).emailLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (pageNum - 1) * sizeNum,
        take: sizeNum,
      }),
      (this.prisma as any).emailLog.count({ where }),
    ]);

    return {
      items,
      total,
      page: pageNum,
      pageSize: sizeNum,
    };
  }
}
