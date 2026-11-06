import { Body, Controller, Get, Param, Post, Query, UseGuards, Req, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { ReportStatus, UserReportAdminAction } from '@prisma/client';

@Controller('v1/admin/reports')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminUserReportsController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async list(
    @Query('status') status?: ReportStatus,
    @Query('reportedUserId') reportedUserId?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const where: any = {};
    if (status) where.status = status;
    if (reportedUserId) where.reportedUserId = reportedUserId;

    const [total, items] = await Promise.all([
      this.prisma.userReport.count({ where }),
      this.prisma.userReport.findMany({
        where,
        include: {
          reporter: { include: { profile: true } },
          reportedUser: { include: { profile: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
      }),
    ]);

    return { items, page, size, total };
  }

  @Get(':id')
  async detail(@Param('id') id: string) {
    const report = await this.prisma.userReport.findUnique({
      where: { id },
      include: {
        reporter: { include: { profile: true } },
        reportedUser: { include: { profile: true } },
      },
    });
    if (!report) throw new BadRequestException('Report not found');
    const otherReports = await this.prisma.userReport.findMany({
      where: { reportedUserId: report.reportedUserId },
      include: { reporter: { include: { profile: true } } },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    return { report, otherReports };
  }

  @Post(':id/action')
  async takeAction(
    @Param('id') id: string,
    @Req() req: any,
    @Body() body: { action: UserReportAdminAction; adminNote?: string; suspendDurationHours?: number },
  ) {
    const { action, adminNote, suspendDurationHours } = body;
    if (!action || !['DISMISS', 'WARN', 'SUSPEND', 'BAN'].includes(action)) {
      throw new BadRequestException('Invalid action. Must be DISMISS, WARN, SUSPEND, or BAN.');
    }
    const report = await this.prisma.userReport.findUnique({ where: { id }, include: { reportedUser: true } });
    if (!report) throw new BadRequestException('Report not found');
    const adminId = (req.user as any)?.sub;

    const suspendUntil =
      action === 'SUSPEND' && Number.isFinite(suspendDurationHours) && suspendDurationHours! > 0
        ? new Date(Date.now() + suspendDurationHours! * 60 * 60 * 1000)
        : null;

    await this.prisma.$transaction(async (tx) => {
      await (tx as any).userReport.update({
        where: { id },
        data: {
          status: ReportStatus.RESOLVED,
          adminAction: action,
          reviewedBy: adminId,
          reviewedAt: new Date(),
          adminNote: adminNote?.trim() || null,
          suspendUntil,
        },
      });

      const target = report.reportedUserId;
      if (action === 'BAN') {
        await (tx as any).user.update({
          where: { id: target },
          data: { banned: true, bannedUntil: null, banNote: adminNote || `Banned due to report: ${report.reason}` },
        });
      } else if (action === 'SUSPEND' && suspendUntil) {
        await (tx as any).user.update({
          where: { id: target },
          data: { banned: true, bannedUntil: suspendUntil, banNote: adminNote || `Suspended due to report: ${report.reason}` },
        });
      }

      await (tx as any).adminActionAudit.create({
        data: {
          adminId,
          action: 'USER_REPORT_ACTION',
          targetUserId: target,
          details: { reportId: id, action, adminNote, suspendUntil: suspendUntil?.toISOString() },
        },
      });
    });

    return { ok: true, message: `Report ${action.toLowerCase()}ed successfully` };
  }
}
