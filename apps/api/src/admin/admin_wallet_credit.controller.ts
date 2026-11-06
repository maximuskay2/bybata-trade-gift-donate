import { Body, Controller, Post, UseGuards, Req, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

type CreditDto = {
  userId: string;
  amountByc: number;
  memo?: string;
};

@Controller('v1/admin/wallet')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminWalletCreditController {
  constructor(private prisma: PrismaService) {}

  @Post('credit')
  async credit(@Body() body: CreditDto, @Req() req: any) {
    const { userId, amountByc, memo } = body;
    if (!userId || !amountByc || amountByc <= 0) {
      throw new BadRequestException('Invalid payload');
    }
    const admin = req.user as any;
    const adminId = admin?.sub as string;

    const account = await this.prisma.account.upsert({
      where: { userId },
      update: {},
      create: { userId, balance: 0 },
    });

    const tx = await this.prisma.$transaction(async (db) => {
      const created = await db.walletTransaction.create({
        data: {
          userId,
          accountId: account.id,
          type: 'BONUS',
          amount: amountByc as any,
          status: 'SUCCESS',
          memo: memo ?? 'Admin credit',
        } as any,
      });
      await db.account.update({
        where: { id: account.id },
        data: { balance: Number(account.balance as any) + Number(amountByc) },
      });

      await db.adminActionAudit.create({
        data: {
          adminId,
          action: 'WALLET_CREDIT',
          targetUserId: userId,
          details: { amountByc, memo },
        } as any,
      });

      return created;
    });

    return { ok: true, transactionId: tx.id };
  }
}
