import { BadRequestException, Body, Controller, Get, Patch, Post, Query, Param, UseGuards, StreamableFile } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AdStatus } from '@prisma/client';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { WalletService } from './wallet.service';
import { PaymentsService } from '../payments/payments.service';
import { WalletSecurityService } from './wallet-security.service';
import { QRCodeService } from './qr-code.service';
import { AdSchedulingService } from './ad-scheduling.service';
import { PrismaService } from '../common/prisma.service';

@Controller('v1')
@UseGuards(JwtAuthGuard)
export class WalletController {
  constructor(
    private wallet: WalletService,
    private payments: PaymentsService,
    private security: WalletSecurityService,
    private qrCode: QRCodeService,
    private adScheduling: AdSchedulingService,
    private prisma: PrismaService,
  ) {}

  @Get('wallet')
  async getWallet(@CurrentUser() user: any) {
    return this.wallet.getWallet(user.sub);
  }

  // New alias for roadmap: GET /v1/wallet/balance
  @Get('wallet/balance')
  async getBalance(@CurrentUser() user: any) {
    return this.wallet.getBalance(user.sub);
  }

  @Get('wallet/transactions')
  async transactions(
    @CurrentUser() user: any,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
    @Query('type') type?: string,
    @Query('status') status?: string,
    @Query('referenceType') referenceType?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    return this.wallet.listTransactions(user.sub, page, size, { type, status, referenceType, from, to });
  }

  @Get('wallet/transactions/:transactionId/receipt.pdf')
  async transactionReceiptPdf(
    @CurrentUser() user: any,
    @Param('transactionId') transactionId: string,
  ) {
    const { buffer, filename } = await this.wallet.generateTransactionReceiptPdf(
      user.sub,
      transactionId,
    );
    return new StreamableFile(buffer, {
      type: 'application/pdf',
      disposition: `attachment; filename="${filename}"`,
    });
  }

  @Get('wallet/address')
  async getAddress(@CurrentUser() user: any) {
    return this.wallet.getAddress(user.sub);
  }

  @Post('wallet/qr/create')
  async createReceiveQr(
    @CurrentUser() user: any,
    @Body() body: { amount?: number; note?: string },
  ) {
    const addr = await this.wallet.getAddress(user.sub);
    const amount = Number(body?.amount ?? 0);
    const note = body?.note ? String(body.note) : undefined;
    const uuid = `qr_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const payload = {
      t: 'byc_qr',
      uid: user.sub,
      address: addr.address,
      amount: amount > 0 ? amount : undefined,
      note,
      id: uuid,
    };
    const key = process.env.CONFIG_ENCRYPTION_KEY;
    if (!key || key.length < 32) return { ok: false, error: 'Server config missing' };
    const sig = require('crypto').createHmac('sha256', Buffer.from(key, 'hex')).update(JSON.stringify(payload)).digest('hex');
    await this.prisma.webhookEvent.create({ data: { gateway: 'qr', reference: uuid, rawPayload: payload, verified: true, processed: false } });
    const uri = `bybata://app/trade?qr=${encodeURIComponent(Buffer.from(JSON.stringify({ ...payload, s: sig })).toString('base64'))}`;
    return { ok: true, uri, payload: { ...payload, s: sig } };
  }

  @Post('wallet/qr/validate')
  async validateQr(
    @CurrentUser() user: any,
    @Body() body: { code?: string; qrCode?: string },
  ) {
    const raw = String(body.code ?? body.qrCode ?? '').trim();
    if (!raw) return { ok: false, error: 'QR code is required' };

    // Prefer the same validator used by /wallet/qr/generate + /wallet/qr/scan.
    const result = await this.qrCode.validateQR(raw);
    if (!result.valid || !result.userId) {
      return { ok: false, error: 'Invalid or expired QR code' };
    }
    if (result.userId === user.sub) {
      return { ok: false, error: 'This is your own receive QR. Ask the recipient to share theirs.' };
    }

    const recipient = await this.prisma.user.findUnique({
      where: { id: result.userId },
      select: {
        id: true,
        email: true,
        profile: { select: { displayName: true, avatarKey: true } },
      },
    });
    if (!recipient) {
      return { ok: false, error: 'Recipient not found' };
    }

    return {
      ok: true,
      recipient: {
        userId: recipient.id,
        email: recipient.email,
        displayName: recipient.profile?.displayName,
        avatarKey: recipient.profile?.avatarKey,
      },
      amount: result.amount,
      note: result.memo,
      memo: result.memo,
    };
  }

