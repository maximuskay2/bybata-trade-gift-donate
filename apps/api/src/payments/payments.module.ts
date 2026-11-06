import { Module, forwardRef } from '@nestjs/common';
import { PrismaModule } from '../common/prisma.module';
// @ts-ignore: ensure editor does not flag missing type declarations during initial scaffold
import { PaymentsService } from './payments.service';
// @ts-ignore: ensure editor does not flag missing type declarations during initial scaffold
import { PaymentsController } from './payments.controller';
// @ts-ignore: ensure editor does not flag missing type declarations during initial scaffold
import { WebhooksController } from './webhooks.controller';
import { PublicGatewaysController } from './public_gateways.controller';
import { PublicRatesController } from './public_rates.controller';
import { PublicFundingPackagesController } from './public_funding_packages.controller';
import { CallbacksController } from './callbacks.controller';
import { WalletModule } from '../wallet/wallet.module';
import { EmailService } from '../common/email.service';

@Module({
  imports: [PrismaModule, forwardRef(() => WalletModule)],
  controllers: [PaymentsController, WebhooksController, CallbacksController, PublicGatewaysController, PublicRatesController, PublicFundingPackagesController],
  providers: [PaymentsService, EmailService],
  exports: [PaymentsService],
})
export class PaymentsModule {}
