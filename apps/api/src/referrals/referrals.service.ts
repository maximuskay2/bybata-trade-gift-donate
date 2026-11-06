import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { ReferralStatus } from '@prisma/client';
import { WalletService } from '../wallet/wallet.service';
import { KarmaService } from '../karma/karma.service';
import { KarmaPointsConfigService } from '../karma/karma-points-config.service';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType, NotificationPriority } from '@prisma/client';
import { randomBytes } from 'crypto';

// BYC referral rewards remain env-configurable; karma uses admin settings.
const REFERRAL_SIGNUP_BYC = Number(process.env.REFERRAL_SIGNUP_BYC ?? 0.1);
const REFERRAL_FIRST_TRADE_BYC = Number(process.env.REFERRAL_FIRST_TRADE_BYC ?? 0.1);
const REFERRAL_FIRST_DONATION_BYC = Number(process.env.REFERRAL_FIRST_DONATION_BYC ?? 0.1);
const REFERRAL_FIRST_GIFT_BYC = Number(process.env.REFERRAL_FIRST_GIFT_BYC ?? 0.1);

@Injectable()
export class ReferralsService {
  constructor(
    private prisma: PrismaService,
    private wallet: WalletService,
    private karma: KarmaService,
    private karmaPointsConfig: KarmaPointsConfigService,
    private notifications: NotificationsService,
  ) {}

  private normalizeCode(code: string): string {
    return code.trim().toLowerCase().replace(/^@/, '');
  }

  private generateReferralCode(): string {
    return randomBytes(4).toString('hex');
  }

  async getOrCreateReferralCode(userId: string): Promise<string> {
    const profile = await this.prisma.profile.findUnique({
      where: { userId },
      select: { referralCode: true, username: true },
    });
    if (!profile) throw new NotFoundException('Profile not found');
    if (profile.referralCode) return profile.referralCode;
    const base = profile.username || userId.slice(-6);
    let code = this.normalizeCode(base).replace(/[^a-z0-9]/g, '') || 'user';
    code = code.slice(0, 12);
    let suffix = 0;
    while (true) {
      const candidate = suffix === 0 ? code : `${code}${suffix}`;
      const exists = await this.prisma.profile.findFirst({
        where: { referralCode: candidate },
        select: { id: true },
      });
      if (!exists) {
        await this.prisma.profile.update({
          where: { userId },
          data: { referralCode: candidate },
        });
        return candidate;
      }
      suffix += 1;
    }
  }

  async lookupReferrerByCode(code: string): Promise<{ referrerId: string; displayName: string } | null> {
    const normalized = this.normalizeCode(code);
    if (!normalized || normalized.length < 3) return null;
    const profile = await this.prisma.profile.findFirst({
      where: {
        OR: [
          { referralCode: { equals: normalized, mode: 'insensitive' } },
          { username: { equals: normalized, mode: 'insensitive' } },
        ],
      },
      include: { user: { select: { id: true } } },
    });
    if (!profile) return null;
    return {
      referrerId: profile.userId,
      displayName: profile.displayName || 'User',
    };
  }

  async createReferral(referrerId: string, referredUserId: string, referralCode: string): Promise<void> {
    if (referrerId === referredUserId) return;
    const existing = await this.prisma.userReferral.findUnique({
      where: {
        referrerId_referredUserId: { referrerId, referredUserId },
      },
    });
    if (existing) return;

    await this.prisma.userReferral.create({
      data: {
        referrerId,
        referredUserId,
        referralCode,
        status: ReferralStatus.SIGNED_UP,
      },
    });

    await this.awardReferralBonus(referrerId, referredUserId, 'SIGNED_UP');
    await this.notifications.createNotification({
      userId: referrerId,
      type: NotificationType.REFERRAL_SIGNUP,
      title: 'New Referral!',
      message: 'Someone just signed up using your referral link. You earned bonus KARMA and BYC!',
      priority: NotificationPriority.NORMAL,
      sourceId: referredUserId,
      sourceType: 'referral',
    });
  }