  @Post('wallet/fund')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async fund(
    @CurrentUser() user: any,
    @Body() body: { amount: number; memo?: string; idempotencyKey?: string },
  ) {
    return this.wallet.fund(user.sub, Number(body.amount), body.memo, body.idempotencyKey);
  }

  @Post('wallet/send')
  @Throttle({ default: { limit: 30, ttl: 60000 } })
  async send(
    @CurrentUser() user: any,
    @Body() body: {
      toUserId?: string;
      toEmail?: string;
      amount: number;
      memo?: string;
      idempotencyKey?: string;
      verificationMethod?: 'PIN' | 'BIOMETRIC';
      verificationCredential?: string;
    },
  ) {
    let toUserId = body.toUserId;
    if (!toUserId && body.toEmail) {
      const found = await (this.wallet as any).prisma.user.findUnique({ where: { email: body.toEmail } });
      if (!found) throw new Error('Recipient not found');
      toUserId = found.id;
    }
    return this.wallet.send(
      user.sub,
      String(toUserId),
      Number(body.amount),
      body.memo,
      body.idempotencyKey,
      body.verificationMethod,
      body.verificationCredential
    );
  }

  @Get('wallet/withdrawals')
  async listWithdrawals(
    @CurrentUser() user: any,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    return this.wallet.listWithdrawals(user.sub, page, size);
  }

  @Post('wallet/withdrawals/request')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async requestWithdrawal(
    @CurrentUser() user: any,
    @Body() body: {
      amount: number;
      currency?: string;
      memo?: string;
      destination?: Record<string, any>;
      idempotencyKey?: string;
      verificationMethod?: 'PIN' | 'BIOMETRIC';
      verificationCredential?: string;
    },
  ) {
    return this.wallet.requestWithdrawal(user.sub, Number(body.amount), {
      currency: body.currency,
      memo: body.memo,
      destination: body.destination,
      idempotencyKey: body.idempotencyKey,
      verificationMethod: body.verificationMethod,
      verificationCredential: body.verificationCredential,
    });
  }

  @Post('wallet/withdrawals/:id/cancel')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async cancelWithdrawal(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() body: { reason?: string },
  ) {
    return this.wallet.cancelWithdrawal(user.sub, id, body?.reason);
  }

  // Roadmap-aligned BYC transfer route alias
  @Post('wallet/transfer')
  @Throttle({ default: { limit: 30, ttl: 60000 } })
  async transfer(
    @CurrentUser() user: any,
    @Body() body: {
      toUserId?: string;
      toEmail?: string;
      amountByc: number;
      memo?: string;
      idempotencyKey?: string;
      verificationMethod?: 'PIN' | 'BIOMETRIC';
      verificationCredential?: string;
    },
  ) {
    let toUserId = body.toUserId;
    const emailOrUsername = (body.toEmail ?? '').trim();
    if (!toUserId && emailOrUsername) {
      // Support both email and username lookup
      const normalized = emailOrUsername.toLowerCase().replace(/^@/, '');
      const isEmail = normalized.includes('@');
      const found = isEmail
        ? await this.prisma.user.findUnique({ where: { email: emailOrUsername } })
        : await this.prisma.user.findFirst({
            where: { profile: { username: { equals: normalized, mode: 'insensitive' } } },
          });
      if (!found) {
        throw new BadRequestException('Recipient not found. Check the email or username and try again.');
      }
      toUserId = found.id;
    }
    if (!toUserId) {
      throw new BadRequestException('Recipient is required. Enter email or username.');
    }
    return this.wallet.send(
      user.sub,
      String(toUserId),
      Number(body.amountByc),
      body.memo,
      body.idempotencyKey,
      body.verificationMethod,
      body.verificationCredential
    );
  }

