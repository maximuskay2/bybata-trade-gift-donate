import { Controller, Post, UseGuards, Query, Get, Param } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { PaymentsService } from '../payments/payments.service';
import { PrismaService } from '../common/prisma.service';

/**
 * Admin controller for webhook management and reconciliation
 */
@Controller('v1/admin/webhooks')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminWebhooksController {
  constructor(
    private payments: PaymentsService,
    private prisma: PrismaService,
  ) {}

  /**
   * Reconcile unprocessed webhooks
   * Manually trigger reconciliation of verified but unprocessed webhook events
   */
  @Post('reconcile')
  async reconcile(@Query('limit') limitStr?: string) {
    const limit = Math.min(Math.max(parseInt(limitStr ?? '50', 10) || 50, 1), 200);
    const result = await this.payments.reconcileUnprocessedWebhooks(limit);
    return result;
  }

  /**
   * List webhook events with filters
   */
  @Get()
  async list(
    @Query('gateway') gateway?: string,
    @Query('verified') verified?: string,
    @Query('processed') processed?: string,
    @Query('limit') limitStr?: string,
    @Query('offset') offsetStr?: string,
  ) {
    const limit = Math.min(Math.max(parseInt(limitStr ?? '50', 10) || 50, 1), 200);
    const offset = Math.max(parseInt(offsetStr ?? '0', 10) || 0, 0);

    const where: any = {};
    if (gateway) where.gateway = gateway;
    if (verified !== undefined) where.verified = verified === 'true' || verified === '1';
    if (processed !== undefined) where.processed = processed === 'true' || processed === '1';

    const [items, total] = await Promise.all([
      (this.prisma as any).webhookEvent.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: limit,
        skip: offset,
      }),
      (this.prisma as any).webhookEvent.count({ where }),
    ]);

    return {
      items,
      total,
      limit,
      offset,
    };
  }

  /**
   * Get webhook event details
   */
  @Get(':id')
  async get(@Param('id') id: string) {
    const event = await (this.prisma as any).webhookEvent.findUnique({
      where: { id },
    });
    if (!event) {
      return { ok: false, error: 'Webhook event not found' };
    }
    return { ok: true, event };
  }
}