  private async awardReferralBonus(
    referrerId: string,
    referredUserId: string,
    milestone: 'SIGNED_UP' | 'FIRST_TRADE' | 'FIRST_DONATION' | 'FIRST_GIFT',
  ): Promise<void> {
    const ref = await this.prisma.userReferral.findUnique({
      where: { referrerId_referredUserId: { referrerId, referredUserId } },
    });
    if (!ref) return;

    const pointsConfig = await this.karmaPointsConfig.getConfig();
    let karma = 0;
    let byc = 0;
    if (milestone === 'SIGNED_UP') {
      karma = pointsConfig.referralSignup;
      byc = REFERRAL_SIGNUP_BYC;
    } else if (milestone === 'FIRST_TRADE') {
      karma = pointsConfig.referralFirstTrade;
      byc = REFERRAL_FIRST_TRADE_BYC;
    } else if (milestone === 'FIRST_DONATION') {
      karma = pointsConfig.referralFirstDonation;
      byc = REFERRAL_FIRST_DONATION_BYC;
    } else if (milestone === 'FIRST_GIFT') {
      karma = pointsConfig.referralFirstGift;
      byc = REFERRAL_FIRST_GIFT_BYC;
    }

    if (karma > 0) {
      await this.karma.awardKarma(
        referrerId,
        'REFERRAL_BONUS' as any,
        karma,
        `Referral bonus: ${milestone}`,
        { referredUserId, milestone },
        referredUserId,
        'referral',
      );
    }

    if (byc > 0) {
      await this.wallet.fund(
        referrerId,
        byc,
        `Referral bonus: ${milestone}`,
        `ref-${ref.id}-${milestone}`,
        'referral',
        ref.id,
        'REFERRAL_BONUS',
      );
    }

    const karmaAwarded = ref.karmaAwarded + karma;
    const bycAwarded = Number(ref.bycAwarded) + byc;
    const updateData: any = { karmaAwarded, bycAwarded: bycAwarded };
    if (milestone === 'FIRST_TRADE') updateData.firstTradeAt = new Date();
    if (milestone === 'FIRST_DONATION') updateData.firstDonationAt = new Date();
    if (milestone === 'FIRST_GIFT') updateData.firstGiftAt = new Date();
    updateData.status = milestone === 'SIGNED_UP' ? ReferralStatus.SIGNED_UP : (milestone as ReferralStatus);

    await this.prisma.userReferral.update({
      where: { id: ref.id },
      data: updateData,
    });

    await this.notifications.createNotification({
      userId: referrerId,
      type: NotificationType.REFERRAL_BONUS_EARNED,
      title: 'Referral Bonus Earned!',
      message: `+${karma} KARMA and +${byc} BYC for referral ${milestone.replace('_', ' ').toLowerCase()}`,
      priority: NotificationPriority.NORMAL,
      sourceId: referredUserId,
      sourceType: 'referral',
    });
  }

  async onReferredUserFirstTrade(referredUserId: string): Promise<void> {
    const ref = await this.prisma.userReferral.findFirst({
      where: { referredUserId },
    });
    if (!ref || ref.firstTradeAt) return;
    await this.awardReferralBonus(ref.referrerId, referredUserId, 'FIRST_TRADE');
  }

  async onReferredUserFirstDonation(referredUserId: string): Promise<void> {
    const ref = await this.prisma.userReferral.findFirst({
      where: { referredUserId },
    });
    if (!ref || ref.firstDonationAt) return;
    await this.awardReferralBonus(ref.referrerId, referredUserId, 'FIRST_DONATION');
  }

  async onReferredUserFirstGift(referredUserId: string): Promise<void> {
    const ref = await this.prisma.userReferral.findFirst({
      where: { referredUserId },
    });
    if (!ref || ref.firstGiftAt) return;
    await this.awardReferralBonus(ref.referrerId, referredUserId, 'FIRST_GIFT');
  }

  async getMyReferralStats(userId: string) {
    const [code, refs, totalKarma, totalByc] = await Promise.all([
      this.getOrCreateReferralCode(userId),
      this.prisma.userReferral.findMany({
        where: { referrerId: userId },
        include: {
          referredUser: {
            select: {
              id: true,
              email: true,
              createdAt: true,
              profile: { select: { displayName: true, avatarKey: true } },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.userReferral.aggregate({
        where: { referrerId: userId },
        _sum: { karmaAwarded: true },
      }),
      this.prisma.userReferral.aggregate({
        where: { referrerId: userId },
        _sum: { bycAwarded: true },
      }),
    ]);

    // Invite links in /v1/referrals/me: use REFERRAL_WEB_BASE_URL when set (e.g. https://bybata.com)
    // so mobile shares never embed localhost. APP_PUBLIC_URL often points at admin/dev web (localhost:3001).
    const baseUrl = (
      process.env.REFERRAL_WEB_BASE_URL ||
      process.env.APP_PUBLIC_URL ||
      'https://bybata.com'
    )
      .trim()
      .replace(/\/+$/, '');
    const link = `${baseUrl}/invite/${code}`;

    return {
      referralCode: code,
      referralLink: link,
      totalReferrals: refs.length,
      totalKarmaEarned: totalKarma._sum.karmaAwarded ?? 0,
      totalBycEarned: Number(totalByc._sum.bycAwarded ?? 0),
      referrals: refs.map((r) => ({
        id: r.id,
        referredUser: r.referredUser,
        status: r.status,
        karmaAwarded: r.karmaAwarded,
        bycAwarded: Number(r.bycAwarded),
        signedUpAt: r.signedUpAt,
        firstTradeAt: r.firstTradeAt,
        firstDonationAt: r.firstDonationAt,
        firstGiftAt: r.firstGiftAt,
      })),
    };
  }
}
