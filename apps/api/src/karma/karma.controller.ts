import {
  Controller,
  Get,
  Post,
  Param,
  Query,
  Body,
  UseGuards,
  ParseIntPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { KarmaService } from './karma.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';

@Controller('v1/karma')
@UseGuards(JwtAuthGuard)
export class KarmaController {
  constructor(private karmaService: KarmaService) {}

  // GET /v1/karma/test - Test endpoint
  @Get('test')
  async testKarma(@CurrentUser('sub') userId: string) {
    return { message: 'Karma test working', userId };
  }

  // GET /v1/karma/me - Get current user's karma account
  @Get('me')
  async getMyKarma(@CurrentUser() user: any) {
    return this.karmaService.getKarmaAccount(user.sub);
  }

  // GET /v1/karma/earn-guide - Earn opportunities with live completion state
  @Get('earn-guide')
  async getEarnGuide(@CurrentUser() user: any) {
    return this.karmaService.getEarnGuide(user.sub);
  }

  // GET /v1/karma/history - Get current user's karma history
  @Get('history')
  async getMyKarmaHistory(
    @CurrentUser() user: any,
    @Query('page', new ParseIntPipe({ optional: true })) page = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit = 20,
  ) {
    return this.karmaService.getKarmaHistory(user.sub, page, limit);
  }

  // GET /v1/karma/leaderboard - Get karma leaderboard
  @Get('leaderboard')
  async getLeaderboard(
    @Query('page', new ParseIntPipe({ optional: true })) page = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit = 50,
  ) {
    return this.karmaService.getLeaderboard(page, limit);
  }

  // GET /v1/karma/achievements - Get current user's achievements
  @Get('achievements')
  async getMyAchievements(@CurrentUser() user: any) {
    return this.karmaService.getUserAchievements(user.sub);
  }

  // GET /v1/karma/achievements/all - Get all available achievements
  @Get('achievements/all')
  async getAllAchievements() {
    return this.karmaService.getAllAchievements();
  }

  // POST /v1/karma/achievements/:id/claim - Claim an achievement
  @Post('achievements/:id/claim')
  async claimAchievement(
    @CurrentUser() user: any,
    @Param('id') achievementId: string,
  ) {
    return this.karmaService.claimAchievement(user.sub, achievementId);
  }

  // POST /v1/karma/actions/earn - Earn karma from a suggested action
  @Post('actions/earn')
  async earnFromAction(
    @CurrentUser() user: any,
    @Query('actionType') actionType?: string,
  ) {
    return this.karmaService.earnFromAction(user.sub, actionType || 'ACTION_COMPLETED');
  }

  // GET /v1/karma/withdraw-settings - Get min threshold and conversion rate (public for logged-in users)
  @Get('withdraw-settings')
  async getWithdrawSettings() {
    return this.karmaService.getWithdrawSettings();
  }

  // GET /v1/karma/points-config - Active karma earn amounts for app UI
  @Get('points-config')
  async getPointsConfig() {
    return this.karmaService.getPointsConfigPublic();
  }

  // POST /v1/karma/withdraw - Withdraw karma to main wallet
  @Post('withdraw')
  @HttpCode(HttpStatus.OK)
  async withdraw(
    @CurrentUser() user: any,
    @Body() body: { karmaPoints: number },
  ) {
    return this.karmaService.withdrawToWallet(user.sub, Number(body.karmaPoints));
  }
}