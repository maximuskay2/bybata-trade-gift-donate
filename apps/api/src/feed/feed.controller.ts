import { Controller, Get, Query, UseGuards, ForbiddenException } from '@nestjs/common';
import { FeedService } from '../common/services/feed.service';
import { GetHomeFeedDto, HomeFeedResponseDto } from '../common/dto/feed.dto';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { FeatureFlags } from '../config/feature-flags';

@Controller('v1/feed')
@UseGuards(JwtAuthGuard)
export class FeedController {
  constructor(private readonly feedService: FeedService) {}

  @Get('home')
  async getHomeFeed(@Query() dto: GetHomeFeedDto): Promise<HomeFeedResponseDto> {
    if (!FeatureFlags.isEnabled('ENABLE_UNIFIED_FEED')) {
      throw new ForbiddenException('Unified feed is not enabled');
    }
    return this.feedService.getHomeFeed(dto);
  }
}
