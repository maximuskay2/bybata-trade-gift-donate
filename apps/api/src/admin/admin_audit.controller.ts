import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('v1/admin/wallet/audit')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminAuditController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async list(
    @Query('adminId') adminId?: string,
    @Query('targetUserId') targetUserId?: string,
    @Query('action') action?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const where: any = {};
    if (adminId) where.adminId = adminId;
    if (targetUserId) where.targetUserId = targetUserId;
    if (action) where.action = action;
    const [total, items] = await this.prisma.$transaction([
      (this.prisma as any).adminActionAudit.count({ where }),
      (this.prisma as any).adminActionAudit.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
        include: { admin: { select: { email: true } }, targetUser: { select: { email: true } } },
      }),
    ]);
    return { items, page, size, total };
  }
}
