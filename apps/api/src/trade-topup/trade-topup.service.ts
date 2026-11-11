import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, TradeTopUpStatus } from '@prisma/client';
import { PrismaService } from '../common/prisma.service';
import { FairValueAssistant } from './fair-value.assistant';
import { normalizeCondition, roundMoney, topUpCapUsd } from './fair-value';
import { PaypalClient } from './paypal.client';
import { nextTopUpState, TopUpAction } from './topup-state';

const ACTIVE_STATUSES: TradeTopUpStatus[] = [
  TradeTopUpStatus.SUGGESTED,
  TradeTopUpStatus.COUNTERED,
  TradeTopUpStatus.ACCEPTED,
  TradeTopUpStatus.ORDER_CREATED,
  TradeTopUpStatus.CAPTURED,
  TradeTopUpStatus.REFUND_PENDING,
];

@Injectable()
export class TradeTopUpService {
  private readonly logger = new Logger(TradeTopUpService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly assistant: FairValueAssistant,
    private readonly paypal: PaypalClient,
  ) {}

  async suggest(
    userId: string,
    tradeId: string,
    offerId: string,
    body?: { ownerCondition?: string; bidderCondition?: string },
  ) {
    const offer = await this.loadOffer(tradeId, offerId);
    this.assertOfferParty(userId, offer);
    if (!offer.offeredTrade) {
      throw new BadRequestException('Add an item to this offer before evening the trade. Cash gifts and donations stay free.');
    }

    const existing = await this.prisma.tradeTopUp.findFirst({
      where: { offerId, status: { in: ACTIVE_STATUSES } },
      orderBy: { createdAt: 'desc' },
    });
    if (existing) return this.toDto(existing);

    const quote = await this.assistant.suggest(
      {
        role: 'owner',
        title: offer.trade.title,
        category: offer.trade.category,
        condition: normalizeCondition(body?.ownerCondition || readCondition(offer.trade.metadata)),
        photos: offer.trade.mediaKeys,
      },
      {
        role: 'bidder',
        title: offer.offeredTrade.title,
        category: offer.offeredTrade.category,
        condition: normalizeCondition(body?.bidderCondition || readCondition(offer.offeredTrade.metadata)),
        photos: offer.offeredTrade.mediaKeys,
      },
    );

    const payerId = quote.payerRole === 'owner' ? offer.trade.ownerId : offer.bidderId;
    const payeeId = payerId === offer.trade.ownerId ? offer.bidderId : offer.trade.ownerId;
    const even = quote.amount === 0;
    const created = await this.prisma.tradeTopUp.create({
      data: {
        tradeId,
        offerId,
        payerId,
        payeeId,
        amount: money(quote.amount),
        currency: 'USD',
        status: even ? TradeTopUpStatus.ACCEPTED : TradeTopUpStatus.SUGGESTED,
        aiReason: quote.reason,
        confidence: quote.confidence,
        source: quote.source,
        capped: quote.capped,
        payerAccepted: even,
        payeeAccepted: even,
      },
    });
    return this.toDto(created);
  }

