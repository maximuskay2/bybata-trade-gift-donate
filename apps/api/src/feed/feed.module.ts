import { Module } from '@nestjs/common';
import { FeedController } from './feed.controller';
import { FeedService } from '../common/services/feed.service';
import { StorageModule } from '../storage/storage.module';
import { UsersModule } from '../users/users.module';
import { PrismaModule } from '../common/prisma.module';

@Module({
  imports: [PrismaModule, StorageModule, UsersModule],
  controllers: [FeedController],
  providers: [FeedService],
  exports: [FeedService],
})
export class FeedModule {}
