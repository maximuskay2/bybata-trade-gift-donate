import { Module } from '@nestjs/common';
import { PrismaModule } from './prisma.module';
import { ListingUnreadService } from './listing-unread.service';

@Module({
  imports: [PrismaModule],
  providers: [ListingUnreadService],
  exports: [ListingUnreadService],
})
export class ListingUnreadModule {}
