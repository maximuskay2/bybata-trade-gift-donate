import { Module } from '@nestjs/common';
import { PrismaModule } from '../common/prisma.module';
import { forwardRef } from '@nestjs/common';
import { PaymentsModule } from '../payments/payments.module';
import { WalletService } from './wallet.service';
import { WalletController } from './wallet.controller';
import { WalletSecurityService } from './wallet-security.service';
import { QRCodeService } from './qr-code.service';
import { AdSchedulingService } from './ad-scheduling.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { EmailService } from '../common/email.service';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [
    PrismaModule,
    StorageModule,
    forwardRef(() => PaymentsModule),
    forwardRef(() => NotificationsModule),
  ],
  controllers: [WalletController],
  // Use NotificationsModule exports — do not re-provide NotificationsService /
  // PushNotificationService here (duplicate instances break push delivery).
  providers: [
    WalletService,
    WalletSecurityService,
    QRCodeService,
    AdSchedulingService,
    EmailService,
  ],
  exports: [
    WalletService,
    WalletSecurityService,
    QRCodeService,
    AdSchedulingService,
  ],
})
export class WalletModule {}
