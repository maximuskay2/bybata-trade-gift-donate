import { Controller, Get, Patch, Param, Query, Body, UseGuards, Delete, Post } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import {
  countryCodeToDisplayName,
  sanitizeProfileLocation,
} from '../common/profile-location.util';
import { normalizeCountryCode } from '../common/currency.util';
import { ScaleCacheService } from '../common/scale/scale-cache.service';
import { ScaleCacheKeys } from '../common/scale/scale.constants';

@Controller('v1/admin/users')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminUsersController {
  constructor(
    private prisma: PrismaService,
    private scaleCache: ScaleCacheService,
  ) {}

  private async invalidateUserCaches(userId: string) {
    await this.scaleCache.delMany([
      ScaleCacheKeys.me(userId),
      ScaleCacheKeys.meLight(userId),
    ]);
  }

  @Get('location-stats')
  async locationStats(@Query('limit') limitStr?: string) {
    const limit = Math.min(Math.max(parseInt(limitStr ?? '10', 10) || 10, 1), 25);

    const profiles = await this.prisma.profile.findMany({
      where: {
        OR: [
          { countryCode: { not: null } },
          { location: { not: null } },
        ],
      },
      select: { countryCode: true, location: true },
    });

    const buckets = new Map<
      string,
      { label: string; count: number; countryCode?: string }
    >();
    const countryBuckets = new Map<
      string,
      { countryCode: string; label: string; count: number }
    >();
    let totalWithLocation = 0;

    for (const profile of profiles) {
      const resolved = resolveProfileLocation(
        profile.countryCode,
        profile.location,
      );
      if (!resolved) continue;

      totalWithLocation++;
      const key = resolved.label.toLowerCase();
      const existing = buckets.get(key);
      if (existing) {
        existing.count += 1;
        if (!existing.countryCode && resolved.countryCode) {
          existing.countryCode = resolved.countryCode;
        }
      } else {
        buckets.set(key, {
          label: resolved.label,
          count: 1,
          countryCode: resolved.countryCode,
        });
      }

      if (resolved.countryCode) {
        const countryKey = resolved.countryCode;
        const countryExisting = countryBuckets.get(countryKey);
        if (countryExisting) {
          countryExisting.count += 1;
        } else {
          countryBuckets.set(countryKey, {
            countryCode: countryKey,
            label: resolved.label,
            count: 1,
          });
        }
      }
    }

    const locations = [...buckets.values()]
      .sort((a, b) => b.count - a.count)
      .slice(0, limit);

    const byCountry = [...countryBuckets.values()].sort(
      (a, b) => b.count - a.count,
    );

    return {
      totalWithLocation,
      totalProfiles: profiles.length,
      locations,
      byCountry,
    };
  }

  @Get()
  async list(
    @Query('query') query?: string,
    @Query('role') role?: string,
    @Query('kyc') kyc?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
    @Query('sort') sort?: string,
    @Query('dir') dir?: 'asc' | 'desc',
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    const where: any = {};
    if (query) {
      where.OR = [
        { email: { contains: query, mode: 'insensitive' } },
        { profile: { displayName: { contains: query, mode: 'insensitive' } } },
      ];
    }
    if (role) where.role = role;
    if (kyc) where.profile = { ...(where.profile || {}), kycStatus: kyc };

    const d: 'asc' | 'desc' = dir === 'asc' ? 'asc' : 'desc';
    let orderBy: any = { createdAt: d };
    if (sort === 'email') orderBy = { email: d };
    else if (sort === 'role') orderBy = { role: d };
    else if (sort === 'displayName') orderBy = { profile: { displayName: d } };
    else if (sort === 'createdAt') orderBy = { createdAt: d };

    const [total, items] = await this.prisma.$transaction([
      this.prisma.user.count({ where }),
      this.prisma.user.findMany({
        where,
        include: {
          profile: true,
          _count: {
            select: {
              trades: true,
              giftsGiven: true,
              campaignsFounded: true,
              donations: true,
              communityMemberships: true,
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

  @Get(':id')
  async detail(@Param('id') id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: {
        profile: true,
        _count: {
          select: {
            trades: true,
            giftsGiven: true,
            campaignsFounded: true,
            donations: true,
            communityMemberships: true,
          },
        },
        communityMemberships: {
          where: { status: 'ACTIVE' },
          include: {
            community: { select: { id: true, name: true } },
          },
        },
      },
    });
    return user;
  }

  @Patch(':id')
  async patch(
    @Param('id') id: string,
    @Body()
    body: {
      role?: string;
      kycStatus?: string;
      kycNote?: string;
      avatarKey?: string | null;
      ban?: boolean;
      note?: string;
      verifyEmail?: boolean;
      durationMinutes?: number;
    },
  ) {
    const data: any = {};
    if (body.role) data.role = body.role;
    const durationMinutes = Number(body.durationMinutes ?? 0);
    if (Number.isFinite(durationMinutes) && durationMinutes > 0) {
      data.banned = true;
      data.bannedUntil = new Date(Date.now() + durationMinutes * 60 * 1000);
      data.banNote = body?.note ? `Suspended: ${body.note}` : 'Suspended by admin';
    } else if (typeof body.ban === 'boolean') {
      data.banned = body.ban;
      if (body.ban) {
        if (body.note !== undefined) data.banNote = body.note;
        data.bannedUntil = null;
      } else {
        data.banNote = null;
        data.bannedUntil = null;
      }
    }
    if (typeof body.verifyEmail === 'boolean') {
      data.emailVerifiedAt = body.verifyEmail ? new Date() : null;
    }
    if (body.kycStatus || body.kycNote !== undefined || body.avatarKey !== undefined) {
      data.profile = {
        update: {
          ...(body.kycStatus ? { kycStatus: body.kycStatus } : {}),
          ...(body.kycNote !== undefined ? { kycNote: body.kycNote } : {}),
          ...(body.avatarKey !== undefined ? { avatarKey: body.avatarKey } : {}),
        },
      };
    }
    const user = await this.prisma.user.update({ where: { id }, data, include: { profile: true } });
    await this.invalidateUserCaches(id);
    return user;
  }

  @Patch(':id/ban')
  async banUser(
    @Param('id') id: string,
    @Body() body: { note?: string },
  ) {
    const user = await this.prisma.user.update({
      where: { id },
      data: { banned: true, banNote: body?.note ?? 'Banned by admin', bannedUntil: null },
      include: { profile: true },
    });
    return user;
  }

  @Patch(':id/suspend')
  async suspendUser(
    @Param('id') id: string,
    @Body() body: { note?: string; durationMinutes?: number },
  ) {
    const note = body?.note ? `Suspended: ${body.note}` : 'Suspended by admin';
    const minutes = Number(body?.durationMinutes ?? 0);
    if (!Number.isFinite(minutes) || minutes <= 0) {
      throw new Error('durationMinutes is required and must be > 0');
    }
    const bannedUntil = new Date(Date.now() + minutes * 60 * 1000);
    const user = await this.prisma.user.update({
      where: { id },
      data: { banned: true, banNote: note, bannedUntil },
      include: { profile: true },
    });
    return user;
  }

  @Patch(':id/unban')
  async unbanUser(@Param('id') id: string) {
    const user = await this.prisma.user.update({
      where: { id },
      data: { banned: false, banNote: null, bannedUntil: null },
      include: { profile: true },
    });
    return user;
  }

  @Delete(':id')
  async deleteUser(@Param('id') id: string) {
    try {
      const [giftIds, tradeIds, campaignIds, communityIds] = await Promise.all([
        this.prisma.gift.findMany({
          where: { OR: [{ giverId: id }, { targetUserId: id }] },
          select: { id: true },
        }),
        this.prisma.trade.findMany({ where: { ownerId: id }, select: { id: true } }),
        this.prisma.campaign.findMany({ where: { founderId: id }, select: { id: true } }),
        this.prisma.community.findMany({ where: { createdById: id }, select: { id: true } }),
      ]);
      const giftIdList = giftIds.map((g) => g.id);
      const tradeIdList = tradeIds.map((t) => t.id);
      const campaignIdList = campaignIds.map((c) => c.id);
      const communityIdList = communityIds.map((c) => c.id);

      const postIds = await this.prisma.communityPost.findMany({
        where: {
          OR: [
            { authorId: id },
            { linkedTradeId: { in: tradeIdList } },
            { linkedGiftId: { in: giftIdList } },
            { linkedCampaignId: { in: campaignIdList } },
            { communityId: { in: communityIdList } },
          ],
        },
        select: { id: true },
      });
      const postIdList = postIds.map((p) => p.id);

      const commentIds = await this.prisma.communityPostComment.findMany({
        where: { OR: [{ authorId: id }, { postId: { in: postIdList } }] },
        select: { id: true },
      });
      const commentIdList = commentIds.map((c) => c.id);

      const messageIds = await this.prisma.message.findMany({
        where: { senderId: id },
        select: { id: true },
      });
      const messageIdList = messageIds.map((m) => m.id);

      await this.prisma.$transaction([
        // Chat
        this.prisma.messageReaction.deleteMany({ where: { OR: [{ userId: id }, { messageId: { in: messageIdList } }] } }),
        this.prisma.messageReport.deleteMany({ where: { OR: [{ reporterId: id }, { messageId: { in: messageIdList } }] } }),
        this.prisma.message.deleteMany({ where: { senderId: id } }),
        this.prisma.conversationParticipant.deleteMany({ where: { userId: id } }),

        // Community posts and related
        this.prisma.communityPostCommentLike.deleteMany({ where: { OR: [{ userId: id }, { commentId: { in: commentIdList } }] } }),
        this.prisma.communityPostReport.deleteMany({ where: { OR: [{ reporterId: id }, { postId: { in: postIdList } }] } }),
        this.prisma.communityPostComment.deleteMany({ where: { OR: [{ authorId: id }, { postId: { in: postIdList } }] } }),
        this.prisma.communityPostLike.deleteMany({ where: { OR: [{ userId: id }, { postId: { in: postIdList } }] } }),
        this.prisma.communityPollVote.deleteMany({ where: { userId: id } }),
        this.prisma.communityPoll.deleteMany({ where: { postId: { in: postIdList } } }),
        this.prisma.communityPost.deleteMany({ where: { OR: [{ authorId: id }, { id: { in: postIdList } }] } }),

        // Community entities
        this.prisma.communityEventAttendee.deleteMany({ where: { userId: id } }),
        this.prisma.communityEvent.deleteMany({ where: { organizerId: id } }),
        this.prisma.communityMember.deleteMany({ where: { OR: [{ userId: id }, { invitedBy: id }, { communityId: { in: communityIdList } }] } }),
        this.prisma.communityInvite.deleteMany({ where: { OR: [{ inviterId: id }, { inviteeUserId: id }, { communityId: { in: communityIdList } }] } }),
        this.prisma.communityGoal.deleteMany({ where: { communityId: { in: communityIdList } } }),
        this.prisma.community.deleteMany({ where: { createdById: id } }),

        // Gifts
        this.prisma.giftLike.deleteMany({ where: { OR: [{ userId: id }, { giftId: { in: giftIdList } }] } }),
        this.prisma.giftComment.deleteMany({ where: { OR: [{ authorId: id }, { giftId: { in: giftIdList } }] } }),
        this.prisma.giftClaimBlock.deleteMany({ where: { userId: id } }),
        this.prisma.giftRequest.deleteMany({ where: { OR: [{ requesterId: id }, { giftId: { in: giftIdList } }] } }),
        this.prisma.giftClaim.deleteMany({ where: { OR: [{ claimerId: id }, { giftId: { in: giftIdList } }] } }),
        this.prisma.gift.deleteMany({ where: { OR: [{ giverId: id }, { targetUserId: id }] } }),

        // Trades & negotiations
        this.prisma.negotiationMessage.deleteMany({ where: { senderId: id } }),
        this.prisma.negotiation.deleteMany({ where: { OR: [{ ownerId: id }, { bidderId: id }] } }),
        this.prisma.tradeOffer.deleteMany({ where: { bidderId: id } }),
        this.prisma.trade.deleteMany({ where: { ownerId: id } }),

        // Campaigns & donations
        this.prisma.donationReward.deleteMany({ where: { donation: { donorId: id } } }),
        this.prisma.donation.deleteMany({ where: { donorId: id } }),
        this.prisma.campaignUpdate.deleteMany({ where: { authorId: id } }),
        this.prisma.campaign.deleteMany({ where: { founderId: id } }),

        // Wallet & payments
        this.prisma.walletTransaction.deleteMany({ where: { userId: id } }),
        this.prisma.withdrawal.deleteMany({ where: { userId: id } }),
        this.prisma.fundingIntent.deleteMany({ where: { userId: id } }),
        this.prisma.transfer.deleteMany({ where: { OR: [{ senderId: id }, { recipientId: id }] } }),
        this.prisma.account.deleteMany({ where: { userId: id } }),
        this.prisma.walletSecurity.deleteMany({ where: { userId: id } }),
        this.prisma.adSchedule.deleteMany({ where: { userId: id } }),
        this.prisma.boostPurchase.deleteMany({ where: { userId: id } }),
        this.prisma.suspiciousActivity.deleteMany({ where: { userId: id } }),

        // Identity, notifications, logs
        this.prisma.emailLog.deleteMany({ where: { recipientUserId: id } }),
        this.prisma.emailPreference.deleteMany({ where: { userId: id } }),
        this.prisma.notificationSettings.deleteMany({ where: { userId: id } }),
        this.prisma.notification.deleteMany({ where: { userId: id } }),
        this.prisma.userDeviceToken.deleteMany({ where: { userId: id } }),
        this.prisma.emailVerificationToken.deleteMany({ where: { userId: id } }),
        this.prisma.passwordResetToken.deleteMany({ where: { userId: id } }),
        this.prisma.session.deleteMany({ where: { userId: id } }),
        this.prisma.verificationDocument.deleteMany({ where: { userId: id } }),

        // Social / misc
        this.prisma.userBlock.deleteMany({ where: { OR: [{ blockerId: id }, { blockedId: id }] } }),
        this.prisma.karmaEvent.deleteMany({ where: { userId: id } }),
        this.prisma.userAchievement.deleteMany({ where: { userId: id } }),
        this.prisma.karmaAccount.deleteMany({ where: { userId: id } }),
        this.prisma.auditLog.deleteMany({ where: { userId: id } }),
        this.prisma.adminActionAudit.deleteMany({ where: { OR: [{ adminId: id }, { targetUserId: id }] } }),

        // Profile & user
        this.prisma.profile.deleteMany({ where: { userId: id } }),
        this.prisma.user.deleteMany({ where: { id } }),
      ]);
      return { ok: true, deleted: true };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2025') {
        return { ok: true, deleted: false, missing: true };
      }
      throw error;
    }
  }

  @Post(':id/delete')
  async deleteUserFallback(@Param('id') id: string) {
    return this.deleteUser(id);
  }
}

function resolveProfileLocation(
  countryCode?: string | null,
  location?: string | null,
): { label: string; countryCode?: string } | null {
  const normalizedCode = normalizeCountryCode(countryCode);
  const fromCountry = countryCodeToDisplayName(normalizedCode);
  if (fromCountry && normalizedCode) {
    return { label: fromCountry, countryCode: normalizedCode };
  }

  const sanitized = sanitizeProfileLocation(location);
  if (!sanitized) return null;

  const parts = sanitized
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean);

  const label =
    parts.length > 1 ? parts[parts.length - 1] : parts[0] ?? sanitized;

  const inferredCode = inferCountryCodeFromLabel(label);
  return {
    label,
    countryCode: inferredCode,
  };
}

function inferCountryCodeFromLabel(label: string): string | undefined {
  const trimmed = label.trim();
  if (!trimmed) return undefined;

  const upper = trimmed.toUpperCase();
  if (upper.length === 2) {
    return normalizeCountryCode(upper);
  }

  const reverse = Object.entries(COUNTRY_NAME_TO_CODE).find(
    ([name]) => name.toLowerCase() === trimmed.toLowerCase(),
  );
  return reverse?.[1];
}

const COUNTRY_NAME_TO_CODE: Record<string, string> = {
  Nigeria: 'NG',
  Ghana: 'GH',
  Kenya: 'KE',
  'South Africa': 'ZA',
  'United States': 'US',
  'United Kingdom': 'GB',
  Canada: 'CA',
  Japan: 'JP',
  Germany: 'DE',
  France: 'FR',
  Italy: 'IT',
  Spain: 'ES',
  Netherlands: 'NL',
  Belgium: 'BE',
  Austria: 'AT',
  Ireland: 'IE',
  Portugal: 'PT',
  'United Arab Emirates': 'AE',
  India: 'IN',
};