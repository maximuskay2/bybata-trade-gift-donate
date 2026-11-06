import { Controller, Get, Query, Res } from '@nestjs/common';
import type { Response } from 'express';
import { PaymentsService } from './payments.service';

// Public callbacks for payment providers (no auth required)
@Controller('v1/wallet/fund')
export class CallbacksController {
  constructor(private payments: PaymentsService) {}

  @Get('paystack/callback')
  async paystackCallback(
    @Query('reference') reference?: string,
    @Query('redirect') redirect?: string,
    @Res() res?: Response,
  ) {
    if (!reference) return res?.json({ ok: false, error: 'Missing reference' });
    const result = await this.payments.handlePaystackCallback(reference);
    if (redirect) {
      const status = result?.ok ? 'success' : 'failed';
      const url = `${redirect}${redirect.includes('?') ? '&' : '?'}provider=paystack&status=${status}&reference=${encodeURIComponent(reference)}`;
      return res?.redirect(url);
    }
    return res?.json(result);
  }

  @Get('stripe/callback')
  async stripeCallback(
    @Query('session_id') sessionId?: string,
    @Query('redirect') redirect?: string,
    @Res() res?: Response,
  ) {
    if (!sessionId) return res?.json({ ok: false, error: 'Missing session_id' });
    const result = await this.payments.handleStripeCallback(sessionId);
    if (redirect) {
      const status = result?.ok ? 'success' : 'failed';
      const url = `${redirect}${redirect.includes('?') ? '&' : '?'}provider=stripe&status=${status}&session_id=${encodeURIComponent(sessionId)}`;
      return res?.redirect(url);
    }
    return res?.json(result);
  }

  @Get('paypal/callback')
  async paypalCallback(
    @Query('token') orderId?: string,
    @Query('redirect') redirect?: string,
    @Res() res?: Response,
  ) {
    if (!orderId) return res?.json({ ok: false, error: 'Missing order id' });
    const result = await this.payments.handlePaypalCallback(orderId);
    if (redirect) {
      const status = result?.ok ? 'success' : 'failed';
      const url = `${redirect}${redirect.includes('?') ? '&' : '?'}provider=paypal&status=${status}&order_id=${encodeURIComponent(orderId)}`;
      return res?.redirect(url);
    }
    return res?.json(result);
  }

  @Get('flutterwave/callback')
  async flutterwaveCallback(
    @Query('tx_ref') txRef?: string,
    @Query('transaction_id') transactionId?: string,
    @Query('redirect') redirect?: string,
    @Res() res?: Response,
  ) {
    const result = await this.payments.handleFlutterwaveCallback({ tx_ref: txRef, transaction_id: transactionId });
    if (redirect) {
      const status = result?.ok ? 'success' : 'failed';
      const url = `${redirect}${redirect.includes('?') ? '&' : '?'}provider=flutterwave&status=${status}&transaction_id=${encodeURIComponent(transactionId || '')}`;
      return res?.redirect(url);
    }
    return res?.json(result);
  }
}
