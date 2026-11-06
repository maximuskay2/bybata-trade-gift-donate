import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ChatService } from './chat.service';
import { ChatController } from './chat.controller';
import { AdminChatController } from './admin-chat.controller';
import { ChatGateway } from './chat.gateway';
import { ConfigValidation } from '../config/config.validation';
import { SharedModule } from '../shared/shared.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PrismaModule } from '../common/prisma.module';

@Module({
  imports: [
    PrismaModule,
    SharedModule,
    NotificationsModule,
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
  ],
  controllers: [ChatController, AdminChatController],
  providers: [ChatService, ChatGateway],
  exports: [ChatService, ChatGateway],
})
export class ChatModule {}
