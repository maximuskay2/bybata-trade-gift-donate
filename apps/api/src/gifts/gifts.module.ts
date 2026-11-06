import { Module } from '@nestjs/common';
import { GiftsController } from './gifts.controller';
import { GiftsService } from './gifts.service';
import { GiftsSchedulerService } from './gifts.scheduler';
import { PrismaModule } from '../common/prisma.module';
import { ListingUnreadModule } from '../common/listing-unread.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { KarmaModule } from '../karma/karma.module';
import { EmailService } from '../common/email.service';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [PrismaModule, ListingUnreadModule, NotificationsModule, StorageModule, KarmaModule],
  controllers: [GiftsController],
  providers: [GiftsService, GiftsSchedulerService, EmailService],
  exports: [GiftsService],
})
export class GiftsModule {}
