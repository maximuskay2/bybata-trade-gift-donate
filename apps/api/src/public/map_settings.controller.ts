import { Controller, Get } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';

@Controller('v1/settings/maps')
export class PublicMapSettingsController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async get() {
    const setting = await (this.prisma as any).appSetting.findUnique({ where: { key: 'google_maps_api_key' } });
    return { googleMapsApiKey: setting?.value ?? '' };
  }
}
