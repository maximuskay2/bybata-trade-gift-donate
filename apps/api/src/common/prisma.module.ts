import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

/**
 * Single shared PrismaClient for the whole app.
 * Must stay @Global — never re-provide PrismaService in feature modules
 * (that opens extra connection pools and exhausts Postgres).
 */
@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
