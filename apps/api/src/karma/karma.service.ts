import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { KarmaEventType, TrustLevel, AchievementCategory, NotificationType, NotificationPriority } from '@prisma/client';
import { EmailService } from '../common/email.service';
import { EmailEventName } from '../email/email-events';
import { NotificationsService } from '../notifications/notifications.service';
import { WalletService } from '../wallet/wallet.service';
import { enrichKarmaAccount } from './karma-membership.util';
import { EmailLinkRouterService } from '../shared/services/email-link-router.service';
import {
  EARN_GUIDE_METHODS,
} from './earn-karma-guide.util';
import { KarmaPointsConfigService } from './karma-points-config.service';
import { pointsForGuideKeyFromConfig } from './karma-points-config';
import type { KarmaPointsConfig } from './karma-points-config';

@Injectable()
export class KarmaService {
  private readonly logger = new Logger(KarmaService.name);

  constructor(
    private prisma: PrismaService,
    private email: EmailService,
    private notifications: NotificationsService,
    private wallet: WalletService,
    private emailLinkRouter: EmailLinkRouterService,
    private karmaPointsConfig: KarmaPointsConfigService,
  ) {}

  // Get user's karma account
  async getKarmaAccount(userId: string) {
    let karmaAccount = await this.prisma.karmaAccount.findUnique({
      where: { userId },
    });

    // Create karma account if it doesn't exist
    if (!karmaAccount) {
      karmaAccount = await this.prisma.karmaAccount.create({
        data: {
          userId,
          currentPoints: 0,
          totalPointsEarned: 0,
          level: 1,
          trustLevel: TrustLevel.NEWCOMER,
          streak: 0,
        },
      });
    }

    return enrichKarmaAccount(karmaAccount);
  }

  // Get karma history for a user
  async getKarmaHistory(userId: string, page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    
    const [events, total] = await Promise.all([
      this.prisma.karmaEvent.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.karmaEvent.count({
        where: { userId },
      }),
    ]);

    return {
      events,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    };
  }

