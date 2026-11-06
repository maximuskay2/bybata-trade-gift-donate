import { Injectable, BadRequestException, NotFoundException, Logger, Inject, forwardRef } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import type { Cache } from 'cache-manager';
import { PrismaService } from '../common/prisma.service';
import { BoostPurchase, Prisma } from '@prisma/client';
import { WalletSecurityService } from './wallet-security.service';
import { NotificationsService } from '../notifications/notifications.service';
import { EmailService } from '../common/email.service';
import { EmailEventName } from '../email/email-events';
import { NotificationType, NotificationPriority } from '@prisma/client';
import {
  computeBoostPurchaseTotal,
  costForBoostPlacement,
  endOfUtcDay,
  normalizeBoostDates,
  parseBoostDateUtc,
  startOfUtcDay,
} from './boost-config.util';
import { optionalDestinationUrl } from '../common/destination-url.util';
import { mapWalletUserError } from './wallet-errors.util';
import {
  formatDate,
  formatShortDate,
  renderReceiptDocument,
} from '../common/receipt-pdf.util';

/** Debit/purchase transactions: FOR UPDATE + ReadCommitted, longer timeout for Railway DB latency. */
const WALLET_DEBIT_TX_OPTIONS = {
  maxWait: 15_000,
  timeout: 20_000,
  isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted,
} as const;

@Injectable()
export class WalletService {
  private readonly logger = new Logger(WalletService.name);
  constructor(
    private prisma: PrismaService,
    @Inject(forwardRef(() => WalletSecurityService))
    private security: WalletSecurityService,
    @Inject(forwardRef(() => NotificationsService))
    private notifications: NotificationsService,
    private email: EmailService,
    @Inject(CACHE_MANAGER) private cache: Cache,
  ) {}

  // Simple in-memory cache for active conversion rates
  private ratesCache: { items: any[]; ts: number } | null = null;
  private readonly ratesTTLms = 60_000; // 60 seconds

  /**
   * Ensure account exists for a user
   * Uses upsert to avoid race conditions
   */
  private async ensureAccount(userId: string) {
    return this.prisma.account.upsert({
      where: { userId },
      update: {},
      create: { userId, balance: 0 },
    });
  }

  /**
   * Get account with row-level lock for double-spend prevention
   * This ensures balance checks and updates are atomic
   */
  private async getAccountWithLock(db: any, accountId: string) {
    // Use Prisma's $queryRaw with FOR UPDATE to lock the row
    const result = await db.$queryRaw<Array<{ id: string; userId: string; balance: any }>>`
      SELECT id, "userId", balance 
      FROM "Account" 
      WHERE id = ${accountId} 
      FOR UPDATE
    `;
    if (!result || result.length === 0) {
      throw new NotFoundException(`Account not found: ${accountId}`);
    }
    return result[0];
  }

  /**
   * Validate sufficient balance with locked account check
   * This prevents double-spend attacks by ensuring balance check and debit happen atomically
   */
  private async validateBalance(db: any, accountId: string, amount: number): Promise<void> {
    const account = await this.getAccountWithLock(db, accountId);
    const balance = typeof account.balance === 'number' 
      ? account.balance 
      : (account.balance?.toNumber ? account.balance.toNumber() : Number(account.balance || 0));
    
    if (balance < amount) {
      throw new BadRequestException(`Insufficient funds. Available: ${balance} BYC, Required: ${amount} BYC`);
    }
  }

  async getWallet(userId: string) {
    const acc = await this.ensureAccount(userId);
    const latestRate = await this.prisma.conversionRate.findFirst({
      where: { active: true },
      orderBy: { createdAt: 'desc' },
    });
    return { balance: acc.balance, latestRate };
  }

  async getBalance(userId: string) {
    const acc = await this.ensureAccount(userId);
    return { balance: acc.balance };
  }

  async getAddress(userId: string) {
    // Derive a stable BYC address from userId (non-secret)
    const addr = `BYC-${userId.substring(0, 8)}-${userId.substring(userId.length - 4)}`;
    return { address: addr };
  }

  async getAnalytics(userId: string) {
    const account = await this.prisma.account.findUnique({ where: { userId } });
    const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const [spentAgg, receivedAgg, monthlyCount, donationReceivedAgg] = await this.prisma.$transaction([
      this.prisma.walletTransaction.aggregate({
        where: { userId, status: 'SUCCESS', type: { in: ['SEND', 'DONATION', 'ADVERT'] } },
        _sum: { amount: true },
      }),
      this.prisma.walletTransaction.aggregate({
        where: { userId, status: 'SUCCESS', type: { in: ['RECEIVE', 'BONUS', 'CASHBACK'] } },
        _sum: { amount: true },
      }),
      this.prisma.walletTransaction.count({ where: { userId, createdAt: { gte: since } } }),
      // Get total BYC received specifically from donations (RECEIVE transactions with donation-related memos)
      this.prisma.walletTransaction.aggregate({
        where: {
          userId,
          status: 'SUCCESS',
          type: 'RECEIVE',
          memo: { contains: 'Donation to' },
        },
        _sum: { amount: true },
      }),
    ]);
    const toNumber = (d: any) => (d?.toNumber ? d.toNumber() : Number(d || 0));
    return {
      availableBalance: toNumber(account?.balance) || 0,
      totalSpent: toNumber(spentAgg._sum?.amount) || 0,
      totalReceived: toNumber(receivedAgg._sum?.amount) || 0,
      receivedFromDonations: toNumber(donationReceivedAgg._sum?.amount) || 0,
      monthlyTransactions: monthlyCount || 0,
    };
  }

