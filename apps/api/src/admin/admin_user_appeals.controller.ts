import { Body, Controller, Get, Param, Post, Query, UseGuards, Req, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AppealStatus } from '@prisma/client';

@Controller('v1/admin/appeals')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminUserAppealsController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async list(
    @Query('status') status?: AppealStatus,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const where: any = {};
    if (status) where.status = status;

    const [total, items] = await Promise.all([
      this.prisma.userAppeal.count({ where }),
      this.prisma.userAppeal.findMany({
        where,
        include: { user: { include: { profile: true } } },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
      }),
    ]);

    return { items, page, size, total };
  }

  @Post(':id/review')
  async review(
    @Param('id') id: string,
    @Req() req: any,
    @Body() body: { status: 'APPROVED' | 'REJECTED'; adminNote?: string },
  ) {
    const { status, adminNote } = body;
    if (!status || !['APPROVED', 'REJECTED'].includes(status)) {
      throw new BadRequestException('Invalid status. Must be APPROVED or REJECTED.');
    }
    const appeal = await this.prisma.userAppeal.findUnique({ where: { id }, include: { user: true } });
    if (!appeal) throw new BadRequestException('Appeal not found');
    if (appeal.status !== AppealStatus.PENDING && appeal.status !== AppealStatus.UNDER_REVIEW) {
      throw new BadRequestException('Appeal has already been reviewed');
    }
    const adminId = (req.user as any)?.sub;

    await this.prisma.$transaction(async (tx) => {
      await (tx as any).userAppeal.update({
        where: { id },
        data: {
          status: status as AppealStatus,
          reviewedBy: adminId,
          reviewedAt: new Date(),
          adminNote: adminNote?.trim() || null,
        },
      });

      if (status === 'APPROVED') {
        await (tx as any).user.update({
          where: { id: appeal.userId },
          data: { banned: false, bannedUntil: null, banNote: null },
        });
      }

      await (tx as any).adminActionAudit.create({
        data: {
          adminId,
          action: 'APPEAL_REVIEW',
          targetUserId: appeal.userId,
          details: { appealId: id, status, adminNote },
        },
      });
    });

    return { ok: true, message: `Appeal ${status.toLowerCase()} successfully` };
  }
}
