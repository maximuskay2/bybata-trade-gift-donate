import { Module } from '@nestjs/common';
import { PrismaModule } from '../common/prisma.module';
import { ListingUnreadModule } from '../common/listing-unread.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { KarmaModule } from '../karma/karma.module';
import { TradesService } from './trades.service';
import { TradesController } from './trades.controller';
import { OffersController } from './offers.controller';
import { TradesSchedulerService } from './trades.scheduler';
import { EmailService } from '../common/email.service';
import { StorageModule } from '../storage/storage.module';
import { TradeTopUpModule } from '../trade-topup/trade-topup.module';
@Module({
  imports: [PrismaModule, ListingUnreadModule, NotificationsModule, StorageModule, KarmaModule, TradeTopUpModule],
  providers: [TradesService, TradesSchedulerService, EmailService],
  controllers: [TradesController, OffersController],
  exports: [TradesService],
})
export class TradesModule {}
