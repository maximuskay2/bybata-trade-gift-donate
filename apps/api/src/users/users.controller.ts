import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { UsersService } from './users.service';
import { Throttle } from '@nestjs/throttler';
import { ChangePasswordDto } from './dto/user.dto';

@Controller('v1/users')
export class UsersController {
  constructor(private users: UsersService) {}

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(
    @CurrentUser() user: any,
    @Query('light') light?: string,
    @Query('fresh') fresh?: string,
  ) {
    const wantFresh = fresh === '1' || fresh === 'true';
    if (wantFresh) {
      await this.users.invalidateMeCache(user.sub);
    }
    const wantLight = light === '1' || light === 'true';
    if (wantLight) {
      return this.users.getMeLight(user.sub);
    }
    return this.users.getMe(user.sub);
  }

  // Lightweight activity endpoint used by the Profile activity tab.
  @UseGuards(JwtAuthGuard)
  @Get('me/activity')
  async getMyActivity(
    @CurrentUser() user: any,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
    @Query('type') type?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    return this.users.getMyActivity(user.sub, page, size, type);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('me')
  async updateMe(
    @CurrentUser() user: any,
    @Body()
    body: {
      displayName?: string;
      username?: string;
      bio?: string;
      phone?: string;
      avatarKey?: string;
      isProfilePublic?: boolean;
      showEmail?: boolean;
      showPhone?: boolean;
      showLocation?: boolean;
      allowDirectMessages?: boolean;
      preferredFiatCurrency?: string;
      countryCode?: string;
      timezone?: string;
      location?: string;
    },
  ) {
    return this.users.updateMe(user.sub, body);
  }

  /** Sync last known coordinates for nearby listing alerts (private; not public profile). */
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 30, ttl: 60000 } })
  @Post('me/location')
  @HttpCode(HttpStatus.OK)
  async updateMyLocation(
    @CurrentUser() user: any,
    @Body() body: { latitude?: number; longitude?: number },
  ) {
    return this.users.updateMyLocation(user.sub, body.latitude, body.longitude);
  }

  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 30, ttl: 60000 } })
  @Get('search')
  async search(
    @Query('q') q?: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    return this.users.searchUsers(q ?? '', Math.max(parseInt(pageStr ?? '1', 10) || 1, 1), Math.min(Math.max(parseInt(sizeStr ?? '10', 10) || 10, 1), 50));
  }

  @Get('username-available')
  async usernameAvailable(@Query('username') username?: string) {
    if (!username || username.trim() === '') {
      return { available: false, reason: 'username_required' };
    }
    return this.users.isUsernameAvailable(username);
  }

  @Get('username/:username')
  async getByUsername(@Param('username') username: string) {
    return this.users.getUserByUsername(username);
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/password')
  @HttpCode(HttpStatus.OK)
  async changePassword(
    @CurrentUser() user: any,
    @Body() dto: ChangePasswordDto,
  ) {
    return this.users.changePassword(user.sub, dto.currentPassword, dto.newPassword);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('me')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteAccount(@CurrentUser() user: any) {
    await this.users.deleteAccount(user.sub);
    return;
  }

  @UseGuards(JwtAuthGuard)
  @Patch('me/privacy')
  async updatePrivacySettings(
    @CurrentUser() user: any,
    @Body() settings: { isProfilePublic?: boolean; showEmail?: boolean; showPhone?: boolean; showLocation?: boolean; allowDirectMessages?: boolean },
  ) {
    return this.users.updatePrivacySettings(user.sub, settings);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/sessions')
  async getActiveSessions(@CurrentUser() user: any) {
    return this.users.getActiveSessions(user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('me/sessions/:sessionId')
  @HttpCode(HttpStatus.NO_CONTENT)
  async revokeSession(
    @CurrentUser() user: any,
    @Param('sessionId') sessionId: string,
  ) {
    await this.users.revokeSession(user.sub, sessionId);
    return;
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/sessions/revoke-all')
  @HttpCode(HttpStatus.OK)
  async revokeAllOtherSessions(
    @CurrentUser() user: any,
    @Body() body: { currentSessionId: string },
  ) {
    return this.users.revokeAllOtherSessions(user.sub, body.currentSessionId);
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/data-export')
  @HttpCode(HttpStatus.OK)
  async requestDataExport(@CurrentUser() user: any) {
    // TODO: Implement data export generation
    // This should generate a comprehensive JSON/CSV export of all user data
    return { success: true, message: 'Data export request submitted. You will receive an email when ready.' };
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/blocked')
  async getBlockedUsers(@CurrentUser() user: any) {
    return this.users.getBlockedUsers(user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/block/:userId')
  @HttpCode(HttpStatus.OK)
  async blockUser(
    @CurrentUser() user: any,
    @Param('userId') blockedUserId: string,
    @Body() body: { reason?: string },
  ) {
    return this.users.blockUser(user.sub, blockedUserId, body.reason);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('me/block/:userId')
  @HttpCode(HttpStatus.OK)
  async unblockUser(
    @CurrentUser() user: any,
    @Param('userId') blockedUserId: string,
  ) {
    return this.users.unblockUser(user.sub, blockedUserId);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id/follow-status')
  async getFollowStatus(@Param('id') id: string, @CurrentUser() user: any) {
    return this.users.isFollowing(user.sub, id).then((isFollowing) => ({ isFollowing }));
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/follow')
  @HttpCode(HttpStatus.OK)
  async followUser(@Param('id') id: string, @CurrentUser() user: any) {
    return this.users.follow(user.sub, id);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id/follow')
  @HttpCode(HttpStatus.OK)
  async unfollowUser(@Param('id') id: string, @CurrentUser() user: any) {
    return this.users.unfollow(user.sub, id);
  }

  @Get(':id/followers')
  async getFollowers(
    @Param('id') id: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    return this.users.getFollowers(id, page, size);
  }

  @Get(':id/following')
  async getFollowing(
    @Param('id') id: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    return this.users.getFollowing(id, page, size);
  }

  @Get(':id/reviews')
  async getProfileReviews(
    @Param('id') id: string,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    const page = Math.max(parseInt(pageStr ?? '1', 10) || 1, 1);
    const size = Math.min(Math.max(parseInt(sizeStr ?? '20', 10) || 20, 1), 100);
    return this.users.getProfileReviews(id, page, size);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id/like-status')
  async getProfileLikeStatus(@Param('id') id: string, @CurrentUser() user: any) {
    return this.users.isProfileLiked(user.sub, id);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/like')
  @HttpCode(HttpStatus.OK)
  async likeProfile(@Param('id') id: string, @CurrentUser() user: any) {
    return this.users.likeProfile(user.sub, id);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id/like')
  @HttpCode(HttpStatus.OK)
  async unlikeProfile(@Param('id') id: string, @CurrentUser() user: any) {
    return this.users.unlikeProfile(user.sub, id);
  }

  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @Post(':id/report')
  @HttpCode(HttpStatus.CREATED)
  async reportUser(
    @Param('id') reportedUserId: string,
    @CurrentUser() user: any,
    @Body() body: { reason: string; details?: string },
  ) {
    return this.users.reportUser(user.sub, reportedUserId, body.reason, body.details);
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/appeal')
  @HttpCode(HttpStatus.CREATED)
  async submitAppeal(
    @CurrentUser() user: any,
    @Body() body: { reason: string; reportId?: string },
  ) {
    return this.users.createAppeal(user.sub, body.reason, body.reportId);
  }

  @Get(':id')
  async getUser(@Param('id') id: string) {
    return this.users.getUserById(id);
  }
}
