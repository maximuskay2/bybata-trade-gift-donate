import { PaypalClient, PaypalFetch } from './paypal.client';

describe('PaypalClient', () => {
  const original = { ...process.env };

  afterEach(() => {
    process.env = { ...original };
  });

  it('caches the OAuth token across calls', async () => {
    process.env.PAYPAL_ENV = 'sandbox';
    process.env.PAYPAL_CLIENT_ID = 'client';
    process.env.PAYPAL_CLIENT_SECRET = 'secret';
    let calls = 0;
    const http: PaypalFetch = async (url) => {
      calls += 1;
      expect(url).toContain('api-m.sandbox.paypal.com/v1/oauth2/token');
      return jsonResponse({ access_token: 'tok', expires_in: 300 });
    };
    const client = new PaypalClient(http);
    await expect(client.getAccessToken()).resolves.toBe('tok');
    await expect(client.getAccessToken()).resolves.toBe('tok');
    expect(calls).toBe(1);
  });

  it('uses the live host only when PAYPAL_ENV=live', () => {
    process.env.PAYPAL_ENV = 'live';
    expect(new PaypalClient().baseUrl()).toBe('https://api-m.paypal.com');
    process.env.PAYPAL_ENV = 'sandbox';
    expect(new PaypalClient().baseUrl()).toBe('https://api-m.sandbox.paypal.com');
  });

  it('creates a demo order without calling PayPal when demo mode is on', async () => {
    delete process.env.PAYPAL_CLIENT_ID;
    delete process.env.PAYPAL_CLIENT_SECRET;
    process.env.PAYPAL_DEMO_MODE = '1';
    const http: PaypalFetch = async () => {
      throw new Error('network should not be used');
    };
    const order = await new PaypalClient(http).createOrder({
      amount: '12.00',
      currency: 'USD',
      customId: 'topup',
      returnUrl: 'http://localhost:3000/v1/trade-topups/paypal/return?topUpId=1',
      cancelUrl: 'http://localhost:3000/cancel',
    });
    expect(order.demo).toBe(true);
    expect(order.id.startsWith('DEMO-')).toBe(true);
    expect(order.approveLink).toContain('token=');
  });

  it('accepts a webhook only when PayPal says SUCCESS', async () => {
    process.env.PAYPAL_CLIENT_ID = 'client';
    process.env.PAYPAL_CLIENT_SECRET = 'secret';
    process.env.PAYPAL_WEBHOOK_ID = 'wh';
    process.env.PAYPAL_ENV = 'sandbox';
    const http: PaypalFetch = async (url) => {
      if (String(url).includes('oauth2/token')) return jsonResponse({ access_token: 'tok', expires_in: 300 });
      return jsonResponse({ verification_status: 'SUCCESS' });
    };
    const ok = await new PaypalClient(http).verifyWebhook({
      body: { event_type: 'PAYMENT.CAPTURE.COMPLETED' },
      transmissionId: 't',
      transmissionTime: new Date().toISOString(),
      certUrl: 'https://api.paypal.com/cert',
      authAlgo: 'SHA256withRSA',
      transmissionSig: 'sig',
    });
    expect(ok).toBe(true);
  });
});

function jsonResponse(body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}
