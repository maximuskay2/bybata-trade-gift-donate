import {
  BadRequestException,
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { EmailService } from '../common/email.service';
import { EmailEventName } from '../email/email-events';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { StorageService } from '../storage/storage.service';
import { ScaleCacheService } from '../common/scale/scale-cache.service';
import { ScaleCacheKeys } from '../common/scale/scale.constants';

@Controller('v1/admin/verification')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminVerificationController {
  constructor(
    private prisma: PrismaService,
    private email: EmailService,
    private storage: StorageService,
    private scaleCache: ScaleCacheService,
  ) {}

  private async invalidateUserCaches(userId: string) {
    await this.scaleCache.delMany([
      ScaleCacheKeys.me(userId),
      ScaleCacheKeys.meLight(userId),
    ]);
  }

  /**
   * Queue of users who submitted verification documents (grouped by user).
   * Prefer this over flat /documents for admin review.
   */
  @Get('submissions')
  async listSubmissions(
    @Query('status') status?: string,
    @Query('kyc') kyc?: string,
    @Query('q') q?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);

    const docWhere: any = {};
    if (status) docWhere.status = status.toUpperCase();

    const andFilters: any[] = [
      { verificationDocuments: { some: docWhere } },
    ];
    if (kyc) {
      andFilters.push({ profile: { kycStatus: kyc } });
    }
    if (q?.trim()) {
      const term = q.trim();
      andFilters.push({
        OR: [
          { email: { contains: term, mode: 'insensitive' } },
          { profile: { displayName: { contains: term, mode: 'insensitive' } } },
        ],
      });
    }

    const matchingUsers = await this.prisma.user.findMany({
      where: { AND: andFilters },
      select: { id: true },
    });
    const allIds = matchingUsers.map((u) => u.id);
    const total = allIds.length;
    if (total === 0) {
      return { items: [], page, size, total: 0 };
    }

    const latestByUser = await (this.prisma as any).verificationDocument.groupBy({
      by: ['userId'],
      where: {
        userId: { in: allIds },
        ...docWhere,
      },
      _max: { uploadedAt: true },
      _count: { _all: true },
    });
    latestByUser.sort(
      (a: any, b: any) =>
        new Date(b._max.uploadedAt).getTime() -
        new Date(a._max.uploadedAt).getTime(),
    );
    const pageGroups = latestByUser.slice((page - 1) * size, page * size);
    const pageIds = pageGroups.map((g: any) => g.userId as string);

    const [users, docs] = await Promise.all([
      this.prisma.user.findMany({
        where: { id: { in: pageIds } },
        include: {
          profile: {
            select: {
              displayName: true,
              phone: true,
              phoneVerifiedAt: true,
              kycStatus: true,
              kycNote: true,
              avatarKey: true,
            },
          },
        },
      }),
      (this.prisma as any).verificationDocument.findMany({
        where: { userId: { in: pageIds } },
        select: {
          id: true,
          userId: true,
          type: true,
          status: true,
          fileName: true,
          uploadedAt: true,
        },
        orderBy: { uploadedAt: 'desc' },
      }),
    ]);

    const userMap = new Map(users.map((u) => [u.id, u]));
    const docsByUser = new Map<string, any[]>();
    for (const d of docs) {
      const list = docsByUser.get(d.userId) || [];
      list.push(d);
      docsByUser.set(d.userId, list);
    }

    const items = pageIds.map((userId: string) => {
      const user = userMap.get(userId);
      const userDocs = docsByUser.get(userId) || [];
      const pending = userDocs.filter((d) => d.status === 'PENDING').length;
      const approved = userDocs.filter((d) => d.status === 'APPROVED').length;
      const rejected = userDocs.filter((d) => d.status === 'REJECTED').length;
      const latest = pageGroups.find((g: any) => g.userId === userId)?._max
        ?.uploadedAt;
      return {
        userId,
        email: user?.email ?? null,
        displayName: user?.profile?.displayName ?? null,
        phone: user?.profile?.phone ?? null,
        phoneVerified: Boolean(user?.profile?.phoneVerifiedAt),
        emailVerified: Boolean((user as any)?.emailVerifiedAt),
        kycStatus: user?.profile?.kycStatus ?? 'NOT_VERIFIED',
        kycNote: user?.profile?.kycNote ?? null,
        documentCount: userDocs.length,
        pendingCount: pending,
        approvedCount: approved,
        rejectedCount: rejected,
        lastSubmittedAt: latest ?? userDocs[0]?.uploadedAt ?? null,
        documentTypes: [...new Set(userDocs.map((d) => d.type))],
        documents: userDocs,
      };
    });

    return { items, page, size, total };
  }

  /** Full verification packet for one user (all submitted documents). */
  @Get('users/:userId')
  async getUserSubmission(@Param('userId') userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        profile: true,
      },
    });
    if (!user) throw new NotFoundException('User not found');

    const documents = await (this.prisma as any).verificationDocument.findMany({
      where: { userId },
      orderBy: [{ type: 'asc' }, { uploadedAt: 'desc' }],
    });

    return {
      user: {
        id: user.id,
        email: user.email,
        emailVerifiedAt: (user as any).emailVerifiedAt ?? null,
        createdAt: user.createdAt,
        profile: user.profile
          ? {
              displayName: user.profile.displayName,
              phone: user.profile.phone,
              phoneVerifiedAt: user.profile.phoneVerifiedAt,
              kycStatus: user.profile.kycStatus,
              kycNote: user.profile.kycNote,
              location: user.profile.location,
              countryCode: user.profile.countryCode,
            }
          : null,
      },
      documents,
      summary: {
        total: documents.length,
        pending: documents.filter((d: any) => d.status === 'PENDING').length,
        approved: documents.filter((d: any) => d.status === 'APPROVED').length,
        rejected: documents.filter((d: any) => d.status === 'REJECTED').length,
      },
    };
  }

  @Get('documents')
  async listDocuments(
    @Query('status') status?: string,
    @Query('userId') userId?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
    @Query('sort') sort?: string,
    @Query('dir') dir?: 'asc' | 'desc',
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const where: any = {};

    if (status) where.status = status;
    if (userId) where.userId = userId;

    const d: 'asc' | 'desc' = dir === 'asc' ? 'asc' : 'desc';
    let orderBy: any = { createdAt: d };
    if (sort === 'uploadedAt') orderBy = { uploadedAt: d };
    else if (sort === 'reviewedAt') orderBy = { reviewedAt: d };
    else if (sort === 'type') orderBy = { type: d };

    const [total, items] = await this.prisma.$transaction([
      (this.prisma as any).verificationDocument.count({ where }),
      (this.prisma as any).verificationDocument.findMany({
        where,
        include: {
          user: {
            include: {
              profile: true,
            },
          },
        },
        orderBy,
        skip: (page - 1) * size,
        take: size,
      }),
    ]);

    return { items, page, size, total };
  }

  @Get('documents/:id')
  async getDocument(@Param('id') id: string) {
    const document = await (this.prisma as any).verificationDocument.findUnique({
      where: { id },
      include: {
        user: {
          include: {
            profile: true,
          },
        },
      },
    });
    if (!document) throw new NotFoundException('Verification document not found');
    return document;
  }

  @Get('documents/:id/preview-url')
  async getDocumentPreviewUrl(@Param('id') id: string) {
    const document = await (this.prisma as any).verificationDocument.findUnique({
      where: { id },
      select: { documentKey: true },
    });
    if (!document?.documentKey) return { url: null };
    try {
      const { url } = await this.storage.createDownloadUrl(document.documentKey);
      return { url };
    } catch {
      return { url: null };
    }
  }

  @Put('documents/:id/approve')
  async approveDocument(
    @Param('id') id: string,
    @CurrentUser() admin: any,
    @Body() body: { note?: string },
  ) {
    const document = await (this.prisma as any).verificationDocument.update({
      where: { id },
      data: {
        status: 'APPROVED',
        reviewedAt: new Date(),
        reviewedBy: admin.sub,
        rejectionReason: null,
      },
    });

    await this.maybeMarkUserVerified(document.userId);
    await this.invalidateUserCaches(document.userId);
    await this.prisma.adminActionAudit.create({
      data: {
        adminId: admin.sub,
        action: 'VERIFICATION_DOCUMENT_APPROVED',
        targetUserId: document.userId,
        details: {
          documentId: id,
          note: body.note,
        },
      },
    });

    return document;
  }

  /** Approve every pending document for a user and mark KYC verified. */
  @Put('users/:userId/approve')
  async approveUserSubmission(
    @Param('userId') userId: string,
    @CurrentUser() admin: any,
    @Body() body: { note?: string },
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    await (this.prisma as any).verificationDocument.updateMany({
      where: { userId, status: 'PENDING' },
      data: {
        status: 'APPROVED',
        reviewedAt: new Date(),
        reviewedBy: admin.sub,
        rejectionReason: null,
      },
    });

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        profile: {
          update: {
            kycStatus: 'VERIFIED',
            kycNote: body.note ?? null,
          },
        },
      },
    });

    await this.prisma.adminActionAudit.create({
      data: {
        adminId: admin.sub,
        action: 'VERIFICATION_USER_APPROVED',
        targetUserId: userId,
        details: { note: body.note },
      },
    });

    await this.sendApprovedEmail(userId);
    await this.invalidateUserCaches(userId);
    return this.getUserSubmission(userId);
  }

  @Put('documents/:id/reject')
  async rejectDocument(
    @Param('id') id: string,
    @CurrentUser() admin: any,
    @Body() body: { reason: string },
  ) {
    if (!body.reason?.trim()) {
      throw new BadRequestException('Rejection reason is required');
    }

    const document = await (this.prisma as any).verificationDocument.update({
      where: { id },
      data: {
        status: 'REJECTED',
        reviewedAt: new Date(),
        reviewedBy: admin.sub,
        rejectionReason: body.reason.trim(),
      },
    });

    await this.prisma.user.update({
      where: { id: document.userId },
      data: {
        profile: {
          update: {
            kycStatus: 'REJECTED',
            kycNote: body.reason.trim(),
          },
        },
      },
    });

    await this.prisma.adminActionAudit.create({
      data: {
        adminId: admin.sub,
        action: 'VERIFICATION_DOCUMENT_REJECTED',
        targetUserId: document.userId,
        details: {
          documentId: id,
          reason: body.reason,
        },
      },
    });

    await this.sendRejectedEmail(document.userId, body.reason.trim());
    await this.invalidateUserCaches(document.userId);
    return document;
  }

  /** Reject the user's verification (all pending docs + KYC). */
  @Put('users/:userId/reject')
  async rejectUserSubmission(
    @Param('userId') userId: string,
    @CurrentUser() admin: any,
    @Body() body: { reason: string },
  ) {
    if (!body.reason?.trim()) {
      throw new BadRequestException('Rejection reason is required');
    }
    const reason = body.reason.trim();
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    await (this.prisma as any).verificationDocument.updateMany({
      where: { userId, status: 'PENDING' },
      data: {
        status: 'REJECTED',
        reviewedAt: new Date(),
        reviewedBy: admin.sub,
        rejectionReason: reason,
      },
    });

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        profile: {
          update: {
            kycStatus: 'REJECTED',
            kycNote: reason,
          },
        },
      },
    });

    await this.prisma.adminActionAudit.create({
      data: {
        adminId: admin.sub,
        action: 'VERIFICATION_USER_REJECTED',
        targetUserId: userId,
        details: { reason },
      },
    });

    await this.sendRejectedEmail(userId, reason);
    await this.invalidateUserCaches(userId);
    return this.getUserSubmission(userId);
  }

  private async maybeMarkUserVerified(userId: string) {
    // Only the latest document per type counts — old rejected uploads must not block KYC.
    const userDocuments = await (this.prisma as any).verificationDocument.findMany({
      where: { userId },
      orderBy: { uploadedAt: 'desc' },
    });
    const latestByType = new Map<string, any>();
    for (const doc of userDocuments) {
      if (!latestByType.has(doc.type)) latestByType.set(doc.type, doc);
    }
    const latest = Array.from(latestByType.values());
    const hasIdentity = latest.some(
      (d) =>
        String(d.type).toLowerCase().includes('identity') ||
        String(d.type).toLowerCase() === 'government_id' ||
        String(d.type).toLowerCase() === 'id',
    );
    const relevant = hasIdentity
      ? latest.filter((d) => {
          const t = String(d.type).toLowerCase();
          return t.includes('identity') || t === 'government_id' || t === 'id';
        })
      : latest;
    const allApproved =
      relevant.length > 0 &&
      relevant.every((doc: any) => doc.status === 'APPROVED');
    if (!allApproved) return;

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        profile: {
          update: {
            kycStatus: 'VERIFIED',
          },
        },
      },
    });
    await this.invalidateUserCaches(userId);
    await this.sendApprovedEmail(userId);
  }

  private async sendApprovedEmail(userId: string) {
    try {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { email: true, profile: { select: { displayName: true } } },
      });
      if (!user?.email) return;
      this.email.dispatchInBackground({
        eventName: EmailEventName.VerificationApproved,
        recipient: { email: user.email, userId },
        vars: {
          actorName: user.profile?.displayName || user.email,
          approvedAt: new Date().toISOString(),
          trustLevel: 'VERIFIED',
        },
      });
    } catch {
      // Non-blocking
    }
  }

  private async sendRejectedEmail(userId: string, reason: string) {
    try {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { email: true, profile: { select: { displayName: true } } },
      });
      if (!user?.email) return;
      this.email.dispatchInBackground({
        eventName: EmailEventName.VerificationRejected,
        recipient: { email: user.email, userId },
        vars: {
          actorName: user.profile?.displayName || user.email,
          reason,
          supportEmail: process.env.SUPPORT_EMAIL || 'support@bybata.com',
        },
      });
    } catch {
      // Non-blocking
    }
  }
}
