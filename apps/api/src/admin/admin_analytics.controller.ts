import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('v1/admin/wallet/analytics')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminAnalyticsController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async overview(@Query('from') from?: string, @Query('to') to?: string) {
    const whereIntent: any = {};
    if (from || to) {
      whereIntent.createdAt = {};
      if (from) whereIntent.createdAt.gte = new Date(from);
      if (to) whereIntent.createdAt.lte = new Date(to);
    }

    const intents = await (this.prisma as any).fundingIntent.groupBy({
      by: ['provider', 'status'],
      where: whereIntent,
      _count: { _all: true },
      _sum: { amountMinor: true },
    });

    const providers = ['paystack', 'stripe', 'paypal'];
    const volumeByProvider: Record<string, { count: number; amountMinor: number }> = {};
    const failuresByProvider: Record<string, number> = {};
    for (const p of providers) {
      const succeeded = intents.filter((i: any) => i.provider === p && i.status === 'SUCCEEDED');
      const failed = intents.filter((i: any) => i.provider === p && i.status === 'FAILED');
      const sumMinor = succeeded.reduce((acc: number, i: any) => acc + Number(i._sum?.amountMinor ?? 0), 0);
      const count = succeeded.reduce((acc: number, i: any) => acc + Number(i._count?._all ?? 0), 0);
      volumeByProvider[p] = { count, amountMinor: sumMinor };
      failuresByProvider[p] = failed.reduce((acc: number, i: any) => acc + Number(i._count?._all ?? 0), 0);
    }

    // Simple suspicious detection: very large amounts
    const largeThresholdMinor = Math.round(Number(process.env.WALLET_FUND_LARGE_THRESHOLD_MAJOR ?? 1000) * 100);
    const suspicious = await (this.prisma as any).fundingIntent.findMany({
      where: { amountMinor: { gt: largeThresholdMinor }, status: 'SUCCEEDED' },
      orderBy: { amountMinor: 'desc' },
      take: 20,
    });

    return {
      volumeByProvider,
      failuresByProvider,
      suspicious,
    };
  }
}
