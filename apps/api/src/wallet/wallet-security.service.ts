import { Injectable, BadRequestException, UnauthorizedException, Logger, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { EmailService } from '../common/email.service';
import { EmailEventName } from '../email/email-events';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType, NotificationPriority } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';

@Injectable()
export class WalletSecurityService {
  private readonly logger = new Logger(WalletSecurityService.name);
  private readonly PIN_SALT_ROUNDS = 10;
  private readonly SESSION_TIMEOUT_MS = 15 * 60 * 1000; // 15 minutes
  private readonly MAX_PIN_ATTEMPTS = 5;
  private readonly PIN_LOCKOUT_MS = 30 * 60 * 1000; // 30 minutes

  constructor(
    private prisma: PrismaService,
    private email: EmailService,
    private notifications: NotificationsService,
  ) {}

  /**
   * Set or update wallet PIN
   */
  async setPin(userId: string, pin: string): Promise<void> {
    if (!pin || pin.length < 4 || pin.length > 6) {
      throw new BadRequestException('PIN must be 4-6 digits');
    }
    if (!/^\d+$/.test(pin)) {
      throw new BadRequestException('PIN must contain only digits');
    }

    const pinHash = await bcrypt.hash(pin, this.PIN_SALT_ROUNDS);
    
    // Update PIN and refresh wallet session activity
    await (this.prisma.profile.update as any)({
      where: { userId },
      data: {
        walletPinHash: pinHash,
        walletPinSetAt: new Date(),
        lastWalletActivity: new Date(), // Refresh wallet session when PIN is set
      },
    });

    this.logger.log(`Wallet PIN set for user ${userId}`);
  }

  /**
   * Verify wallet PIN
   */
  async verifyPin(userId: string, pin: string): Promise<boolean> {
    const profile = await this.prisma.profile.findUnique({
      where: { userId },
      select: { walletPinHash: true },
    });

    if (!profile?.walletPinHash) {
      throw new BadRequestException('Wallet PIN not set');
    }

    const isValid = await bcrypt.compare(pin, profile.walletPinHash);
    
    if (!isValid) {
      this.logger.warn(`Invalid PIN attempt for user ${userId}`);
      // TODO: Track failed attempts and lock after MAX_PIN_ATTEMPTS
    }

    return isValid;
  }

  /**
   * Generate biometric verification token
   * Mobile app handles biometric, sends token to backend
   */
  async generateBiometricToken(userId: string): Promise<string> {
    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

    // Store in session or temporary storage
    // For now, we'll use a simple in-memory cache (in production, use Redis)
    // TODO: Implement Redis-based token storage
    
    return token;
  }

  /**
   * Verify biometric token
   */
  async verifyBiometricToken(userId: string, token: string): Promise<boolean> {
    // TODO: Verify token from Redis/cache
    // For now, return true if token format is valid
    return /^[a-f0-9]{64}$/.test(token);
  }

  /**
   * Request OTP for wallet PIN reset. Sends 6-digit code to user's email.
   */
  async requestPinResetOtp(userId: string): Promise<{ ok: boolean; message: string }> {
    const pinSet = await this.isPinSet(userId);
    if (!pinSet) {
      throw new BadRequestException('Wallet PIN is not set. Use Set PIN instead.');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { email: true, profile: { select: { displayName: true } } },
    });
    if (!user?.email) {
      throw new BadRequestException('No email associated with account. Cannot send OTP.');
    }

    let code: string;
    do {
      code = (Math.floor(100000 + Math.random() * 900000)).toString();
      const existing = await this.prisma.walletPinResetToken.findUnique({ where: { token: code } });
      if (!existing) break;
    } while (true);

    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes
    await this.prisma.walletPinResetToken.create({
      data: { userId, token: code, expiresAt },
    });

    try {
      this.email.dispatchInBackground({
        eventName: EmailEventName.WalletPinResetRequest,
        recipient: { email: user.email, userId },
        vars: {
          displayName: user.profile?.displayName || user.email,
          resetLink: code,
          expiresAt: expiresAt.toISOString(),
          appName: 'bYbata',
        },
      });
    } catch (err) {
      this.logger.warn(`Failed to send PIN reset OTP email: ${err}`);
      throw new BadRequestException('Failed to send verification code. Please try again.');
    }

