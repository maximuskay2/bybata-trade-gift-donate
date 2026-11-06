import { Body, Controller, Get, Post, UseGuards, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@Controller('v1/admin/settings/communities')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminCommunitySettingsController {
  constructor(private prisma: PrismaService) {}

  @Get()
  async get() {
    const setting = await (this.prisma as any).appSetting.findUnique({ 
      where: { key: 'community_join_distance_meters' } 
    });
    // Default to 100km (100000 meters) if not set
    const distanceMeters = setting?.value ? parseInt(setting.value, 10) : 100000;
    return { 
      joinDistanceMeters: distanceMeters,
      joinDistanceKm: Math.round(distanceMeters / 1000)
    };
  }

  @Post('upsert')
  async upsert(@Body() body: { joinDistanceKm: number }) {
    if (!body?.joinDistanceKm || body.joinDistanceKm < 1 || body.joinDistanceKm > 1000) {
      throw new BadRequestException('Join distance must be between 1 and 1000 km');
    }
    
    const distanceMeters = Math.round(body.joinDistanceKm * 1000);
    
    const setting = await (this.prisma as any).appSetting.upsert({
      where: { key: 'community_join_distance_meters' },
      update: { value: distanceMeters.toString() },
      create: { key: 'community_join_distance_meters', value: distanceMeters.toString() },
    });
    
    return { 
      ok: true, 
      joinDistanceMeters: parseInt(setting.value, 10),
      joinDistanceKm: Math.round(parseInt(setting.value, 10) / 1000)
    };
  }
}

