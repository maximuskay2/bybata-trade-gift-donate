import { Module } from '@nestjs/common';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { PushNotificationService } from './push-notification.service';
import { NearbyListingNotifierService } from './nearby-listing-notifier.service';
import { PrismaModule } from '../common/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    PushNotificationService,
    NearbyListingNotifierService,
  ],
  exports: [
    NotificationsService,
    PushNotificationService,
    NearbyListingNotifierService,
  ],
})
export class NotificationsModule {}
