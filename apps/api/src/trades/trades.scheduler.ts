import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { TradesService } from './trades.service';

/**
 * Cron job to auto-withdraw PENDING offers with no activity for 3+ days.
 * Activity = offer update (e.g. postMessage touches offer.updatedAt) or offer creation.
 */
@Injectable()
export class TradesSchedulerService {
  private readonly logger = new Logger(TradesSchedulerService.name);

  constructor(private trades: TradesService) {}

  @Cron(process.env.TRADE_AUTO_WITHDRAW_CRON ?? CronExpression.EVERY_DAY_AT_2AM)
  async autoWithdrawStaleOffers() {
    const days = Number(process.env.TRADE_INACTIVITY_DAYS ?? 3);
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const count = await this.trades.autoWithdrawStaleOffers(cutoff);
    if (count > 0) {
      this.logger.log(`Auto-withdrew ${count} stale offer(s) (no activity since ${cutoff.toISOString()})`);
    }
  }
}
