import { Module } from '@nestjs/common';
import { StorageService } from './storage.service';
import { StorageController } from './storage.controller';
import { PrismaModule } from '../common/prisma.module';
import { MediaService } from './media.service';

@Module({
  imports: [PrismaModule],
  controllers: [StorageController],
  providers: [StorageService, MediaService],
  exports: [StorageService, MediaService],
})
export class StorageModule {}
