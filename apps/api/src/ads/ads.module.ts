import { Module } from '@nestjs/common';
import { PrismaModule } from '../common/prisma.module';
import { WalletModule } from '../wallet/wallet.module';
import { StorageModule } from '../storage/storage.module';
import { AdsController } from './ads.controller';
import { AdsService } from './ads.service';
import { AdsSchedulerService } from './ads.scheduler';

@Module({
  imports: [PrismaModule, WalletModule, StorageModule],
  controllers: [AdsController],
  providers: [AdsService, AdsSchedulerService],
})
export class AdsModule {}
