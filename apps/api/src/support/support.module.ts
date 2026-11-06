import { Module } from '@nestjs/common';
import { PrismaModule } from '../common/prisma.module';
import { SupportController } from './support.controller';
import { SupportService } from './support.service';
import { AdminSupportController } from '../admin/admin_support.controller';

@Module({
  imports: [PrismaModule],
  controllers: [SupportController, AdminSupportController],
  providers: [SupportService],
  exports: [SupportService],
})
export class SupportModule {}
