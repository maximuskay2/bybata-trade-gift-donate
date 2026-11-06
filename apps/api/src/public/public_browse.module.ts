import { Module } from '@nestjs/common';
import { PublicBrowseController } from './public_browse.controller';
import { TradesModule } from '../trades/trades.module';
import { GiftsModule } from '../gifts/gifts.module';
import { CampaignsModule } from '../campaigns/campaigns.module';
import { CommunitiesModule } from '../communities/communities.module';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [TradesModule, GiftsModule, CampaignsModule, CommunitiesModule, UsersModule],
  controllers: [PublicBrowseController],
})
export class PublicBrowseModule {}
