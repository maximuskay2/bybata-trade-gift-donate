import { Module } from '@nestjs/common';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { VerificationController } from './verification.controller';
import { EmailPreferencesController } from './email-preferences.controller';
import { PrismaModule } from '../common/prisma.module';
import { EmailService } from '../common/email.service';
import { KarmaModule } from '../karma/karma.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { SharedModule } from '../shared/shared.module';

@Module({
  imports: [PrismaModule, KarmaModule, NotificationsModule, SharedModule],
  controllers: [UsersController, VerificationController, EmailPreferencesController],
  providers: [UsersService, EmailService],
  exports: [UsersService],
})
export class UsersModule {}
