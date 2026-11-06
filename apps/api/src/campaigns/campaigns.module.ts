import { Module } from '@nestjs/common';
import { CampaignsController } from './campaigns.controller';
import { CampaignsService } from './campaigns.service';
import { PrismaModule } from '../common/prisma.module';
import { ListingUnreadModule } from '../common/listing-unread.module';
import { WalletModule } from '../wallet/wallet.module';
import { ChatModule } from '../chat/chat.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { EmailService } from '../common/email.service';
import { StorageModule } from '../storage/storage.module';
import { ReferralsModule } from '../referrals/referrals.module';
import { KarmaModule } from '../karma/karma.module';

@Module({
  imports: [PrismaModule, ListingUnreadModule, WalletModule, ChatModule, NotificationsModule, StorageModule, ReferralsModule, KarmaModule],
  controllers: [CampaignsController],
  providers: [CampaignsService, EmailService],
  exports: [CampaignsService],
})
export class CampaignsModule {}
