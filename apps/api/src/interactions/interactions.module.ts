import { Module } from '@nestjs/common';
import { InteractionsController } from './interactions.controller';
import { InteractionsService } from './interactions.service';
import { ChatModule } from '../chat/chat.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { KarmaModule } from '../karma/karma.module';
import { ReferralsModule } from '../referrals/referrals.module';
import { PrismaModule } from '../common/prisma.module';

@Module({
  imports: [
    PrismaModule,
    ChatModule,
    NotificationsModule,
    KarmaModule,
    ReferralsModule,
  ],
  controllers: [InteractionsController],
  providers: [InteractionsService],
  exports: [InteractionsService],
})
export class InteractionsModule {}