    this.logger.log(`PIN reset OTP sent to user ${userId}`);
    return { ok: true, message: 'Verification code sent to your email' };
  }

  /**
   * Verify OTP and set new PIN (PIN reset flow).
   */
  async confirmPinResetWithOtp(userId: string, token: string, newPin: string): Promise<void> {
    if (!newPin || newPin.length < 4 || newPin.length > 6 || !/^\d+$/.test(newPin)) {
      throw new BadRequestException('PIN must be 4-6 digits');
    }

    const record = await this.prisma.walletPinResetToken.findFirst({
      where: { userId, token },
    });
    if (!record) {
      throw new UnauthorizedException('Invalid or expired verification code');
    }
    if (record.usedAt) {
      throw new UnauthorizedException('Verification code has already been used');
    }
    if (record.expiresAt < new Date()) {
      throw new UnauthorizedException('Verification code has expired. Please request a new one.');
    }

    const pinHash = await bcrypt.hash(newPin, this.PIN_SALT_ROUNDS);
    await this.prisma.$transaction([
      this.prisma.profile.update({
        where: { userId },
        data: {
          walletPinHash: pinHash,
          walletPinSetAt: new Date(),
          lastWalletActivity: new Date(),
        },
      }),
      this.prisma.walletPinResetToken.update({
        where: { id: record.id },
        data: { usedAt: new Date() },
      }),
    ]);

    this.logger.log(`Wallet PIN reset via OTP for user ${userId}`);
  }

  /**
   * Check if user has set a wallet PIN
   */
  async isPinSet(userId: string): Promise<boolean> {
    const profile = await this.prisma.profile.findUnique({
      where: { userId },
      select: { walletPinHash: true },
    });
    return !!(profile?.walletPinHash);
  }

  /**
   * Check if wallet is locked
   */
  async isWalletLocked(userId: string): Promise<boolean> {
    const security = await this.prisma.walletSecurity.findUnique({
      where: { userId },
      select: { walletLocked: true, lockedAt: true },
    });
    if (!security) return false;
    return security.walletLocked === true;
  }

  /**
   * Lock wallet
   */
  async lockWallet(userId: string, reason: string, lockedBy?: string): Promise<void> {
    await this.prisma.walletSecurity.upsert({
      where: { userId },
      create: {
        userId,
        walletLocked: true,
        lockReason: reason,
        lockedAt: new Date(),
        lockedBy: lockedBy || 'system',
      },
      update: {
        walletLocked: true,
        lockReason: reason,
        lockedAt: new Date(),
        lockedBy: lockedBy || 'system',
      },
    });
    this.logger.warn(`Wallet locked for user ${userId}: ${reason}`);

    try {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { email: true, profile: { select: { displayName: true } } },
      });
      if (user?.email) {
        await Promise.all([
          this.notifications.createNotification({
            userId,
            type: NotificationType.ACCOUNT_SECURITY,
            title: 'Wallet Locked',
            message: 'Your wallet has been locked for security. Please verify your account.',
            priority: NotificationPriority.URGENT,
            sourceId: userId,
            sourceType: 'wallet',
          }),
          this.email.dispatch({
            eventName: EmailEventName.AuthAccountLocked,
            recipient: { email: user.email, userId },
            vars: {
              displayName: user.profile?.displayName || user.email,
              unlockSteps: reason || 'Open the app to unlock or contact support.',
              supportEmail: process.env.SUPPORT_EMAIL || 'support@bybata.com',
            },
          }),
        ]);
      }
    } catch {
      // Non-blocking
    }
  }

  /**
   * Unlock wallet
   */
  async unlockWallet(userId: string, unlockToken?: string): Promise<void> {
    const security = await this.prisma.walletSecurity.findUnique({
      where: { userId },
    });
    if (!security || !security.walletLocked) {
      throw new BadRequestException('Wallet is not locked');
    }
    if (unlockToken && security.unlockToken) {
      if (security.unlockToken !== unlockToken) {
        throw new UnauthorizedException('Invalid unlock token');
      }
      if (security.unlockTokenExpiresAt && security.unlockTokenExpiresAt < new Date()) {
        throw new UnauthorizedException('Unlock token expired');
      }
    }
    await this.prisma.walletSecurity.update({
      where: { userId },
      data: {
        walletLocked: false,
        lockReason: null,
        lockedAt: null,
        lockedBy: null,
        unlockToken: null,
        unlockTokenExpiresAt: null,
      },
    });
    this.logger.log(`Wallet unlocked for user ${userId}`);
  }

  /**
   * Check session timeout for wallet operations.
   * Returns true when an existing wallet session has gone idle too long.
   * No prior activity = first use — not timed out.
   */
  async checkSessionTimeout(userId: string): Promise<boolean> {
    const profile = await this.prisma.profile.findUnique({
      where: { userId },
      select: { lastWalletActivity: true },
    });
    if (!profile?.lastWalletActivity) {
      return false;
    }
    const timeSinceActivity = Date.now() - profile.lastWalletActivity.getTime();
    return timeSinceActivity > this.SESSION_TIMEOUT_MS;
  }

  /**
   * Update last wallet activity timestamp
   */
  async updateWalletActivity(userId: string): Promise<void> {
    await this.prisma.profile.update({
      where: { userId },
      data: {
        lastWalletActivity: new Date(),
      },
    });
  }

  /**
   * Identity (KYC) must be VERIFIED before outbound BYC (send / withdraw).
   */
  async assertUserIdentityVerified(userId: string): Promise<void> {
    const profile = await this.prisma.profile.findUnique({
      where: { userId },
      select: { kycStatus: true },
    });
    if ((profile?.kycStatus ?? '').toUpperCase() !== 'VERIFIED') {
      throw new ForbiddenException(
        'Identity verification is required before sending or withdrawing BYC. Complete verification in your profile.',
      );
    }
  }

  /**
   * Whether outbound wallet actions require PIN/biometric.
   * Wallet security is optional — only users who set a PIN are gated.
   */
  async isTransactionAuthRequired(userId: string): Promise<boolean> {
    return this.isPinSet(userId);
  }

  /**
   * Require PIN or biometric for outbound transactions when the user enabled wallet security.
   * Users without a wallet PIN skip this gate.
   */
  async requireTransactionAuth(
    userId: string,
    method?: 'PIN' | 'BIOMETRIC' | 'NONE',
    credential?: string,
  ): Promise<void> {
    if (!(await this.isTransactionAuthRequired(userId))) {
      return;
    }
    if (!method || !credential || method === 'NONE') {
      throw new BadRequestException(
        'Wallet PIN or biometric authentication is required for this transaction',
      );
    }
    await this.verifyTransactionAuth(userId, method, credential);
  }

  /**
   * Verify transaction authorization (PIN or biometric).
   * Fresh credentials re-establish the wallet session — idle timeout must not block them.
   */
  async verifyTransactionAuth(
    userId: string,
    method: 'PIN' | 'BIOMETRIC',
    credential: string
  ): Promise<boolean> {
    if (await this.isWalletLocked(userId)) {
      throw new BadRequestException('Wallet is locked. Please unlock to continue.');
    }

    if (method === 'PIN') {
      const isValid = await this.verifyPin(userId, credential);
      if (!isValid) {
        throw new ForbiddenException('Invalid PIN');
      }
    } else if (method === 'BIOMETRIC') {
      const isValid = await this.verifyBiometricToken(userId, credential);
      if (!isValid) {
        throw new ForbiddenException('Invalid biometric token');
      }
    } else {
      throw new BadRequestException('Invalid verification method');
    }

    // Successful auth unlocks / refreshes the wallet session
    await this.updateWalletActivity(userId);

    return true;
  }

  /**
   * Get transaction limits for user
   */
  async getTransactionLimits(userId: string): Promise<{
    dailyLimit: number | null;
    monthlyLimit: number | null;
    perTransactionLimit: number | null;
  }> {
    const security = await this.prisma.walletSecurity.findUnique({
      where: { userId },
      select: {
        dailyLimit: true,
        monthlyLimit: true,
        perTransactionLimit: true,
      },
    });

    const defaults = {
      dailyLimit: Number(process.env.WALLET_DAILY_LIMIT_BYC) || null,
      monthlyLimit: Number(process.env.WALLET_MONTHLY_LIMIT_BYC) || null,
      perTransactionLimit: Number(process.env.WALLET_PER_TRANSACTION_LIMIT_BYC) || null,
    };

    return {
      dailyLimit: security?.dailyLimit ? Number(security.dailyLimit) : defaults.dailyLimit,
      monthlyLimit: security?.monthlyLimit ? Number(security.monthlyLimit) : defaults.monthlyLimit,
      perTransactionLimit: security?.perTransactionLimit 
        ? Number(security.perTransactionLimit) 
        : defaults.perTransactionLimit,
    };
  }

  /**
   * Check if transaction exceeds limits
   */
  async checkTransactionLimits(
    userId: string,
    amount: number,
    transactionType: string
  ): Promise<void> {
    const limits = await this.getTransactionLimits(userId);

    // Check per-transaction limit
    if (limits.perTransactionLimit && amount > limits.perTransactionLimit) {
      throw new BadRequestException(
        `Transaction amount exceeds per-transaction limit of ${limits.perTransactionLimit} BYC`
      );
    }

    // Check daily limit
    if (limits.dailyLimit) {
      const since = new Date(Date.now() - 24 * 3600 * 1000);
      const dailyTotal = await this.prisma.walletTransaction.aggregate({
        where: {
          userId,
          type: transactionType as any,
          status: 'SUCCESS',
          createdAt: { gte: since },
        },
        _sum: { amount: true },
      });

      const total = Number((dailyTotal as any)?._sum?.amount ?? 0);
      if (total + amount > limits.dailyLimit) {
        throw new BadRequestException(
          `Transaction would exceed daily limit of ${limits.dailyLimit} BYC. ` +
          `Already spent ${total} BYC} today.`
        );
      }
    }

    // Check monthly limit
    if (limits.monthlyLimit) {
      const since = new Date(Date.now() - 30 * 24 * 3600 * 1000);
      const monthlyTotal = await this.prisma.walletTransaction.aggregate({
        where: {
          userId,
          type: transactionType as any,
          status: 'SUCCESS',
          createdAt: { gte: since },
        },
        _sum: { amount: true },
      });

      const total = Number((monthlyTotal as any)?._sum?.amount ?? 0);
      if (total + amount > limits.monthlyLimit) {
        throw new BadRequestException(
          `Transaction would exceed monthly limit of ${limits.monthlyLimit} BYC. ` +
          `Already spent ${total} BYC this month.`
        );
      }
    }
  }

  /**
   * Detect suspicious activity
   */
  async detectSuspiciousActivity(
    userId: string,
    transactionId: string,
    amount: number,
    transactionType: string
  ): Promise<void> {
    const checks: Array<{ type: string; description: string; severity: string }> = [];

    // Check for rapid transactions
    const recentTransactions = await this.prisma.walletTransaction.count({
      where: {
        userId,
        type: transactionType as any,
        status: 'SUCCESS',
        createdAt: { gte: new Date(Date.now() - 5 * 60 * 1000) }, // Last 5 minutes
      },
    });

    if (recentTransactions >= 5) {
      checks.push({
        type: 'RAPID_TRANSACTIONS',
        description: `User made ${recentTransactions} transactions in the last 5 minutes`,
        severity: 'HIGH',
      });
    }

    // Check for large amount
    const largeAmountThreshold = Number(process.env.SUSPICIOUS_LARGE_AMOUNT_BYC) || 10000;
    if (amount > largeAmountThreshold) {
      checks.push({
        type: 'LARGE_AMOUNT',
        description: `Transaction amount ${amount} BYC exceeds threshold of ${largeAmountThreshold} BYC`,
        severity: 'MEDIUM',
      });
    }

    // Record suspicious activities
    for (const check of checks) {
      // TODO: Uncomment after schema migration
      // await (this.prisma as any).suspiciousActivity.create({
      //   data: {
      //     userId,
      //     activityType: check.type,
      //     description: check.description,
      //     severity: check.severity as any,
      //     transactionId,
      //   },
      // });

      // Auto-lock on critical severity
      if (check.severity === 'CRITICAL' || check.severity === 'HIGH') {
        await this.lockWallet(
          userId,
          `Suspicious activity detected: ${check.description}`,
          'system'
        );
      }

      // TODO: Uncomment after schema migration
      // await (this.prisma as any).walletSecurity.upsert({
      //   where: { userId },
      //   create: {
      //     userId,
      //     suspiciousActivityCount: 1,
      //     lastSuspiciousActivity: new Date(),
      //   },
      //   update: {
      //     suspiciousActivityCount: { increment: 1 },
      //     lastSuspiciousActivity: new Date(),
      //   },
      // });
      
      this.logger.warn(`Suspicious activity detected for user ${userId}: ${check.description} [PLACEHOLDER - Schema migration needed]`);
    }
  }
}

