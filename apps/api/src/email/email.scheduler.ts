import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../common/prisma.service';
import { EmailService } from '../common/email.service';
import { EmailLinkRouterService } from '../shared/services/email-link-router.service';
import { EmailEventName } from './email-events';

@Injectable()
export class EmailSchedulerService {
  private readonly logger = new Logger(EmailSchedulerService.name);

  constructor(
    private prisma: PrismaService,
    private email: EmailService,
    private emailLinkRouter: EmailLinkRouterService,
  ) {}

  @Cron(process.env.EMAIL_CRON_DAILY ?? CronExpression.EVERY_DAY_AT_8AM)
  async runDaily() {
    await this.sendTradeReminders();
    await this.sendGiftExpiryAndThanks();
    await this.sendCampaignExpiring();
    await this.sendCommunityDigest();
    await this.sendAdBudgetLow();
    await this.sendMaintenanceIfPending();
    await this.sendPolicyUpdateIfPending();
  }

  @Cron(process.env.EMAIL_CRON_WEEKLY ?? CronExpression.EVERY_WEEK)
  async runWeeklySummary() {
    await this.sendWeeklySummary();
    await this.sendPromotionPerformanceSummary();
  }

  private async sendTradeReminders() {
    const days = Number(process.env.TRADE_REMINDER_DAYS ?? 7);
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const trades = await this.prisma.trade.findMany({
      where: {
        status: 'OPEN',
        offers: { some: { status: 'PENDING', createdAt: { lte: cutoff } } },
      },
      include: { owner: { select: { id: true, email: true, profile: { select: { displayName: true } } } } },
      take: 200,
    });
    for (const trade of trades) {
      if (!trade.owner?.email) continue;
      const shouldSkip = await this.hasRecentLog(EmailEventName.TradeReminderPending, trade.owner.id, trade.id);
      if (shouldSkip) continue;
      await this.email.dispatch({
        eventName: EmailEventName.TradeReminderPending,
        recipient: { email: trade.owner.email, userId: trade.owner.id },
        vars: {
          actorName: trade.owner.profile?.displayName || trade.owner.email,
          tradeTitle: trade.title,
          daysPending: days,
          tradeUrl: this.emailLinkRouter.getTradeLink(trade.id),
        },
        metadata: { ref: trade.id },
      });
    }
  }

  private async sendGiftExpiryAndThanks() {
    const now = new Date();
    const gifts = await this.prisma.gift.findMany({
      where: { status: 'ACTIVE', expiresAt: { lte: now } },
      include: { giver: { select: { id: true, email: true, profile: { select: { displayName: true } } } } },
      take: 200,
    });
    for (const gift of gifts) {
      await this.prisma.gift.update({
        where: { id: gift.id },
        data: { status: 'EXPIRED' },
      });
      if (gift.giver?.email) {
        await this.email.dispatch({
          eventName: EmailEventName.GiftExpired,
          recipient: { email: gift.giver.email, userId: gift.giver.id },
          vars: {
            actorName: gift.giver.profile?.displayName || gift.giver.email,
            giftTitle: gift.title,
            expiredAt: gift.expiresAt?.toISOString() || now.toISOString(),
          },
        metadata: { ref: gift.id },
        });
      }
    }

    const days = Number(process.env.GIFT_THANK_YOU_DAYS ?? 3);
    const thanksCutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const claims = await this.prisma.giftClaim.findMany({
      where: { claimedAt: { lte: thanksCutoff }, completedAt: null },
      include: {
        claimer: { select: { id: true, email: true, profile: { select: { displayName: true } } } },
        gift: { include: { giver: { select: { email: true, profile: { select: { displayName: true } } } } } },
      },
      take: 200,
    });
    for (const claim of claims) {
      if (!claim.claimer?.email) continue;
      const shouldSkip = await this.hasRecentLog(EmailEventName.GiftThankYouPrompt, claim.claimer.id, claim.id);
      if (shouldSkip) continue;
      await this.email.dispatch({
        eventName: EmailEventName.GiftThankYouPrompt,
        recipient: { email: claim.claimer.email, userId: claim.claimer.id },
        vars: {
          targetName: claim.claimer.profile?.displayName || claim.claimer.email,
          actorName: claim.gift.giver?.profile?.displayName || claim.gift.giver?.email || 'Someone',
          giftTitle: claim.gift.title,
          giftUrl: this.emailLinkRouter.getGiftLink(claim.giftId),
        },
        metadata: { ref: claim.id },
      });
    }
  }

