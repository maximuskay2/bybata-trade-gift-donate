import { Module } from '@nestjs/common';
import { PrismaModule } from '../common/prisma.module';
import { PublicMapSettingsController } from '../public/map_settings.controller';

@Module({
  imports: [PrismaModule],
  controllers: [PublicMapSettingsController],
})
export class SettingsModule {}