  async list(userId: string, tradeId: string) {
    await this.assertTradeParty(userId, tradeId);
    const rows = await this.prisma.tradeTopUp.findMany({
      where: { tradeId },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((row) => this.toDto(row));
  }

  async respond(userId: string, id: string, action: TopUpAction, amount?: number) {
    const row = await this.findForParty(userId, id);
    let next;
    try {
      next = nextTopUpState(
        {
          payerId: row.payerId,
          payeeId: row.payeeId,
          amount: Number(row.amount),
          status: row.status,
          payerAccepted: row.payerAccepted,
          payeeAccepted: row.payeeAccepted,
          aiReason: row.aiReason,
          counteredById: row.counteredById,
          capped: row.capped,
        },
        userId,
        action,
        amount,
        topUpCapUsd(),
      );
    } catch (error) {
      throw new BadRequestException((error as Error).message);
    }
    const updated = await this.prisma.tradeTopUp.update({
      where: { id: row.id },
      data: {
        amount: money(next.amount),
        status: next.status as TradeTopUpStatus,
        payerAccepted: next.payerAccepted,
        payeeAccepted: next.payeeAccepted,
        aiReason: next.aiReason,
        counteredById: next.counteredById,
        capped: next.capped,
        approveLink: next.status === 'DECLINED' ? null : row.approveLink,
      },
    });
    return this.toDto(updated);
  }

  async createPaypalOrder(userId: string, id: string) {
    const row = await this.findForParty(userId, id);
    if (row.payerId !== userId) {
      throw new ForbiddenException('Only the person who owes the top-up can pay');
    }
    if (row.status !== TradeTopUpStatus.ACCEPTED && row.status !== TradeTopUpStatus.ORDER_CREATED) {
      throw new BadRequestException('Both people need to accept the amount before PayPal checkout');
    }
    if (Number(row.amount) <= 0) {
      throw new BadRequestException('This trade is already even, so there is nothing to pay');
    }
    if (!this.paypal.hasCredentials() && !this.paypal.demoMode()) {
      throw new BadRequestException(
        'PayPal is not configured. Set PAYPAL_CLIENT_ID and PAYPAL_CLIENT_SECRET, or PAYPAL_DEMO_MODE=1 for a local walkthrough.',
      );
    }
    if (row.status === TradeTopUpStatus.ORDER_CREATED && row.paypalOrderId && row.approveLink) {
      return this.toDto(row);
    }

    const apiBase = apiBaseUrl();
    const returnUrl = `${apiBase}/v1/trade-topups/paypal/return?topUpId=${encodeURIComponent(row.id)}`;
    const cancelUrl = `${apiBase}/v1/trade-topups/paypal/cancel?topUpId=${encodeURIComponent(row.id)}`;
    const order = await this.paypal.createOrder({
      amount: Number(row.amount).toFixed(2),
      currency: row.currency || 'USD',
      customId: row.id,
      returnUrl,
      cancelUrl,
    });
    const updated = await this.prisma.tradeTopUp.update({
      where: { id: row.id },
      data: {
        paypalOrderId: order.id,
        approveLink: order.approveLink,
        status: TradeTopUpStatus.ORDER_CREATED,
      },
    });
    return this.toDto(updated);
  }

  async capture(userId: string, id: string, orderId?: string) {
    const row = await this.findForParty(userId, id);
    return this.captureRow(row, orderId || row.paypalOrderId || undefined);
  }

  async captureReturn(topUpId?: string, orderId?: string) {
    if (!topUpId) throw new BadRequestException('Missing top-up');
    const row = await this.prisma.tradeTopUp.findUnique({ where: { id: topUpId } });
    if (!row) throw new NotFoundException('Top-up not found');
    return this.captureRow(row, orderId || row.paypalOrderId || undefined);
  }

  async refundCapturedForTrade(tradeId: string, reason: string) {
    const rows = await this.prisma.tradeTopUp.findMany({
      where: { tradeId, status: TradeTopUpStatus.CAPTURED },
    });
    return Promise.all(rows.map((row) => this.refundRow(row, reason)));
  }

  async refundCapturedForOffer(offerId: string, reason: string) {
    const rows = await this.prisma.tradeTopUp.findMany({
      where: { offerId, status: TradeTopUpStatus.CAPTURED },
    });
    return Promise.all(rows.map((row) => this.refundRow(row, reason)));
  }

  async handleWebhook(body: any, verified: boolean) {
    if (!verified) return { ok: false, error: 'invalid_signature' };
    const event = String(body?.event_type || '');
    const resource = body?.resource || {};
    const captureId = resource?.id ? String(resource.id) : undefined;
    const orderId =
      resource?.supplementary_data?.related_ids?.order_id ||
      resource?.supplementary_data?.related_ids?.orderId ||
      undefined;
    const customId = resource?.custom_id ? String(resource.custom_id) : undefined;

    if (event === 'PAYMENT.CAPTURE.COMPLETED') {
      const row = await this.findByPaypal(customId, orderId, captureId);
      if (!row) return { ok: true, ignored: true };
      if (row.status === TradeTopUpStatus.REFUNDED) return { ok: true, duplicate: true };
      const updated = await this.prisma.tradeTopUp.update({
        where: { id: row.id },
        data: {
          status: TradeTopUpStatus.CAPTURED,
          captureId: captureId || row.captureId,
          paypalOrderId: row.paypalOrderId || (orderId ? String(orderId) : undefined),
        },
      });
      return { ok: true, topUp: this.toDto(updated) };
    }

    if (event === 'PAYMENT.CAPTURE.REFUNDED') {
      const linkedCapture = captureIdFromLinks(resource?.links);
      const row = await this.findByPaypal(customId, orderId, linkedCapture);
      const byCapture = row || (linkedCapture
        ? await this.prisma.tradeTopUp.findFirst({ where: { captureId: linkedCapture } })
        : null);
      if (!byCapture) return { ok: true, ignored: true };
      const updated = await this.prisma.tradeTopUp.update({
        where: { id: byCapture.id },
        data: {
          status: TradeTopUpStatus.REFUNDED,
          refundId: captureId && captureId !== byCapture.captureId ? captureId : byCapture.refundId,
        },
      });
      return { ok: true, topUp: this.toDto(updated) };
    }

    return { ok: true, ignored: true };
  }

  private async captureRow(row: {
    id: string;
    status: TradeTopUpStatus;
    paypalOrderId: string | null;
    captureId: string | null;
    amount: Prisma.Decimal;
    currency: string;
  }, orderId?: string) {
    if (row.status === TradeTopUpStatus.CAPTURED || row.status === TradeTopUpStatus.REFUNDED) {
      const current = await this.prisma.tradeTopUp.findUnique({ where: { id: row.id } });
      return this.toDto(current!);
    }
    const paypalOrderId = orderId || row.paypalOrderId;
    if (!paypalOrderId) throw new BadRequestException('No PayPal order to capture');
    if (row.paypalOrderId && paypalOrderId !== row.paypalOrderId) {
      throw new BadRequestException('This payment does not match the top-up');
    }
    const captured = await this.paypal.captureOrder(paypalOrderId);
    const updated = await this.prisma.tradeTopUp.update({
      where: { id: row.id },
      data: {
        status: TradeTopUpStatus.CAPTURED,
        paypalOrderId,
        captureId: captured.captureId,
      },
    });
    return this.toDto(updated);
  }

  private async refundRow(row: {
    id: string;
    captureId: string | null;
    amount: Prisma.Decimal;
    currency: string;
    aiReason: string | null;
  }, reason: string) {
    if (!row.captureId) {
      throw new BadRequestException('This top-up has no PayPal capture to refund');
    }
    await this.prisma.tradeTopUp.update({
      where: { id: row.id },
      data: { status: TradeTopUpStatus.REFUND_PENDING },
    });
    try {
      const refund = await this.paypal.refundCapture(
        row.captureId,
        Number(row.amount).toFixed(2),
        row.currency || 'USD',
      );
      const updated = await this.prisma.tradeTopUp.update({
        where: { id: row.id },
        data: {
          status: TradeTopUpStatus.REFUNDED,
          refundId: refund.refundId,
          aiReason: row.aiReason,
        },
      });
      this.logger.log(`Refunded trade top-up ${row.id} (${reason})`);
      return this.toDto(updated);
    } catch (error) {
      await this.prisma.tradeTopUp.update({
        where: { id: row.id },
        data: { status: TradeTopUpStatus.CAPTURED },
      });
      throw error;
    }
  }

  private async findByPaypal(customId?: string, orderId?: string, captureId?: string) {
    if (customId) {
      const byId = await this.prisma.tradeTopUp.findUnique({ where: { id: customId } });
      if (byId) return byId;
    }
    if (orderId) {
      const byOrder = await this.prisma.tradeTopUp.findUnique({ where: { paypalOrderId: String(orderId) } });
      if (byOrder) return byOrder;
    }
    if (captureId) {
      return this.prisma.tradeTopUp.findFirst({ where: { captureId } });
    }
    return null;
  }

  private async loadOffer(tradeId: string, offerId: string) {
    const offer = await this.prisma.tradeOffer.findUnique({
      where: { id: offerId },
      include: {
        trade: true,
        offeredTrade: true,
      },
    });
    if (!offer || offer.tradeId !== tradeId) throw new NotFoundException('Offer not found');
    return offer;
  }

  private assertOfferParty(userId: string, offer: { bidderId: string; trade: { ownerId: string } }) {
    if (userId !== offer.trade.ownerId && userId !== offer.bidderId) {
      throw new ForbiddenException('Only the two people in this trade can even it');
    }
  }

  private async assertTradeParty(userId: string, tradeId: string) {
    const trade = await this.prisma.trade.findUnique({
      where: { id: tradeId },
      include: { offers: { select: { bidderId: true } } },
    });
    if (!trade) throw new NotFoundException('Trade not found');
    const involved = trade.ownerId === userId || trade.offers.some((offer) => offer.bidderId === userId);
    if (!involved) throw new ForbiddenException('Only the people in this trade can view the top-up');
    return trade;
  }

  private async findForParty(userId: string, id: string) {
    const row = await this.prisma.tradeTopUp.findUnique({ where: { id } });
    if (!row) throw new NotFoundException('Top-up not found');
    if (row.payerId !== userId && row.payeeId !== userId) {
      throw new ForbiddenException('Only the two people in this trade can update the top-up');
    }
    return row;
  }

  private toDto(row: {
    id: string;
    tradeId: string;
    offerId: string;
    payerId: string;
    payeeId: string;
    amount: Prisma.Decimal | number | string;
    currency: string;
    paypalOrderId: string | null;
    captureId: string | null;
    refundId: string | null;
    status: TradeTopUpStatus | string;
    aiReason: string | null;
    confidence: number | null;
    source: string;
    payerAccepted: boolean;
    payeeAccepted: boolean;
    counteredById: string | null;
    capped: boolean;
    approveLink: string | null;
  }) {
    return {
      id: row.id,
      tradeId: row.tradeId,
      offerId: row.offerId,
      payerId: row.payerId,
      payeeId: row.payeeId,
      amount: roundMoney(Number(row.amount)),
      currency: row.currency,
      paypalOrderId: row.paypalOrderId,
      captureId: row.captureId,
      refundId: row.refundId,
      status: row.status,
      aiReason: row.aiReason,
      confidence: row.confidence,
      source: row.source,
      payerAccepted: row.payerAccepted,
      payeeAccepted: row.payeeAccepted,
      counteredById: row.counteredById,
      capped: row.capped,
      approveLink: row.approveLink,
    };
  }
}

function captureIdFromLinks(links: Array<{ rel?: string; href?: string }> | undefined): string | undefined {
  const href = links?.find((link) => link.rel === 'up' && String(link.href || '').includes('/captures/'))?.href;
  if (!href) return undefined;
  const id = href.split('/captures/')[1]?.split(/[?#]/)[0];
  return id || undefined;
}

function money(amount: number): string {
  return roundMoney(amount).toFixed(2);
}

function readCondition(metadata: Prisma.JsonValue | null | undefined): string | undefined {
  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) return undefined;
  const value = (metadata as Record<string, unknown>).condition;
  return typeof value === 'string' ? value : undefined;
}

export function apiBaseUrl(): string {
  const explicit = (process.env.API_PUBLIC_URL || process.env.API_PUBLIC_BASE_URL || '').trim();
  if (explicit) return explicit.replace(/\/+$/, '');
  const railway = (process.env.RAILWAY_PUBLIC_DOMAIN || '').trim();
  if (railway) return `https://${railway.replace(/^https?:\/\//, '').replace(/\/+$/, '')}`;
  const port = process.env.PORT || '3000';
  return `http://localhost:${port}`;
}