  private async sendCampaignExpiring() {
    const days = Number(process.env.CAMPAIGN_EXPIRING_DAYS ?? 3);
    const now = new Date();
    const windowEnd = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
    const campaigns = await this.prisma.campaign.findMany({
      where: { status: 'ACTIVE', endsAt: { gte: now, lte: windowEnd } },
      include: { founder: { select: { id: true, email: true, profile: { select: { displayName: true } } } } },
      take: 200,
    });
    for (const campaign of campaigns) {
      if (!campaign.founder?.email) continue;
      const shouldSkip = await this.hasRecentLog(EmailEventName.CampaignExpiring, campaign.founder.id, campaign.id);
      if (shouldSkip) continue;
      await this.email.dispatch({
        eventName: EmailEventName.CampaignExpiring,
        recipient: { email: campaign.founder.email, userId: campaign.founder.id },
        vars: {
          targetName: campaign.founder.profile?.displayName || campaign.founder.email,
          campaignTitle: campaign.title,
          daysLeft: days,
          campaignUrl: this.emailLinkRouter.getCampaignLink(campaign.id),
        },
        metadata: { ref: campaign.id },
      });
    }
  }

  private async sendCommunityDigest() {
    const lookbackHours = Number(process.env.COMMUNITY_DIGEST_LOOKBACK_HOURS ?? 24);
    const since = new Date(Date.now() - lookbackHours * 60 * 60 * 1000);
    const posts = await this.prisma.communityPost.groupBy({
      by: ['communityId'],
      where: { createdAt: { gte: since } },
      _count: { _all: true },
    });
    for (const group of posts) {
      const community = await this.prisma.community.findUnique({
        where: { id: group.communityId },
        select: { id: true, name: true },
      });
      if (!community) continue;
      const members = await this.prisma.communityMember.findMany({
        where: { communityId: community.id, status: 'ACTIVE' },
        include: { user: { select: { id: true, email: true, profile: { select: { displayName: true } } } } },
        take: 500,
      });
      for (const member of members) {
        if (!member.user?.email) continue;
        const shouldSkip = await this.hasRecentLog(EmailEventName.CommunityNewPostDigest, member.user.id, community.id);
        if (shouldSkip) continue;
        await this.email.dispatch({
          eventName: EmailEventName.CommunityNewPostDigest,
          recipient: { email: member.user.email, userId: member.user.id },
          vars: {
            targetName: member.user.profile?.displayName || member.user.email,
            communityName: community.name,
            postCount: group._count._all,
            digestUrl: this.emailLinkRouter.getCommunityLink(community.id),
          },
          category: 'digest',
          metadata: { ref: community.id },
        });
      }
    }
  }

