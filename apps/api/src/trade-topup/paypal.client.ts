import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { randomBytes } from 'crypto';

export type PaypalFetch = (input: string, init?: RequestInit) => Promise<Response>;

/** Optional Nest token so unit tests can pass a mock fetch by hand. */
export const PAYPAL_HTTP = 'PAYPAL_HTTP';

export interface PaypalOrder {
  id: string;
  approveLink: string;
  demo: boolean;
}

export interface PaypalCapture {
  captureId: string;
  status: string;
  demo: boolean;
}

export interface PaypalRefund {
  refundId: string;
  status: string;
  demo: boolean;
}

interface CachedToken {
  value: string;
  expiresAt: number;
}

/**
 * PayPal Orders v2, Payments v2 refunds, and webhook signature checks.
 * Sandbox is the default. Live is used only when PAYPAL_ENV=live.
 */
@Injectable()
export class PaypalClient {
  private readonly logger = new Logger(PaypalClient.name);
  private readonly http: PaypalFetch;
  private token: CachedToken | null = null;

  constructor(@Optional() @Inject(PAYPAL_HTTP) http?: PaypalFetch) {
    // Nest would otherwise try to inject the Function type alias as a provider.
    this.http = http ?? defaultFetch;
  }

  baseUrl(): string {
    const env = (process.env.PAYPAL_ENV || 'sandbox').trim().toLowerCase();
    return env === 'live' ? 'https://api-m.paypal.com' : 'https://api-m.sandbox.paypal.com';
  }

  demoMode(): boolean {
    return process.env.PAYPAL_DEMO_MODE === '1' && !this.hasCredentials();
  }

  hasCredentials(): boolean {
    return Boolean(this.clientId() && this.clientSecret());
  }

  async getAccessToken(): Promise<string> {
    if (this.token && this.token.expiresAt > Date.now() + 30_000) {
      return this.token.value;
    }
    const clientId = this.clientId();
    const clientSecret = this.clientSecret();
    if (!clientId || !clientSecret) {
      throw new Error('PayPal credentials are not configured');
    }
    const res = await this.http(`${this.baseUrl()}/v1/oauth2/token`, {
      method: 'POST',
      headers: {
        Authorization: 'Basic ' + Buffer.from(`${clientId}:${clientSecret}`).toString('base64'),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials',
    });
    const json = await readJson(res);
    if (!res.ok || !json?.access_token) {
      throw new Error(`PayPal OAuth failed (${res.status})`);
    }
    const expiresIn = Number(json.expires_in) || 300;
    this.token = {
      value: String(json.access_token),
      expiresAt: Date.now() + expiresIn * 1000,
    };
    return this.token.value;
  }

  async createOrder(input: {
    amount: string;
    currency: string;
    customId: string;
    returnUrl: string;
    cancelUrl: string;
  }): Promise<PaypalOrder> {
    if (this.demoMode()) {
      const id = `DEMO-${randomBytes(6).toString('hex')}`;
      const join = input.returnUrl.includes('?') ? '&' : '?';
      return {
        id,
        approveLink: `${input.returnUrl}${join}token=${encodeURIComponent(id)}`,
        demo: true,
      };
    }
    const token = await this.getAccessToken();
    const res = await this.http(`${this.baseUrl()}/v2/checkout/orders`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        intent: 'CAPTURE',
        purchase_units: [
          {
            custom_id: input.customId,
            amount: { currency_code: input.currency, value: input.amount },
            description: 'Bybata trade top-up',
          },
        ],
        application_context: {
          return_url: input.returnUrl,
          cancel_url: input.cancelUrl,
          brand_name: 'Bybata',
          user_action: 'PAY_NOW',
          shipping_preference: 'NO_SHIPPING',
        },
      }),
    });
    const json = await readJson(res);
    const approveLink = (json?.links || []).find((link: { rel?: string }) => link.rel === 'approve')?.href;
    if (!res.ok || !json?.id || !approveLink) {
      this.logger.error(`PayPal order failed: ${json?.message || res.status}`);
      throw new Error(json?.message || 'PayPal order creation failed');
    }
    return { id: String(json.id), approveLink: String(approveLink), demo: false };
  }

  async captureOrder(orderId: string): Promise<PaypalCapture> {
    if (orderId.startsWith('DEMO-')) {
      return { captureId: orderId.replace('DEMO-', 'DEMOCAP-'), status: 'COMPLETED', demo: true };
    }
    const token = await this.getAccessToken();
    const res = await this.http(`${this.baseUrl()}/v2/checkout/orders/${encodeURIComponent(orderId)}/capture`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });
    const json = await readJson(res);
    const capture = json?.purchase_units?.[0]?.payments?.captures?.[0];
    if (!res.ok || !capture?.id) {
      throw new Error(json?.message || 'PayPal capture failed');
    }
    return { captureId: String(capture.id), status: String(capture.status || json.status || 'COMPLETED'), demo: false };
  }

  async refundCapture(captureId: string, amount: string, currency: string): Promise<PaypalRefund> {
    if (captureId.startsWith('DEMOCAP-') || this.demoMode()) {
      return { refundId: `DEMOREF-${randomBytes(4).toString('hex')}`, status: 'COMPLETED', demo: true };
    }
    const token = await this.getAccessToken();
    const res = await this.http(`${this.baseUrl()}/v2/payments/captures/${encodeURIComponent(captureId)}/refund`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: { value: amount, currency_code: currency },
      }),
    });
    const json = await readJson(res);
    if (!res.ok || !json?.id) {
      throw new Error(json?.message || 'PayPal refund failed');
    }
    return { refundId: String(json.id), status: String(json.status || 'COMPLETED'), demo: false };
  }

  async verifyWebhook(input: {
    body: unknown;
    transmissionId?: string;
    transmissionTime?: string;
    certUrl?: string;
    authAlgo?: string;
    transmissionSig?: string;
  }): Promise<boolean> {
    if (process.env.PAYPAL_E2E_ALLOW_FAKE === '1') return true;
    const webhookId = process.env.PAYPAL_WEBHOOK_ID?.trim();
    if (!webhookId || !this.hasCredentials()) return false;
    if (!input.transmissionId || !input.transmissionSig || !input.transmissionTime || !input.certUrl || !input.authAlgo) {
      return false;
    }
    const token = await this.getAccessToken();
    const res = await this.http(`${this.baseUrl()}/v1/notifications/verify-webhook-signature`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        auth_algo: input.authAlgo,
        cert_url: input.certUrl,
        transmission_id: input.transmissionId,
        transmission_sig: input.transmissionSig,
        transmission_time: input.transmissionTime,
        webhook_id: webhookId,
        webhook_event: input.body,
      }),
    });
    const json = await readJson(res);
    return res.ok && json?.verification_status === 'SUCCESS';
  }

  private clientId(): string {
    return (process.env.PAYPAL_CLIENT_ID || '').trim();
  }

  private clientSecret(): string {
    return (process.env.PAYPAL_CLIENT_SECRET || process.env.PAYPAL_SECRET || '').trim();
  }
}

function defaultFetch(input: string, init?: RequestInit): Promise<Response> {
  return fetch(input, init);
}

async function readJson(res: Response): Promise<any> {
  try {
    return await res.json();
  } catch {
    return null;
  }
}
