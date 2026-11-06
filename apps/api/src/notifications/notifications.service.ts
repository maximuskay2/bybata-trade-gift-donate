import { Injectable, Logger } from '@nestjs/common';
import { ModuleRef } from '@nestjs/core';
import { PrismaService } from '../common/prisma.service';
import { NotificationType, NotificationPriority, Prisma } from '@prisma/client';
import { PushNotificationService } from './push-notification.service';

export interface NotificationFilters {
  type?: string;
  read?: boolean;
  priority?: string;
}

export interface CreateNotificationDto {
  userId: string;
  type: NotificationType;
  title: string;
  message: string;
  data?: any;
  actionUrl?: string;
  sourceId?: string;
  sourceType?: string;
  priority?: NotificationPriority;
  expiresAt?: Date;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private prisma: PrismaService,
    private pushNotifications: PushNotificationService,
    private moduleRef: ModuleRef,
  ) {}

  private defaultSettings() {
    return {
      pushEnabled: true,
      emailEnabled: true,
      typeSettings: {
        message: true,
        trade: true,
        gift: true,
        campaign: true,
        achievement: true,
        system: true,
        reminder: true,
        broadcast: true,
        nearby: true,
      },
    };
  }

  async getNotifications(
    userId: string,
    page: number,
    size: number,
    filters: NotificationFilters,
  ) {
    const where: Prisma.NotificationWhereInput = {
      userId,
      ...(filters.type && { type: filters.type as NotificationType }),
      ...(typeof filters.read === 'boolean' && { read: filters.read }),
      ...(filters.priority && { priority: filters.priority as NotificationPriority }),
      // Only show non-expired notifications
      OR: [
        { expiresAt: null },
        { expiresAt: { gte: new Date() } }
      ],
    };

    const [notifications, total] = await Promise.all([
      this.prisma.notification.findMany({
        where,
        orderBy: [
          { priority: 'desc' },
          { createdAt: 'desc' },
        ],
        skip: (page - 1) * size,
        take: size,
      }),
      this.prisma.notification.count({ where }),
    ]);

    return {
      items: notifications,
      total,
      page,
      size,
      totalPages: Math.ceil(total / size),
    };
  }

  async getUnreadCount(userId: string): Promise<number> {
    return this.prisma.notification.count({
      where: {
        userId,
        read: false,
        OR: [
          { expiresAt: null },
          { expiresAt: { gte: new Date() } }
        ],
      },
    });
  }

  async markAsRead(notificationId: string, userId: string) {
    await this.prisma.notification.updateMany({
      where: {
        id: notificationId,
        userId,
        read: false,
      },
      data: {
        read: true,
        readAt: new Date(),
      },
    });
  }

  async markAllAsRead(userId: string): Promise<number> {
    const result = await this.prisma.notification.updateMany({
      where: {
        userId,
        read: false,
      },
      data: {
        read: true,
        readAt: new Date(),
      },
    });

    return result.count;
  }

  /**
   * Deletes a single notification belonging to the given user. Scoped to the
   * owner so callers cannot delete notifications they do not own.
   */
  async deleteOne(notificationId: string, userId: string): Promise<number> {
    const result = await this.prisma.notification.deleteMany({
      where: {
        id: notificationId,
        userId,
      },
    });
    return result.count;
  }

  /**
   * Bulk-delete ALL notifications for the user. Used by the "Clear all"
   * action in the mobile app so the unread badge resets immediately.
   */
  async clearAll(userId: string): Promise<number> {
    const result = await this.prisma.notification.deleteMany({
      where: { userId },
    });
    return result.count;
  }

  async createNotification(data: CreateNotificationDto) {
    const created = await this.prisma.notification.create({
      data: {
        userId: data.userId,
        type: data.type,
        title: data.title,
        message: data.message,
        data: data.data || null,
        actionUrl: data.actionUrl,
        sourceId: data.sourceId,
        sourceType: data.sourceType,
        priority: data.priority || NotificationPriority.NORMAL,
        expiresAt: data.expiresAt,
      },
    });

    try {
      const pushData = this.buildPushDataPayload(created.id, data);
      // Android click_action must be an intent action, never a deep-link path.
      await this.pushNotifications.sendNotification(data.userId, {
        userId: data.userId,
        title: data.title,
        body: data.message,
        data: pushData,
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      });
    } catch (error) {
      // Log push errors for debugging but don't break notification creation
      console.error(`Push notification failed for user ${data.userId}:`, error);
    }

    // Realtime inbox for online clients (same path as broadcasts).
    this.emitRealtimeNotification(data.userId, {
      id: created.id,
      type: created.type,
      title: created.title,
      message: created.message,
      read: created.read,
      createdAt: created.createdAt,
      actionUrl: created.actionUrl,
      sourceId: created.sourceId,
      sourceType: created.sourceType,
      notificationType: created.type,
      data: data.data || null,
    });

    return created;
  }

  async createBulkNotifications(notifications: CreateNotificationDto[]) {
    return this.prisma.notification.createMany({
      data: notifications.map(notification => ({
        userId: notification.userId,
        type: notification.type,
        title: notification.title,
        message: notification.message,
        data: notification.data || null,
        actionUrl: notification.actionUrl,
        sourceId: notification.sourceId,
        sourceType: notification.sourceType,
        priority: notification.priority || NotificationPriority.NORMAL,
        expiresAt: notification.expiresAt,
      })),
    });
  }

  async getNotificationTypes() {
    return {
      types: Object.values(NotificationType).map(type => ({
        value: type,
        label: this.formatNotificationType(type),
      })),
      priorities: Object.values(NotificationPriority).map(priority => ({
        value: priority,
        label: this.formatPriority(priority),
      })),
    };
  }

  async getNotificationSettings(userId: string) {
    const existing = await this.prisma.notificationSettings.findUnique({
      where: { userId },
    });
    if (existing) return existing;

    const defaults = this.defaultSettings();
    return this.prisma.notificationSettings.create({
      data: {
        userId,
        pushEnabled: defaults.pushEnabled,
        emailEnabled: defaults.emailEnabled,
        typeSettings: defaults.typeSettings,
      },
    });
  }

  async updateNotificationSettings(
    userId: string,
    data: {
      pushEnabled?: boolean;
      emailEnabled?: boolean;
      typeSettings?: Record<string, boolean>;
    }
  ) {
    const defaults = this.defaultSettings();
    const existing = await this.prisma.notificationSettings.findUnique({
      where: { userId },
    });

    let nextTypeSettings: Record<string, boolean> | undefined;
    if (data.typeSettings !== undefined) {
      const prev =
        existing?.typeSettings &&
        typeof existing.typeSettings === 'object' &&
        !Array.isArray(existing.typeSettings)
          ? (existing.typeSettings as Record<string, boolean>)
          : {};
      nextTypeSettings = {
        ...defaults.typeSettings,
        ...prev,
        ...data.typeSettings,
      };
    }

    return this.prisma.notificationSettings.upsert({
      where: { userId },
      update: {
        ...(data.pushEnabled !== undefined && { pushEnabled: data.pushEnabled }),
        ...(data.emailEnabled !== undefined && { emailEnabled: data.emailEnabled }),
        ...(nextTypeSettings !== undefined && {
          typeSettings: nextTypeSettings as Prisma.InputJsonValue,
        }),
      },
      create: {
        userId,
        pushEnabled: data.pushEnabled ?? defaults.pushEnabled,
        emailEnabled: data.emailEnabled ?? defaults.emailEnabled,
        typeSettings: (nextTypeSettings ??
          defaults.typeSettings) as Prisma.InputJsonValue,
      },
    });
  }

  /**
   * Normalized FCM data payload so trade/gift/donation taps route correctly on mobile.
   * `notificationType` keeps the Prisma enum; `type` may be overridden by event data (e.g. chat).
   */
  private buildPushDataPayload(
    notificationId: string,
    data: CreateNotificationDto,
  ): Record<string, string> {
    const pushData: Record<string, string> = {
      notificationId,
      notificationType: data.type,
      type: data.type,
      actionUrl: data.actionUrl || '',
      sourceId: data.sourceId || '',
      sourceType: data.sourceType || '',
      title: data.title,
      body: data.message,
    };

    if (data.data && typeof data.data === 'object') {
      for (const [k, v] of Object.entries(data.data)) {
        if (v != null) pushData[k] = String(v);
      }
    }

    // Never let nested data wipe routing / preference keys.
    pushData.notificationType = data.type;
    pushData.sourceType = data.sourceType || pushData.sourceType || '';
    pushData.sourceId = data.sourceId || pushData.sourceId || '';
    pushData.actionUrl = data.actionUrl || pushData.actionUrl || '';
    pushData.title = data.title;
    pushData.body = data.message;

    const sourceType = (pushData.sourceType || '').toLowerCase();
    const sourceId = pushData.sourceId || '';

    // Chat must route as CHAT even though DB row may be SYSTEM_ANNOUNCEMENT.
    if (sourceType === 'chat_message' || sourceType === 'chat') {
      pushData.type = 'CHAT';
      pushData.notificationType = 'CHAT';
    }

    if (sourceType === 'trade' && sourceId) pushData.tradeId = sourceId;
    if (sourceType === 'trade' && data.data && typeof data.data === 'object') {
      const d = data.data as Record<string, unknown>;
      if (d.kind != null) pushData.kind = String(d.kind);
      if (d.offerId != null) pushData.offerId = String(d.offerId);
    }
    if (sourceType === 'gift' && sourceId) pushData.giftId = sourceId;
    if (sourceType === 'gift_request') {
      if (data.data && typeof data.data === 'object') {
        const d = data.data as Record<string, unknown>;
        if (d.giftId != null) pushData.giftId = String(d.giftId);
        if (d.requestId != null) pushData.requestId = String(d.requestId);
        if (d.kind != null) pushData.kind = String(d.kind);
      }
      pushData.kind = pushData.kind || 'gift_request';
      pushData.type = 'GIFT';
    }
    if (sourceType === 'campaign' && sourceId) pushData.campaignId = sourceId;
    if (sourceType === 'donation') {
      if (sourceId) pushData.donationId = sourceId;
      if (!pushData.campaignId && data.data && typeof data.data === 'object') {
        const campaignId = (data.data as Record<string, unknown>).campaignId;
        if (campaignId != null) pushData.campaignId = String(campaignId);
      }
    }
    if (sourceType === 'transfer' || sourceType === 'wallet') {
      pushData.kind = pushData.kind || 'byc_transfer';
      if (sourceId) pushData.transactionId = pushData.transactionId || sourceId;
      pushData.type = 'TRANSFER';
    }
    if (sourceType.startsWith('nearby_')) {
      pushData.type = 'NEARBY_LISTING';
      pushData.notificationType = 'NEARBY_LISTING';
    }

    return pushData;
  }

  private inferClickAction(data: CreateNotificationDto): string | undefined {
    if (data.actionUrl) return data.actionUrl;
    const sourceType = (data.sourceType || '').toLowerCase();
    const id = data.sourceId;
    if (!id) return undefined;
    if (sourceType === 'trade') return `/trades/${id}`;
    if (sourceType === 'gift') return `/gifts/${id}`;
    if (sourceType === 'gift_request') return '/gifting/requests';
    if (sourceType === 'campaign') {
      return `/campaigns/${id}`;
    }
    if (sourceType === 'donation') {
      const campaignId =
        data.data && typeof data.data === 'object'
          ? (data.data as Record<string, unknown>).campaignId
          : undefined;
      if (campaignId != null && String(campaignId).length > 0) {
        return `/campaigns/${String(campaignId)}`;
      }
      return '/donations';
    }
    if (sourceType === 'transfer' || sourceType === 'wallet') {
      return '/wallet';
    }
    if (sourceType === 'chat_message' && data.data?.conversationId) {
      return `/chat/${data.data.conversationId}`;
    }
    return undefined;
  }

  private formatNotificationType(type: NotificationType): string {
    return type.toLowerCase()
      .split('_')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  }

  private formatPriority(priority: NotificationPriority): string {
    return priority.charAt(0).toUpperCase() + priority.slice(1).toLowerCase();
  }

  // Helper methods for creating specific notification types
  async notifyTradeOffer(tradeId: string, bidderName: string, ownerId: string, offerId: string) {
    await this.createNotification({
      userId: ownerId,
      type: NotificationType.TRADE_OFFER_RECEIVED,
      title: 'New Trade Offer',
      message: `${bidderName} has made an offer on your trade`,
      actionUrl: `/trades/${tradeId}`,
      sourceId: tradeId,
      sourceType: 'trade',
      priority: NotificationPriority.HIGH,
      data: { tradeId, offerId, kind: 'trade_offer' },
    });
  }

  async notifyTradeAccepted(tradeId: string, ownerName: string, bidderId: string, offerId: string) {
    await this.createNotification({
      userId: bidderId,
      type: NotificationType.TRADE_OFFER_ACCEPTED,
      title: 'Trade Offer Accepted!',
      message: `${ownerName} has accepted your trade offer`,
      actionUrl: `/trades/${tradeId}`,
      sourceId: tradeId,
      sourceType: 'trade',
      priority: NotificationPriority.HIGH,
      data: { tradeId, offerId, kind: 'trade_offer' },
    });
  }

  async notifyTradeRejected(tradeId: string, ownerName: string, bidderId: string, offerId: string) {
    await this.createNotification({
      userId: bidderId,
      type: NotificationType.TRADE_OFFER_REJECTED,
      title: 'Offer Declined',
      message: `${ownerName} has declined your trade offer`,
      actionUrl: `/trades/${tradeId}`,
      sourceId: tradeId,
      sourceType: 'trade',
      priority: NotificationPriority.HIGH,
      data: { tradeId, offerId, kind: 'trade_offer' },
    });
  }

  async notifyCounterOffer(
    tradeId: string,
    counterOffererName: string,
    originalOffererId: string,
    counterOfferId: string,
    parentOfferId: string,
  ) {
    await this.createNotification({
      userId: originalOffererId,
      type: NotificationType.TRADE_OFFER_RECEIVED,
      title: 'Counter-Offer Received',
      message: `${counterOffererName} has made a counter-offer to your proposal`,
      actionUrl: `/trades/${tradeId}`,
      sourceId: tradeId,
      sourceType: 'trade',
      priority: NotificationPriority.HIGH,
      data: {
        tradeId,
        offerId: counterOfferId,
        parentOfferId,
        isCounterOffer: true,
        kind: 'trade_offer',
      },
    });
  }

  async notifyGiftReceived(giftId: string, giverName: string, recipientId: string) {
    await this.createNotification({
      userId: recipientId,
      type: NotificationType.GIFT_RECEIVED,
      title: 'Gift Received!',
      message: `${giverName} has sent you a gift`,
      actionUrl: `/gifts/${giftId}`,
      sourceId: giftId,
      sourceType: 'gift',
      priority: NotificationPriority.HIGH,
    });
  }

  async notifyKarmaLevelUp(userId: string, newLevel: string, points: number) {
    await this.createNotification({
      userId,
      type: NotificationType.KARMA_LEVEL_UP,
      title: 'Level Up!',
      message: `Congratulations! You've reached ${newLevel} level with ${points} karma points`,
      actionUrl: '/profile/karma',
      priority: NotificationPriority.HIGH,
      data: { level: newLevel, points },
    });
  }

  async notifyWelcome(userId: string, displayName: string) {
    await this.createNotification({
      userId,
      type: NotificationType.WELCOME,
      title: 'Welcome to bYbata!',
      message: `Hi ${displayName}! Welcome to our community. Start by exploring trades, gifts, and connecting with others.`,
      actionUrl: '/onboarding',
      priority: NotificationPriority.NORMAL,
    });
  }

  // Clean up expired notifications
  async cleanupExpiredNotifications() {
    const result = await this.prisma.notification.deleteMany({
      where: {
        expiresAt: {
          lt: new Date(),
        },
      },
    });

    return result.count;
  }

  // Broadcast notification methods
  async getBroadcastNotifications(page: number, size: number, filters: { status?: string }) {
    const where: Prisma.BroadcastNotificationWhereInput = {
      ...(filters.status && { status: filters.status as any }),
    };

    const [broadcasts, total] = await Promise.all([
      this.prisma.broadcastNotification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
      }),
      this.prisma.broadcastNotification.count({ where }),
    ]);

    return {
      items: broadcasts,
      total,
      page,
      size,
      totalPages: Math.ceil(total / size),
    };
  }

  async getBroadcastNotificationById(id: string) {
    return this.prisma.broadcastNotification.findUnique({ where: { id } });
  }

  async createBroadcastNotification(data: {
    title: string;
    message: string;
    targetCriteria?: any;
    scheduledAt?: Date;
    createdBy: string;
  }) {
    return this.prisma.broadcastNotification.create({
      data: {
        title: data.title,
        message: data.message,
        targetCriteria: this.sanitizeTargetCriteria(data.targetCriteria) ?? Prisma.JsonNull,
        scheduledAt: data.scheduledAt,
        createdBy: data.createdBy,
        status: data.scheduledAt ? 'SCHEDULED' : 'DRAFT',
      },
    });
  }

  /**
   * Clone an existing broadcast into a new DRAFT (for edit-then-send reuse).
   */
  async duplicateBroadcastNotification(broadcastId: string, adminUserId: string) {
    const original = await this.prisma.broadcastNotification.findUnique({
      where: { id: broadcastId },
    });
    if (!original) {
      throw new Error('Broadcast notification not found');
    }

    const clone = await this.createBroadcastNotification({
      title: original.title,
      message: original.message,
      targetCriteria: original.targetCriteria,
      createdBy: adminUserId,
    });

    return {
      ...clone,
      reusedFromId: broadcastId,
    };
  }

  /**
   * Resend by cloning the original (preserves sent history) then delivering the copy.
   */
  async resendBroadcastNotification(broadcastId: string, adminUserId: string) {
    const original = await this.prisma.broadcastNotification.findUnique({
      where: { id: broadcastId },
    });
    if (!original) {
      throw new Error('Broadcast notification not found');
    }
    if (original.status === 'SENDING') {
      throw new Error('Broadcast is currently sending');
    }

    const clone = await this.createBroadcastNotification({
      title: original.title,
      message: original.message,
      targetCriteria: original.targetCriteria,
      createdBy: adminUserId,
    });

    const result = await this.sendBroadcastNotification(clone.id, adminUserId);
    return {
      ...result,
      originalId: broadcastId,
      broadcastId: clone.id,
      title: clone.title,
    };
  }

  async updateBroadcastNotification(
    id: string,
    data: {
      title?: string;
      message?: string;
      targetCriteria?: any;
      scheduledAt?: Date;
      status?: string;
    }
  ) {
    return this.prisma.broadcastNotification.update({
      where: { id },
      data: {
        ...(data.title && { title: data.title }),
        ...(data.message && { message: data.message }),
        ...(data.targetCriteria !== undefined && { targetCriteria: data.targetCriteria }),
        ...(data.scheduledAt !== undefined && { scheduledAt: data.scheduledAt }),
        ...(data.status && { status: data.status as any }),
      },
    });
  }

  async sendBroadcastNotification(broadcastId: string, adminUserId: string) {
    const broadcast = await this.prisma.broadcastNotification.findUnique({
      where: { id: broadcastId },
    });

    if (!broadcast) {
      throw new Error('Broadcast notification not found');
    }

    if (broadcast.status !== 'DRAFT' && broadcast.status !== 'SCHEDULED') {
      throw new Error('Broadcast can only be sent from DRAFT or SCHEDULED status');
    }

    const targetUsers = await this.getTargetUsers(broadcast.targetCriteria);
    this.logger.log(
      `Broadcast ${broadcastId}: targeting ${targetUsers.length} users (admin ${adminUserId})`,
    );

    await this.prisma.broadcastNotification.update({
      where: { id: broadcastId },
      data: {
        status: 'SENDING',
        sentAt: new Date(),
        recipientCount: targetUsers.length,
      },
    });

    if (targetUsers.length === 0) {
      await this.prisma.broadcastNotification.update({
        where: { id: broadcastId },
        data: { status: 'SENT', deliveredCount: 0 },
      });
      return {
        success: true,
        deliveredCount: 0,
        totalRecipients: 0,
        pushSuccess: 0,
        pushFailed: 0,
        warning: 'No matching users for this audience',
      };
    }

    const dtoBase = {
      type: NotificationType.BROADCAST,
      title: broadcast.title,
      message: broadcast.message,
      priority: NotificationPriority.NORMAL,
      sourceId: broadcastId,
      sourceType: 'broadcast',
      actionUrl: '/notifications',
    };

    // 1) Persist in-app notification rows
    const batchSize = 500;
    let deliveredCount = 0;
    for (let i = 0; i < targetUsers.length; i += batchSize) {
      const batch = targetUsers.slice(i, i + batchSize).map((userId) => ({
        userId,
        ...dtoBase,
      }));
      try {
        const result = await this.createBulkNotifications(batch);
        deliveredCount += result.count;
      } catch (error) {
        this.logger.error(`Broadcast ${broadcastId} DB batch failed`, error as Error);
      }
    }

    // 2) Load created rows so push includes real notificationId (required by the app)
    const createdRows = await this.prisma.notification.findMany({
      where: { sourceId: broadcastId, sourceType: 'broadcast' },
      select: {
        id: true,
        userId: true,
        title: true,
        message: true,
        type: true,
        createdAt: true,
        read: true,
        actionUrl: true,
        sourceId: true,
        sourceType: true,
      },
      orderBy: { createdAt: 'desc' },
      take: targetUsers.length,
    });

    // 3) FCM push + realtime WS so online users see it immediately
    let pushSuccess = 0;
    let pushFailed = 0;
    const pushBatchSize = 50;

    for (let i = 0; i < createdRows.length; i += pushBatchSize) {
      const batch = createdRows.slice(i, i + pushBatchSize);
      const results = await Promise.allSettled(
        batch.map(async (row) => {
          const dto: CreateNotificationDto = {
            userId: row.userId,
            type: NotificationType.BROADCAST,
            title: broadcast.title,
            message: broadcast.message,
            actionUrl: '/notifications',
            sourceId: broadcastId,
            sourceType: 'broadcast',
            priority: NotificationPriority.NORMAL,
          };
          const pushData = this.buildPushDataPayload(row.id, dto);
          const sent = await this.pushNotifications.sendNotification(row.userId, {
            userId: row.userId,
            title: broadcast.title,
            body: broadcast.message,
            data: pushData,
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          });
          this.emitRealtimeNotification(row.userId, {
            id: row.id,
            type: row.type,
            title: row.title,
            message: row.message,
            read: row.read,
            createdAt: row.createdAt,
            actionUrl: row.actionUrl,
            sourceId: row.sourceId,
            sourceType: row.sourceType,
          });
          return sent;
        }),
      );

      for (const r of results) {
        if (r.status === 'fulfilled' && r.value === true) pushSuccess += 1;
        else pushFailed += 1;
      }
    }

    await this.prisma.broadcastNotification.update({
      where: { id: broadcastId },
      data: {
        status: 'SENT',
        deliveredCount,
      },
    });

    this.logger.log(
      `Broadcast ${broadcastId} done: inApp=${deliveredCount}/${targetUsers.length} pushOk=${pushSuccess} pushFail=${pushFailed}`,
    );

    return {
      success: true,
      deliveredCount,
      totalRecipients: targetUsers.length,
      pushSuccess,
      pushFailed,
    };
  }

  /** Best-effort realtime inbox update via ChatGateway (if loaded). */
  private emitRealtimeNotification(userId: string, notification: Record<string, unknown>) {
    try {
      // Lazy resolve avoids circular ChatModule <-> NotificationsModule import.
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const { ChatGateway } = require('../chat/chat.gateway') as {
        ChatGateway: new (...args: any[]) => {
          sendNotificationToUser: (userId: string, notification: any) => Promise<void> | void;
        };
      };
      const gateway = this.moduleRef.get(ChatGateway, { strict: false });
      if (gateway?.sendNotificationToUser) {
        void gateway.sendNotificationToUser(userId, notification);
      }
    } catch {
      // Gateway not available in this process — push/poll still deliver.
    }
  }

  /**
   * Live audience size for admin broadcast preview.
   * Returns the exact same set `sendBroadcastNotification` would target.
   */
  async previewBroadcastAudience(targetCriteria?: any) {
    const userIds = await this.getTargetUsers(targetCriteria);
    return {
      count: userIds.length,
      sampleUserIds: userIds.slice(0, 5),
    };
  }

  private sanitizeTargetCriteria(raw: any): Record<string, any> | null {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
    const cleaned: Record<string, any> = {};
    for (const [key, value] of Object.entries(raw)) {
      if (value === undefined || value === null || value === '' || value === false) {
        continue;
      }
      cleaned[key] = value;
    }
    return Object.keys(cleaned).length > 0 ? cleaned : null;
  }

  private async getTargetUsers(targetCriteria: any): Promise<string[]> {
    const criteria = this.sanitizeTargetCriteria(targetCriteria);

    // Default "All users" = active app members (USER role), not staff accounts.
    // This matches what admins mean by "users in the system".
    const where: Prisma.UserWhereInput = {
      banned: false,
      ...(criteria?.role
        ? { role: criteria.role as any }
        : { role: 'USER' }),
      ...(criteria?.verified && {
        profile: { kycStatus: 'VERIFIED' },
      }),
      ...(criteria?.joinedAfter && {
        createdAt: { gte: new Date(String(criteria.joinedAfter)) },
      }),
      ...(criteria?.hasCompletedTrades && {
        trades: { some: { status: 'CLOSED' } },
      }),
    };

    const users = await this.prisma.user.findMany({
      where,
      select: { id: true },
    });

    return users.map((user) => user.id);
  }

  async getBroadcastDeliveryLogs(broadcastId: string, page: number, size: number) {
    // Get individual notifications created from this broadcast
    const where = {
      sourceId: broadcastId,
      sourceType: 'broadcast',
    };

    const [notifications, total] = await Promise.all([
      this.prisma.notification.findMany({
        where,
        include: {
          user: {
            select: {
              email: true,
              profile: {
                select: {
                  displayName: true,
                }
              }
            }
          }
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * size,
        take: size,
      }),
      this.prisma.notification.count({ where }),
    ]);

    return {
      items: notifications.map(notif => ({
        id: notif.id,
        userId: notif.userId,
        userEmail: notif.user.email,
        userDisplayName: notif.user.profile?.displayName,
        delivered: true,
        deliveredAt: notif.createdAt,
        read: notif.read,
        readAt: notif.readAt,
      })),
      total,
      page,
      size,
      totalPages: Math.ceil(total / size),
    };
  }

  async getDeliveryStats(fromDate?: Date, toDate?: Date) {
    const where: Prisma.NotificationWhereInput = {
      ...(fromDate && { createdAt: { gte: fromDate } }),
      ...(toDate && { createdAt: { lte: toDate } }),
    };

    const [totalSent, totalRead, typeStats, dailyStats] = await Promise.all([
      // Total notifications sent
      this.prisma.notification.count({ where }),
      
      // Total notifications read
      this.prisma.notification.count({ 
        where: { ...where, read: true } 
      }),
      
      // Stats by notification type
      this.prisma.notification.groupBy({
        by: ['type'],
        where,
        _count: { id: true },
      }),
      
      // Daily delivery stats for the last 30 days
      this.prisma.$queryRaw`
        SELECT 
          DATE(created_at) as date,
          COUNT(*) as sent,
          SUM(CASE WHEN read = true THEN 1 ELSE 0 END) as read_count
        FROM "Notification" 
        WHERE created_at >= NOW() - INTERVAL '30 days'
        GROUP BY DATE(created_at)
        ORDER BY date DESC
      `,
    ]);

    const readRate = totalSent > 0 ? (totalRead / totalSent) * 100 : 0;

    return {
      summary: {
        totalSent,
        totalRead,
        readRate: Math.round(readRate * 100) / 100,
        unread: totalSent - totalRead,
      },
      typeStats: await Promise.all(
        typeStats.map(async (stat) => {
          const readCount = await this.prisma.notification.count({
            where: {
              ...where,
              type: stat.type,
              read: true,
            },
          });
          return {
            type: stat.type,
            sent: stat._count.id,
            read: readCount,
            readRate: stat._count.id > 0 ? Math.round((readCount / stat._count.id) * 100) : 0,
          };
        })
      ),
      dailyStats,
    };
  }

  async getNotificationAnalytics(period: string) {
    let days = 7;
    switch (period) {
      case '24h':
        days = 1;
        break;
      case '7d':
        days = 7;
        break;
      case '30d':
        days = 30;
        break;
      case '90d':
        days = 90;
        break;
    }

    const fromDate = new Date();
    fromDate.setDate(fromDate.getDate() - days);

    const [notifications, broadcasts] = await Promise.all([
      this.prisma.notification.findMany({
        where: {
          createdAt: { gte: fromDate },
        },
        select: {
          type: true,
          read: true,
          priority: true,
          createdAt: true,
        },
      }),
      this.prisma.broadcastNotification.findMany({
        where: {
          createdAt: { gte: fromDate },
        },
        select: {
          status: true,
          recipientCount: true,
          deliveredCount: true,
          createdAt: true,
        },
      }),
    ]);

    // Calculate metrics
    const totalNotifications = notifications.length;
    const readNotifications = notifications.filter(n => n.read).length;
    const highPriorityNotifications = notifications.filter(n => n.priority === 'HIGH' || n.priority === 'URGENT').length;
    
    const totalBroadcasts = broadcasts.length;
    const sentBroadcasts = broadcasts.filter(b => b.status === 'SENT').length;
    const totalBroadcastRecipients = broadcasts.reduce((sum, b) => sum + (b.recipientCount || 0), 0);
    const totalBroadcastDelivered = broadcasts.reduce((sum, b) => sum + (b.deliveredCount || 0), 0);

    return {
      period,
      notifications: {
        total: totalNotifications,
        read: readNotifications,
        readRate: totalNotifications > 0 ? Math.round((readNotifications / totalNotifications) * 100) : 0,
        highPriority: highPriorityNotifications,
      },
      broadcasts: {
        total: totalBroadcasts,
        sent: sentBroadcasts,
        totalRecipients: totalBroadcastRecipients,
        totalDelivered: totalBroadcastDelivered,
        deliveryRate: totalBroadcastRecipients > 0 ? Math.round((totalBroadcastDelivered / totalBroadcastRecipients) * 100) : 0,
      },
    };
  }
}