  private async sendAdBudgetLow() {
    const threshold = Number(process.env.AD_BUDGET_LOW_THRESHOLD ?? 0.2);
    const ads = await this.prisma.adSchedule.findMany({
      where: { status: 'ACTIVE', scheduledEnd: { not: null } },
      include: {
        user: { select: { id: true, email: true, profile: { select: { displayName: true } } } },
        transaction: true,
      },
      take: 200,
    });
    for (const ad of ads) {
      if (!ad.user?.email) continue;
      if (!ad.scheduledEnd || !ad.scheduledStart) continue;
      const totalMs = ad.scheduledEnd.getTime() - ad.scheduledStart.getTime();
      if (totalMs <= 0) continue;
      const remainingMs = ad.scheduledEnd.getTime() - Date.now();
      const remainingRatio = Math.max(0, remainingMs / totalMs);
      if (remainingRatio > threshold) continue;
      if (remainingRatio <= 0) {
        const shouldSkip = await this.hasRecentLog(EmailEventName.AdBudgetDepleted, ad.user.id, ad.id);
        if (shouldSkip) continue;
        await this.email.dispatch({
          eventName: EmailEventName.AdBudgetDepleted,
          recipient: { email: ad.user.email, userId: ad.user.id },
          vars: {
            actorName: ad.user.profile?.displayName || ad.user.email,
            adTitle: ad.title,
            adUrl: this.emailLinkRouter.getAppOpenLink(`/ads/${ad.id}`),
          },
          metadata: { ref: ad.id },
        });
        continue;
      }
      const shouldSkip = await this.hasRecentLog(EmailEventName.AdBudgetLow, ad.user.id, ad.id);
      if (shouldSkip) continue;
      const spent = Number((ad as any).transaction?.amount ?? 0);
      const remainingBudget = spent * remainingRatio;
      await this.email.dispatch({
        eventName: EmailEventName.AdBudgetLow,
        recipient: { email: ad.user.email, userId: ad.user.id },
        vars: {
          actorName: ad.user.profile?.displayName || ad.user.email,
          adTitle: ad.title,
          remainingBudget: Number.isFinite(remainingBudget) ? remainingBudget : 'Low',
          adUrl: `${process.env.APP_PUBLIC_URL || 'http://localhost:3001'}/ads/${ad.id}`,
        },
        metadata: { ref: ad.id },
      });
    }
  }

  private async sendMaintenanceIfPending() {
    const setting = await this.prisma.appSetting.findUnique({ where: { key: 'MAINTENANCE_WINDOW' } });
    if (!setting?.value) return;
    let payload: any = null;
    try {
      payload = JSON.parse(setting.value);
    } catch {
      return;
    }
    if (!payload?.windowStart || !payload?.windowEnd || payload?.notifiedAt) return;
    const users = await this.prisma.user.findMany({
      where: { email: { not: '' } },
      select: { id: true, email: true },
      take: 2000,
    });
    for (const user of users) {
      if (!user.email) continue;
      await this.email.dispatch({
        eventName: EmailEventName.SystemMaintenanceScheduled,
        recipient: { email: user.email, userId: user.id },
        vars: {
          windowStart: payload.windowStart,
          windowEnd: payload.windowEnd,
          statusUrl: payload.statusUrl || this.emailLinkRouter.getWebLink('/status'),
        },
        category: 'digest',
        metadata: { ref: payload.id || 'maintenance' },
      });
    }
    payload.notifiedAt = new Date().toISOString();
    await this.prisma.appSetting.update({ where: { key: 'MAINTENANCE_WINDOW' }, data: { value: JSON.stringify(payload) } });
  }

