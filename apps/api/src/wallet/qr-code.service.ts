import { Injectable, Logger } from '@nestjs/common';
import * as crypto from 'crypto';
import { PrismaService } from '../common/prisma.service';

export interface QRCodeData {
  userId: string;
  amount?: number;
  memo?: string;
  expiresAt: Date;
}

@Injectable()
export class QRCodeService {
  private readonly logger = new Logger(QRCodeService.name);
  // No expiration - QR codes are unique per user and remain valid indefinitely
  private readonly QR_EXPIRY_MS = 100 * 365 * 24 * 60 * 60 * 1000; // ~100 years (effectively never)

  constructor(private prisma: PrismaService) {}

  /**
   * Generate QR code data for receiving BYC transfers.
   * QR codes do not expire - they are stable identifiers for a user's receive address.
   */
  async generateReceiveQR(
    userId: string,
    amount?: number,
    memo?: string
  ): Promise<{ qrCode: string; expiresAt: Date }> {
    const encryptionKey = process.env.CONFIG_ENCRYPTION_KEY;
    if (!encryptionKey || encryptionKey.length < 32) {
      throw new Error('CONFIG_ENCRYPTION_KEY must be set (32+ hex chars) for QR generation');
    }

    const reference = this.buildReceiveReference(userId, amount, memo);
    const existing = await (this.prisma as any).webhookEvent.findUnique({
      where: { gateway_reference: { gateway: 'qr', reference } },
    });

    if (existing?.rawPayload) {
      const stored = existing.rawPayload as QRCodeData;
      if (
        stored.userId === userId &&
        (stored.amount ?? undefined) === (amount ?? undefined) &&
        (stored.memo ?? undefined) === (memo ?? undefined)
      ) {
        const expiresAt = this.parseStoredDate(stored.expiresAt);
        const qrCode = this.signReceivePayload(
          encryptionKey,
          reference,
          userId,
          amount,
          memo,
          expiresAt,
        );
        this.logger.log(`Reused stable QR for user ${userId}, reference: ${reference}`);
        return { qrCode, expiresAt };
      }
    }

    const expiresAt = new Date(Date.now() + this.QR_EXPIRY_MS);
    const data: QRCodeData = { userId, amount, memo, expiresAt };
    const qrCode = this.signReceivePayload(
      encryptionKey,
      reference,
      userId,
      amount,
      memo,
      expiresAt,
    );

    try {
      await (this.prisma as any).webhookEvent.upsert({
        where: { gateway_reference: { gateway: 'qr', reference } },
        create: {
          gateway: 'qr',
          reference,
          rawPayload: data,
          verified: false,
          processed: false,
        },
        update: { rawPayload: data },
      });
    } catch (error) {
      this.logger.warn(`Failed to store QR reference: ${(error as Error).message}`);
    }

    this.logger.log(`Generated stable QR for user ${userId}, reference: ${reference}`);
    return { qrCode, expiresAt };
  }

  /** One stable reference per user (default) or per amount/memo variant. */
  private buildReceiveReference(userId: string, amount?: number, memo?: string): string {
    if (!amount && !memo) {
      return `qr_receive_${userId}`;
    }
    const hash = crypto
      .createHash('sha256')
      .update(`${userId}|${amount ?? ''}|${memo ?? ''}`)
      .digest('hex')
      .slice(0, 16);
    return `qr_receive_${userId}_${hash}`;
  }

  private parseStoredDate(value: Date | string): Date {
    return value instanceof Date ? value : new Date(value);
  }

  private signReceivePayload(
    encryptionKey: string,
    reference: string,
    userId: string,
    amount: number | undefined,
    memo: string | undefined,
    expiresAt: Date,
  ): string {
    const payload: Record<string, unknown> = {
      id: reference,
      uid: userId,
      amount: amount || null,
      note: memo || null,
      exp: expiresAt.getTime(),
    };
    const canonicalPayload = this.canonicalJson(payload);
    const signature = crypto
      .createHmac('sha256', Buffer.from(encryptionKey, 'hex'))
      .update(canonicalPayload)
      .digest('hex');
    const signedPayload = { ...payload, s: signature };
    return Buffer.from(JSON.stringify(signedPayload)).toString('base64');
  }

  /**
   * Validate and parse QR code
   */
  async validateQR(qrCode: string): Promise<{
    userId: string;
    amount?: number;
    memo?: string;
    valid: boolean;
  }> {
    try {
      const encryptionKey = process.env.CONFIG_ENCRYPTION_KEY;
      if (!encryptionKey || encryptionKey.length < 32) {
        return { userId: '', valid: false };
      }

      const json = Buffer.from(qrCode, 'base64').toString('utf8');
      const data = JSON.parse(json);
      
      // Verify signature (use canonical JSON to match generation)
      const signature = data.s;
      delete data.s;
      const canonicalData = this.canonicalJson(data);
      const expected = crypto
        .createHmac('sha256', Buffer.from(encryptionKey, 'hex'))
        .update(canonicalData)
        .digest('hex');

      if (signature !== expected) {
        return { userId: '', valid: false };
      }

      // Expiration check - QR codes effectively never expire (exp is set ~100 years out)
      if (data.exp && data.exp < Date.now()) {
        return { userId: '', valid: false };
      }

      // Verify reference exists (do NOT check processed - QR can be scanned multiple times by different senders)
      const found = await (this.prisma as any).webhookEvent.findUnique({
        where: { gateway_reference: { gateway: 'qr', reference: data.id } },
      });

      if (!found) {
        return { userId: '', valid: false };
      }

      // Do NOT mark as processed - receiving QR codes are reusable; multiple people can scan to send

      return {
        userId: data.uid,
        amount: data.amount || undefined,
        memo: data.note || undefined,
        valid: true,
      };
    } catch (error) {
      this.logger.warn(`QR code validation failed: ${(error as Error).message}`);
      return { userId: '', valid: false };
    }
  }

  /** Canonical JSON stringify (sorted keys) for consistent signature verification */
  private canonicalJson(obj: Record<string, unknown>): string {
    const sorted = Object.keys(obj).sort().reduce<Record<string, unknown>>((acc, k) => {
      acc[k] = obj[k];
      return acc;
    }, {});
    return JSON.stringify(sorted);
  }

  /**
   * Get BYC address for user (for QR code display)
   */
  async getAddress(userId: string): Promise<string> {
    // Derive a stable BYC address from userId
    const addr = `BYC-${userId.substring(0, 8)}-${userId.substring(userId.length - 4)}`;
    return addr;
  }
}

