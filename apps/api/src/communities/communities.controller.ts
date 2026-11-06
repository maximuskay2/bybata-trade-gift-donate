import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
  ParseIntPipe,
  DefaultValuePipe,
  ForbiddenException,
  NotFoundException
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { CommunitiesService } from './communities.service';
import {
  CreateCommunityDto,
  UpdateCommunityDto,
  CreatePostDto,
  UpdatePostDto,
  CreateEventDto,
  UpdateEventDto,
  JoinCommunityDto,
  UpdateMemberRoleDto,
  CreateCommentDto,
  InviteCommunityMemberDto,
  RevokeInviteDto,
  ResendInviteDto
} from './dto/community.dto';
import { CreateRequestDto } from './dto/create-request.dto';

@Controller('v1/communities')
export class CommunitiesController {
  constructor(private readonly communitiesService: CommunitiesService) {}

  // Community endpoints
  @Post()
  @UseGuards(JwtAuthGuard)
  async createCommunity(@CurrentUser() user: any, @Body() dto: CreateCommunityDto) {
    return this.communitiesService.createCommunity(user.sub, dto);
  }

  @Get()
  async getCommunities(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
    @Query('category') category?: string,
    @Query('type') type?: string,
    @Query('search') search?: string,
    @Query('membership') membership?: string,
    @CurrentUser() user?: any,
  ) {
    if (membership === 'joined' && user?.sub) {
      return this.communitiesService.getJoinedCommunities(user.sub, page, size);
    }
    return this.communitiesService.getCommunities(page, size, category, type as any, search);
  }

  @Get('joined')
  @UseGuards(JwtAuthGuard)
  async getJoinedCommunities(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
    @CurrentUser() user: any,
  ) {
    return this.communitiesService.getJoinedCommunities(user.sub, page, size);
  }

  @Get('my')
  @UseGuards(JwtAuthGuard)
  async getMyCommunities(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
    @CurrentUser() user: any,
  ) {
    return this.communitiesService.getJoinedCommunities(user.sub, page, size);
  }

  @Get('nearby')
  async getNearby(
    @Query('lat') lat: string,
    @Query('lng') lng: string,
    @Query('radius', new DefaultValuePipe(20000), ParseIntPipe) radius: number,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
  ) {
    const latNum = parseFloat(lat);
    const lngNum = parseFloat(lng);
    if (isNaN(latNum) || isNaN(lngNum)) return { items: [], total: 0, page, size, totalPages: 0 };
    return this.communitiesService.getNearbyCommunities(latNum, lngNum, radius, page, size);
  }

  @Get('invites')
  @UseGuards(JwtAuthGuard)
  async getMyInvites(@CurrentUser() user: any) {
    return this.communitiesService.getMyInvites(user.sub);
  }

  @Get(':id')
  async getCommunity(@Param('id') id: string, @CurrentUser() user?: any) {
    return this.communitiesService.getCommunity(id, user?.sub);
  }

  // IMPORTANT: Specific routes must come before general parameterized routes
  // This route must come before :id/members to ensure proper matching
  @Get(':id/members/me')
  @UseGuards(JwtAuthGuard)
  async getMyMembership(@Param('id') id: string, @CurrentUser() user: any) {
    return this.communitiesService.getMyMembership(id, user.sub);
  }

