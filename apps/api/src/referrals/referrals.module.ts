import { Module } from '@nestjs/common';
import { ReferralsController } from './referrals.controller';
import { ReferralsService } from './referrals.service';
import { PrismaModule } from '../common/prisma.module';
import { WalletModule } from '../wallet/wallet.module';
import { KarmaModule } from '../karma/karma.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [PrismaModule, WalletModule, KarmaModule, NotificationsModule],
  controllers: [ReferralsController],
  providers: [ReferralsService],
  exports: [ReferralsService],
})
export class ReferralsModule {}