  // Wallet Security Endpoints

  @Post('wallet/security/pin/set')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  async setPin(@CurrentUser() user: any, @Body() body: { pin: string }) {
    await this.security.setPin(user.sub, body.pin);
    return { ok: true, message: 'PIN set successfully' };
  }

  @Post('wallet/security/pin/verify')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async verifyPin(@CurrentUser() user: any, @Body() body: { pin: string }) {
    const isValid = await this.security.verifyPin(user.sub, body.pin);
    if (isValid) {
      await this.security.updateWalletActivity(user.sub);
    }
    return { ok: isValid, message: isValid ? 'PIN verified' : 'Invalid PIN' };
  }

  @Post('wallet/security/biometric/token')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async generateBiometricToken(@CurrentUser() user: any) {
    const token = await this.security.generateBiometricToken(user.sub);
    return { ok: true, token, expiresIn: 300 }; // 5 minutes
  }

  @Post('wallet/security/lock')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  async lockWallet(@CurrentUser() user: any, @Body() body: { reason?: string }) {
    await this.security.lockWallet(user.sub, body.reason || 'User requested', user.sub);
    return { ok: true, message: 'Wallet locked' };
  }

  @Post('wallet/security/unlock')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  async unlockWallet(@CurrentUser() user: any, @Body() body: { unlockToken?: string }) {
    await this.security.unlockWallet(user.sub, body.unlockToken);
    return { ok: true, message: 'Wallet unlocked' };
  }

  @Post('wallet/security/pin/reset/request')
  @Throttle({ default: { limit: 3, ttl: 60000 } })
  async requestPinResetOtp(@CurrentUser() user: any) {
    const result = await this.security.requestPinResetOtp(user.sub);
    return result;
  }

  @Post('wallet/security/pin/reset/confirm')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  async confirmPinResetWithOtp(
    @CurrentUser() user: any,
    @Body() body: { token: string; newPin: string },
  ) {
    await this.security.confirmPinResetWithOtp(user.sub, body.token, body.newPin);
    return { ok: true, message: 'PIN reset successfully' };
  }

  @Get('wallet/security/status')
  async getSecurityStatus(@CurrentUser() user: any) {
    const [isLocked, limits, sessionTimeout, pinSet] = await Promise.all([
      this.security.isWalletLocked(user.sub),
      this.security.getTransactionLimits(user.sub),
      this.security.checkSessionTimeout(user.sub),
      this.security.isPinSet(user.sub),
    ]);

    return {
      ok: true,
      walletLocked: isLocked,
      sessionExpired: pinSet ? sessionTimeout : false,
      pinSet,
      hasPin: pinSet, // Alias for client compatibility
      // Wallet security is optional — only PIN users must re-auth for send/withdraw
      transactionAuthRequired: pinSet,
      limits,
    };
  }

  // QR Code Endpoints

  @Post('wallet/qr/generate')
  @Throttle({ default: { limit: 20, ttl: 60000 } })
  async generateQR(
    @CurrentUser() user: any,
    @Body() body: { amount?: number; memo?: string }
  ) {
    try {
      const result = await this.qrCode.generateReceiveQR(user.sub, body.amount, body.memo);
      const address = await this.qrCode.getAddress(user.sub);
      return {
        ok: true,
        qrCode: result.qrCode,
        address,
        expiresAt: result.expiresAt,
      };
    } catch (e) {
      const msg = (e as Error)?.message || 'Failed to generate QR';
      throw new BadRequestException(msg);
    }
  }