  @Get(':id/members')
  @UseGuards(JwtAuthGuard)
  async getCommunityMembers(@Param('id') id: string, @CurrentUser() user: any) {
    // JWT guard should ensure user exists, but add safety check
    if (!user) {
      console.error('[getCommunityMembers] User is null or undefined');
      throw new ForbiddenException('Authentication required');
    }
    
    // Normalize user ID - use sub if available, otherwise id
    const userId = user.sub || user.id;
    if (!userId) {
      console.error('[getCommunityMembers] User missing identifier:', { user, hasSub: !!user?.sub, hasId: !!user?.id });
      throw new ForbiddenException('Invalid user authentication');
    }
    
    return this.communitiesService.getCommunityMembers(id, userId);
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard)
  async updateCommunity(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() dto: UpdateCommunityDto,
  ) {
    return this.communitiesService.updateCommunity(id, user.sub, dto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  async deleteCommunity(@Param('id') id: string, @CurrentUser() user: any) {
    return this.communitiesService.deleteCommunity(id, user.sub);
  }

  // Member management endpoints
  @Post(':id/join')
  @UseGuards(JwtAuthGuard)
  async joinCommunity(
    @Param('id') communityId: string,
    @CurrentUser() user: any,
    @Body() dto?: JoinCommunityDto,
  ) {
    return this.communitiesService.joinCommunity(communityId, user.sub, dto);
  }

  @Get(':id/join-requests')
  @UseGuards(JwtAuthGuard)
  async listPendingJoinRequests(
    @Param('id') communityId: string,
    @CurrentUser() user: any,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
  ) {
    return this.communitiesService.listPendingJoinRequests(communityId, user.sub, page, size);
  }

  @Post(':id/join-requests/:memberId/approve')
  @UseGuards(JwtAuthGuard)
  async approveJoinRequest(
    @Param('id') communityId: string,
    @Param('memberId') memberId: string,
    @CurrentUser() user: any,
  ) {
    return this.communitiesService.approveJoinRequest(communityId, memberId, user.sub);
  }

  @Post(':id/join-requests/:memberId/reject')
  @UseGuards(JwtAuthGuard)
  async rejectJoinRequest(
    @Param('id') communityId: string,
    @Param('memberId') memberId: string,
    @CurrentUser() user: any,
    @Body() body: { reason?: string },
  ) {
    return this.communitiesService.rejectJoinRequest(communityId, memberId, user.sub, body?.reason);
  }

  @Post(':id/invite')
  @UseGuards(JwtAuthGuard)
  async inviteMember(
    @Param('id') communityId: string,
    @CurrentUser() user: any,
    @Body() dto: InviteCommunityMemberDto,
  ) {
    return this.communitiesService.inviteMember(
      communityId,
      user.sub,
      dto.userId,
      dto.userIds,
      dto.email,
      dto.emails,
      dto.username,
      dto.usernames,
      dto.message,
      dto.expiresAt,
      dto.templateKey,
    );
  }

  @Get(':id/invites')
  @UseGuards(JwtAuthGuard)
  async getCommunityInvites(@Param('id') communityId: string, @CurrentUser() user: any) {
    return this.communitiesService.getCommunityInvites(communityId, user.sub);
  }

  @Post(':id/invite/accept')
  @UseGuards(JwtAuthGuard)
  async acceptInvite(@Param('id') communityId: string, @CurrentUser() user: any) {
    return this.communitiesService.acceptInvite(communityId, user.sub);
  }

  @Post(':id/invite/decline')
  @UseGuards(JwtAuthGuard)
  async declineInvite(@Param('id') communityId: string, @CurrentUser() user: any) {
    return this.communitiesService.declineInvite(communityId, user.sub);
  }

  @Post(':id/invite/revoke')
  @UseGuards(JwtAuthGuard)
  async revokeInvite(
    @Param('id') communityId: string,
    @CurrentUser() user: any,
    @Body() dto: RevokeInviteDto,
  ) {
    return this.communitiesService.revokeInvite(
      communityId,
      user.sub,
      dto.userId,
      dto.inviteId,
      dto.email,
    );
  }

  @Post(':id/invite/resend')
  @UseGuards(JwtAuthGuard)
  async resendInvite(
    @Param('id') communityId: string,
    @CurrentUser() user: any,
    @Body() dto: ResendInviteDto,
  ) {
    return this.communitiesService.resendInvites(
      communityId,
      user.sub,
      dto.inviteId,
      dto.inviteIds,
      dto.templateKey,
    );
  }

  @Get('invite/lookup')
  async lookupInvite(@Query('code') code: string) {
    return this.communitiesService.lookupInvite(code);
  }

  @Post('invite/accept-code')
  @UseGuards(JwtAuthGuard)
  async acceptInviteByCode(@CurrentUser() user: any, @Body() body: { code: string }) {
    return this.communitiesService.acceptInviteByCode(body.code, user.sub);
  }

  @Post(':id/leave')
  @UseGuards(JwtAuthGuard)
  async leaveCommunity(@Param('id') communityId: string, @CurrentUser() user: any) {
    return this.communitiesService.leaveCommunity(communityId, user.sub);
  }

  @Put(':id/members/:memberId/role')
  @UseGuards(JwtAuthGuard)
  async updateMemberRole(
    @Param('id') communityId: string,
    @Param('memberId') memberId: string,
    @CurrentUser() user: any,
    @Body() dto: UpdateMemberRoleDto,
  ) {
    return this.communitiesService.updateMemberRole(communityId, memberId, user.sub, dto);
  }

  @Delete(':id/members/:memberId')
  @UseGuards(JwtAuthGuard)
  async removeMember(
    @Param('id') communityId: string,
    @Param('memberId') memberId: string,
    @CurrentUser() user: any,
    @Query('banReason') banReason?: string,
  ) {
    return this.communitiesService.removeMember(communityId, memberId, user.sub, banReason);
  }

  // Posts endpoints
  @Post(':id/posts')
  @UseGuards(JwtAuthGuard)
  async createPost(
    @Param('id') communityId: string,
    @CurrentUser() user: any,
    @Body() dto: CreatePostDto,
  ) {
    return this.communitiesService.createPost(communityId, user.sub, dto);
  }

  // Ask-Request endpoint
  @Post('requests')
  @UseGuards(JwtAuthGuard)
  async createRequest(
    @CurrentUser() user: any,
    @Body() dto: CreateRequestDto,
  ) {
    return this.communitiesService.createRequest(user.sub, dto);
  }

  @Get(':id/posts')
  @UseGuards(JwtAuthGuard)
  async getCommunityPosts(
    @Param('id') communityId: string,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
    @CurrentUser() user: any,
  ) {
    return this.communitiesService.getCommunityPosts(communityId, user.sub, page, size);
  }

  @Post('posts/:postId/like')
  @UseGuards(JwtAuthGuard)
  async likePost(@Param('postId') postId: string, @CurrentUser() user: any) {
    return this.communitiesService.likePost(postId, user.sub);
  }

  @Delete('posts/:postId/like')
  @UseGuards(JwtAuthGuard)
  async unlikePost(@Param('postId') postId: string, @CurrentUser() user: any) {
    return this.communitiesService.unlikePost(postId, user.sub);
  }

  @Get('posts/:postId/comments')
  async getPostComments(
    @Param('postId') postId: string,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(10), ParseIntPipe) size: number,
    @CurrentUser() user?: any,
  ) {
    if (!user?.sub) {
      throw new ForbiddenException('Authentication required');
    }
    
    return this.communitiesService.getPostComments(postId, user.sub, page, size);
  }

  @Post('posts/:postId/comments')
  @UseGuards(JwtAuthGuard)
  async createPostComment(
    @Param('postId') postId: string,
    @CurrentUser() user: any,
    @Body() body: CreateCommentDto,
  ) {
    return this.communitiesService.createPostComment(postId, user.sub, { content: body.content, parentCommentId: body.parentId });
  }

  // Events endpoints
  @Post(':id/events')
  @UseGuards(JwtAuthGuard)
  async createEvent(
    @Param('id') communityId: string,
    @CurrentUser() user: any,
    @Body() dto: CreateEventDto,
  ) {
    return this.communitiesService.createEvent(communityId, user.sub, dto);
  }

  @Get(':id/events')
  @UseGuards(JwtAuthGuard)
  async getCommunityEvents(
    @Param('id') communityId: string,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
    @Query('upcoming', new DefaultValuePipe(true)) upcoming: boolean,
    @CurrentUser() user?: any,
  ) {
    if (!user?.sub) {
      throw new ForbiddenException('Authentication required');
    }
    
    return this.communitiesService.getCommunityEvents(communityId, user.sub, page, size, upcoming);
  }

  @Post('events/:eventId/register')
  @UseGuards(JwtAuthGuard)
  async registerForEvent(@Param('eventId') eventId: string, @CurrentUser() user: any) {
    return this.communitiesService.registerForEvent(eventId, user.sub);
  }
}
