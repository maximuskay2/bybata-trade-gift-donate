import { Body, Controller, Get, Post, UseGuards, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('v1/admin/settings/maps')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminMapSettingsController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async get() {
    const setting = await (this.prisma as any).appSetting.findUnique({ where: { key: 'google_maps_api_key' } });
    return { googleMapsApiKey: setting?.value ?? '' };
  }

  @Post('upsert')
  async upsert(@Body() body: { apiKey: string }) {
    if (!body?.apiKey || body.apiKey.length < 20) throw new BadRequestException('Invalid API key');
    const setting = await (this.prisma as any).appSetting.upsert({
      where: { key: 'google_maps_api_key' },
      update: { value: body.apiKey },
      create: { key: 'google_maps_api_key', value: body.apiKey },
    });
    return { ok: true, googleMapsApiKey: setting.value };
  }
}
