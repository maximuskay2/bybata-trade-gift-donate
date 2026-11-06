import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { AdSchedulingService } from '../wallet/ad-scheduling.service';

@Injectable()
export class AdsSchedulerService {
  private readonly logger = new Logger(AdsSchedulerService.name);

  constructor(private readonly adScheduling: AdSchedulingService) {}

  /** Activate scheduled ads and expire ended ads. */
  @Cron(process.env.AD_SCHEDULE_CRON ?? CronExpression.EVERY_5_MINUTES)
  async handleScheduledAds(): Promise<void> {
    try {
      await this.adScheduling.processScheduledAds();
    } catch (err) {
      this.logger.error(
        'processScheduledAds failed',
        err instanceof Error ? err.stack : err,
      );
    }
  }
}
