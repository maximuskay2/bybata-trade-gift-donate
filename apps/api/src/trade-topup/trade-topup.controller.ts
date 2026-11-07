import { BadRequestException, Body, Controller, Get, Headers, HttpCode, Param, Post, Query, Req, Res, UseGuards } from '@nestjs/common';
import type { Request, Response } from 'express';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { PaypalClient } from './paypal.client';
import { TradeTopUpService } from './trade-topup.service';
import { TopUpAction } from './topup-state';

@Controller('v1')
export class TradeTopUpController {
  constructor(
    private readonly topUps: TradeTopUpService,
    private readonly paypal: PaypalClient,
  ) {}

  @UseGuards(JwtAuthGuard)
  @Post('trades/:tradeId/offers/:offerId/even')
  even(
    @CurrentUser() user: { sub: string },
    @Param('tradeId') tradeId: string,
    @Param('offerId') offerId: string,
    @Body() body: { ownerCondition?: string; bidderCondition?: string },
  ) {
    return this.topUps.suggest(user.sub, tradeId, offerId, body);
  }

  @UseGuards(JwtAuthGuard)
  @Get('trades/:tradeId/topups')
  list(@CurrentUser() user: { sub: string }, @Param('tradeId') tradeId: string) {
    return this.topUps.list(user.sub, tradeId);
  }

  @UseGuards(JwtAuthGuard)
  @Post('trade-topups/:id/respond')
  respond(
    @CurrentUser() user: { sub: string },
    @Param('id') id: string,
    @Body() body: { action?: TopUpAction; amount?: number },
  ) {
    const action = body?.action;
    if (action !== 'accept' && action !== 'decline' && action !== 'counter') {
      throw new BadRequestException('action must be accept, decline, or counter');
    }
    return this.topUps.respond(user.sub, id, action, body.amount);
  }

  @UseGuards(JwtAuthGuard)
  @Post('trade-topups/:id/paypal/order')
  order(@CurrentUser() user: { sub: string }, @Param('id') id: string) {
    return this.topUps.createPaypalOrder(user.sub, id);
  }

  @UseGuards(JwtAuthGuard)
  @Post('trade-topups/:id/paypal/capture')
  capture(
    @CurrentUser() user: { sub: string },
    @Param('id') id: string,
    @Body() body: { orderId?: string },
  ) {
    return this.topUps.capture(user.sub, id, body?.orderId);
  }

  @Get('trade-topups/paypal/return')
  async paypalReturn(
    @Query('topUpId') topUpId: string,
    @Query('token') token: string,
    @Res() res: Response,
  ) {
    try {
      const topUp = await this.topUps.captureReturn(topUpId, token);
      res.status(200).type('html').send(renderResult(topUp, 'Payment received'));
    } catch (error) {
      res.status(400).type('html').send(renderResult(null, (error as Error).message || 'Payment failed'));
    }
  }

  @Get('trade-topups/paypal/cancel')
  paypalCancel(@Query('topUpId') topUpId: string, @Res() res: Response) {
    res.status(200).type('html').send(renderResult(
      { id: topUpId, status: 'ORDER_CREATED', amount: null, currency: 'USD' },
      'PayPal checkout was cancelled. You can try again in the app.',
    ));
  }

  @Post('trade-topups/paypal/webhook')
  @HttpCode(200)
  async webhook(
    @Req() req: Request,
    @Body() body: any,
    @Headers('paypal-transmission-id') transmissionId?: string,
    @Headers('paypal-transmission-time') transmissionTime?: string,
    @Headers('paypal-cert-url') certUrl?: string,
    @Headers('paypal-auth-algo') authAlgo?: string,
    @Headers('paypal-transmission-sig') transmissionSig?: string,
  ) {
    const parsed = parseWebhookBody(req, body);
    const verified = await this.paypal.verifyWebhook({
      body: parsed,
      transmissionId,
      transmissionTime,
      certUrl,
      authAlgo,
      transmissionSig,
    });
    return this.topUps.handleWebhook(parsed, verified);
  }
}

function parseWebhookBody(req: Request, body: any) {
  const raw = (req as any).body;
  if (Buffer.isBuffer(raw)) {
    try {
      return JSON.parse(raw.toString('utf8'));
    } catch {
      return {};
    }
  }
  if (Buffer.isBuffer(body)) {
    try {
      return JSON.parse(body.toString('utf8'));
    } catch {
      return {};
    }
  }
  return body ?? {};
}

function renderResult(
  topUp: { id?: string; status?: string; amount?: number | null; currency?: string } | null,
  title: string,
) {
  const status = topUp?.status || 'UNKNOWN';
  const amount = topUp?.amount != null ? `${topUp.currency || 'USD'} ${Number(topUp.amount).toFixed(2)}` : '';
  const deepLink = topUp?.id
    ? `bybata://trade-topup/done?topUpId=${encodeURIComponent(topUp.id)}&status=${encodeURIComponent(status)}`
    : 'bybata://trade-topup/done';
  return `<!doctype html>
<html>
<head><meta charset="utf-8"><title>${escapeHtml(title)}</title></head>
<body style="font-family: sans-serif; padding: 32px;">
  <h1>${escapeHtml(title)}</h1>
  <p>${escapeHtml(amount)} ${escapeHtml(status)}</p>
  <p><a href="${deepLink}">Return to Bybata</a></p>
</body>
</html>`;
}

function escapeHtml(value: string) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
