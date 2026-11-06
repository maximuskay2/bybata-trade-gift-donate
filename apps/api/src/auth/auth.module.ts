import { Module, forwardRef } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './jwt.strategy';
import { PrismaModule } from '../common/prisma.module';
import { EmailService } from '../common/email.service';
import { MessagingService } from '../common/messaging.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { ReferralsModule } from '../referrals/referrals.module';
import { ConfigValidation } from '../config/config.validation';

@Module({
  imports: [
    PassportModule,
    JwtModule.registerAsync({
      useFactory: () => {
        // Use ConfigValidation which handles production vs development appropriately
        const secret = ConfigValidation.getRequired(
          'JWT_ACCESS_SECRET',
          'JWT access token signing secret',
          'dev-secret' // Fallback only allowed in development
        );
        return {
          secret,
          signOptions: { expiresIn: '20m' },
        };
      },
    }),
    PrismaModule,
    NotificationsModule,
    forwardRef(() => ReferralsModule),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy, EmailService, MessagingService],
  exports: [AuthService],
})
export class AuthModule {}