  private async sendPromotionPerformanceSummary() {
    const lookbackDays = Number(process.env.PROMO_SUMMARY_LOOKBACK_DAYS ?? 7);
    const since = new Date(Date.now() - lookbackDays * 24 * 60 * 60 * 1000);
    const [boosts, ads] = await Promise.all([
      this.prisma.boostPurchase.findMany({
        where: { createdAt: { gte: since } },
        select: { userId: true },
      }),
      this.prisma.adSchedule.findMany({
        where: { createdAt: { gte: since } },
        select: { userId: true, viewCount: true, clickCount: true },
      }),
    ]);

    const userStats = new Map<string, { boosts: number; ads: number; views: number; clicks: number }>();
    for (const b of boosts) {
      const stat = userStats.get(b.userId) ?? { boosts: 0, ads: 0, views: 0, clicks: 0 };
      stat.boosts += 1;
      userStats.set(b.userId, stat);
    }
    for (const ad of ads) {
      const stat = userStats.get(ad.userId) ?? { boosts: 0, ads: 0, views: 0, clicks: 0 };
      stat.ads += 1;
      stat.views += Number(ad.viewCount ?? 0);
      stat.clicks += Number(ad.clickCount ?? 0);
      userStats.set(ad.userId, stat);
    }

    for (const [userId, stat] of userStats.entries()) {
      if (stat.boosts === 0 && stat.ads === 0) continue;
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, email: true, profile: { select: { displayName: true } } },
      });
      if (!user?.email) continue;
      const shouldSkip = await this.hasRecentLog(EmailEventName.PromotionPerformanceSummary, user.id, 'promo-summary');
      if (shouldSkip) continue;
      const summaryItems = [
        `Boost purchases: ${stat.boosts}`,
        `Ads created: ${stat.ads}`,
        `Views: ${stat.views}`,
        `Clicks: ${stat.clicks}`,
      ].join('\n');
      await this.email.dispatch({
        eventName: EmailEventName.PromotionPerformanceSummary,
        recipient: { email: user.email, userId: user.id },
        vars: {
          actorName: user.profile?.displayName || user.email,
          summaryItems,
          summaryUrl: this.emailLinkRouter.getAppOpenLink('/wallet/promotions'),
        },
        metadata: { ref: 'promo-summary' },
      });
    }
  }

  private async sendPolicyUpdateIfPending() {
    const setting = await this.prisma.appSetting.findUnique({ where: { key: 'POLICY_UPDATE' } });
    if (!setting?.value) return;
    let payload: any = null;
    try {
      payload = JSON.parse(setting.value);
    } catch {
      return;
    }
    if (!payload?.policyUrl || payload?.notifiedAt) return;
    const users = await this.prisma.user.findMany({
      where: { email: { not: '' } },
      select: { id: true, email: true },
      take: 2000,
    });
    for (const user of users) {
      if (!user.email) continue;
      await this.email.dispatch({
        eventName: EmailEventName.SystemPolicyUpdated,
        recipient: { email: user.email, userId: user.id },
        vars: {
          effectiveAt: payload.effectiveAt || new Date().toISOString(),
          policyUrl: payload.policyUrl,
        },
        category: 'digest',
        metadata: { ref: payload.id || 'policy' },
      });
    }
    payload.notifiedAt = new Date().toISOString();
    await this.prisma.appSetting.update({ where: { key: 'POLICY_UPDATE' }, data: { value: JSON.stringify(payload) } });
  }

  private async sendWeeklySummary() {
    const summaryDays = Number(process.env.SYSTEM_WEEKLY_SUMMARY_LOOKBACK_DAYS ?? 7);
    const since = new Date(Date.now() - summaryDays * 24 * 60 * 60 * 1000);
    const [tradeCount, giftCount, donationCount] = await Promise.all([
      this.prisma.trade.count({ where: { createdAt: { gte: since } } }),
      this.prisma.gift.count({ where: { createdAt: { gte: since } } }),
      this.prisma.donation.count({ where: { createdAt: { gte: since } } }),
    ]);
    const summaryItems = `Trades: ${tradeCount}, Gifts: ${giftCount}, Donations: ${donationCount}`;
    // Only send to users who opted in (weeklyReport = true); default is off
    const users = await this.prisma.user.findMany({
      where: {
        email: { not: '' },
        emailPreferences: { weeklyReport: true },
      },
      select: { id: true, email: true, profile: { select: { displayName: true } } },
      take: 2000,
    });
    let sent = 0;
    for (const user of users) {
      if (!user.email) continue;
      const shouldSkip = await this.hasRecentLog(EmailEventName.SystemWeeklySummary, user.id, 'weekly');
      if (shouldSkip) continue;
      try {
        await this.email.dispatch({
          eventName: EmailEventName.SystemWeeklySummary,
          recipient: { email: user.email, userId: user.id },
          vars: {
            actorName: user.profile?.displayName || user.email,
            summaryItems,
            summaryUrl: this.emailLinkRouter.getAppOpenLink('/dashboard'),
          },
          category: 'digest',
          metadata: { ref: 'weekly' },
        });
        sent++;
        if (sent % 100 === 0) {
          this.logger.log(`Weekly summary: sent ${sent} emails`);
        }
      } catch (e) {
        this.logger.error(`Weekly summary failed for ${user.email}: ${e}`);
        // Continue with next user; retries are handled in EmailService
      }
    }
    if (sent > 0) {
      this.logger.log(`Weekly summary complete: ${sent} emails sent`);
    }
  }

  private async hasRecentLog(eventName: EmailEventName, userId: string, ref: string) {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const log = await (this.prisma as any).emailLog.findFirst({
      where: {
        eventName,
        recipientUserId: userId,
        createdAt: { gte: since },
        metadata: { path: ['ref'], equals: ref },
      },
    });
    return Boolean(log);
  }
}
