import { Controller, Get, Query, Param, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('v1/admin/wallet/transactions')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminWalletController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async list(
    @Query('type') type?: string,
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
    if (type) where.type = type;
    if (status) where.status = status;
    if (query) {
      where.OR = [
        { memo: { contains: query, mode: 'insensitive' } },
        { user: { email: { contains: query, mode: 'insensitive' } } },
        { user: { profile: { displayName: { contains: query, mode: 'insensitive' } } } },
      ];
    }
    const d: 'asc' | 'desc' = dir === 'asc' ? 'asc' : 'desc';
    let orderBy: any = { createdAt: d };
    if (sort === 'type') orderBy = { type: d };
    else if (sort === 'status') orderBy = { status: d };
    else if (sort === 'amount') orderBy = { amount: d } as any;
    else if (sort === 'userEmail') orderBy = { user: { email: d } };
    else if (sort === 'createdAt') orderBy = { createdAt: d };

    const [total, items] = await this.prisma.$transaction([
      this.prisma.walletTransaction.count({ where }),
      this.prisma.walletTransaction.findMany({
        where,
        include: { 
          user: { 
            include: { profile: true } 
          },
          transfer: true,
          promotion: true,
        },
        orderBy,
        skip: (page - 1) * size,
        take: size,
      }),
    ]);
    
    // Format items for better readability
    const formattedItems = items.map((item: any) => ({
      ...item,
      amount: typeof item.amount === 'number' ? item.amount : (item.amount?.toNumber ? item.amount.toNumber() : Number(item.amount || 0)),
    }));
    
    return { items: formattedItems, page, size, total };
  }

  /**
   * Get transaction details by ID
   * Provides complete audit trail information
   */
  @Get(':id')
  async getTransaction(@Param('id') id: string) {
    const transaction = await this.prisma.walletTransaction.findUnique({
      where: { id },
      include: {
        user: {
          include: { profile: true },
        },
        account: true,
        transfer: {
          include: {
            sender: { include: { profile: true } },
            recipient: { include: { profile: true } },
          },
        },
        promotion: true,
      },
    });

    if (!transaction) {
      return { ok: false, error: 'Transaction not found' };
    }

    return {
      ok: true,
      transaction: {
        ...transaction,
        amount: typeof transaction.amount === 'number' 
          ? transaction.amount 
          : (transaction.amount?.toNumber ? transaction.amount.toNumber() : Number(transaction.amount || 0)),
      },
    };
  }
}