import { Global, Module } from '@nestjs/common';
import { EmailLinkRouterService } from './services/email-link-router.service';

@Global()
@Module({
  providers: [EmailLinkRouterService],
  exports: [EmailLinkRouterService],
})
export class SharedModule {}