  @Post('wallet/qr/scan')
  @Throttle({ default: { limit: 20, ttl: 60000 } })
  async scanQR(@CurrentUser() user: any, @Body() body: { qrCode: string }) {
    const result = await this.qrCode.validateQR(body.qrCode);
    if (!result.valid || !result.userId) {
      return { ok: false, error: 'Invalid or expired QR code' };
    }
    if (result.userId === user.sub) {
      return { ok: false, error: 'This is your own receive QR. Ask the recipient to share theirs.' };
    }

    const recipient = await this.prisma.user.findUnique({
      where: { id: result.userId },
      select: {
        id: true,
        email: true,
        profile: { select: { displayName: true, avatarKey: true } },
      },
    });
    if (!recipient) {
      return { ok: false, error: 'Recipient not found' };
    }

    return {
      ok: true,
      recipient: {
        userId: recipient.id,
        email: recipient.email,
        displayName: recipient.profile?.displayName,
        avatarKey: recipient.profile?.avatarKey,
      },
      amount: result.amount,
      memo: result.memo,
      note: result.memo,
    };
  }

  // Create Paystack funding intent (NGN, GHS, KES, ZAR)
  @Post('wallet/fund/paystack/create')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async createPaystackFunding(
    @CurrentUser() user: any,
    @Body() body: { amount: number; currency?: string; amountNgn?: number; returnUrl?: string; amountByc?: number },
  ) {
    const amount = Number(body?.amount ?? body?.amountNgn ?? 0);
    const currency = String(body?.currency ?? 'NGN').toUpperCase();
    const amountByc = body?.amountByc != null && body.amountByc > 0 ? Number(body.amountByc) : undefined;
    if (!Number.isFinite(amount) || amount <= 0) {
      return { ok: false, error: 'Invalid amount. Provide a positive amount.' };
    }
    return this.payments.createPaystackInit(user.sub, amount, currency, body?.returnUrl, amountByc);
  }

  // Create Stripe funding intent (USD)
  // Supports both PaymentIntent (client-side) and Checkout Session (hosted) flows
  @Post('wallet/fund/stripe/create')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async createStripeFunding(
    @CurrentUser() user: any,
    @Body() body: { amountUsd: number; returnUrl?: string; usePaymentIntent?: boolean; amountByc?: number },
  ) {
    const amount = Number(body?.amountUsd ?? 0);
    const amountByc = body?.amountByc != null && body.amountByc > 0 ? Number(body.amountByc) : undefined;
    if (!Number.isFinite(amount) || amount <= 0) {
      return { ok: false, error: 'Invalid amountUsd. Provide a positive USD amount.' };
    }
    const usePaymentIntent = body?.usePaymentIntent === true;
    return this.payments.createStripeInit(user.sub, amount, body?.returnUrl, usePaymentIntent, amountByc);
  }

  // Create PayPal funding intent (USD)
  @Post('wallet/fund/paypal/create')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async createPayPalFunding(
    @CurrentUser() user: any,
    @Body() body: { amountUsd: number; returnUrl?: string; amountByc?: number },
  ) {
    const amount = Number(body?.amountUsd ?? 0);
    const amountByc = body?.amountByc != null && body.amountByc > 0 ? Number(body.amountByc) : undefined;
    if (!Number.isFinite(amount) || amount <= 0) {
      return { ok: false, error: 'Invalid amountUsd. Provide a positive USD amount.' };
    }
    return this.payments.createPayPalInit(user.sub, amount, body?.returnUrl, amountByc);
  }

