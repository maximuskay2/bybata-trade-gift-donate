import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('v1/admin/referrals')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminReferralsController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async list(
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
    @Query('referrerId') referrerId?: string,
    @Query('referredUserId') referredUserId?: string,
    @Query('sort') sort?: string,
    @Query('dir') dir?: 'asc' | 'desc',
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const d: 'asc' | 'desc' = dir === 'asc' ? 'asc' : 'desc';

    const where: any = {};
    if (referrerId) where.referrerId = referrerId;
    if (referredUserId) where.referredUserId = referredUserId;

    let orderBy: any = { createdAt: d };
    if (sort === 'referrerId') orderBy = { referrer: { email: d } };
    else if (sort === 'referredUserId') orderBy = { referredUser: { email: d } };
    else if (sort === 'status') orderBy = { status: d };
    else if (sort === 'karmaAwarded') orderBy = { karmaAwarded: d };
    else if (sort === 'bycAwarded') orderBy = { bycAwarded: d };
    else if (sort === 'createdAt') orderBy = { createdAt: d };

    const [total, items] = await this.prisma.$transaction([
      this.prisma.userReferral.count({ where }),
      this.prisma.userReferral.findMany({
        where,
        include: {
          referrer: {
            select: {
              id: true,
              email: true,
              profile: { select: { displayName: true, referralCode: true } },
            },
          },
          referredUser: {
            select: {
              id: true,
              email: true,
              createdAt: true,
              profile: { select: { displayName: true } },
            },
          },
        },
        orderBy,
        skip: (page - 1) * size,
        take: size,
      }),
    ]);

    return {
      items: items.map((r) => ({
        id: r.id,
        referrerId: r.referrerId,
        referredUserId: r.referredUserId,
        referralCode: r.referralCode,
        status: r.status,
        karmaAwarded: r.karmaAwarded,
        bycAwarded: Number(r.bycAwarded),
        signedUpAt: r.signedUpAt,
        firstTradeAt: r.firstTradeAt,
        firstDonationAt: r.firstDonationAt,
        firstGiftAt: r.firstGiftAt,
        createdAt: r.createdAt,
        referrer: r.referrer,
        referredUser: r.referredUser,
      })),
      page,
      size,
      total,
    };
  }

  @Get('stats')
  async stats() {
    const [totalReferrals, referrerGroups, totalKarmaAwarded, totalBycAwarded, statusGroups] =
      await Promise.all([
        this.prisma.userReferral.count(),
        this.prisma.userReferral.groupBy({
          by: ['referrerId'],
          _count: true,
        }),
        this.prisma.userReferral.aggregate({ _sum: { karmaAwarded: true } }),
        this.prisma.userReferral.aggregate({ _sum: { bycAwarded: true } }),
        this.prisma.userReferral.groupBy({
          by: ['status'],
          _count: true,
          orderBy: { status: 'asc' },
        }),
      ]);

    const conversionCounts = statusGroups.reduce(
      (acc, s) => {
        acc[s.status] = s._count;
        return acc;
      },
      {} as Record<string, number>,
    );

    return {
      totalReferrals,
      totalReferrers: referrerGroups.length,
      totalKarmaAwarded: totalKarmaAwarded._sum.karmaAwarded ?? 0,
      totalBycEarned: Number(totalBycAwarded._sum.bycAwarded ?? 0),
      byStatus: conversionCounts,
    };
  }
}
