import { Injectable, Logger, Inject, forwardRef } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import * as crypto from 'crypto';
import { WalletService } from '../wallet/wallet.service';
import { EmailService } from '../common/email.service';
import { EmailEventName } from '../email/email-events';
import { decryptSecret } from '../common/crypto.util';

type Provider = 'paystack' | 'stripe' | 'paypal' | 'flutterwave';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);
  // Simple in-memory replay guards for recent signatures/events
  private recentStripeSigs = new Map<string, number>(); // v1 signature -> timestamp (ms)
  private recentPaystackSigs = new Map<string, number>(); // computed HMAC -> timestamp (ms)
  private recentPayPalTransmissions = new Map<string, number>(); // transmissionId -> timestamp (ms)
  constructor(
    private prisma: PrismaService,
    @Inject(forwardRef(() => WalletService)) private wallet: WalletService,
    private email: EmailService,
  ) {}

  private async resolveGatewaySecret(gateway: 'paystack' | 'stripe' | 'paypal' | 'flutterwave'): Promise<string | null> {
    try {
      const cfg = await (this.prisma as any).paymentGatewayConfig.findFirst({
        where: { gateway, active: true },
        orderBy: { updatedAt: 'desc' },
      });
      if (cfg?.secretKeyEnc) {
        const encKey = process.env.CONFIG_ENCRYPTION_KEY;
        if (!encKey || encKey.length !== 64) return null;
        return decryptSecret(cfg.secretKeyEnc, encKey);
      }
      if (cfg?.secretKey) return cfg.secretKey;
    } catch {}
    if (gateway === 'paystack') return process.env.PAYSTACK_SECRET || null;
    if (gateway === 'stripe') return process.env.STRIPE_SECRET || null;
    if (gateway === 'paypal') return process.env.PAYPAL_CLIENT_SECRET || process.env.PAYPAL_SECRET || null;
    if (gateway === 'flutterwave') return process.env.FLW_SECRET_KEY || process.env.FLUTTERWAVE_SECRET || null;
    return null;
  }

  /**
   * Resolve the public API base URL used for provider callbacks.
   *
   * Priority:
   *   1. API_PUBLIC_URL if set (always wins)
   *   2. In production, try to infer from CORS_ORIGINS (prefer an origin that looks like an API host)
   *   3. Fallbacks:
   *      - In production, APP_PUBLIC_URL if available
   *      - In development, http://localhost:3000
   */
  private getApiBaseUrl(): string {
    const explicit = (process.env.API_PUBLIC_URL || '').trim();
    if (explicit.length > 0) {
      return explicit.replace(/\/+$/, '');
    }

    const isProduction = process.env.NODE_ENV === 'production';
    const appUrl = (process.env.APP_PUBLIC_URL || '').trim().replace(/\/+$/, '');
    const cors = (process.env.CORS_ORIGINS || '').trim();

    if (isProduction && cors) {
      const origins = cors
        .split(',')
        .map((o) => o.trim())
        .filter((o) => o.length > 0);

      // Prefer an origin that is not the app URL and contains "api" in the host
      let apiOrigin = origins.find((o) => o !== appUrl && /api/i.test(o));
      if (!apiOrigin) {
        // Otherwise, pick any origin that is not the app URL
        apiOrigin = origins.find((o) => o !== appUrl) || origins[0];
      }
      if (apiOrigin) {
        return apiOrigin.replace(/\/+$/, '');
      }
    }

    // Production fallback: use APP_PUBLIC_URL rather than localhost if we have nothing else
    if (isProduction && appUrl) {
      this.logger.warn('API_PUBLIC_URL not set; falling back to APP_PUBLIC_URL for callbacks');
      return appUrl;
    }

    // Development / final fallback
    return 'http://localhost:3000';
  }

  private async resolveGatewayKeys(gateway: 'paystack' | 'stripe' | 'paypal' | 'flutterwave'): Promise<{ public?: string; secret?: string }> {
    try {
      const cfg = await (this.prisma as any).paymentGatewayConfig.findFirst({
        where: { gateway, active: true },
        orderBy: { updatedAt: 'desc' },
      });
      let secret: string | undefined;
      if (cfg?.secretKeyEnc) {
        const encKey = process.env.CONFIG_ENCRYPTION_KEY;
        if (encKey && encKey.length === 64) {
          secret = decryptSecret(cfg.secretKeyEnc, encKey);
        }
      } else if (cfg?.secretKey) secret = cfg.secretKey;
      return { public: cfg?.publicKey, secret };
    } catch {}
    return { public: undefined, secret: await this.resolveGatewaySecret(gateway) ?? undefined };
  }

  // Accessor to the Prisma delegate for FundingIntent to avoid editor type lag
  // when Prisma Client types are out-of-date. The runtime client always exposes
  // the delegate since it is generated from the current schema.
  private get fundingIntent() {
    return (this.prisma as any).fundingIntent;
  }

  private get webhookEvent() {
    return (this.prisma as any).webhookEvent;
  }

  // Placeholder for Phase 1: list supported providers based on env configuration
  listProviders() {
    const providers = [] as string[];
    if (process.env.PAYSTACK_SECRET) providers.push('paystack');
    if (process.env.STRIPE_SECRET) providers.push('stripe');
    if (process.env.PAYPAL_CLIENT_ID && process.env.PAYPAL_SECRET) providers.push('paypal');
    // Fallback to roadmap providers if env not yet set
    if (providers.length === 0) return ['paystack', 'stripe', 'paypal'];
    return providers;
  }

  // Create a funding intent record and return a placeholder authorization URL.
  // Supports NGN, GHS, KES, ZAR. Amount is in major units; converted to subunits for Paystack.
  // When amountByc is provided (e.g. from a package), wallet will be credited that exact amount.
  async createPaystackInit(userId: string, amount: number, currency: string, returnUrl?: string, amountByc?: number) {
    const cur = (currency || 'NGN').toUpperCase();
    const supported = ['NGN', 'GHS', 'KES', 'ZAR'];
    if (!supported.includes(cur)) {
      return { ok: false, error: `Paystack supports ${supported.join(', ')} only` };
    }
    const amountMinor = Math.round(amount * 100); // kobo/pesewas/cents
    const intentReference = `fi_${Date.now()}_${crypto.randomBytes(6).toString('hex')}`;
    const intent = await this.fundingIntent.create({
      data: {
        userId,
        provider: 'paystack',
        currency: cur,
        amountMinor,
        status: 'PENDING',
        intentReference,
        initPayload: { amount, currency: cur, returnUrl, ...(amountByc != null && amountByc > 0 ? { amountByc } : {}) },
      },
    });
    const apiBase = this.getApiBaseUrl();
    const redirectTarget = returnUrl || (process.env.APP_PUBLIC_URL ? `${process.env.APP_PUBLIC_URL}/status` : 'https://example.com/status');
    const callbackUrl = `${apiBase}/v1/wallet/fund/paystack/callback?redirect=${encodeURIComponent(redirectTarget)}`;
    const secret = await this.resolveGatewaySecret('paystack');
    if (!secret) {
      return { ok: false, error: 'PAYSTACK_SECRET not configured' };
    }
    let email = `${userId}@bybata.local`;
    try {
      const u = await (this.prisma as any).user.findUnique({ where: { id: userId }, select: { email: true } });
      if (u?.email) email = u.email;
    } catch {}

    const body: Record<string, unknown> = {
      amount: amountMinor,
      currency: cur,
      email,
      callback_url: callbackUrl,
      metadata: { intentReference, userId },
    };
    const res = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secret}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    const json: any = await res.json();
    if (!res.ok || !json?.status) {
      return { ok: false, error: json?.message || 'Paystack init failed' };
    }
    const data = json?.data || {};
    const authorizationUrl = data?.authorization_url;
    const providerReference = data?.reference;
    const accessCode = data?.access_code;

    await this.fundingIntent.update({
      where: { id: intent.id },
      data: {
        providerReference,
        initPayload: { amount, currency: cur, returnUrl, response: json, ...(amountByc != null && amountByc > 0 ? { amountByc } : {}) },
      },
    });

    return {
      ok: true,
      provider: 'paystack' as const,
      reference: intent.intentReference,
      amount,
      currency: cur,
      authorization_url: authorizationUrl,
      authorizationUrl: authorizationUrl,
      access_code: accessCode,
      returnUrl: callbackUrl,
      meta: { userId, providerReference, access_code: accessCode },
    };
  }

  // Stripe: Create PaymentIntent for client-side card handling OR Checkout Session for hosted payment
  // Supports both PaymentIntent (client-side) and Checkout Session (hosted) flows
  // When amountByc is provided (e.g. from a package), wallet will be credited that exact amount.
  async createStripeInit(userId: string, amountUsd: number, returnUrl?: string, usePaymentIntent = false, amountByc?: number) {
    const amountMinor = Math.round(amountUsd * 100);
    const intentReference = `fi_${Date.now()}_${crypto.randomBytes(6).toString('hex')}`;
    const apiBase = this.getApiBaseUrl();
    const redirectTarget = returnUrl || (process.env.APP_PUBLIC_URL ? `${process.env.APP_PUBLIC_URL}/status` : 'https://example.com/status');
    
    const intent = await this.fundingIntent.create({
      data: {
        userId,
        provider: 'stripe',
        currency: 'USD',
        amountMinor,
        status: 'PENDING',
        intentReference,
        initPayload: { amountUsd, returnUrl, usePaymentIntent, ...(amountByc != null && amountByc > 0 ? { amountByc } : {}) },
      },
    });

    const fallback = {
      ok: true,
      provider: 'stripe' as const,
      amountUsd,
      clientSecret: `cs_test_${Date.now()}_${crypto.randomBytes(6).toString('hex')}`,
      paymentIntentId: `pi_test_${Date.now()}_${crypto.randomBytes(6).toString('hex')}`,
      returnUrl: returnUrl || process.env.APP_PUBLIC_URL || 'https://example.com',
      meta: { userId, intentReference },
    };

    try {
      const secret = await this.resolveGatewaySecret('stripe');
      if (!secret) {
        this.logger.warn('STRIPE_SECRET not configured; returning fallback');
        return fallback;
      }

      // Resolve user email for Stripe
      let email = `${userId}@bybata.local`;
      try {
        const u = await (this.prisma as any).user.findUnique({ where: { id: userId }, select: { email: true } });
        if (u?.email) email = u.email;
      } catch {}

      if (usePaymentIntent) {
        // Create PaymentIntent for client-side card handling
        const params = new URLSearchParams();
        params.set('amount', String(amountMinor));
        params.set('currency', 'usd');
        params.set('metadata[userId]', userId);
        params.set('metadata[intentReference]', intentReference);
        params.set('receipt_email', email);
        
        const res = await fetch('https://api.stripe.com/v1/payment_intents', {
          method: 'POST',
          headers: { Authorization: `Bearer ${secret}`, 'Content-Type': 'application/x-www-form-urlencoded' },
          body: params.toString(),
        });
        const json: any = await res.json();
        
        if (!res.ok || !json?.id || !json?.client_secret) {
          this.logger.error(`Stripe PaymentIntent creation failed: ${json?.error?.message || 'Unknown error'}`);
          return fallback;
        }

        await this.fundingIntent.update({
          where: { id: intent.id },
          data: { providerReference: json.id, initPayload: { amountUsd, returnUrl, usePaymentIntent, response: json, ...(amountByc != null && amountByc > 0 ? { amountByc } : {}) } },
        });

        return {
          ok: true,
          provider: 'stripe' as const,
          amountUsd,
          clientSecret: json.client_secret,
          paymentIntentId: json.id,
          returnUrl: returnUrl || process.env.APP_PUBLIC_URL || 'https://example.com',
          meta: { userId, intentReference, providerReference: json.id },
        };
      } else {
        // Create Checkout Session for hosted payment page
        const successUrl = `${apiBase}/v1/wallet/fund/stripe/callback?redirect=${encodeURIComponent(redirectTarget)}&session_id={CHECKOUT_SESSION_ID}`;
        const cancelUrl = successUrl;
        
        const params = new URLSearchParams();
        params.set('mode', 'payment');
        params.set('success_url', successUrl);
        params.set('cancel_url', cancelUrl);
        params.set('line_items[0][price_data][currency]', 'usd');
        params.set('line_items[0][price_data][product_data][name]', `BYBATA Wallet Funding ${intentReference}`);
        params.set('line_items[0][price_data][unit_amount]', String(amountMinor));
        params.set('line_items[0][quantity]', '1');
        params.set('metadata[userId]', userId);
        params.set('metadata[intentReference]', intentReference);
        params.set('customer_email', email);
        
        const res = await fetch('https://api.stripe.com/v1/checkout/sessions', {
          method: 'POST',
          headers: { Authorization: `Bearer ${secret}`, 'Content-Type': 'application/x-www-form-urlencoded' },
          body: params.toString(),
        });
        const json: any = await res.json();
        
        if (!res.ok || !json?.url) {
          this.logger.error(`Stripe Checkout Session creation failed: ${json?.error?.message || 'Unknown error'}`);
          return fallback;
        }

        await this.fundingIntent.update({
          where: { id: intent.id },
          data: { providerReference: json.id, initPayload: { amountUsd, returnUrl, usePaymentIntent, response: json, ...(amountByc != null && amountByc > 0 ? { amountByc } : {}) } },
        });

        return {
          ok: true,
          provider: 'stripe' as const,
          amountUsd,
          checkoutUrl: json.url,
          sessionId: json.id,
          returnUrl: returnUrl || process.env.APP_PUBLIC_URL || 'https://example.com',
          meta: { userId, intentReference, providerReference: json.id },
        };
      }
    } catch (e) {
      this.logger.error(`Stripe init error: ${(e as Error)?.message}`);
      return fallback;
    }
  }

  // PayPal: create order and return approve link via client-side browser
  // Consolidated method - supports both sandbox and live environments
  async createPaypalInit(userId: string, amountUsd: number, returnUrl?: string) {
    return this.createPayPalInit(userId, amountUsd, returnUrl);
  }

  async handlePaypalCallback(orderId: string) {
    const clientId = process.env.PAYPAL_CLIENT_ID;
    const clientSecret = await this.resolveGatewaySecret('paypal');
    if (!clientId || !clientSecret) {
      this.logger.warn('PAYPAL_CLIENT_ID or PAYPAL_SECRET not configured; skipping PayPal order capture');
      return { ok: false, error: 'PAYPAL keys not configured' };
    }
    
    const base = (process.env.PAYPAL_ENV === 'sandbox') ? 'https://api-m.sandbox.paypal.com' : 'https://api-m.paypal.com';
    
    try {
      // Get OAuth token
      const tokenRes = await fetch(`${base}/v1/oauth2/token`, {
        method: 'POST',
        headers: {
          Authorization: 'Basic ' + Buffer.from(`${clientId}:${clientSecret}`).toString('base64'),
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      });
      
      if (!tokenRes.ok) {
        this.logger.error(`PayPal OAuth token request failed: ${tokenRes.status}`);
        return { ok: false, error: 'Failed to get PayPal access token' };
      }
      
      const tokenJson: any = await tokenRes.json();
      const accessToken = tokenJson.access_token;
      if (!accessToken) {
        this.logger.error('PayPal OAuth token missing from response');
        return { ok: false, error: 'Failed to get PayPal access token' };
      }
      
      // Capture order
      const capRes = await fetch(`${base}/v2/checkout/orders/${encodeURIComponent(orderId)}/capture`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      });
      
      const capJson: any = await capRes.json();
      if (!capRes.ok) {
        this.logger.error(`PayPal capture failed: ${capJson?.message || 'Unknown error'}`);
        return { ok: false, error: capJson?.message || 'PayPal capture failed' };
      }
      
      // Check if order was canceled
      if (capJson.status === 'CANCELLED' || capJson.status === 'VOIDED') {
        this.logger.warn(`[paypal] Order ${orderId} was canceled or voided`);
        // Update FundingIntent status
        try {
          await this.fundingIntent.updateMany({
            where: { providerReference: orderId },
            data: { status: 'CANCELLED', webhookPayload: capJson },
          });
        } catch (e) {
          this.logger.warn(`Failed to update FundingIntent status: ${(e as Error)?.message}`);
        }
        return { ok: true, verified: true, status: 'cancelled', result: capJson };
      }
      
      // Emit funding event for successful capture
      const body = {
        event_type: 'PAYMENT.CAPTURE.COMPLETED',
        resource: capJson,
      };
      const result = await this.handleProviderFundingEvent('paypal', body, true);
      // Return success only if the funding event was processed successfully
      const success = result?.ok;
      return { ok: success, verified: success, result };
    } catch (e) {
      this.logger.error(`PayPal callback error: ${(e as Error)?.message}`);
      return { ok: false, error: (e as Error)?.message || 'PayPal callback processing failed' };
    }
  }

  async handleFlutterwaveCallback(params: { tx_ref?: string; transaction_id?: string }) {
    const secret = await this.resolveGatewaySecret('flutterwave');
    if (!secret) return { ok: false, error: 'FLUTTERWAVE_SECRET not configured' };
    let verifyUrl: string | null = null;
    if (params.transaction_id) verifyUrl = `https://api.flutterwave.com/v3/transactions/${encodeURIComponent(params.transaction_id)}/verify`;
    if (!verifyUrl) return { ok: false, error: 'Missing transaction_id' };
    const res = await fetch(verifyUrl, { headers: { Authorization: `Bearer ${secret}` } });
    const json: any = await res.json();
    if (!res.ok || json?.status !== 'success') return { ok: false, error: json?.message || 'Verification failed' };
    const body = { type: 'flutterwave.charge.completed', data: { object: json?.data } };
    const result = await this.handleProviderFundingEvent('flutterwave', body, true);
    // Return success only if the funding event was processed successfully
    const success = result?.ok;
    return { ok: success, verified: success, result };
  }

  async handleStripeCallback(sessionId: string) {
    const secret = await this.resolveGatewaySecret('stripe');
    if (!secret) {
      this.logger.warn('STRIPE_SECRET not configured; skipping Stripe session verification');
      return { ok: false, error: 'STRIPE_SECRET not configured' };
    }
    // Fetch Checkout Session
    const sessRes = await fetch(`https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(sessionId)}`, {
      headers: { Authorization: `Bearer ${secret}` },
    });
    const sessJson: any = await sessRes.json();
    if (!sessRes.ok || !sessJson?.id) {
      return { ok: false, error: sessJson?.error?.message || 'Stripe session fetch failed' };
    }
    // If paid, fetch PaymentIntent for amount
    let intentJson: any = null;
    const piId = sessJson.payment_intent;
    if (piId) {
      const piRes = await fetch(`https://api.stripe.com/v1/payment_intents/${encodeURIComponent(piId)}`, {
        headers: { Authorization: `Bearer ${secret}` },
      });
      intentJson = await piRes.json();
    }
    const obj = intentJson || sessJson;
    const body = {
      type: 'payment_intent.succeeded',
      data: { object: obj },
    };
    const result = await this.handleProviderFundingEvent('stripe', body, true);
    // Return success only if the funding event was processed successfully
    const success = result?.ok;
    return { ok: success, verified: success, result };
  }

  // Flutterwave: create a hosted payment via v3/payments and return checkout link
  // When amountByc is provided (e.g. from a package), wallet will be credited that exact amount.
  async createFlutterwaveInit(userId: string, amount: number, currency: string, returnUrl?: string, amountByc?: number) {
    const intentReference = `fi_${Date.now()}_${crypto.randomBytes(6).toString('hex')}`;
    const redirectTarget = returnUrl || (process.env.APP_PUBLIC_URL ? `${process.env.APP_PUBLIC_URL}/status` : 'https://example.com/status');
    const intent = await this.fundingIntent.create({
      data: {
        userId,
        provider: 'flutterwave',
        currency: currency.toUpperCase(),
        amountMinor: Math.round(amount * 100),
        status: 'PENDING',
        intentReference,
        initPayload: { amount, currency, returnUrl, ...(amountByc != null && amountByc > 0 ? { amountByc } : {}) },
      },
    });
    const secret = await this.resolveGatewaySecret('flutterwave');
    if (!secret) {
      return {
        ok: false,
        error: 'FLUTTERWAVE_SECRET not configured',
      };
    }
    // Resolve user email for customer field
    let email = `${userId}@bybata.local`;
    try {
      const u = await (this.prisma as any).user.findUnique({ where: { id: userId }, select: { email: true } });
      if (u?.email) email = u.email;
    } catch {}

    const res = await fetch('https://api.flutterwave.com/v3/payments', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secret}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        tx_ref: intentReference,
        amount,
        currency: currency.toUpperCase(),
        redirect_url: `${this.getApiBaseUrl()}/v1/wallet/fund/flutterwave/callback?redirect=${encodeURIComponent(redirectTarget)}`,
        customer: { email },
        meta: { intentReference, userId },
      }),
    });
    const json: any = await res.json();
    if (!res.ok || !json?.status || !json?.data?.link) {
      return { ok: false, error: json?.message || 'Flutterwave init failed' };
    }
    await this.fundingIntent.update({
      where: { id: intent.id },
      data: { providerReference: json?.data?.id, initPayload: { amount, currency, returnUrl, response: json, ...(amountByc != null && amountByc > 0 ? { amountByc } : {}) } },
    });
    return {
      ok: true,
      provider: 'flutterwave' as const,
      amount,
      currency: currency.toUpperCase(),
      checkoutUrl: json.data.link,
      returnUrl: redirectTarget,
      meta: { userId, intentReference, providerReference: json?.data?.id },
    };
  }

  // PayPal: create order with FundingIntent and custom_id; returns orderId and approveLink.
  // Supports both sandbox and live environments
  // When amountByc is provided (e.g. from a package), wallet will be credited that exact amount.
  async createPayPalInit(userId: string, amountUsd: number, returnUrl?: string, amountByc?: number) {
    const amountMinor = Math.round(amountUsd * 100);
    const intentReference = `fi_${Date.now()}_${crypto.randomBytes(6).toString('hex')}`;
    const redirectTarget = returnUrl || (process.env.APP_PUBLIC_URL ? `${process.env.APP_PUBLIC_URL}/status` : 'https://example.com/status');
    const apiBase = this.getApiBaseUrl();
    
    const intent = await this.fundingIntent.create({
      data: {
        userId,
        provider: 'paypal',
        currency: 'USD',
        amountMinor,
        status: 'PENDING',
        intentReference,
        initPayload: { amountUsd, returnUrl, ...(amountByc != null && amountByc > 0 ? { amountByc } : {}) },
      },
    });
    
    const fallback = {
      ok: true,
      provider: 'paypal' as const,
      amountUsd,
      orderId: `order_test_${Date.now()}_${crypto.randomBytes(6).toString('hex')}`,
      approveLink: `https://www.paypal.com/checkoutnow?token=order_test_${Date.now()}`,
      returnUrl: returnUrl || process.env.APP_PUBLIC_URL || 'https://example.com',
      meta: { userId, intentReference },
    };
    
    try {
      const clientId = process.env.PAYPAL_CLIENT_ID;
      const clientSecret = await this.resolveGatewaySecret('paypal');
      if (!clientId || !clientSecret) {
        this.logger.warn('PAYPAL_CLIENT_ID or PAYPAL_SECRET not configured; returning fallback');
        return fallback;
      }
      
      const base = (process.env.PAYPAL_ENV === 'sandbox') ? 'https://api-m.sandbox.paypal.com' : 'https://api-m.paypal.com';
      
      // Get OAuth token
      const tokenRes = await fetch(`${base}/v1/oauth2/token`, {
        method: 'POST',
        headers: {
          Authorization: 'Basic ' + Buffer.from(`${clientId}:${clientSecret}`).toString('base64'),
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      });
      
      if (!tokenRes.ok) {
        this.logger.error(`PayPal OAuth token request failed: ${tokenRes.status}`);
        return fallback;
      }
      
      const tokenJson: any = await tokenRes.json();
      const accessToken = tokenJson.access_token;
      if (!accessToken) {
        this.logger.error('PayPal OAuth token missing from response');
        return fallback;
      }
      
      // Create order
      const orderRes = await fetch(`${base}/v2/checkout/orders`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          intent: 'CAPTURE',
          purchase_units: [{
            amount: { currency_code: 'USD', value: amountUsd.toFixed(2) },
            custom_id: intentReference, // Include intentReference for webhook resolution
          }],
          application_context: {
            return_url: `${apiBase}/v1/wallet/fund/paypal/callback?redirect=${encodeURIComponent(redirectTarget)}`,
            cancel_url: `${redirectTarget}?provider=paypal&status=cancel`,
            brand_name: 'BYBATA',
            landing_page: 'BILLING',
            user_action: 'PAY_NOW',
          },
        }),
      });
      
      const orderJson: any = await orderRes.json();
      if (!orderRes.ok || !orderJson?.id) {
        this.logger.error(`PayPal order creation failed: ${orderJson?.message || 'Unknown error'}`);
        return { ok: false, error: orderJson?.message || 'PayPal order creation failed' };
      }
      
      const approveLink = (orderJson.links || []).find((l: any) => l.rel === 'approve')?.href;
      if (!approveLink) {
        this.logger.error('PayPal approve link not found in order response');
        return fallback;
      }
      
      await this.fundingIntent.update({
        where: { id: intent.id },
        data: { providerReference: orderJson.id, initPayload: { amountUsd, returnUrl, response: orderJson, ...(amountByc != null && amountByc > 0 ? { amountByc } : {}) } },
      });
      
      this.logger.log(`[paypal] Order created: ${orderJson.id}, intent: ${intentReference}`);
      
      return {
        ok: true,
        provider: 'paypal' as const,
        amountUsd,
        orderId: orderJson.id,
        approveLink,
        returnUrl: redirectTarget,
        meta: { userId, intentReference, providerReference: orderJson.id },
      };
    } catch (e) {
      this.logger.error(`PayPal init error: ${(e as Error)?.message}`);
      return fallback;
    }
  }

  // Verify Paystack webhook signature using sha512 HMAC
  async verifyPaystackSignature(rawBody: string, signature?: string): Promise<boolean> {
    try {
      const secret = process.env.PAYSTACK_WEBHOOK_SECRET || process.env.PAYSTACK_SECRET;
      if (!secret || !signature) return false;
      const computed = crypto.createHmac('sha512', secret).update(rawBody).digest('hex');
      const ok = crypto.timingSafeEqual(Buffer.from(computed), Buffer.from(signature));
      if (!ok) return false;

      // Replay guard: reject identical HMAC seen within tolerance
      const now = Date.now();
      const toleranceMs = Math.max(0, Number(process.env.PAYSTACK_SIG_TOLERANCE_S ?? 300)) * 1000;
      const last = this.recentPaystackSigs.get(computed);
      if (last && now - last < toleranceMs) {
        this.logger.warn('Paystack replay detected within tolerance window');
        return false;
      }
      this.recentPaystackSigs.set(computed, now);
      // Opportunistic cleanup of old entries
      for (const [k, ts] of this.recentPaystackSigs) {
        if (now - ts > toleranceMs) this.recentPaystackSigs.delete(k);
      }
      return ok;
    } catch (e) {
      this.logger.warn(`Paystack verify error: ${(e as Error)?.message}`);
      return false;
    }
  }

  // Verify Stripe signature (manual implementation of v1 scheme). For production, prefer Stripe SDK.
  async verifyStripeSignature(rawBody: string, stripeSig?: string): Promise<boolean> {
    try {
      const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET || process.env.STRIPE_SECRET;
      if (!endpointSecret || !stripeSig) return false;
      // Stripe header format: t=timestamp,v1=signature[,v0=...]
      const parts = Object.fromEntries(
        (stripeSig || '')
          .split(',')
          .map((kv) => kv.split('='))
          .filter((a) => a.length === 2),
      ) as Record<string, string>;
      const timestamp = parts['t'];
      const v1 = parts['v1'];
      if (!timestamp || !v1) return false;
      const signedPayload = `${timestamp}.${rawBody}`;
      const expected = crypto.createHmac('sha256', endpointSecret).update(signedPayload).digest('hex');
      const ok = crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(v1));
      if (!ok) return false;

      // Timestamp tolerance window
      const toleranceSec = Math.max(0, Number(process.env.STRIPE_SIG_TOLERANCE_S ?? 300));
      const tMs = Number(timestamp) * 1000;
      if (!isFinite(tMs) || Math.abs(Date.now() - tMs) > toleranceSec * 1000) {
        this.logger.warn('Stripe signature timestamp outside tolerance window');
        return false;
      }

      // Replay guard: reject same v1 signature within tolerance
      const now = Date.now();
      const last = this.recentStripeSigs.get(v1);
      if (last && now - last < toleranceSec * 1000) {
        this.logger.warn('Stripe replay detected within tolerance window');
        return false;
      }
      this.recentStripeSigs.set(v1, now);
      for (const [k, ts] of this.recentStripeSigs) {
        if (now - ts > toleranceSec * 1000) this.recentStripeSigs.delete(k);
      }
      return true;
    } catch (e) {
      this.logger.warn(`Stripe verify error: ${(e as Error)?.message}`);
      return false;
    }
  }

  // Verify PayPal webhook signature via REST API call (requires credentials).
  async verifyPayPalWebhook(params: {
    body: any;
    transmissionId?: string;
    transmissionTime?: string;
    certUrl?: string;
    authAlgo?: string;
    transmissionSig?: string;
    environment?: 'live' | 'sandbox' | string;
  }): Promise<boolean> {
    try {
      // Dev-only bypass to enable E2E tests without real PayPal webhook signatures
      if (process.env.PAYPAL_E2E_ALLOW_FAKE === '1') {
        this.logger.warn('PAYPAL_E2E_ALLOW_FAKE=1 set — bypassing PayPal webhook verification for E2E.');
        return true;
      }
      const { body, transmissionId, transmissionTime, certUrl, authAlgo, transmissionSig, environment } = params;
      const webhookId = process.env.PAYPAL_WEBHOOK_ID;
      const clientId = process.env.PAYPAL_CLIENT_ID;
      const clientSecret = process.env.PAYPAL_CLIENT_SECRET || process.env.PAYPAL_SECRET;
      if (!webhookId || !clientId || !clientSecret) return false;

      // Timestamp tolerance window (uses PayPal transmission_time)
      const toleranceSec = Math.max(0, Number(process.env.PAYPAL_SIG_TOLERANCE_S ?? 300));
      if (transmissionTime) {
        const tMs = Date.parse(transmissionTime);
        if (!isNaN(tMs) && Math.abs(Date.now() - tMs) > toleranceSec * 1000) {
          this.logger.warn('PayPal transmission_time outside tolerance window');
          return false;
        }
      }

      // Replay guard: reject same transmission ID within tolerance
      if (transmissionId) {
        const now = Date.now();
        const last = this.recentPayPalTransmissions.get(transmissionId);
        if (last && now - last < toleranceSec * 1000) {
          this.logger.warn('PayPal replay detected within tolerance window');
          return false;
        }
        this.recentPayPalTransmissions.set(transmissionId, now);
        for (const [k, ts] of this.recentPayPalTransmissions) {
          if (now - ts > toleranceSec * 1000) this.recentPayPalTransmissions.delete(k);
        }
      }

      // Get OAuth token
      const base = environment === 'sandbox' ? 'https://api-m.sandbox.paypal.com' : 'https://api-m.paypal.com';
      const tokenRes = await fetch(`${base}/v1/oauth2/token`, {
        method: 'POST',
        headers: {
          Authorization: 'Basic ' + Buffer.from(`${clientId}:${clientSecret}`).toString('base64'),
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      });
      if (!tokenRes.ok) return false;
      const tokenJson: any = await tokenRes.json();
      const accessToken = tokenJson.access_token;
      if (!accessToken) return false;

      // Verify webhook signature
      const verifyRes = await fetch(`${base}/v1/notifications/verify-webhook-signature`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          auth_algo: authAlgo,
          cert_url: certUrl,
          transmission_id: transmissionId,
          transmission_sig: transmissionSig,
          transmission_time: transmissionTime,
          webhook_id: webhookId,
          webhook_event: body,
        }),
      });
      if (!verifyRes.ok) return false;
      const verifyJson: any = await verifyRes.json();
      return verifyJson.verification_status === 'SUCCESS';
    } catch (e) {
      this.logger.warn(`PayPal verify error: ${(e as Error)?.message}`);
      return false;
    }
  }

  // Unified provider funding event handling with intent resolution and wallet crediting.
  async handleProviderFundingEvent(provider: Provider, body: any, verified: boolean) {
    const event = body?.event || body?.type || body?.event_type || 'unknown';
    this.logger.log(`[${provider}] webhook event=${event} verified=${verified}`);

    // Handle PayPal order cancellations
    if (provider === 'paypal') {
      const eventType = body?.event_type;
      
      // Handle order cancellations
      if (eventType === 'CHECKOUT.ORDER.CANCELLED' || eventType === 'PAYMENT.CAPTURE.DENIED' || body?.status === 'CANCELLED') {
        const order = body?.resource || body?.data?.object || body;
        const providerReference = order?.id || order?.order_id;
        const intentReference = order?.custom_id || order?.purchase_units?.[0]?.custom_id;
        
        this.logger.warn(`[paypal] Order canceled: ${providerReference}, intent: ${intentReference}`);
        
        // Update FundingIntent status
        if (intentReference || providerReference) {
          try {
            await this.fundingIntent.updateMany({
              where: {
                OR: [
                  intentReference ? { intentReference } : undefined,
                  providerReference ? { providerReference } : undefined,
                ].filter(Boolean) as any,
              },
              data: {
                status: 'CANCELLED',
                webhookPayload: body,
              },
            });
          } catch (e) {
            this.logger.warn(`Failed to update FundingIntent status: ${(e as Error)?.message}`);
          }
        }

        try {
          await this.notifyFundingFailed(intentReference, providerReference, 'PayPal payment cancelled');
        } catch (e) {
          this.logger.warn(`Failed to send funding failed email: ${(e as Error)?.message}`);
        }
        
        // Store webhook event
        if (providerReference) {
          try {
            await this.webhookEvent.upsert({
              where: { gateway_reference: { gateway: 'paypal', reference: providerReference } },
              create: { gateway: 'paypal', reference: providerReference, rawPayload: body, verified, processed: true },
              update: { rawPayload: body, verified, processed: true },
            });
          } catch {}
        }
        
        return { ok: true, provider, verified, event, handled: 'cancelled' };
      }
    }

    // Handle Stripe payment failures and refunds
    if (provider === 'stripe') {
      const eventType = body?.type;
      
      // Handle payment failures
      if (eventType === 'payment_intent.payment_failed') {
        const paymentIntent = body?.data?.object;
        const providerReference = paymentIntent?.id;
        const intentReference = paymentIntent?.metadata?.intentReference;
        
        this.logger.warn(`[stripe] Payment failed: ${providerReference}, intent: ${intentReference}`);
        
        // Update FundingIntent status
        if (intentReference || providerReference) {
          try {
            await this.fundingIntent.updateMany({
              where: {
                OR: [
                  intentReference ? { intentReference } : undefined,
                  providerReference ? { providerReference } : undefined,
                ].filter(Boolean) as any,
              },
              data: {
                status: 'FAILED',
                webhookPayload: body,
              },
            });
          } catch (e) {
            this.logger.warn(`Failed to update FundingIntent status: ${(e as Error)?.message}`);
          }
        }

        try {
          await this.notifyFundingFailed(intentReference, providerReference, 'Stripe payment failed');
        } catch (e) {
          this.logger.warn(`Failed to send funding failed email: ${(e as Error)?.message}`);
        }
        
        // Store webhook event
        if (providerReference) {
          try {
            await this.webhookEvent.upsert({
              where: { gateway_reference: { gateway: 'stripe', reference: providerReference } },
              create: { gateway: 'stripe', reference: providerReference, rawPayload: body, verified, processed: true },
              update: { rawPayload: body, verified, processed: true },
            });
          } catch {}
        }
        
        return { ok: true, provider, verified, event, handled: 'payment_failed' };
      }
      
      // Handle refunds
      if (eventType === 'charge.refunded' || eventType === 'payment_intent.canceled') {
        const charge = body?.data?.object;
        const paymentIntentId = charge?.payment_intent || charge?.id;
        const refundAmount = charge?.amount_refunded || charge?.amount || 0;
        const refundAmountMajor = refundAmount / 100; // cents to USD
        
        this.logger.warn(`[stripe] Refund detected: ${paymentIntentId}, amount: ${refundAmountMajor} USD`);
        
        // Find the original funding intent
        const originalIntent = await this.fundingIntent.findFirst({
          where: {
            OR: [
              { providerReference: paymentIntentId },
              { providerReference: charge?.id },
            ],
          },
        });
        
        if (originalIntent && originalIntent.status === 'SUCCEEDED') {
          // Get conversion rate to calculate BYC refund amount
          const rate = await this.getBycRateForCurrency('USD');
          if (rate > 0) {
            const refundByc = refundAmountMajor / rate;
            
            // Create refund transaction (debit from wallet)
            try {
              await this.wallet.send(
                originalIntent.userId,
                'system', // System account for refunds
                refundByc,
                `Stripe refund for ${originalIntent.intentReference}`,
                `refund:${originalIntent.intentReference}:${Date.now()}`,
              );
              this.logger.log(`[stripe] Refunded ${refundByc} BYC to user ${originalIntent.userId}`);

              const user = await this.prisma.user.findUnique({
                where: { id: originalIntent.userId },
                select: { email: true, profile: { select: { displayName: true } } },
              });
              if (user?.email) {
                this.email.dispatchInBackground({
                  eventName: EmailEventName.WalletRefunded,
                  recipient: { email: user.email, userId: originalIntent.userId },
                  vars: {
                    actorName: user.profile?.displayName || user.email,
                    amount: refundByc,
                    currency: 'BYC',
                    reason: 'Stripe refund',
                    refundedAt: new Date().toISOString(),
                  },
                });
              }
            } catch (e) {
              this.logger.error(`[stripe] Failed to process refund: ${(e as Error)?.message}`);
            }
          }
        }
        
        // Store webhook event
        if (paymentIntentId) {
          try {
            await this.webhookEvent.upsert({
              where: { gateway_reference: { gateway: 'stripe', reference: paymentIntentId } },
              create: { gateway: 'stripe', reference: paymentIntentId, rawPayload: body, verified, processed: true },
              update: { rawPayload: body, verified, processed: true },
            });
          } catch {}
        }
        
        return { ok: true, provider, verified, event, handled: 'refund' };
      }
    }

    // Map provider payload to reference and amount in minor units
    const mapped = this.extractFundingPayload(provider, body);
    if (!mapped) return { ok: true, provider, verified, event };

    const { intentReference, providerReference, amountMinor, currency, success } = mapped;

    // Persist webhook event (idempotent per gateway+reference)
    if (providerReference) {
      try {
        await this.webhookEvent.upsert({
          where: { gateway_reference: { gateway: provider, reference: providerReference } },
          create: { gateway: provider, reference: providerReference, rawPayload: body, verified, processed: false },
          update: { rawPayload: body, verified },
        });
      } catch (e) {
        this.logger.warn(`WebhookEvent upsert failed: ${(e as Error)?.message}`);
      }
    }

    // Resolve FundingIntent: try by intentReference (preferred), then providerReference
    const intent = await this.fundingIntent.findFirst({
      where: {
        OR: [
          intentReference ? { intentReference } : undefined,
          providerReference ? { providerReference } : undefined,
        ].filter(Boolean) as any,
      },
    });

    if (!intent) {
      // If not found, upsert by providerReference to record webhook for later reconciliation
      if (providerReference) {
        const inferredUserId = body?.data?.metadata?.userId || body?.metadata?.userId;
        if (inferredUserId) {
          await this.fundingIntent.create({
            data: {
              userId: inferredUserId,
              provider,
              currency: currency || 'NGN',
              amountMinor: amountMinor ?? 0,
              status: success && verified ? 'SUCCEEDED' : 'PENDING',
              intentReference: intentReference || `fi_${crypto.randomBytes(6).toString('hex')}`,
              providerReference,
              webhookPayload: body,
            },
          });
        }
      }
      return { ok: true, provider, verified, event };
    }

    // Update intent with providerReference if missing, and store webhook payload
    const updated = await this.fundingIntent.update({
      where: { id: intent.id },
      data: {
        providerReference: intent.providerReference ?? providerReference,
        webhookPayload: body,
        status: success && verified ? 'SUCCEEDED' : intent.status,
        resolvedAt: success && verified ? new Date() : undefined,
      },
    });

    // Credit wallet only if verified and event indicates success, and intent not yet credited
    // Additional check: ensure we haven't already credited this intent (idempotency)
    if (verified && success && updated.status === 'SUCCEEDED' && typeof amountMinor === 'number') {
      // Check if this intent has already been credited (idempotency check)
      const existingCredit = await this.prisma.walletTransaction.findFirst({
        where: {
          idempotencyKey: `fund:${updated.intentReference}`,
          type: 'FUND',
          status: 'SUCCESS',
        },
      });

      if (existingCredit) {
        this.logger.warn(`[${provider}] Intent ${updated.intentReference} already credited, skipping duplicate credit`);
        // Mark webhook as processed even though we didn't credit (already done)
        if (providerReference) {
          try {
            await this.webhookEvent.update({
              where: { gateway_reference: { gateway: provider, reference: providerReference } },
              data: { processed: true },
            });
          } catch {}
        }
        return { ok: true, provider, verified, event, skipped: 'already_credited' };
      }

      try {
        const amountMajor = amountMinor / 100; // smallest unit to major (e.g., kobo->NGN, cents->USD)
        const initPayload = (updated.initPayload as Record<string, unknown>) || {};
        const packageAmountByc = typeof initPayload.amountByc === 'number' && initPayload.amountByc > 0
          ? initPayload.amountByc
          : null;

        let amountByc: number;
        if (packageAmountByc != null) {
          // Package-based funding: credit exact BYC from package (e.g. Premium Pack)
          amountByc = packageAmountByc;
          this.logger.log(
            `[${provider}] Crediting wallet (package): ${amountByc} BYC for ${amountMajor} ${currency || updated.currency || 'NGN'}`
          );
        } else {
          const rate = await this.getBycRateForCurrency(currency || updated.currency || 'NGN');
          if (rate <= 0) {
            this.logger.error(`[${provider}] No valid conversion rate found for ${currency || updated.currency || 'NGN'}. Cannot credit wallet.`);
            return { ok: false, provider, verified, event, error: 'no_conversion_rate' };
          }
          // Convert fiat to BYC: BYC = amountMajor / rate
          amountByc = amountMajor / rate;
          this.logger.log(
            `[${provider}] Crediting wallet: ${amountMajor} ${currency || updated.currency || 'NGN'} = ${amountByc} BYC (rate: ${rate})`
          );
        }

        await this.wallet.fund(
          updated.userId,
          amountByc,
          `${provider.toUpperCase()} funding ${updated.intentReference}`,
          `fund:${updated.intentReference}`, // Idempotency key
        );

        // Send wallet funded confirmation email AFTER payment is verified and balance credited
        // Email MUST be sent successfully before we consider the funding complete
        let emailSent = false;
        try {
          const [user, account] = await Promise.all([
            this.prisma.user.findUnique({ where: { id: updated.userId }, select: { email: true, profile: { select: { displayName: true } } } }),
            this.prisma.account.findUnique({ where: { userId: updated.userId } }),
          ]);
          if (user?.email && account) {
            const balance = (account.balance as any)?.toNumber ? (account.balance as any).toNumber() : Number(account.balance || 0);
            this.email.dispatchInBackground({
              eventName: EmailEventName.WalletFunded,
              recipient: { email: user.email, userId: updated.userId },
              vars: {
                actorName: user.profile?.displayName || user.email,
                amount: amountByc,
                currency: 'BYC',
                balance,
                fundedAt: new Date().toISOString(),
              },
            });
            emailSent = true;
            this.logger.log(`[${provider}] Confirmation email dispatched to ${user.email}`);
          }
        } catch (e) {
          this.logger.warn(`Wallet funded email dispatch failed after confirmed deposit: ${(e as Error).message}`);
          emailSent = false;
        }

        // Mark webhook event as processed
        if (providerReference) {
          try {
            await this.webhookEvent.update({
              where: { gateway_reference: { gateway: provider, reference: providerReference } },
              data: { processed: true },
            });
          } catch (e) {
            this.logger.warn(`Failed to mark webhook as processed: ${(e as Error)?.message}`);
          }
        }

        this.logger.log(`[${provider}] Successfully credited ${amountByc} BYC to user ${updated.userId}${emailSent ? ' with confirmation email dispatched' : ' (email dispatch may be pending)'}`);
      } catch (e) {
        this.logger.error(`[${provider}] Failed to credit wallet for intent ${updated.intentReference}: ${(e as Error)?.message}`);
        // Don't mark as processed if credit failed - allow retry
        return { ok: false, provider, verified, event, error: (e as Error)?.message };
      }
    }

    return { ok: true, provider, verified, event };
  }

  private async notifyFundingFailed(
    intentReference?: string,
    providerReference?: string,
    reason: string = 'Funding failed',
  ) {
    if (!intentReference && !providerReference) return;
    const intent = await this.fundingIntent.findFirst({
      where: {
        OR: [
          intentReference ? { intentReference } : undefined,
          providerReference ? { providerReference } : undefined,
        ].filter(Boolean) as any,
      },
    });
    if (!intent?.userId) return;
    const user = await (this.prisma as any).user.findUnique({
      where: { id: intent.userId },
      select: { email: true, profile: { select: { displayName: true } } },
    });
    if (!user?.email) return;
    const amount = Number(intent.amountMinor || 0) / 100;
    this.email.dispatchInBackground({
      eventName: EmailEventName.WalletFundingFailed,
      recipient: { email: user.email, userId: intent.userId },
      vars: {
        actorName: user.profile?.displayName || user.email,
        amount,
        currency: intent.currency || 'USD',
        reason,
        supportEmail: process.env.SUPPORT_EMAIL || 'support@bybata.com',
      },
    });
  }

  // Reconciliation job for verified but unprocessed webhooks
  async reconcileUnprocessedWebhooks(limit = 50) {
    const events = await this.webhookEvent.findMany({ where: { verified: true, processed: false }, take: limit, orderBy: { createdAt: 'asc' } });
    for (const ev of events) {
      try {
        // Attempt to reconstruct minimal payload and re-handle
        const body = ev.rawPayload;
        const provider = ev.gateway as Provider;
        await this.handleProviderFundingEvent(provider, body, true);
      } catch (e) {
        this.logger.warn(`Reconcile webhook ${ev.gateway}/${ev.reference} failed: ${(e as Error)?.message}`);
      }
    }
    return { ok: true, processed: events.length };
  }

  // Fetch BYC conversion rate for a given fiat currency (e.g., NGN, USD)
  /**
   * Get BYC conversion rate for a given currency
   * Respects validity windows (validFrom, validTo) and returns the most recent active rate
   */
  private async getBycRateForCurrency(currency: string): Promise<number> {
    try {
      const quote = currency?.toUpperCase() || 'NGN';
      const now = new Date();

      // Find all active rates for this currency pair
      const allRates = await (this.prisma as any).conversionRate.findMany({
        where: {
          base: 'BYC',
          quote,
          active: true,
        },
        orderBy: { createdAt: 'desc' },
      });

      // Filter to find the most recent rate that is currently valid
      // A rate is valid if:
      // - validFrom is null OR validFrom <= now
      // - AND validTo is null OR validTo >= now
      let rec: any = null;
      for (const rate of allRates) {
        const validFrom = rate.validFrom ? new Date(rate.validFrom) : null;
        const validTo = rate.validTo ? new Date(rate.validTo) : null;

        const isFromValid = !validFrom || validFrom <= now;
        const isToValid = !validTo || validTo >= now;

        if (isFromValid && isToValid) {
          rec = rate;
          break; // Use the most recent valid rate
        }
      }

      if (!rec || rec.rate === null || rec.rate === undefined) {
        this.logger.warn(`No valid conversion rate found for ${quote} at ${now.toISOString()}`);
        return 0;
      }

      // Prisma Decimal -> number
      const rateNum = typeof rec.rate === 'number' ? rec.rate : Number(rec.rate.toString?.() ?? rec.rate);
      if (!rateNum || rateNum <= 0 || !isFinite(rateNum)) {
        this.logger.warn(`Invalid conversion rate for ${quote}: ${rateNum}`);
        return 0;
      }

      return rateNum;
    } catch (e) {
      this.logger.warn(`getBycRateForCurrency error: ${(e as Error)?.message}`);
      return 0;
    }
  }

  private extractFundingPayload(
    provider: Provider,
    body: any,
  ): { intentReference?: string; providerReference?: string; amountMinor?: number; currency?: string; success: boolean } | null {
    try {
      if (provider === 'paystack') {
        const data = body?.data || body;
        const providerReference = data?.reference || data?.id;
        const amountMinor = typeof data?.amount === 'number' ? data.amount : undefined; // kobo
        const currency = data?.currency || 'NGN';
        const success = (body?.event === 'charge.success') || (data?.status === 'success');
        // We expect intentReference to be carried in metadata during init
        const intentReference = data?.metadata?.intentReference || data?.metadata?.reference || data?.metadata?.intent_id;
        return { intentReference, providerReference, amountMinor, currency, success };
      }
      if (provider === 'stripe') {
        const obj = body?.data?.object || body?.object || {};
        // Stripe amounts are in smallest unit (cents for USD)
        const amountMinor = obj?.amount_received ?? obj?.amount ?? undefined;
        const currency = obj?.currency?.toUpperCase() || 'USD';
        const providerReference = obj?.id;
        const success = (body?.type === 'payment_intent.succeeded') || obj?.status === 'succeeded';
        const intentReference = obj?.metadata?.intentReference || obj?.metadata?.reference || obj?.metadata?.intent_id;
        return { intentReference, providerReference, amountMinor, currency, success };
      }
      if (provider === 'paypal') {
        const res = body?.resource || body;
        const amountMinor = res?.amount?.value ? Math.round(parseFloat(res.amount.value) * 100) : undefined;
        const currency = res?.amount?.currency_code || 'USD';
        const providerReference = res?.id;
        const success = (body?.event_type?.includes('PAYMENT.CAPTURE.COMPLETED')) || (res?.status === 'COMPLETED');
        const intentReference = res?.custom_id || res?.supplementary_data?.related_ids?.order_id || res?.invoice_id;
        return { intentReference, providerReference, amountMinor, currency, success };
      }
      return null;
    } catch (e) {
      this.logger.warn(`extractFundingPayload error: ${(e as Error)?.message}`);
      return null;
    }
  }

  // Paystack callback handler: verify transaction by reference and resolve funding intent
  async handlePaystackCallback(reference: string) {
    const secret = await this.resolveGatewaySecret('paystack');
    if (!secret) {
      this.logger.warn('PAYSTACK_SECRET not configured; skipping callback verification');
      return { ok: false, error: 'PAYSTACK_SECRET not configured' };
    }
    const res = await fetch(`https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`, {
      headers: { Authorization: `Bearer ${secret}` },
    });
    const json: any = await res.json();
    if (!res.ok || !json?.status) {
      return { ok: false, error: json?.message || 'Verification failed' };
    }
    const body = json?.data || json;
    const result = await this.handleProviderFundingEvent('paystack', { event: 'charge.success', data: body }, true);
    // Return success only if the funding event was processed successfully
    const success = result?.ok;
    return { ok: success, verified: success, result };
  }
}