  // Create Flutterwave funding intent (NGN or USD)
  @Post('wallet/fund/flutterwave/create')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async createFlutterwaveFunding(
    @CurrentUser() user: any,
    @Body() body: { amount: number; currency: string; returnUrl?: string; amountByc?: number },
  ) {
    const amount = Number(body?.amount ?? 0);
    const currency = String(body?.currency ?? 'NGN').toUpperCase();
    const amountByc = body?.amountByc != null && body.amountByc > 0 ? Number(body.amountByc) : undefined;
    if (!Number.isFinite(amount) || amount <= 0) {
      return { ok: false, error: 'Invalid amount. Provide a positive amount.' };
    }
    const flutterwaveCurrencies = ['NGN', 'GHS', 'KES', 'ZAR', 'USD'];
    if (!flutterwaveCurrencies.includes(currency)) {
      return { ok: false, error: `Unsupported currency for Flutterwave. Use: ${flutterwaveCurrencies.join(', ')}` };
    }
    return (this.payments as any).createFlutterwaveInit?.(user.sub, amount, currency, body?.returnUrl, amountByc) ?? {
      ok: true,
      provider: 'flutterwave',
      amount,
      currency,
      checkoutUrl: `https://flutterwave.com/pay/${Date.now()}`,
      returnUrl: body?.returnUrl || process.env.APP_PUBLIC_URL || 'https://example.com',
      meta: { userId: user.sub },
    };
  }

  // Paystack return/callback endpoint to verify transaction by provider reference
  // Moved to public Payments CallbacksController (no auth required)

  @Get('wallet/conversion-rates')
  async legacyRates() {
    return this.wallet.listRates();
  }

  // New alias for roadmap: GET /v1/wallet/rates
  @Get('wallet/rates')
  async currentRates() {
    return this.wallet.listActiveRates();
  }

  @Get('wallet/promotions')
  async promotions() {
    return this.wallet.listPromotions();
  }

  @Get('wallet/boost-config')
  async boostConfig() {
    return this.wallet.getBoostConfig();
  }

  @Post('wallet/promotions/purchase')
  async purchasePromotion(
    @CurrentUser() user: any,
    @Body() body: {
      promotionSlug: string;
      referenceType: string;
      referenceId: string;
      idempotencyKey?: string;
      verificationMethod?: 'PIN' | 'BIOMETRIC';
      verificationCredential?: string;
    },
  ) {
    return this.wallet.purchasePromotion(
      user.sub,
      body.promotionSlug,
      body.referenceType,
      body.referenceId,
      body.idempotencyKey,
      body.verificationMethod,
      body.verificationCredential
    );
  }

  @Post('wallet/boosts/purchase')
  async purchaseBoost(
    @CurrentUser() user: any,
    @Body() body: {
      referenceType: string;
      referenceId: string;
      boostTypeId: string;
      days?: number;
      boostDates?: string[];
      placementKey?: string;
      placementKeys?: string[];
      destinationUrl?: string;
      idempotencyKey?: string;
      verificationMethod?: 'PIN' | 'BIOMETRIC';
      verificationCredential?: string;
    },
  ) {
    return this.wallet.purchaseBoostFromConfig(
      user.sub,
      body.referenceType,
      body.referenceId,
      body.boostTypeId,
      body.days != null ? Number(body.days) : undefined,
      body.placementKey,
      body.destinationUrl,
      body.idempotencyKey,
      body.verificationMethod,
      body.verificationCredential,
      body.boostDates,
      body.placementKeys,
    );
  }

  @Post('wallet/adverts/purchase')
  async purchaseAdvert(
    @CurrentUser() user: any,
    @Body() body: {
      amount: number;
      title: string;
      duration: number;
      type: string;
      idempotencyKey?: string;
      verificationMethod?: 'PIN' | 'BIOMETRIC';
      verificationCredential?: string;
    },
  ) {
    return this.wallet.purchaseAdvert(
      user.sub,
      Number(body.amount),
      { title: body.title, duration: body.duration, type: body.type },
      body.idempotencyKey,
      body.verificationMethod,
      body.verificationCredential
    );
  }

  // Ad Scheduling Endpoints (Days 8-9)

