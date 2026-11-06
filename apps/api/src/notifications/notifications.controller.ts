import { Controller, Get, Post, Put, Param, Query, Body, UseGuards, HttpCode, HttpStatus, Delete } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { PushNotificationService } from './push-notification.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { AdminGuard } from '../auth/admin.guard';

@Controller('v1/notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(
    private readonly notificationsService: NotificationsService,
    private readonly pushNotifications: PushNotificationService,
  ) {}

  @Get()
  async getNotifications(
    @CurrentUser() user: any,
    @Query('page') page: string = '1',
    @Query('size') size: string = '20',
    @Query('type') type?: string,
    @Query('read') read?: string,
    @Query('priority') priority?: string,
  ) {
    const userId = user.sub;

    const pageNum = parseInt(page) || 1;
    const pageSize = Math.min(parseInt(size) || 20, 100);
    
    const filters = {
      type: type || undefined,
      read: read ? read === 'true' : undefined,
      priority: priority || undefined,
    };

    const result = await this.notificationsService.getNotifications(
      userId,
      pageNum,
      pageSize,
      filters,
    );

    return result;
  }

  // Static paths MUST be registered before parameterized `:id` routes.
  @Get('unread-count')
  async getUnreadCount(@CurrentUser() user: any) {
    const userId = user.sub;

    const count = await this.notificationsService.getUnreadCount(userId);
    return { count };
  }

  @Get('types')
  async getNotificationTypes() {
    return this.notificationsService.getNotificationTypes();
  }

  @Get('settings')
  async getNotificationSettings(@CurrentUser() user: any) {
    return this.notificationsService.getNotificationSettings(user.sub);
  }

  @Put('settings')
  async updateNotificationSettings(
    @CurrentUser() user: any,
    @Body() data: {
      pushEnabled?: boolean;
      emailEnabled?: boolean;
      typeSettings?: Record<string, boolean>;
    },
  ) {
    return this.notificationsService.updateNotificationSettings(user.sub, data);
  }

  @Post('mark-all-read')
  @HttpCode(HttpStatus.OK)
  async markAllAsRead(@CurrentUser() user: any) {
    const userId = user.sub;

    const count = await this.notificationsService.markAllAsRead(userId);
    return { success: true, markedCount: count };
  }

  @Post('device-tokens')
  @HttpCode(HttpStatus.OK)
  async registerDeviceToken(
    @CurrentUser() user: any,
    @Body() data: { token: string; deviceType: 'ios' | 'android' | 'web' },
  ) {
    await this.pushNotifications.registerDeviceToken(user.sub, data.token, data.deviceType);
    return { success: true };
  }

  @Delete('device-tokens')
  @HttpCode(HttpStatus.OK)
  async removeDeviceToken(
    @CurrentUser() user: any,
    @Body() data: { token: string },
  ) {
    await this.pushNotifications.removeDeviceToken(user.sub, data.token);
    return { success: true };
  }

  @Delete()
  @HttpCode(HttpStatus.OK)
  async clearAll(@CurrentUser() user: any) {
    const userId = user.sub;
    const count = await this.notificationsService.clearAll(userId);
    return { success: true, deletedCount: count };
  }

  @Post(':id/read')
  @HttpCode(HttpStatus.OK)
  async markAsRead(@Param('id') id: string, @CurrentUser() user: any) {
    const userId = user.sub;

    await this.notificationsService.markAsRead(id, userId);
    return { success: true };
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  async deleteOne(@Param('id') id: string, @CurrentUser() user: any) {
    const userId = user.sub;
    const count = await this.notificationsService.deleteOne(id, userId);
    return { success: true, deletedCount: count };
  }

  // Admin-only endpoints
  @Get('admin/broadcasts')
  @UseGuards(AdminGuard)
  async getBroadcastNotifications(
    @Query('page') page: string = '1',
    @Query('size') size: string = '20',
    @Query('status') status?: string,
  ) {
    const pageNum = parseInt(page) || 1;
    const pageSize = Math.min(parseInt(size) || 20, 100);
    
    return this.notificationsService.getBroadcastNotifications(
      pageNum,
      pageSize,
      { status }
    );
  }

  @Get('admin/broadcasts/:id')
  @UseGuards(AdminGuard)
  async getBroadcastNotification(@Param('id') id: string) {
    return this.notificationsService.getBroadcastNotificationById(id);
  }

  @Post('admin/broadcasts/preview-audience')
  @UseGuards(AdminGuard)
  @HttpCode(HttpStatus.OK)
  async previewBroadcastAudience(@Body() data: { targetCriteria?: any }) {
    return this.notificationsService.previewBroadcastAudience(data?.targetCriteria);
  }

  @Post('admin/broadcasts')
  @UseGuards(AdminGuard)
  async createBroadcastNotification(
    @Body() data: {
      title: string;
      message: string;
      targetCriteria?: any;
      scheduledAt?: string;
    },
    @CurrentUser() user: any,
  ) {
    const adminUserId = user.sub;
    
    return this.notificationsService.createBroadcastNotification({
      ...data,
      createdBy: adminUserId,
      scheduledAt: data.scheduledAt ? new Date(data.scheduledAt) : undefined,
    });
  }

  @Put('admin/broadcasts/:id')
  @UseGuards(AdminGuard)
  async updateBroadcastNotification(
    @Param('id') id: string,
    @Body() data: {
      title?: string;
      message?: string;
      targetCriteria?: any;
      scheduledAt?: string;
      status?: string;
    },
  ) {
    return this.notificationsService.updateBroadcastNotification(id, {
      ...data,
      scheduledAt: data.scheduledAt ? new Date(data.scheduledAt) : undefined,
    });
  }

  @Post('admin/broadcasts/:id/send')
  @UseGuards(AdminGuard)
  @HttpCode(HttpStatus.OK)
  async sendBroadcastNotification(
    @Param('id') id: string,
    @CurrentUser() user: any,
  ) {
    const adminUserId = user.sub;
    
    return this.notificationsService.sendBroadcastNotification(id, adminUserId);
  }

  /** Clone a broadcast and send it again (keeps original history intact). */
  @Post('admin/broadcasts/:id/resend')
  @UseGuards(AdminGuard)
  @HttpCode(HttpStatus.OK)
  async resendBroadcastNotification(
    @Param('id') id: string,
    @CurrentUser() user: any,
  ) {
    return this.notificationsService.resendBroadcastNotification(id, user.sub);
  }

  /** Clone a broadcast into a new DRAFT so the admin can edit before sending. */
  @Post('admin/broadcasts/:id/duplicate')
  @UseGuards(AdminGuard)
  @HttpCode(HttpStatus.OK)
  async duplicateBroadcastNotification(
    @Param('id') id: string,
    @CurrentUser() user: any,
  ) {
    return this.notificationsService.duplicateBroadcastNotification(id, user.sub);
  }

  @Get('admin/broadcasts/:id/logs')
  @UseGuards(AdminGuard)
  async getBroadcastDeliveryLogs(
    @Param('id') id: string,
    @Query('page') page: string = '1',
    @Query('size') size: string = '20',
  ) {
    const pageNum = parseInt(page) || 1;
    const pageSize = Math.min(parseInt(size) || 20, 100);
    
    return this.notificationsService.getBroadcastDeliveryLogs(
      id,
      pageNum,
      pageSize
    );
  }

  @Get('admin/delivery-stats')
  @UseGuards(AdminGuard)
  async getDeliveryStats(
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    const fromDate = from ? new Date(from) : undefined;
    const toDate = to ? new Date(to) : undefined;
    
    return this.notificationsService.getDeliveryStats(fromDate, toDate);
  }

  @Get('admin/notification-analytics')
  @UseGuards(AdminGuard)
  async getNotificationAnalytics(
    @Query('period') period: string = '7d',
  ) {
    return this.notificationsService.getNotificationAnalytics(period);
  }
}
