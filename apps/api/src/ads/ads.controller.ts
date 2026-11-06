import { Controller, Get, Param, Post } from '@nestjs/common';
import { AdsService } from './ads.service';

@Controller('v1/ads')
export class AdsController {
  constructor(private ads: AdsService) {}

  @Get('placements/:key')
  async listByPlacement(@Param('key') placementKey: string) {
    return this.ads.listActiveAdsByPlacement(placementKey);
  }

  @Post('boosts/:id/track/view')
  async trackBoostView(@Param('id') id: string) {
    await this.ads.trackBoostView(id);
    return { ok: true };
  }

  @Post('boosts/:id/track/click')
  async trackBoostClick(@Param('id') id: string) {
    await this.ads.trackBoostClick(id);
    return { ok: true };
  }
}