  async listTransactions(userId: string, page = 1, size = 20, opts?: { type?: string; status?: string; from?: string; to?: string; referenceType?: string }) {
    await this.ensureAccount(userId);
    const where: any = { userId };
    if (opts?.type) where.type = opts.type;
    if (opts?.status) where.status = opts.status;
    if (opts?.referenceType) where.referenceType = opts.referenceType;
    if (opts?.from || opts?.to) {
      where.createdAt = {};
      if (opts.from) (where.createdAt as any).gte = new Date(opts.from);
      if (opts.to) (where.createdAt as any).lte = new Date(opts.to);
    }
    const [total, items] = await this.prisma.$transaction([
      this.prisma.walletTransaction.count({ where }),
      this.prisma.walletTransaction.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
      }),
    ]);
    return { items, page, size, total };
  }

  /**
   * Fund wallet (credit BYC to user account)
   * Atomic transaction with idempotency and audit trail
   * @param txType - Optional transaction type (default: FUND). Use REFERRAL_BONUS for referral rewards.
   */
  async fund(
    userId: string,
    amount: number,
    memo?: string,
    idempotencyKey?: string,
    referenceType?: string,
    referenceId?: string,
    txType: 'FUND' | 'REFERRAL_BONUS' | 'BONUS' = 'FUND',
  ) {
    if (amount <= 0) throw new BadRequestException('Amount must be positive');
    
    // Idempotency check (outside transaction for efficiency)
    if (idempotencyKey) {
      const existing = await this.prisma.walletTransaction.findUnique({ where: { idempotencyKey } });
      if (existing) {
        this.logger.log(`Fund operation already processed: idempotencyKey=${idempotencyKey}, transactionId=${existing.id}`);
        return { ok: true, transactionId: existing.id, duplicate: true };
      }
    }

    try {
      const tx = await this.prisma.$transaction(async (db) => {
        const account = await this.ensureAccount(userId);
        
        // Create transaction record with SUCCESS status and update balance atomically
        // For payment gateway funding, the transaction is marked SUCCESS immediately upon wallet crediting
        // The webhook verification has already occurred in the calling handler
        const created = await db.walletTransaction.create({
          data: {
            userId,
            accountId: account.id,
            type: txType,
            amount,
            status: 'SUCCESS', // Marked SUCCESS since balance is being credited immediately
            memo,
            idempotencyKey,
            referenceType,
            referenceId,
          } as any,
        });

        // Update account balance atomically within the same transaction
        const currentBalance = (account.balance as any)?.toNumber ? (account.balance as any).toNumber() : Number(account.balance || 0);
        await db.account.update({
          where: { id: account.id },
          data: { balance: currentBalance + amount },
        });

        this.logger.log(`Funded wallet: ${amount} BYC for userId=${userId}, new balance will be updated`);
        return created;
      }, {
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
      });
      
      return { ok: true, transactionId: tx.id };
    } catch (error) {
      this.logger.error(`Failed to fund wallet for userId=${userId}: ${(error as Error).message}`);
      throw error;
    }
  }

  /**
   * Send BYC from one user to another (P2P Transfer)
   * Atomic transaction with double-spend prevention, balance validation, and transfer record
   * Includes security checks, transaction limits, and notifications
   */
  async send(
    fromUserId: string,
    toUserId: string,
    amount: number,
    memo?: string,
    idempotencyKey?: string,
    verificationMethod?: 'PIN' | 'BIOMETRIC',
    verificationCredential?: string
  ) {
    if (fromUserId === toUserId) throw new BadRequestException('Cannot send to self');
    if (amount <= 0) throw new BadRequestException('Amount must be positive');

    await this.security.assertUserIdentityVerified(fromUserId);
    await this.security.requireTransactionAuth(
      fromUserId,
      verificationMethod,
      verificationCredential,
    );

    // Check transaction limits
    await this.security.checkTransactionLimits(fromUserId, amount, 'SEND');

    // Limits: minimum and daily cap (checked outside transaction for efficiency)
    const minAmt = Number(process.env.WALLET_TRANSFER_MIN_BYC ?? 0);
    if (minAmt > 0 && amount < minAmt) {
      throw new BadRequestException(`Minimum transfer amount is ${minAmt} BYC`);
    }
    
    const dailyCap = Number(process.env.WALLET_TRANSFER_DAILY_LIMIT_BYC ?? 0);
    if (dailyCap > 0) {
      const since = new Date(Date.now() - 24 * 3600 * 1000);
      const sentToday = await this.prisma.walletTransaction.aggregate({
        _sum: { amount: true as any },
        where: { 
          userId: fromUserId, 
          type: 'SEND', 
          status: 'SUCCESS',
          createdAt: { gte: since } 
        },
      });
      const totalSent = Number((sentToday as any)?._sum?.amount ?? 0);
      if (totalSent + amount > dailyCap) {
        throw new BadRequestException(`Daily transfer limit exceeded. Limit: ${dailyCap} BYC, Sent today: ${totalSent} BYC`);
      }
    }

    // Idempotency check
    if (idempotencyKey) {
      const existing = await this.prisma.walletTransaction.findUnique({ where: { idempotencyKey } });
      if (existing) {
        this.logger.log(`Send operation already processed: idempotencyKey=${idempotencyKey}, transactionId=${existing.id}`);
        return { ok: true, transactionId: existing.id, duplicate: true };
      }
    }

    // Ensure accounts exist
    const fromAcc = await this.ensureAccount(fromUserId);
    const toAcc = await this.ensureAccount(toUserId);

    try {
      // Atomic transaction with row-level locking for double-spend prevention
      const result = await this.prisma.$transaction(async (db) => {
        // Validate balance with lock (prevents double-spend)
        await this.validateBalance(db, fromAcc.id, amount);

        // Create transfer record
        const transfer = await (db as any).transfer.create({
          data: { 
            senderId: fromUserId, 
            recipientId: toUserId, 
            amount, 
            memo, 
            status: 'SUCCESS' 
          },
        });

        // Get locked accounts for atomic balance updates
        const lockedFrom = await this.getAccountWithLock(db, fromAcc.id);
        const lockedTo = await this.getAccountWithLock(db, toAcc.id);
        
        const fromBalance = typeof lockedFrom.balance === 'number'
          ? lockedFrom.balance
          : (lockedFrom.balance?.toNumber ? lockedFrom.balance.toNumber() : Number(lockedFrom.balance || 0));
        const toBalance = typeof lockedTo.balance === 'number'
          ? lockedTo.balance
          : (lockedTo.balance?.toNumber ? lockedTo.balance.toNumber() : Number(lockedTo.balance || 0));

        // Create debit transaction (sender)
        const debit = await db.walletTransaction.create({
          data: {
            userId: fromUserId,
            accountId: fromAcc.id,
            type: 'SEND',
            amount,
            status: 'SUCCESS',
            memo,
            idempotencyKey,
            transferId: transfer.id,
          } as any,
        });

        // Create credit transaction (receiver)
        await db.walletTransaction.create({
          data: {
            userId: toUserId,
            accountId: toAcc.id,
            type: 'RECEIVE',
            amount,
            status: 'SUCCESS',
            memo,
            transferId: transfer.id,
          } as any,
        });

        // Update balances atomically
        await db.account.update({
          where: { id: fromAcc.id },
          data: { balance: fromBalance - amount },
        });
        await db.account.update({
          where: { id: toAcc.id },
          data: { balance: toBalance + amount },
        });

        this.logger.log(`Transfer completed: ${amount} BYC from ${fromUserId} to ${toUserId}`);
        return { debit, transfer, toUserId };
      }, {
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable, // Highest isolation for double-spend prevention
        timeout: 10000, // 10 second timeout
      });

      // Send notifications to both parties
      try {
        const [sender, recipient] = await Promise.all([
          this.prisma.user.findUnique({
            where: { id: fromUserId },
            select: { profile: { select: { displayName: true } } },
          }),
          this.prisma.user.findUnique({
            where: { id: result.toUserId },
            select: { profile: { select: { displayName: true } } },
          }),
        ]);

        const recipientName = recipient?.profile?.displayName || 'Someone';
        const senderName = sender?.profile?.displayName || 'You';

        // Notify sender
        await this.notifications.createNotification({
          userId: fromUserId,
          type: NotificationType.SYSTEM_ANNOUNCEMENT,
          title: 'Transfer Sent',
          message: `You sent ${amount} BYC to ${recipientName}`,
          actionUrl: '/wallet',
          sourceId: result.debit.id,
          sourceType: 'transfer',
          priority: NotificationPriority.NORMAL,
          data: {
            kind: 'byc_transfer',
            direction: 'sent',
            transactionId: result.debit.id,
            amount,
            recipientId: result.toUserId,
          },
        });

        // Notify recipient
        await this.notifications.createNotification({
          userId: result.toUserId,
          type: NotificationType.SYSTEM_ANNOUNCEMENT,
          title: 'Transfer Received!',
          message: `You received ${amount} BYC from ${senderName}`,
          actionUrl: '/wallet',
          sourceId: result.debit.id,
          sourceType: 'transfer',
          priority: NotificationPriority.HIGH,
          data: {
            kind: 'byc_transfer',
            direction: 'received',
            transactionId: result.debit.id,
            amount,
            senderId: fromUserId,
          },
        });
      } catch (error) {
        this.logger.warn(`Failed to send transfer notifications: ${(error as Error).message}`);
      }

      try {
        const [senderUser, recipientUser, senderAccount, recipientAccount] = await Promise.all([
          this.prisma.user.findUnique({ where: { id: fromUserId }, select: { email: true, profile: { select: { displayName: true } } } }),
          this.prisma.user.findUnique({ where: { id: result.toUserId }, select: { email: true, profile: { select: { displayName: true } } } }),
          this.prisma.account.findUnique({ where: { userId: fromUserId } }),
          this.prisma.account.findUnique({ where: { userId: result.toUserId } }),
        ]);
        const senderBalance = senderAccount ? ((senderAccount.balance as any)?.toNumber ? (senderAccount.balance as any).toNumber() : Number(senderAccount.balance || 0)) : 0;
        const recipientBalance = recipientAccount ? ((recipientAccount.balance as any)?.toNumber ? (recipientAccount.balance as any).toNumber() : Number(recipientAccount.balance || 0)) : 0;

        if (senderUser?.email) {
          this.email.dispatchInBackground({
            eventName: EmailEventName.WalletBycSent,
            recipient: { email: senderUser.email, userId: fromUserId },
            vars: {
              actorName: senderUser.profile?.displayName || senderUser.email,
              amount,
              recipientName: recipientUser?.profile?.displayName || recipientUser?.email || 'Recipient',
              balance: senderBalance,
              txId: result.debit.id,
            },
          });
        }
        if (recipientUser?.email) {
          this.email.dispatchInBackground({
            eventName: EmailEventName.WalletBycReceived,
            recipient: { email: recipientUser.email, userId: result.toUserId },
            vars: {
              targetName: recipientUser.profile?.displayName || recipientUser.email,
              amount,
              senderName: senderUser?.profile?.displayName || senderUser?.email || 'Sender',
              balance: recipientBalance,
              txId: result.debit.id,
            },
          });
        }
      } catch (error) {
        this.logger.warn(`Failed to send transfer emails: ${(error as Error).message}`);
      }

      // Detect suspicious activity
      try {
        await this.security.detectSuspiciousActivity(
          fromUserId,
          result.debit.id,
          amount,
          'SEND'
        );
      } catch (error) {
        this.logger.warn(`Suspicious activity detection failed: ${(error as Error).message}`);
      }

      return { ok: true, transactionId: result.debit.id };
    } catch (error) {
      // If it's a balance validation error, re-throw it
      if (error instanceof BadRequestException) throw error;
      
      this.logger.error(`Failed to send ${amount} BYC from ${fromUserId} to ${toUserId}: ${(error as Error).message}`);
      throw new BadRequestException(`Transfer failed: ${(error as Error).message}`);
    }
  }

  async requestWithdrawal(
    userId: string,
    amount: number,
    opts?: {
      currency?: string;
      memo?: string;
      destination?: Record<string, any>;
      idempotencyKey?: string;
      verificationMethod?: 'PIN' | 'BIOMETRIC';
      verificationCredential?: string;
    }
  ) {
    if (amount <= 0) throw new BadRequestException('Amount must be positive');
    const currency = (opts?.currency || 'BYC').toUpperCase();

    await this.security.assertUserIdentityVerified(userId);
    await this.security.requireTransactionAuth(
      userId,
      opts?.verificationMethod,
      opts?.verificationCredential,
    );
    await this.security.checkTransactionLimits(userId, amount, 'WITHDRAWAL');

    if (opts?.idempotencyKey) {
      const existing = await this.prisma.walletTransaction.findUnique({
        where: { idempotencyKey: opts.idempotencyKey },
      });
      if (existing) {
        return {
          ok: true,
          withdrawalId: existing.referenceId,
          transactionId: existing.id,
          duplicate: true,
        };
      }
    }

    const account = await this.ensureAccount(userId);
    const result = await this.prisma.$transaction(async (db) => {
      await this.validateBalance(db, account.id, amount);
      const lockedAccount = await this.getAccountWithLock(db, account.id);
      const currentBalance = typeof lockedAccount.balance === 'number'
        ? lockedAccount.balance
        : (lockedAccount.balance?.toNumber ? lockedAccount.balance.toNumber() : Number(lockedAccount.balance || 0));

      const withdrawal = await (db as any).withdrawal.create({
        data: {
          userId,
          amount,
          currency,
          status: 'PENDING',
          memo: opts?.memo,
          destination: opts?.destination ?? null,
        },
      });

      const tx = await db.walletTransaction.create({
        data: {
          userId,
          accountId: account.id,
          type: 'WITHDRAWAL',
          amount,
          status: 'PENDING',
          memo: opts?.memo,
          idempotencyKey: opts?.idempotencyKey,
          referenceType: 'withdrawal',
          referenceId: withdrawal.id,
          metadata: { currency, destination: opts?.destination ?? null },
        } as any,
      });

      await (db as any).withdrawal.update({
        where: { id: withdrawal.id },
        data: { transactionId: tx.id },
      });

      await db.account.update({
        where: { id: account.id },
        data: { balance: currentBalance - amount },
      });

      return { withdrawal, tx };
    }, {
      isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
    });

    try {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { email: true, profile: { select: { displayName: true } } },
      });
      if (user?.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.WalletWithdrawalRequested,
          recipient: { email: user.email, userId },
          vars: {
            actorName: user.profile?.displayName || user.email,
            amount,
            currency,
            withdrawalId: result.withdrawal.id,
            createdAt: result.withdrawal.createdAt.toISOString(),
          },
        });
      }
    } catch (e) {
      this.logger.warn(`Withdrawal requested email failed: ${(e as Error).message}`);
    }

    return { ok: true, withdrawalId: result.withdrawal.id, transactionId: result.tx.id };
  }

  async completeWithdrawal(withdrawalId: string, adminId?: string, reference?: string) {
    const existing = await (this.prisma as any).withdrawal.findUnique({
      where: { id: withdrawalId },
      include: { user: { select: { id: true, email: true, profile: { select: { displayName: true } } } } },
    });
    if (!existing) throw new NotFoundException('Withdrawal not found');
    if (existing.status === 'COMPLETED') {
      return { ok: true, withdrawalId, status: existing.status };
    }

    const completedAt = new Date();
    const updated = await this.prisma.$transaction(async (db) => {
      const withdrawal = await (db as any).withdrawal.update({
        where: { id: withdrawalId },
        data: {
          status: 'COMPLETED',
          completedAt,
          destination: existing.destination ?? undefined,
        },
      });

      const txId = existing.transactionId;
      if (txId) {
        await db.walletTransaction.update({
          where: { id: txId },
          data: { status: 'SUCCESS', memo: reference ? `Withdrawal completed: ${reference}` : undefined },
        });
      } else {
        await db.walletTransaction.updateMany({
          where: { referenceType: 'withdrawal', referenceId: withdrawalId },
          data: { status: 'SUCCESS' },
        });
      }

      if (adminId) {
        await db.adminActionAudit.create({
          data: {
            adminId,
            action: 'WALLET_WITHDRAWAL_COMPLETED',
            targetUserId: existing.userId,
            details: { withdrawalId, reference },
          } as any,
        });
      }

      return withdrawal;
    });

    try {
      if (existing.user?.email) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.WalletWithdrawalCompleted,
          recipient: { email: existing.user.email, userId: existing.user.id },
          vars: {
            actorName: existing.user.profile?.displayName || existing.user.email,
            amount: Number(existing.amount ?? 0),
            currency: existing.currency || 'BYC',
            withdrawalId: existing.id,
            completedAt: completedAt.toISOString(),
          },
        });
      }
    } catch (e) {
      this.logger.warn(`Withdrawal completed email failed: ${(e as Error).message}`);
    }

    return { ok: true, withdrawalId: updated.id, status: updated.status };
  }

  async rejectWithdrawal(withdrawalId: string, adminId?: string, reason?: string, status: 'REJECTED' | 'FAILED' | 'CANCELLED' = 'REJECTED') {
    const existing = await (this.prisma as any).withdrawal.findUnique({
      where: { id: withdrawalId },
      include: { user: { select: { id: true, email: true, profile: { select: { displayName: true } } } } },
    });
    if (!existing) throw new NotFoundException('Withdrawal not found');
    if (existing.status === 'COMPLETED') {
      throw new BadRequestException('Withdrawal already completed');
    }
    if (['REJECTED', 'FAILED', 'CANCELLED'].includes(existing.status)) {
      return { ok: true, withdrawalId, status: existing.status };
    }

    const updated = await this.prisma.$transaction(async (db) => {
      const withdrawal = await (db as any).withdrawal.update({
        where: { id: withdrawalId },
        data: {
          status,
          memo: reason ? `${existing.memo ?? ''}${existing.memo ? ' | ' : ''}${reason}` : existing.memo,
        },
      });

      const txId = existing.transactionId;
      if (txId) {
        await db.walletTransaction.update({
          where: { id: txId },
          data: { status: 'FAILED', memo: reason ? `Withdrawal ${status.toLowerCase()}: ${reason}` : undefined },
        });
      } else {
        await db.walletTransaction.updateMany({
          where: { referenceType: 'withdrawal', referenceId: withdrawalId },
          data: { status: 'FAILED' },
        });
      }

      const account = await db.account.upsert({
        where: { userId: existing.userId },
        update: {},
        create: { userId: existing.userId, balance: 0 },
      });
      const lockedAccount = await this.getAccountWithLock(db, account.id);
      const currentBalance = typeof lockedAccount.balance === 'number'
        ? lockedAccount.balance
        : (lockedAccount.balance?.toNumber ? lockedAccount.balance.toNumber() : Number(lockedAccount.balance || 0));

      await db.walletTransaction.create({
        data: {
          userId: existing.userId,
          accountId: account.id,
          type: 'REFUND',
          amount: existing.amount,
          status: 'SUCCESS',
          memo: reason ? `Withdrawal refund: ${reason}` : 'Withdrawal refund',
          referenceType: 'withdrawal_refund',
          referenceId: withdrawalId,
          metadata: { withdrawalId, status, reason },
        } as any,
      });

      await db.account.update({
        where: { id: account.id },
        data: { balance: currentBalance + Number(existing.amount ?? 0) },
      });

      if (adminId) {
        await db.adminActionAudit.create({
          data: {
            adminId,
            action: `WALLET_WITHDRAWAL_${status}`,
            targetUserId: existing.userId,
            details: { withdrawalId, reason },
          } as any,
        });
      }

      return withdrawal;
    });

    try {
      if (existing.user?.email) {
        const eventName =
          status === 'FAILED'
            ? EmailEventName.WalletWithdrawalFailed
            : status === 'CANCELLED'
                ? EmailEventName.WalletWithdrawalCancelled
                : EmailEventName.WalletWithdrawalRejected;
        this.email.dispatchInBackground({
          eventName,
          recipient: { email: existing.user.email, userId: existing.user.id },
          vars: {
            actorName: existing.user.profile?.displayName || existing.user.email,
            amount: Number(existing.amount ?? 0),
            currency: existing.currency || 'BYC',
            withdrawalId: existing.id,
            status,
            reason: reason ?? 'Not specified',
          },
        });
      }
    } catch (e) {
      this.logger.warn(`Withdrawal ${status.toLowerCase()} email failed: ${(e as Error).message}`);
    }

    return { ok: true, withdrawalId: updated.id, status: updated.status };
  }

  async cancelWithdrawal(userId: string, withdrawalId: string, reason?: string) {
    const existing = await (this.prisma as any).withdrawal.findUnique({
      where: { id: withdrawalId },
    });
    if (!existing || existing.userId !== userId) {
      throw new NotFoundException('Withdrawal not found');
    }
    if (existing.status !== 'PENDING') {
      throw new BadRequestException('Only pending withdrawals can be cancelled');
    }
    return this.rejectWithdrawal(withdrawalId, userId, reason ?? 'User cancelled', 'CANCELLED');
  }

  async listWithdrawals(userId: string, page = 1, size = 20) {
    const where = { userId } as any;
    const [total, items] = await this.prisma.$transaction([
      (this.prisma as any).withdrawal.count({ where }),
      (this.prisma as any).withdrawal.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
      }),
    ]);
    return { items, page, size, total };
  }

  async listRates() {
    return this.prisma.conversionRate.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async listActiveRates() {
    const cacheKey = 'wallet:rates:active';
    const ttlSeconds = Number(process.env.WALLET_RATES_CACHE_TTL_S ?? 300);

    // 1) Try distributed/app-level cache (Redis or in-memory CacheModule)
    try {
      const cached = await this.cache.get<any[]>(cacheKey);
      if (cached && Array.isArray(cached) && cached.length > 0) {
        return cached;
      }
    } catch (err) {
      const error: any = err;
      this.logger.warn(`WalletService.listActiveRates cache get failed: ${error?.message ?? error}`);
    }

    // 2) Fallback to short-lived in-process cache
    const now = Date.now();
    if (this.ratesCache && now - this.ratesCache.ts < this.ratesTTLms) {
      return this.ratesCache.items;
    }

    // 3) Hit the database as source of truth
    const items = await this.prisma.conversionRate.findMany({
      where: { active: true },
      orderBy: { createdAt: 'desc' },
    });
    this.ratesCache = { items, ts: now };

    // 4) Populate distributed cache (best-effort)
    try {
      await this.cache.set(cacheKey, items, ttlSeconds);
    } catch (err) {
      const error: any = err;
      this.logger.warn(`WalletService.listActiveRates cache set failed: ${error?.message ?? error}`);
    }

    return items;
  }

  async listPromotions() {
    return this.prisma.promotion.findMany({ where: { active: true }, orderBy: { createdAt: 'desc' } });
  }

  async getBoostConfig() {
    const [boostTypes, placements, configs, adPricing] = await Promise.all([
      this.prisma.boostType.findMany({ where: { active: true }, orderBy: { createdAt: 'desc' } }),
      this.prisma.adPlacement.findMany({ where: { active: true }, orderBy: [{ priority: 'desc' }, { createdAt: 'desc' }] }),
      this.prisma.boostConfig.findMany({ where: { active: true }, orderBy: { createdAt: 'desc' } }),
      this.getAdPricingFromSettings(),
    ]);
    const configsWithPricing = configs.map((c) => {
      const boostType = boostTypes.find((t) => t.id === c.boostTypeId);
      const slug = (boostType?.slug ?? '').toLowerCase();
      let dailyByc = c.dailyCostBYC ? Number(c.dailyCostBYC) : null;
      if (dailyByc == null || dailyByc <= 0) {
        if (slug.includes('trade')) dailyByc = adPricing.tradeBycPerDay;
        else if (slug.includes('gift')) dailyByc = adPricing.giftBycPerDay;
        else if (slug.includes('campaign') || slug.includes('donation')) dailyByc = adPricing.donationBycPerDay;
        else dailyByc = adPricing.normalBycPerDay;
      }
      return { ...c, dailyCostBYC: dailyByc };
    });
    return { boostTypes, placements, configs: configsWithPricing, adPricing };
  }

  async getAdPricingRates(): Promise<{
    tradeBycPerDay: number;
    giftBycPerDay: number;
    donationBycPerDay: number;
    normalBycPerDay: number;
  }> {
    return this.getAdPricingFromSettings();
  }

  private async getAdPricingFromSettings(): Promise<{
    tradeBycPerDay: number;
    giftBycPerDay: number;
    donationBycPerDay: number;
    normalBycPerDay: number;
  }> {
    const [t, g, d, n] = await Promise.all([
      this.prisma.appSetting.findUnique({ where: { key: 'AD_PRICING_TRADE_BYC_PER_DAY' } }),
      this.prisma.appSetting.findUnique({ where: { key: 'AD_PRICING_GIFT_BYC_PER_DAY' } }),
      this.prisma.appSetting.findUnique({ where: { key: 'AD_PRICING_DONATION_BYC_PER_DAY' } }),
      this.prisma.appSetting.findUnique({ where: { key: 'AD_PRICING_NORMAL_BYC_PER_DAY' } }),
    ]);
    return {
      tradeBycPerDay: t ? parseFloat(t.value) : 2.5,
      giftBycPerDay: g ? parseFloat(g.value) : 2,
      donationBycPerDay: d ? parseFloat(d.value) : 2,
      normalBycPerDay: n ? parseFloat(n.value) : 3,
    };
  }


  /** Default feed placement when boosting a listing (no external link). */
  resolveBoostPlacementKey(referenceType: string, placementKey?: string | null): string {
    if (placementKey?.trim()) return placementKey.trim();
    const t = (referenceType ?? '').toLowerCase();
    if (t === 'trade') return 'trade_feed';
    if (t === 'gift') return 'gift_feed';
    if (t === 'campaign' || t === 'donation') return 'campaign_feed';
    return 'home_feed';
  }

  async purchaseBoostFromConfig(
    userId: string,
    referenceType: string,
    referenceId: string,
    boostTypeId: string,
    days?: number,
    placementKey?: string | null,
    destinationUrl?: string,
    idempotencyKey?: string,
    verificationMethod?: 'PIN' | 'BIOMETRIC',
    verificationCredential?: string,
    boostDatesInput?: string[],
    placementKeysInput?: string[],
  ) {
    if (!referenceType || !referenceId) throw new BadRequestException('Invalid reference');
    if (!boostTypeId) throw new BadRequestException('Boost type is required');

    const boostDates = normalizeBoostDates(boostDatesInput, days);
    if (boostDates.length === 0) {
      throw new BadRequestException('Select at least one boost day');
    }

    const dayCount = boostDates.length;
    const todayKey = new Date().toISOString().slice(0, 10);
    for (const d of boostDates) {
      if (d < todayKey) {
        throw new BadRequestException('Boost days must be today or in the future');
      }
    }

    const resolvedPlacementKeys = [
      ...new Set(
        (placementKeysInput?.length
          ? placementKeysInput
          : placementKey
            ? [placementKey]
            : [this.resolveBoostPlacementKey(referenceType, null)]
        )
          .map((k) => k.trim())
          .filter(Boolean),
      ),
    ];
    if (resolvedPlacementKeys.length === 0) {
      throw new BadRequestException('Select at least one placement');
    }

    const [boostType, config, placements] = await Promise.all([
      this.prisma.boostType.findUnique({ where: { id: boostTypeId } }),
      this.prisma.boostConfig.findFirst({ where: { boostTypeId, active: true } }),
      this.prisma.adPlacement.findMany({
        where: { key: { in: resolvedPlacementKeys }, active: true },
      }),
    ]);
    if (!boostType || !boostType.active) throw new NotFoundException('Boost type not found');
    if (!config) throw new NotFoundException('Boost configuration not found');
    if (placements.length !== resolvedPlacementKeys.length) {
      throw new BadRequestException('One or more placements are invalid or inactive');
    }

    if (dayCount < config.minDays || dayCount > config.maxDays) {
      throw new BadRequestException(
        `Select between ${config.minDays} and ${config.maxDays} day(s)`,
      );
    }
    if (config.placementKeys?.length) {
      for (const key of resolvedPlacementKeys) {
        if (!config.placementKeys.includes(key)) {
          throw new BadRequestException('Placement not allowed for this boost');
        }
      }
    }

    const adPricing = await this.getAdPricingFromSettings();
    const slug = (boostType.slug ?? '').toLowerCase();
    let dailyByc = config.dailyCostBYC ? Number(config.dailyCostBYC) : null;
    if (dailyByc == null || dailyByc <= 0) {
      if (slug.includes('trade')) dailyByc = adPricing.tradeBycPerDay;
      else if (slug.includes('gift')) dailyByc = adPricing.giftBycPerDay;
      else if (slug.includes('campaign') || slug.includes('donation')) dailyByc = adPricing.donationBycPerDay;
      else dailyByc = adPricing.normalBycPerDay;
    }
    const configWithPricing = { ...config, dailyCostBYC: dailyByc };
    const amount = computeBoostPurchaseTotal(
      configWithPricing,
      dayCount,
      resolvedPlacementKeys,
      adPricing,
    );
    if (amount <= 0) throw new BadRequestException('Invalid boost cost');

    const normalizedDestinationUrl = null;

    if (verificationMethod && verificationCredential) {
      await this.security.verifyTransactionAuth(userId, verificationMethod, verificationCredential);
    }
    await this.security.checkTransactionLimits(userId, amount, 'PROMOTION');

    if (idempotencyKey) {
      const existing = await this.prisma.walletTransaction.findUnique({ where: { idempotencyKey } });
      if (existing) {
        return { ok: true, transactionId: existing.id, duplicate: true };
      }
    }

    const firstDate = parseBoostDateUtc(boostDates[0]);
    const lastDate = parseBoostDateUtc(boostDates[boostDates.length - 1]);
    const startsAt = startOfUtcDay(firstDate);
    const endsAt = endOfUtcDay(lastDate);

    const account = await this.ensureAccount(userId);

    try {
      const tx = await this.prisma.$transaction(async (db) => {
        await this.validateBalance(db, account.id, amount);
        const lockedAccount = await this.getAccountWithLock(db, account.id);
        const currentBalance = typeof lockedAccount.balance === 'number'
          ? lockedAccount.balance
          : (lockedAccount.balance?.toNumber ? lockedAccount.balance.toNumber() : Number(lockedAccount.balance || 0));

        const created = await db.walletTransaction.create({
          data: {
            userId,
            accountId: account.id,
            type: 'PROMOTION',
            amount,
            status: 'SUCCESS',
            memo: `Boost purchase: ${boostType.title}`,
            referenceType,
            referenceId,
            metadata: {
              boostTypeId,
              placementKeys: resolvedPlacementKeys,
              boostDates,
              days: dayCount,
              pricingModel: config.pricingModel,
            },
            idempotencyKey,
          } as any,
        });

        const boostPurchases: BoostPurchase[] = [];
        for (const key of resolvedPlacementKeys) {
          const placementCost = costForBoostPlacement(
            configWithPricing,
            dayCount,
            key,
            adPricing,
          );
          const boostPurchase = await db.boostPurchase.create({
            data: {
              userId,
              referenceType,
              referenceId,
              boostTypeId,
              placementKey: key,
              boostDates,
              days: dayCount,
              costBYC: placementCost,
              destinationUrl: normalizedDestinationUrl,
              status: 'ACTIVE',
              startsAt,
              endsAt,
            } as any,
          });
          boostPurchases.push(boostPurchase);
        }

        await db.account.update({
          where: { id: account.id },
          data: { balance: currentBalance - amount },
        });

        return { created, boostPurchases };
      }, {
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
      });

      try {
        const user = await this.prisma.user.findUnique({
          where: { id: userId },
          select: { email: true, profile: { select: { displayName: true } } },
        });
        if (user?.email) {
          this.email.dispatchInBackground({
            eventName: EmailEventName.WalletBoostReceipt,
            recipient: { email: user.email, userId },
            vars: {
              actorName: user.profile?.displayName || user.email,
              amount,
              currency: 'BYC',
              itemTitle: boostType.title,
              purchaseId: tx.boostPurchases[0]?.id,
              purchasedAt: new Date().toISOString(),
            },
          });
        }
      } catch (e) {
        this.logger.warn(`Boost receipt email failed: ${(e as Error).message}`);
      }

      return {
        ok: true,
        transactionId: tx.created.id,
        boostPurchaseId: tx.boostPurchases[0]?.id,
        boostPurchaseIds: tx.boostPurchases.map((b) => b.id),
      };
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      this.logger.error(`Failed to purchase boost for userId=${userId}: ${(error as Error).message}`);
      throw new BadRequestException(`Boost purchase failed: ${(error as Error).message}`);
    }
  }

  /**
   * Purchase promotion for a trade/item
   * Atomic transaction with balance validation and double-spend prevention
   * Includes security checks and applies promotion to trade
   */
  async purchasePromotion(
    userId: string,
    promotionSlug: string,
    referenceType: string,
    referenceId: string,
    idempotencyKey?: string,
    verificationMethod?: 'PIN' | 'BIOMETRIC',
    verificationCredential?: string
  ) {
    const promotion = await this.prisma.promotion.findUnique({ where: { slug: promotionSlug } });
    if (!promotion) throw new NotFoundException('Promotion not found');
    if (!promotion.active) throw new BadRequestException('Promotion is not active');

    const amount = Number(promotion.amountBYC);
    if (amount <= 0) throw new BadRequestException('Invalid promotion amount');

    // Security checks: Verify PIN/biometric if provided
    if (verificationMethod && verificationCredential) {
      await this.security.verifyTransactionAuth(userId, verificationMethod, verificationCredential);
    }

    // Check transaction limits
    await this.security.checkTransactionLimits(userId, amount, 'PROMOTION');

    // Idempotency check
    if (idempotencyKey) {
      const existing = await this.prisma.walletTransaction.findUnique({ where: { idempotencyKey } });
      if (existing) {
        this.logger.log(`Promotion purchase already processed: idempotencyKey=${idempotencyKey}, transactionId=${existing.id}`);
        return { ok: true, transactionId: existing.id, duplicate: true };
      }
    }

    const account = await this.ensureAccount(userId);

    try {
      const tx = await this.prisma.$transaction(async (db) => {
        const lockedAccount = await this.getAccountWithLock(db, account.id);
        const currentBalance = typeof lockedAccount.balance === 'number'
          ? lockedAccount.balance
          : (lockedAccount.balance?.toNumber ? lockedAccount.balance.toNumber() : Number(lockedAccount.balance || 0));

        if (currentBalance < amount) {
          throw new BadRequestException(
            `Insufficient funds. Available: ${currentBalance} BYC, Required: ${amount} BYC`,
          );
        }

        const created = await db.walletTransaction.create({
          data: {
            userId,
            accountId: account.id,
            type: 'PROMOTION',
            amount,
            status: 'SUCCESS',
            memo: `Promotion purchase: ${promotion.title}`,
            referenceType,
            referenceId,
            metadata: { promotionSlug, promotionTitle: promotion.title },
            idempotencyKey,
            promotionId: promotion.id,
          } as any,
        });

        // Apply promotion to trade if referenceType is 'trade'
        if (referenceType === 'trade' && referenceId) {
          try {
            const trade = await db.trade.findUnique({ where: { id: referenceId } });
            if (trade) {
              // Calculate expiration date (e.g., 7 days from now, or use promotion endsAt)
              const expiresAt = promotion.endsAt 
                ? new Date(promotion.endsAt)
                : new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // Default 7 days

              // Update promotion to link to trade
              await db.promotion.update({
                where: { id: promotion.id },
                data: {
                  appliedToTradeId: referenceId,
                  appliedAt: new Date(),
                  activeUntil: expiresAt,
                },
              });

              // Update trade with active promotion
              await db.trade.update({
                where: { id: referenceId },
                data: {
                  activePromotionId: promotion.id,
                  promotionExpiresAt: expiresAt,
                },
              });

              this.logger.log(`Promotion ${promotionSlug} applied to trade ${referenceId}`);
            }
          } catch (error) {
            this.logger.warn(`Failed to apply promotion to trade: ${(error as Error).message}`);
            // Don't fail the transaction if promotion application fails
          }
        }

        // Update balance atomically
        await db.account.update({
          where: { id: account.id },
          data: { balance: currentBalance - amount },
        });

        this.logger.log(`Promotion purchased: ${promotionSlug} for ${userId}, amount=${amount} BYC`);
        return created;
      }, WALLET_DEBIT_TX_OPTIONS);

      // Detect suspicious activity
      try {
        await this.security.detectSuspiciousActivity(
          userId,
          tx.id,
          amount,
          'PROMOTION'
        );
      } catch (error) {
        this.logger.warn(`Suspicious activity detection failed: ${(error as Error).message}`);
      }
      
      try {
        const user = await this.prisma.user.findUnique({
          where: { id: userId },
          select: { email: true, profile: { select: { displayName: true } } },
        });
        if (user?.email) {
          this.email.dispatchInBackground({
            eventName: EmailEventName.WalletPromotionReceipt,
            recipient: { email: user.email, userId },
            vars: {
              actorName: user.profile?.displayName || user.email,
              amount,
              currency: 'BYC',
              itemTitle: promotion.title,
              purchaseId: tx.id,
              purchasedAt: new Date().toISOString(),
            },
          });
        }
      } catch (e) {
        this.logger.warn(`Promotion receipt email failed: ${(e as Error).message}`);
      }

      return { ok: true, transactionId: tx.id };
    } catch (error) {
      this.logger.error(
        `Failed to purchase promotion ${promotionSlug} for userId=${userId}:`,
        error instanceof Error ? error.stack : error,
      );
      throw mapWalletUserError(
        error,
        'We could not complete your promotion payment. Please try again.',
      );
    }
  }

  /**
   * Purchase advertisement
   * Atomic transaction with balance validation and double-spend prevention
   * Includes security checks and transaction limits
   */
  async purchaseAdvert(
    userId: string,
    amount: number,
    advertDetails: { title: string; duration: number; type: string },
    idempotencyKey?: string,
    verificationMethod?: 'PIN' | 'BIOMETRIC',
    verificationCredential?: string
  ) {
    if (amount <= 0) throw new BadRequestException('Amount must be positive');
    
    // Security checks: Verify PIN/biometric if provided
    if (verificationMethod && verificationCredential) {
      await this.security.verifyTransactionAuth(userId, verificationMethod, verificationCredential);
    }

    // Check transaction limits
    await this.security.checkTransactionLimits(userId, amount, 'ADVERT');
    
    // Idempotency check
    if (idempotencyKey) {
      const existing = await this.prisma.walletTransaction.findUnique({ where: { idempotencyKey } });
      if (existing) {
        this.logger.log(`Advert purchase already processed: idempotencyKey=${idempotencyKey}, transactionId=${existing.id}`);
        return { ok: true, transactionId: existing.id, duplicate: true };
      }
    }

    const account = await this.ensureAccount(userId);
    const advertRef = `adv_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;

    try {
      const tx = await this.prisma.$transaction(async (db) => {
        const lockedAccount = await this.getAccountWithLock(db, account.id);
        const currentBalance = typeof lockedAccount.balance === 'number'
          ? lockedAccount.balance
          : (lockedAccount.balance?.toNumber ? lockedAccount.balance.toNumber() : Number(lockedAccount.balance || 0));

        if (currentBalance < amount) {
          throw new BadRequestException(
            `Insufficient funds. Available: ${currentBalance} BYC, Required: ${amount} BYC`,
          );
        }

        const created = await db.walletTransaction.create({
          data: {
            userId,
            accountId: account.id,
            type: 'ADVERT',
            amount,
            status: 'SUCCESS',
            memo: `Advert purchase: ${advertDetails.title}`,
            referenceType: 'advert',
            referenceId: advertRef,
            metadata: advertDetails,
            idempotencyKey,
          } as any,
        });

        await db.account.update({
          where: { id: account.id },
          data: { balance: currentBalance - amount },
        });

        this.logger.log(`Advert purchased: ${advertRef} for ${userId}, amount=${amount} BYC`);
        return created;
      }, WALLET_DEBIT_TX_OPTIONS);

      // Detect suspicious activity
      try {
        await this.security.detectSuspiciousActivity(
          userId,
          tx.id,
          amount,
          'ADVERT'
        );
      } catch (error) {
        this.logger.warn(`Suspicious activity detection failed: ${(error as Error).message}`);
      }
      
      return { ok: true, transactionId: tx.id, advertId: advertRef };
    } catch (error) {
      this.logger.error(
        `Failed to purchase advert for userId=${userId}:`,
        error instanceof Error ? error.stack : error,
      );
      throw mapWalletUserError(
        error,
        'We could not complete your ad payment. Please try again.',
      );
    }
  }

  /**
   * Process donation: Debit from donor and credit to campaign wallet/escrow
   * Creates two immutable ledger entries (debit donor, credit campaign)
   * Atomic transaction with balance validation and double-spend prevention
   * Includes security checks and transaction limits
   */
  async processDonation(
    donorId: string,
    campaignId: string,
    amount: number,
    memo?: string,
    idempotencyKey?: string,
    verificationMethod?: 'PIN' | 'BIOMETRIC',
    verificationCredential?: string
  ) {
    if (amount <= 0) throw new BadRequestException('Donation amount must be positive');

    // Security checks: Verify PIN/biometric if provided
    if (verificationMethod && verificationCredential) {
      await this.security.verifyTransactionAuth(donorId, verificationMethod, verificationCredential);
    }

    // Check transaction limits
    await this.security.checkTransactionLimits(donorId, amount, 'DONATION');

    // Idempotency check
    if (idempotencyKey) {
      const existing = await this.prisma.walletTransaction.findUnique({ 
        where: { idempotencyKey },
      });
      if (existing) {
        this.logger.log(`Donation already processed: idempotencyKey=${idempotencyKey}, transactionId=${existing.id}`);
        return { 
          ok: true, 
          transactionId: existing.id, 
          duplicate: true,
          debitTransactionId: existing.id,
        };
      }
    }

    // Get campaign to verify it exists and get founder ID
    const campaign = await this.prisma.campaign.findUnique({ 
      where: { id: campaignId },
      select: { id: true, founderId: true, title: true },
    });
    if (!campaign) throw new NotFoundException('Campaign not found');

    const donorAccount = await this.ensureAccount(donorId);
    const campaignAccount = await this.ensureAccount(campaign.founderId); // Campaign wallet is founder's wallet

    try {
      const result = await this.prisma.$transaction(async (db) => {
        // Validate donor balance with lock (prevents double-spend)
        await this.validateBalance(db, donorAccount.id, amount);

        // Get locked accounts for atomic balance updates
        const lockedDonor = await this.getAccountWithLock(db, donorAccount.id);
        const lockedCampaign = await this.getAccountWithLock(db, campaignAccount.id);
        
        const donorBalance = typeof lockedDonor.balance === 'number'
          ? lockedDonor.balance
          : (lockedDonor.balance?.toNumber ? lockedDonor.balance.toNumber() : Number(lockedDonor.balance || 0));
        const campaignBalance = typeof lockedCampaign.balance === 'number'
          ? lockedCampaign.balance
          : (lockedCampaign.balance?.toNumber ? lockedCampaign.balance.toNumber() : Number(lockedCampaign.balance || 0));

        // Create debit transaction (donor)
        const debitTx = await db.walletTransaction.create({
          data: {
            userId: donorId,
            accountId: donorAccount.id,
            type: 'DONATION',
            amount,
            status: 'SUCCESS',
            memo: memo || `Donation to ${campaign.title}`,
            idempotencyKey,
            referenceType: 'campaign',
            referenceId: campaignId,
            metadata: { campaignId, campaignTitle: campaign.title },
          } as any,
        });

        // Create credit transaction (campaign wallet)
        const creditTx = await db.walletTransaction.create({
          data: {
            userId: campaign.founderId,
            accountId: campaignAccount.id,
            type: 'RECEIVE',
            amount,
            status: 'SUCCESS',
            memo: `Donation received for ${campaign.title}`,
            referenceType: 'campaign',
            referenceId: campaignId,
            metadata: { 
              campaignId, 
              campaignTitle: campaign.title,
              donorId,
              donationTransactionId: debitTx.id,
            },
          } as any,
        });

        // Update balances atomically
        await db.account.update({
          where: { id: donorAccount.id },
          data: { balance: donorBalance - amount },
        });
        await db.account.update({
          where: { id: campaignAccount.id },
          data: { balance: campaignBalance + amount },
        });

        this.logger.log(`Donation processed: ${amount} BYC from ${donorId} to campaign ${campaignId}`);
        
        return {
          debitTransactionId: debitTx.id,
          creditTransactionId: creditTx.id,
          donorBalance: donorBalance - amount,
          campaignBalance: campaignBalance + amount,
        };
      }, {
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
        timeout: 10000,
      });

      return {
        ok: true,
        transactionId: result.debitTransactionId,
        debitTransactionId: result.debitTransactionId,
        creditTransactionId: result.creditTransactionId,
        donorBalance: result.donorBalance,
        campaignBalance: result.campaignBalance,
      };

      // Detect suspicious activity
      try {
        await this.security.detectSuspiciousActivity(
          donorId,
          result.debitTransactionId,
          amount,
          'DONATION'
        );
      } catch (error) {
        this.logger.warn(`Suspicious activity detection failed: ${(error as Error).message}`);
      }

      return {
        ok: true,
        transactionId: result.debitTransactionId,
        debitTransactionId: result.debitTransactionId,
        creditTransactionId: result.creditTransactionId,
        donorBalance: result.donorBalance,
        campaignBalance: result.campaignBalance,
      };
    } catch (error) {
      if (error instanceof BadRequestException || error instanceof NotFoundException) throw error;
      this.logger.error(`Failed to process donation: donorId=${donorId}, campaignId=${campaignId}, amount=${amount}: ${(error as Error).message}`);
      throw new BadRequestException(`Donation failed: ${(error as Error).message}`);
    }
  }

  // Bank Details Management
  async saveBankDetails(
    userId: string,
    data: {
      bankName: string;
      accountHolderName: string;
      accountNumber: string;
      accountType?: string;
    },
  ) {
    if (!data.bankName?.trim()) throw new BadRequestException('Bank name is required');
    if (!data.accountHolderName?.trim()) throw new BadRequestException('Account holder name is required');
    if (!data.accountNumber?.trim()) throw new BadRequestException('Account number is required');
    if (data.accountNumber.trim().length < 8) throw new BadRequestException('Account number must be at least 8 digits');

    try {
      const existing = await (this.prisma as any).bankDetails.findFirst({
        where: {
          userId,
          accountNumber: data.accountNumber.trim(),
        },
      });

      if (existing) {
        // Update existing
        const updated = await (this.prisma as any).bankDetails.update({
          where: { id: existing.id },
          data: {
            bankName: data.bankName.trim(),
            accountHolderName: data.accountHolderName.trim(),
            accountType: data.accountType || 'Savings',
          },
        });
        return { ok: true, bankDetails: updated };
      } else {
        // Create new
        const created = await (this.prisma as any).bankDetails.create({
          data: {
            userId,
            bankName: data.bankName.trim(),
            accountHolderName: data.accountHolderName.trim(),
            accountNumber: data.accountNumber.trim(),
            accountType: data.accountType || 'Savings',
          },
        });
        return { ok: true, bankDetails: created };
      }
    } catch (error) {
      if ((error as any).code === 'P2002') {
        throw new BadRequestException('This account number is already registered');
      }
      throw error;
    }
  }

  async getBankDetails(userId: string) {
    const bankDetails = await (this.prisma as any).bankDetails.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
    return { ok: true, items: bankDetails };
  }

  async getBankDetailsByAccount(userId: string, accountNumber: string) {
    const bankDetails = await (this.prisma as any).bankDetails.findFirst({
      where: {
        userId,
        accountNumber,
      },
    });
    if (!bankDetails) {
      throw new NotFoundException('Bank details not found');
    }
    return { ok: true, bankDetails };
  }

  async deleteBankDetails(userId: string, id: string) {
    const existing = await (this.prisma as any).bankDetails.findUnique({
      where: { id },
    });
    if (!existing) throw new NotFoundException('Bank details not found');
    if (existing.userId !== userId) {
      throw new BadRequestException('Unauthorized');
    }

    await (this.prisma as any).bankDetails.delete({
      where: { id },
    });
    return { ok: true };
  }

  /**
   * ESCROW METHODS FOR TRADE OFFERS
   * Lock funds when creating a cash offer, transfer on finalization, release on rejection
   */

  /**
   * Lock funds in escrow for a trade offer
   * Moves amount from available balance to locked balance
   */
  async lockFundsForOffer(userId: string, offerId: string, amount: number): Promise<void> {
    this.logger.log(`Locking ${amount} BYC for user ${userId}, offerId ${offerId}`);
    
    const acc = await this.ensureAccount(userId);
    
    await this.prisma.$transaction(async (tx) => {
      // Get account with lock
      const locked = await this.getAccountWithLock(tx, acc.id);
      const currentBalance = typeof locked.balance === 'number' 
        ? locked.balance 
        : (locked.balance?.toNumber ? locked.balance.toNumber() : Number(locked.balance || 0));
      
      // Validate sufficient available balance
      if (currentBalance < amount) {
        throw new BadRequestException(`Insufficient funds. Available: ${currentBalance} BYC, Required: ${amount} BYC`);
      }
      
      // Move funds from balance to lockedBalance
      await tx.account.update({
        where: { id: acc.id },
        data: {
          balance: { decrement: amount },
          lockedBalance: { increment: amount },
        },
      });
      
      // Create transaction record
      await tx.walletTransaction.create({
        data: {
          userId,
          accountId: acc.id,
          type: 'ESCROW_LOCK',
          amount: new Prisma.Decimal(amount),
          memo: `Funds locked for trade offer ${offerId}`,
          metadata: { offerId, action: 'lock' },
        },
      });
    });
    
    this.logger.log(`Successfully locked ${amount} BYC for offerId ${offerId}`);
  }

  /**
   * Transfer locked funds from offerer to trade owner
   * Called when offer is finalized
   */
  async transferLockedFunds(offererId: string, ownerId: string, offerId: string, amount: number): Promise<void> {
    this.logger.log(`Transferring ${amount} BYC from ${offererId} to ${ownerId}, offerId ${offerId}`);
    
    const [offererAcc, ownerAcc] = await Promise.all([
      this.ensureAccount(offererId),
      this.ensureAccount(ownerId),
    ]);
    
    await this.prisma.$transaction(async (tx) => {
      // Validate offerer has locked funds
      const offererLocked = await tx.account.findUnique({ where: { id: offererAcc.id } });
      if (!offererLocked) {
        throw new NotFoundException('Offerer account not found');
      }
      const lockedBalance = typeof offererLocked.lockedBalance === 'number'
        ? offererLocked.lockedBalance
        : (offererLocked.lockedBalance?.toNumber ? offererLocked.lockedBalance.toNumber() : Number(offererLocked.lockedBalance || 0));
      
      if (lockedBalance < amount) {
        throw new BadRequestException(`Insufficient locked funds. Locked: ${lockedBalance} BYC, Required: ${amount} BYC`);
      }
      
      // Deduct from offerer's locked balance
      await tx.account.update({
        where: { id: offererAcc.id },
        data: { lockedBalance: { decrement: amount } },
      });
      
      // Add to owner's available balance
      await tx.account.update({
        where: { id: ownerAcc.id },
        data: { balance: { increment: amount } },
      });
      
      // Create transaction records
      await tx.walletTransaction.createMany({
        data: [
          {
            userId: offererId,
            accountId: offererAcc.id,
            type: 'SEND',
            amount: new Prisma.Decimal(-amount),
            memo: `Payment for trade offer ${offerId}`,
            metadata: { offerId, recipientId: ownerId, action: 'transfer' },
          },
          {
            userId: ownerId,
            accountId: ownerAcc.id,
            type: 'RECEIVE',
            amount: new Prisma.Decimal(amount),
            memo: `Received payment for trade offer ${offerId}`,
            metadata: { offerId, senderId: offererId, action: 'transfer' },
          },
        ],
      });
    });
    
    this.logger.log(`Successfully transferred ${amount} BYC for offerId ${offerId}`);
  }

  /**
   * Release locked funds back to offerer
   * Called when offer is rejected or withdrawn
   */
  async releaseLockedFunds(userId: string, offerId: string, amount: number): Promise<void> {
    this.logger.log(`Releasing ${amount} BYC for user ${userId}, offerId ${offerId}`);
    
    const acc = await this.ensureAccount(userId);
    
    await this.prisma.$transaction(async (tx) => {
      // Validate locked funds exist
      const account = await tx.account.findUnique({ where: { id: acc.id } });
      if (!account) {
        throw new NotFoundException('Account not found');
      }
      const lockedBalance = typeof account.lockedBalance === 'number'
        ? account.lockedBalance
        : (account.lockedBalance?.toNumber ? account.lockedBalance.toNumber() : Number(account.lockedBalance || 0));
      
      if (lockedBalance < amount) {
        // Log warning but don't throw - funds may have already been released
        this.logger.warn(`Attempting to release ${amount} BYC but only ${lockedBalance} BYC locked for offerId ${offerId}`);
        // Release whatever is locked
        const releaseAmount = Math.min(amount, lockedBalance);
        if (releaseAmount > 0) {
          await tx.account.update({
            where: { id: acc.id },
            data: {
              balance: { increment: releaseAmount },
              lockedBalance: { decrement: releaseAmount },
            },
          });
          
          await tx.walletTransaction.create({
            data: {
              userId,
              accountId: acc.id,
              type: 'ESCROW_RELEASE',
              amount: new Prisma.Decimal(releaseAmount),
              memo: `Funds released from trade offer ${offerId}`,
              metadata: { offerId, action: 'release' },
            },
          });
        }
        return;
      }
      
      // Move funds from lockedBalance back to balance
      await tx.account.update({
        where: { id: acc.id },
        data: {
          balance: { increment: amount },
          lockedBalance: { decrement: amount },
        },
      });
      
      // Create transaction record
      await tx.walletTransaction.create({
        data: {
          userId,
          accountId: acc.id,
          type: 'ESCROW_RELEASE',
          amount: new Prisma.Decimal(amount),
          memo: `Funds released from trade offer ${offerId}`,
          metadata: { offerId, action: 'release' },
        },
      });
    });
    
    this.logger.log(`Successfully released ${amount} BYC for offerId ${offerId}`);
  }

  /**
   * Get available balance (excluding locked funds)
   */
  async getAvailableBalance(userId: string): Promise<number> {
    const acc = await this.ensureAccount(userId);
    const balance = typeof acc.balance === 'number'
      ? acc.balance
      : (acc.balance?.toNumber ? acc.balance.toNumber() : Number(acc.balance || 0));
    return balance;
  }

  /**
   * Get locked balance
   */
  async getLockedBalance(userId: string): Promise<number> {
    const acc = await this.ensureAccount(userId);
    const lockedBalance = typeof acc.lockedBalance === 'number'
      ? acc.lockedBalance
      : (acc.lockedBalance?.toNumber ? acc.lockedBalance.toNumber() : Number(acc.lockedBalance || 0));
    return lockedBalance;
  }

  /** BYC transaction receipt (send, receive, fund, donation, etc.). */
  async generateTransactionReceiptPdf(userId: string, transactionId: string) {
    const tx = await this.prisma.walletTransaction.findUnique({
      where: { id: transactionId },
      include: {
        transfer: {
          include: {
            sender: {
              select: {
                email: true,
                profile: { select: { displayName: true } },
              },
            },
            recipient: {
              select: {
                email: true,
                profile: { select: { displayName: true } },
              },
            },
          },
        },
        user: {
          select: {
            email: true,
            profile: { select: { displayName: true } },
          },
        },
      },
    });
    if (!tx || tx.userId !== userId) {
      throw new NotFoundException('Transaction not found');
    }

    const accountLabel =
      tx.user.profile?.displayName || tx.user.email || 'Account holder';
    const receiptTitle = this.transactionReceiptTitle(tx.type);
    const direction =
      tx.type === 'SEND' || tx.type === 'WITHDRAWAL' || tx.type === 'DONATION'
        ? 'Outgoing'
        : tx.type === 'RECEIVE' ||
            tx.type === 'FUND' ||
            tx.type === 'REFUND' ||
            tx.type === 'BONUS' ||
            tx.type === 'CASHBACK' ||
            tx.type === 'REFERRAL_BONUS'
          ? 'Incoming'
          : 'Neutral';
    let counterparty: string | undefined;
    if (tx.transfer) {
      const other =
        tx.type === 'SEND' ? tx.transfer.recipient : tx.transfer.sender;
      counterparty = this.userDisplayLabel(other);
    }

    const amountDirection =
      direction === 'Outgoing' ? 'out' : direction === 'Incoming' ? 'in' : 'neutral';

    const parties: { label: string; name: string }[] = [
      { label: 'Account holder', name: accountLabel },
    ];
    if (counterparty) {
      parties.push({
        label: tx.type === 'SEND' ? 'Sent to' : 'Received from',
        name: counterparty,
      });
    }

    const details: { label: string; value: string; monospace?: boolean }[] = [
      { label: 'Transaction type', value: this.formatTransactionTypeLabel(tx.type) },
      { label: 'Direction', value: direction },
      { label: 'Receipt ID', value: tx.id, monospace: true },
    ];
    if (tx.transfer?.id) {
      details.push({ label: 'Transfer ID', value: tx.transfer.id, monospace: true });
    }
    if (tx.memo) {
      details.push({ label: 'Memo', value: tx.memo });
    }
    if (tx.referenceType) {
      details.push({ label: 'Reference type', value: tx.referenceType });
    }
    if (tx.referenceId) {
      details.push({ label: 'Reference ID', value: tx.referenceId, monospace: true });
    }

    const sections: { title: string; rows: { label: string; value: string }[] }[] = [];
    if (tx.verificationMethod) {
      const verifyRows: { label: string; value: string }[] = [
        { label: 'Method', value: tx.verificationMethod },
      ];
      if (tx.verifiedAt) {
        verifyRows.push({ label: 'Verified at', value: formatDate(tx.verifiedAt) });
      }
      sections.push({ title: 'Verification', rows: verifyRows });
    }

    return renderReceiptDocument(
      {
        title: receiptTitle,
        subtitle: this.transactionReceiptSubtitle(tx.type),
        receiptId: tx.id,
        issuedAt: tx.createdAt,
        status: tx.status,
        amount: {
          value: tx.amount.toString(),
          currency: 'BYC',
          direction: amountDirection,
        },
        parties,
        details,
        sections: sections.length ? sections : undefined,
      },
      `bybata-transaction-${tx.id}.pdf`,
    );
  }

  private formatTransactionTypeLabel(type: string): string {
    return type.replace(/_/g, ' ');
  }

  private transactionReceiptSubtitle(type: string): string {
    switch (type) {
      case 'SEND':
        return 'BYC sent successfully';
      case 'RECEIVE':
        return 'BYC received in your wallet';
      case 'FUND':
        return 'Wallet balance funded';
      case 'DONATION':
        return 'Campaign donation payment';
      case 'WITHDRAWAL':
        return 'Withdrawal from your wallet';
      case 'REFUND':
        return 'Funds returned to your wallet';
      case 'BONUS':
        return 'Bonus credited to your wallet';
      case 'CASHBACK':
        return 'Cashback credited to your wallet';
      case 'REFERRAL_BONUS':
        return 'Referral bonus credited';
      default:
        return 'Wallet transaction record';
    }
  }

  private transactionReceiptTitle(type: string): string {
    switch (type) {
      case 'SEND':
        return 'BYC Sent Receipt';
      case 'RECEIVE':
        return 'BYC Received Receipt';
      case 'FUND':
        return 'Wallet Funding Receipt';
      case 'DONATION':
        return 'Donation Payment Receipt';
      case 'WITHDRAWAL':
        return 'Withdrawal Receipt';
      case 'REFUND':
        return 'Refund Receipt';
      case 'BONUS':
        return 'Bonus Credit Receipt';
      case 'CASHBACK':
        return 'Cashback Receipt';
      case 'REFERRAL_BONUS':
        return 'Referral Bonus Receipt';
      default:
        return 'BYC Transaction Receipt';
    }
  }

  private userDisplayLabel(user: {
    email: string | null;
    profile: { displayName: string | null } | null;
  }): string {
    return user.profile?.displayName || user.email || 'User';
  }
}