  // Get karma leaderboard
  async getLeaderboard(page = 1, limit = 50) {
    const skip = (page - 1) * limit;

    const [accounts, total] = await Promise.all([
      this.prisma.karmaAccount.findMany({
        include: {
          user: {
            include: {
              profile: true,
            },
          },
        },
        orderBy: { currentPoints: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.karmaAccount.count(),
    ]);

    return {
      leaderboard: accounts.map((account, index) => ({
        rank: skip + index + 1,
        userId: account.userId,
        displayName: account.user.profile?.displayName || account.user.email,
        avatarKey: account.user.profile?.avatarKey,
        points: account.currentPoints,
        level: account.level,
        trustLevel: account.trustLevel,
      })),
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    };
  }

  // Get achievements for a user
  async getUserAchievements(userId: string) {
    const [userAchievements, allAchievements] = await Promise.all([
      this.prisma.userAchievement.findMany({
        where: { userId },
        include: { achievement: true },
        orderBy: { unlockedAt: 'desc' },
      }),
      this.prisma.achievement.findMany({
        where: { isActive: true },
        orderBy: [{ category: 'asc' }, { pointsRequired: 'asc' }],
      }),
    ]);

    const unlockedIds = new Set(userAchievements.map(ua => ua.achievementId));

    return {
      unlocked: userAchievements.map(ua => ({
        ...ua.achievement,
        unlockedAt: ua.unlockedAt,
        claimedAt: ua.claimedAt,
      })),
      locked: allAchievements.filter(a => !unlockedIds.has(a.id)),
      total: allAchievements.length,
      unlockedCount: userAchievements.length,
    };
  }

  // Award karma points to a user
  async awardKarma(
    userId: string,
    type: KarmaEventType,
    points: number,
    reason?: string,
    metadata?: any,
    sourceId?: string,
    sourceType?: string,
  ) {
    let levelUp = false;
    let nextLevel = 1;
    let totalPoints = points;
    try {
      await this.prisma.$transaction(async (tx) => {
        // Create karma event
        await tx.karmaEvent.create({
          data: {
            userId,
            type,
            points,
            reason,
            metadata,
            sourceId,
            sourceType,
          },
        });

        // Get or create karma account
        let karmaAccount = await tx.karmaAccount.findUnique({
          where: { userId },
        });

        if (!karmaAccount) {
          karmaAccount = await tx.karmaAccount.create({
            data: {
              userId,
              currentPoints: points,
              totalPointsEarned: points,
              level: 1,
              trustLevel: TrustLevel.NEWCOMER,
              streak: type === KarmaEventType.DAILY_LOGIN ? 1 : 0,
              lastActivityAt: new Date(),
            },
          });
          nextLevel = 1;
          totalPoints = points;
        } else {
          // Update karma account
          const newCurrentPoints = karmaAccount.currentPoints + points;
          const newTotalPoints = karmaAccount.totalPointsEarned + points;
          const newLevel = this.calculateLevel(newTotalPoints);
          const newTrustLevel = this.calculateTrustLevel(newTotalPoints);
          const newStreak = type === KarmaEventType.DAILY_LOGIN 
            ? this.calculateStreak(karmaAccount.lastActivityAt, karmaAccount.streak)
            : karmaAccount.streak;

          await tx.karmaAccount.update({
            where: { userId },
            data: {
              currentPoints: newCurrentPoints,
              totalPointsEarned: newTotalPoints,
              level: newLevel,
              trustLevel: newTrustLevel,
              streak: newStreak,
              lastActivityAt: new Date(),
            },
          });

          // Check for achievements
          await this.checkAndUnlockAchievements(tx, userId, newTotalPoints, type);
          levelUp = newLevel > karmaAccount.level;
          nextLevel = newLevel;
          totalPoints = newTotalPoints;
        }
      });

      if (levelUp) {
        try {
          const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: {
              email: true,
              profile: { select: { displayName: true, username: true } },
            },
          });
          if (user?.email) {
            const profileUrl = user.profile?.username
              ? this.emailLinkRouter.getProfileLink(user.profile.username)
              : this.emailLinkRouter.getAppOpenLink('/profile');
            await Promise.all([
              this.notifications.createNotification({
                userId,
                type: NotificationType.KARMA_LEVEL_UP,
                title: `Level Up!`,
                message: `Congratulations! You've reached Level ${nextLevel}`,
                priority: NotificationPriority.HIGH,
                sourceId: userId,
                sourceType: 'karma',
              }),
              this.email.dispatch({
                eventName: EmailEventName.KarmaLevelUp,
                recipient: { email: user.email, userId },
                vars: {
                  actorName: user.profile?.displayName || user.email,
                  newLevel: nextLevel,
                  points: totalPoints,
                  profileUrl,
                },
              }),
            ]);
          }
        } catch {
          // Non-blocking
        }
      }

      this.logger.log(`Awarded ${points} karma to user ${userId} for ${type}`);
      return true;
    } catch (error) {
      this.logger.error(`Failed to award karma to user ${userId}:`, error);
      return false;
    }
  }

  // Calculate level based on total points
  private calculateLevel(totalPoints: number): number {
    // Simple level calculation: every 1000 points = 1 level
    return Math.floor(totalPoints / 1000) + 1;
  }

  // Calculate trust level based on total points
  private calculateTrustLevel(totalPoints: number): TrustLevel {
    if (totalPoints >= 50000) return TrustLevel.LEGEND;
    if (totalPoints >= 25000) return TrustLevel.DIAMOND;
    if (totalPoints >= 10000) return TrustLevel.PLATINUM;
    if (totalPoints >= 5000) return TrustLevel.GOLD;
    if (totalPoints >= 2000) return TrustLevel.SILVER;
    if (totalPoints >= 500) return TrustLevel.BRONZE;
    return TrustLevel.NEWCOMER;
  }

  // Calculate streak for daily login
  private calculateStreak(lastActivity: Date | null, currentStreak: number): number {
    if (!lastActivity) return 1;
    
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(today.getDate() - 1);
    
    const lastActivityDate = new Date(lastActivity);
    lastActivityDate.setHours(0, 0, 0, 0);
    yesterday.setHours(0, 0, 0, 0);
    
    // If last activity was yesterday, increment streak
    if (lastActivityDate.getTime() === yesterday.getTime()) {
      return currentStreak + 1;
    }
    
    // Otherwise, reset streak
    return 1;
  }

  // Check and unlock achievements
  private async checkAndUnlockAchievements(
    tx: any,
    userId: string,
    totalPoints: number,
    eventType: KarmaEventType,
  ) {
    // Get point-based achievements that user might have unlocked
    const pointAchievements = await tx.achievement.findMany({
      where: {
        isActive: true,
        pointsRequired: { lte: totalPoints },
        NOT: {
          userAchievements: {
            some: { userId },
          },
        },
      },
    });

    // Unlock point-based achievements
    for (const achievement of pointAchievements) {
      await tx.userAchievement.create({
        data: {
          userId,
          achievementId: achievement.id,
        },
      });

      // Award achievement points
      if (achievement.pointsReward > 0) {
        await tx.karmaEvent.create({
          data: {
            userId,
            type: KarmaEventType.MANUAL_ADJUSTMENT,
            points: achievement.pointsReward,
            reason: `Achievement unlocked: ${achievement.name}`,
            sourceId: achievement.id,
            sourceType: 'achievement',
          },
        });
      }
    }

    // TODO: Add event-based achievement checking
    // This would check for specific conditions like "first trade", "10 donations", etc.
  }

  // Get all achievements (for admin/display purposes)
  async getAllAchievements() {
    return this.prisma.achievement.findMany({
      where: { isActive: true },
      orderBy: [{ category: 'asc' }, { pointsRequired: 'asc' }],
    });
  }

  // Claim achievement (if applicable)
  async claimAchievement(userId: string, achievementId: string) {
    const userAchievement = await this.prisma.userAchievement.findUnique({
      where: {
        userId_achievementId: { userId, achievementId },
      },
      include: { achievement: true },
    });

    if (!userAchievement) {
      throw new Error('Achievement not unlocked');
    }

    if (userAchievement.claimedAt) {
      throw new Error('Achievement already claimed');
    }

    await this.prisma.userAchievement.update({
      where: { id: userAchievement.id },
      data: { claimedAt: new Date() },
    });

    return { success: true };
  }

  private startOfTodayUtc(): Date {
    const d = new Date();
    d.setUTCHours(0, 0, 0, 0);
    return d;
  }

  private async hasClaimedDailyLoginToday(userId: string): Promise<boolean> {
    const todayStart = this.startOfTodayUtc();
    const events = await this.prisma.karmaEvent.findMany({
      where: {
        userId,
        createdAt: { gte: todayStart },
        OR: [
          { type: KarmaEventType.DAILY_LOGIN },
          { type: KarmaEventType.MANUAL_ADJUSTMENT },
        ],
      },
      select: { type: true, metadata: true },
    });
    return events.some(
      (e) =>
        e.type === KarmaEventType.DAILY_LOGIN ||
        (e.metadata as { actionType?: string } | null)?.actionType ===
          'DAILY_LOGIN',
    );
  }

  /** Earn opportunities with live completion state for the earn guide screen. */
  async getEarnGuide(userId: string) {
    const [
      user,
      eventCounts,
      referralCount,
      communityMembershipCount,
      dailyClaimedToday,
    ] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: userId },
        include: { profile: true },
      }),
      this.prisma.karmaEvent.groupBy({
        by: ['type'],
        where: { userId },
        _count: { type: true },
      }),
      this.prisma.userReferral.count({ where: { referrerId: userId } }),
      this.prisma.communityMember.count({ where: { userId } }),
      this.hasClaimedDailyLoginToday(userId),
    ]);

    const countByType = new Map(
      eventCounts.map((row) => [row.type, row._count.type]),
    );
    const hasEvent = (...types: KarmaEventType[]) =>
      types.some((t) => (countByType.get(t) ?? 0) > 0);

    const isVerified =
      user?.profile?.kycStatus === 'VERIFIED' ||
      hasEvent(KarmaEventType.PROFILE_VERIFIED);
    const hasCompletedTrade = hasEvent(
      KarmaEventType.TRADE_COMPLETED,
      KarmaEventType.FIRST_TRADE_COMPLETED,
    );
    const hasGift = hasEvent(
      KarmaEventType.GIFT_GIVEN,
      KarmaEventType.FIRST_GIFT_GIVEN,
    );
    const hasDonation = hasEvent(
      KarmaEventType.DONATION_MADE,
      KarmaEventType.FIRST_DONATION,
    );
    const hasCommunityPost = hasEvent(KarmaEventType.COMMUNITY_POST);
    const hasJoinedCommunity =
      communityMembershipCount > 0 ||
      hasEvent(KarmaEventType.COMMUNITY_JOINED);
    const hasWalletPin = !!user?.profile?.walletPinHash;

    const completionById: Record<string, boolean> = {
      first_trade: hasCompletedTrade,
      trade_regular: false,
      give_gift: hasGift,
      make_donation: hasDonation,
      refer_friend: referralCount > 0,
      get_verified: isVerified,
      secure_account: hasWalletPin,
      community_join: hasJoinedCommunity,
      create_post: hasCommunityPost,
      daily_login: dailyClaimedToday,
      leaderboard: false,
      achievements: false,
    };

    const pointsConfig = await this.karmaPointsConfig.getConfig();

    const methods = EARN_GUIDE_METHODS.map((def) => ({
      id: def.id,
      category: def.category,
      title: def.title,
      description: def.description,
      points: pointsForGuideKeyFromConfig(def.pointsKey, pointsConfig),
      iconKey: def.iconKey,
      route: def.route,
      actionLabel: def.actionLabel,
      isRecurring: def.isRecurring,
      claimActionType: def.claimActionType ?? null,
      isCompleted: def.isRecurring
        ? def.id === 'daily_login'
          ? dailyClaimedToday
          : false
        : (completionById[def.id] ?? false),
      canClaim:
        def.claimActionType === 'DAILY_LOGIN' && !dailyClaimedToday,
    }));

    const categories = [
      'All',
      ...Array.from(new Set(EARN_GUIDE_METHODS.map((m) => m.category))),
    ];

    const streak = await this.prisma.karmaAccount.findUnique({
      where: { userId },
      select: { streak: true },
    });

    return {
      categories,
      methods,
      stats: {
        streak: streak?.streak ?? 0,
        dailyClaimedToday,
        referralCount,
        completedOneTime: methods.filter((m) => !m.isRecurring && m.isCompleted)
          .length,
        totalOneTime: methods.filter((m) => !m.isRecurring).length,
      },
      tips: [
        'Verify your account first — it unlocks the most rewards.',
        'Daily login and streaks add up quickly.',
        'Referrals give some of the biggest single boosts.',
      ],
      generatedAt: new Date(),
    };
  }

  // Earn karma from a suggested action
  async earnFromAction(userId: string, actionType: string) {
    const config = await this.karmaPointsConfig.getConfig();
    const actionPoints: Record<string, number> = {
      ACTION_COMPLETED: config.actionCompleted,
      SHARE_CONTENT: config.shareContent,
      CREATE_POST: config.createPost,
      JOIN_EVENT: config.joinEvent,
      REPORT_ISSUE: config.reportIssue,
      COMPLETE_TRADE: config.tradeComplete,
      GIVE_GIFT: config.giftGiven,
      MAKE_DONATION: config.makeDonation,
      HELP_COMMUNITY: config.helpCommunity,
      GET_VERIFIED: config.getVerified,
      RECEIVE_REVIEW: config.receiveReview,
      MENTOR_USER: config.mentorUser,
      REFER_FRIEND: config.referFriend,
      DAILY_LOGIN: config.dailyLogin,
    };

    const points = actionPoints[actionType] ?? config.actionCompleted;

    if (actionType === 'DAILY_LOGIN') {
      const alreadyClaimed = await this.hasClaimedDailyLoginToday(userId);
      if (alreadyClaimed) {
        throw new BadRequestException('Daily login reward already claimed today');
      }
    }
    
    try {
      // Map action type to KarmaEventType
      let karmaEventType: KarmaEventType = KarmaEventType.MANUAL_ADJUSTMENT;
      
      switch (actionType) {
        case 'COMPLETE_TRADE':
          karmaEventType = KarmaEventType.TRADE_COMPLETED;
          break;
        case 'GIVE_GIFT':
          karmaEventType = KarmaEventType.GIFT_GIVEN;
          break;
        case 'MAKE_DONATION':
          karmaEventType = KarmaEventType.DONATION_MADE;
          break;
        case 'COMMUNITY_POST':
        case 'CREATE_POST':
          karmaEventType = KarmaEventType.COMMUNITY_POST;
          break;
        case 'GET_VERIFIED':
          karmaEventType = KarmaEventType.PROFILE_VERIFIED;
          break;
        case 'REFER_FRIEND':
          karmaEventType = KarmaEventType.REFERRAL_BONUS;
          break;
        case 'JOIN_EVENT':
          karmaEventType = KarmaEventType.COMMUNITY_EVENT_ATTENDED;
          break;
        case 'DAILY_LOGIN':
          karmaEventType = KarmaEventType.DAILY_LOGIN;
          break;
        default:
          karmaEventType = KarmaEventType.MANUAL_ADJUSTMENT;
      }

      // Award karma for the action
      await this.awardKarma(
        userId,
        karmaEventType,
        points,
        `Earned ${points} KARMA for ${actionType}`,
        { actionType },
      );

      // Get updated karma account
      const karmaAccount = await this.prisma.karmaAccount.findUnique({
        where: { userId },
      });

      return {
        actionType,
        pointsEarned: points,
        totalPoints: karmaAccount?.currentPoints || 0,
        newLevel: karmaAccount?.level || 1,
        message: `You earned +${points} KARMA for ${actionType}!`,
        leveledUp: false, // Can be enhanced to check for level ups
        timestamp: new Date(),
      };
    } catch (error) {
      this.logger.error(`Failed to earn karma from action: ${error}`);
      throw error;
    }
  }

  // Manual karma adjustment (admin only)
  async adjustKarma(
    userId: string,
    points: number,
    reason: string,
    adminId: string,
  ) {
    return this.awardKarma(
      userId,
      KarmaEventType.MANUAL_ADJUSTMENT,
      points,
      `Manual adjustment by admin: ${reason}`,
      { adminId },
    );
  }

  /** Get karma withdrawal settings (min threshold, conversion rate) from AppSetting */
  async getWithdrawSettings(): Promise<{ minThreshold: number; karmaToBycRate: number }> {
    const [minSetting, rateSetting] = await Promise.all([
      this.prisma.appSetting.findUnique({ where: { key: 'KARMA_MIN_WITHDRAWAL_THRESHOLD' } }),
      this.prisma.appSetting.findUnique({ where: { key: 'KARMA_TO_BYC_RATE' } }),
    ]);
    const minThreshold = minSetting ? parseInt(minSetting.value, 10) : 500;
    const karmaToBycRate = rateSetting ? parseFloat(rateSetting.value) : 100; // 100 karma = 1 BYC
    return { minThreshold, karmaToBycRate };
  }

  /** Withdraw karma points to main wallet (converts to BYC) */
  async withdrawToWallet(userId: string, karmaPoints: number): Promise<{ ok: boolean; bycAmount: number; message?: string }> {
    if (karmaPoints <= 0) throw new BadRequestException('Amount must be positive');
    const { minThreshold, karmaToBycRate } = await this.getWithdrawSettings();
    if (karmaPoints < minThreshold) {
      throw new BadRequestException(
        `Minimum withdrawal is ${minThreshold} karma points. You requested ${karmaPoints}.`,
      );
    }
    if (karmaToBycRate <= 0) throw new BadRequestException('Karma conversion rate not configured. Contact admin.');

    const karmaAccount = await this.getKarmaAccount(userId);
    if (karmaAccount.currentPoints < karmaPoints) {
      throw new BadRequestException(
        `Insufficient karma. You have ${karmaAccount.currentPoints}, requested ${karmaPoints}.`,
      );
    }

    const bycAmount = karmaPoints / karmaToBycRate;
    if (bycAmount < 0.001) {
      throw new BadRequestException(
        `Amount too small. ${karmaPoints} karma = ${bycAmount.toFixed(4)} BYC. Minimum 0.001 BYC.`,
      );
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.karmaEvent.create({
        data: {
          userId,
          type: KarmaEventType.KARMA_WITHDRAWN,
          points: -karmaPoints,
          reason: `Withdrew ${karmaPoints} karma to wallet (${bycAmount.toFixed(4)} BYC)`,
          metadata: { karmaPoints, bycAmount, karmaToBycRate },
          sourceId: userId,
          sourceType: 'karma_withdrawal',
        },
      });
      await tx.karmaAccount.update({
        where: { userId },
        data: {
          currentPoints: { decrement: karmaPoints },
          updatedAt: new Date(),
        },
      });
    });

    await this.wallet.fund(
      userId,
      bycAmount,
      `Karma withdrawal: ${karmaPoints} karma → ${bycAmount.toFixed(4)} BYC`,
      `karma-withdraw:${userId}:${Date.now()}`,
    );

    this.logger.log(`User ${userId} withdrew ${karmaPoints} karma → ${bycAmount.toFixed(4)} BYC`);
    return { ok: true, bycAmount };
  }

  async getPointsConfig(): Promise<KarmaPointsConfig> {
    return this.karmaPointsConfig.getConfig();
  }

  async getPointsConfigPublic() {
    const [points, withdraw] = await Promise.all([
      this.karmaPointsConfig.getConfig(),
      this.getWithdrawSettings(),
    ]);
    return {
      points,
      withdraw,
      defaults: this.karmaPointsConfig.getDefaults(),
    };
  }
}