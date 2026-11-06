import { Module } from '@nestjs/common';
import { CommunitiesController } from './communities.controller';
import { CommunitiesService } from './communities.service';
import { PrismaModule } from '../common/prisma.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { EmailService } from '../common/email.service';

@Module({
  imports: [PrismaModule, NotificationsModule],
  controllers: [CommunitiesController],
  providers: [CommunitiesService, EmailService],
  exports: [CommunitiesService],
})
export class CommunitiesModule {}