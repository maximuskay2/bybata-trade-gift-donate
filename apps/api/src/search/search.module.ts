import { Module } from '@nestjs/common';
import { AiModule } from '../ai/ai.module';
import { SearchController } from './search.controller';
import { SearchInterpretController } from './search-interpret.controller';
import { SearchService } from './search.service';
import { SearchInterpretService } from './search-interpret.service';
import { SearchIntentService } from './search-intent.service';
import { PrismaModule } from '../common/prisma.module';
import { ListingUnreadModule } from '../common/listing-unread.module';

@Module({
  imports: [PrismaModule, ListingUnreadModule, AiModule],
  controllers: [SearchController, SearchInterpretController],
  providers: [SearchService, SearchInterpretService, SearchIntentService],
  exports: [SearchService, SearchInterpretService, SearchIntentService],
})
export class SearchModule {}