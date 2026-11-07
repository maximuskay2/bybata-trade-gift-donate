import { Module } from '@nestjs/common';
import { AiModule } from '../ai/ai.module';
import { PrismaModule } from '../common/prisma.module';
import { FairValueAssistant } from './fair-value.assistant';
import { PaypalClient } from './paypal.client';
import { TradeTopUpController } from './trade-topup.controller';
import { TradeTopUpService } from './trade-topup.service';

@Module({
  imports: [PrismaModule, AiModule],
  controllers: [TradeTopUpController],
  providers: [PaypalClient, FairValueAssistant, TradeTopUpService],
  exports: [TradeTopUpService],
})
export class TradeTopUpModule {}
