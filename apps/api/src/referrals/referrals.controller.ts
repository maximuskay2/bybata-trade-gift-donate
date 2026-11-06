import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { ReferralsService } from './referrals.service';

@Controller('v1/referrals')
export class ReferralsController {
  constructor(private referrals: ReferralsService) {}

  @Get('lookup')
  async lookup(@Query('code') code: string) {
    const result = await this.referrals.lookupReferrerByCode(code || '');
    return result ?? { valid: false };
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  async getMyReferralStats(@CurrentUser() user: any) {
    return this.referrals.getMyReferralStats(user.sub);
  }
}
