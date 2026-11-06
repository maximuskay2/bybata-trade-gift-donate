import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { PrismaService } from '../common/prisma.service';
import { WalletService } from '../wallet/wallet.service';

@Controller('v1/admin/wallet/withdrawals')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminWalletWithdrawalsController {
  constructor(
    private prisma: PrismaService,
    private wallet: WalletService,
  ) {}

  @Get()
  async list(
    @Query('status') status?: string,
    @Query('userId') userId?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const where: any = {};
    if (status) where.status = status;
    if (userId) where.userId = userId;

    const [total, items] = await this.prisma.$transaction([
      (this.prisma as any).withdrawal.count({ where }),
      (this.prisma as any).withdrawal.findMany({
        where,
        include: {
          user: { include: { profile: true } },
          transaction: true,
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
      }),
    ]);
    return { items, page, size, total };
  }

  @Post(':id/complete')
  async complete(@Param('id') id: string, @Body() body: { reference?: string }, @Req() req: any) {
    const admin = req.user as any;
    const adminId = admin?.sub as string | undefined;
    return this.wallet.completeWithdrawal(id, adminId, body?.reference);
  }

  @Post(':id/reject')
  async reject(@Param('id') id: string, @Body() body: { reason?: string }, @Req() req: any) {
    const admin = req.user as any;
    const adminId = admin?.sub as string | undefined;
    return this.wallet.rejectWithdrawal(id, adminId, body?.reason, 'REJECTED');
  }

  @Post(':id/fail')
  async fail(@Param('id') id: string, @Body() body: { reason?: string }, @Req() req: any) {
    const admin = req.user as any;
    const adminId = admin?.sub as string | undefined;
    return this.wallet.rejectWithdrawal(id, adminId, body?.reason, 'FAILED');
  }
}
