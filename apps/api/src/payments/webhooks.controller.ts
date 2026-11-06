import { Body, Controller, Headers, Post, Req, HttpCode } from '@nestjs/common';
import type { Request } from 'express';
import { PaymentsService } from './payments.service';

// Real webhook verification scaffolds for Paystack, Stripe, and PayPal.
// Note: To verify signatures correctly, configure raw-body parsing for these routes in the Nest bootstrap.
@Controller('v1/wallet/webhooks')
export class WebhooksController {
  constructor(private payments: PaymentsService) {}

  // Paystack: header `x-paystack-signature` is HMAC-SHA512 of the raw request body using webhook secret.
  @Post('paystack')
  @HttpCode(200)
  async paystackWebhook(
    @Req() req: Request,
    @Body() body: any,
    @Headers('x-paystack-signature') signature?: string,
  ) {
    const rawBuf: Buffer = (req as any).body && Buffer.isBuffer((req as any).body)
      ? (req as any).body
      : Buffer.from(typeof body === 'string' ? body : JSON.stringify(body ?? {}));
    const raw = rawBuf.toString('utf8');
    const parsed = Buffer.isBuffer(body) ? JSON.parse(raw) : body;
    const verified = await this.payments.verifyPaystackSignature(raw, signature);
    const ack = await this.payments.handleProviderFundingEvent('paystack', parsed, verified);
    return ack;
  }

  // Stripe: header `stripe-signature` contains timestamp and signature; verify against raw body and endpoint secret.
  @Post('stripe')
  @HttpCode(200)
  async stripeWebhook(
    @Req() req: Request,
    @Body() body: any,
    @Headers('stripe-signature') stripeSig?: string,
  ) {
    const rawBuf: Buffer = (req as any).body && Buffer.isBuffer((req as any).body)
      ? (req as any).body
      : Buffer.from(typeof body === 'string' ? body : JSON.stringify(body ?? {}));
    const raw = rawBuf.toString('utf8');
    const parsed = Buffer.isBuffer(body) ? JSON.parse(raw) : body;
    const verified = await this.payments.verifyStripeSignature(raw, stripeSig);
    const ack = await this.payments.handleProviderFundingEvent('stripe', parsed, verified);
    return ack;
  }

  // PayPal: verify via REST API `verify-webhook-signature` using provided transmission headers.
  @Post('paypal')
  @HttpCode(200)
  async paypalWebhook(
    @Req() req: Request,
    @Body() body: any,
    @Headers('paypal-transmission-id') transmissionId?: string,
    @Headers('paypal-transmission-time') transmissionTime?: string,
    @Headers('paypal-cert-url') certUrl?: string,
    @Headers('paypal-auth-algo') authAlgo?: string,
    @Headers('paypal-transmission-sig') transmissionSig?: string,
  ) {
    const rawBuf: Buffer = (req as any).body && Buffer.isBuffer((req as any).body)
      ? (req as any).body
      : Buffer.from(typeof body === 'string' ? body : JSON.stringify(body ?? {}));
    const parsed = Buffer.isBuffer(body) ? JSON.parse(rawBuf.toString('utf8')) : body;
    const environment = process.env.PAYPAL_ENV || 'live';
    const verified = await this.payments.verifyPayPalWebhook({
      body: parsed,
      transmissionId,
      transmissionTime,
      certUrl,
      authAlgo,
      transmissionSig,
      environment,
    });
    const ack = await this.payments.handleProviderFundingEvent('paypal', parsed, verified);
    return ack;
  }

  // Flutterwave: header `verif-hash` equals your secret key value
  @Post('flutterwave')
  @HttpCode(200)
  async flutterwaveWebhook(
    @Req() req: Request,
    @Body() body: any,
    @Headers('verif-hash') verifHash?: string,
  ) {
    const secret = process.env.FLW_SECRET_KEY || process.env.FLUTTERWAVE_SECRET;
    const verified = !!secret && !!verifHash && secret === verifHash;
    const parsed = body;
    const ack = await this.payments.handleProviderFundingEvent('flutterwave', parsed, verified);
    return ack;
  }
}