  @Post('wallet/ads/schedule')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async scheduleAd(
    @CurrentUser() user: any,
    @Body() body: {
      title: string;
      description?: string;
      mediaType?: 'IMAGE' | 'VIDEO';
      mediaKeys?: string[];
      videoKey?: string;
      placementKey?: string;
      placementKeys?: string[];
      scheduledStart: string;
      scheduledEnd?: string;
      amount: number;
      budgetPerPlacement?: number;
      destinationUrl: string;
      idempotencyKey?: string;
    }
  ) {
    return this.adScheduling.scheduleAd(
      user.sub,
      {
        title: body.title,
        description: body.description,
        mediaType: body.mediaType as any,
        mediaKeys: body.mediaKeys,
        videoKey: body.videoKey,
        placementKey: body.placementKey,
        placementKeys: body.placementKeys,
        destinationUrl: body.destinationUrl,
        scheduledStart: new Date(body.scheduledStart),
        scheduledEnd: body.scheduledEnd ? new Date(body.scheduledEnd) : undefined,
        amount: Number(body.amount),
        budgetPerPlacement:
          body.budgetPerPlacement != null
            ? Number(body.budgetPerPlacement)
            : undefined,
      },
      body.idempotencyKey
    );
  }

  @Get('wallet/ads/scheduled')
  async getScheduledAds(
    @CurrentUser() user: any,
    @Query('status') status?: string
  ) {
    return this.adScheduling.getScheduledAds(user.sub, status);
  }

  @Patch('wallet/ads/:id')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async updateAd(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body()
    body: {
      title?: string;
      description?: string;
      mediaType?: 'IMAGE' | 'VIDEO';
      mediaKeys?: string[];
      videoKey?: string;
      placementKeys?: string[];
      scheduledStart?: string;
      scheduledEnd?: string;
      destinationUrl?: string;
    },
  ) {
    return this.adScheduling.updateAdSchedule(id, {
      title: body.title,
      description: body.description,
      mediaType: body.mediaType as any,
      mediaKeys: body.mediaKeys,
      videoKey: body.videoKey,
      placementKeys: body.placementKeys,
      destinationUrl: body.destinationUrl,
      scheduledStart: body.scheduledStart
        ? new Date(body.scheduledStart)
        : undefined,
      scheduledEnd: body.scheduledEnd
        ? new Date(body.scheduledEnd)
        : undefined,
    }, { userId: user.sub });
  }

  @Post('wallet/ads/:id/status')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async updateAdStatus(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() body: { status: AdStatus }
  ) {
    await this.adScheduling.updateAdStatus(user.sub, id, body.status);
    return { ok: true, message: 'Ad status updated' };
  }

  @Get('wallet/ads/:id/performance')
  async getAdPerformance(
    @CurrentUser() user: any,
    @Param('id') id: string
  ) {
    return this.adScheduling.getAdPerformance(id, user.sub);
  }

  @Post('wallet/ads/:id/track/view')
  async trackAdView(@Param('id') id: string) {
    await this.adScheduling.trackAdView(id);
    return { ok: true };
  }

  @Post('wallet/ads/:id/track/click')
  async trackAdClick(@Param('id') id: string) {
    await this.adScheduling.trackAdClick(id);
    return { ok: true };
  }

  @Get('wallet/analytics')
  async getAnalytics(@CurrentUser() user: any) {
    return this.wallet.getAnalytics(user.sub);
  }

  // Bank Details endpoints
  @Get('wallet/bank-details')
  async getBankDetails(@CurrentUser() user: any) {
    return this.wallet.getBankDetails(user.sub);
  }

  @Post('wallet/bank-details')
  async saveBankDetails(
    @CurrentUser() user: any,
    @Body() body: {
      bankName: string;
      accountHolderName: string;
      accountNumber: string;
      accountType?: string;
    },
  ) {
    return this.wallet.saveBankDetails(user.sub, body);
  }

  @Get('wallet/bank-details/:accountNumber')
  async getBankDetailsByAccount(
    @CurrentUser() user: any,
    @Param('accountNumber') accountNumber: string,
  ) {
    return this.wallet.getBankDetailsByAccount(user.sub, accountNumber);
  }

  @Post('wallet/bank-details/:id/delete')
  async deleteBankDetails(
    @CurrentUser() user: any,
    @Param('id') id: string,
  ) {
    return this.wallet.deleteBankDetails(user.sub, id);
  }
}
