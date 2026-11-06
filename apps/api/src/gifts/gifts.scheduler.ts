import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { GiftsService } from './gifts.service';

/**
 * Cron job to auto-expire PENDING gift requests when the owner does not
 * approve or decline within the configured days (default 2).
 */
@Injectable()
export class GiftsSchedulerService {
  private readonly logger = new Logger(GiftsSchedulerService.name);

  constructor(private gifts: GiftsService) {}

  @Cron(process.env.GIFT_REQUEST_EXPIRE_CRON ?? CronExpression.EVERY_DAY_AT_2AM)
  async expireStaleGiftRequests() {
    const days = Number(process.env.GIFT_REQUEST_EXPIRE_DAYS ?? 2);
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const count = await this.gifts.expireStaleGiftRequests(cutoff);
    if (count > 0) {
      this.logger.log(
        `Expired ${count} gift request(s) (no owner response since ${cutoff.toISOString()})`,
      );
    }
  }
}
