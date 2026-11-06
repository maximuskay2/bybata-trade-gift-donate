import { Module, forwardRef } from '@nestjs/common';
import { KarmaController } from './karma.controller';
import { KarmaService } from './karma.service';
import { KarmaPointsConfigService } from './karma-points-config.service';
import { AuthModule } from '../auth/auth.module';
import { WalletModule } from '../wallet/wallet.module';
import { SharedModule } from '../shared/shared.module';
import { PrismaModule } from '../common/prisma.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { EmailService } from '../common/email.service';

@Module({
  imports: [
    PrismaModule,
    forwardRef(() => AuthModule),
    WalletModule,
    SharedModule,
    NotificationsModule,
  ],
  controllers: [KarmaController],
  providers: [KarmaService, KarmaPointsConfigService, EmailService],
  exports: [KarmaService, KarmaPointsConfigService],
})
export class KarmaModule {}
