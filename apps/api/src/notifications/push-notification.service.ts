import { Injectable, Logger } from '@nestjs/common';
import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import { PrismaService } from '../common/prisma.service';

export interface PushNotificationPayload {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, any>;
  badge?: number;
  sound?: string;
  clickAction?: string;
}

export interface ChatNotificationData {
  type: 'new_message' | 'message_reaction' | 'typing' | 'mention';
  conversationId: string;
  messageId?: string;
  senderId: string;
  senderName: string;
  messageContent?: string;
}

/** Must match Flutter [PushNotificationsService.androidChannelId]. */
const FCM_CHANNEL_ID = 'bybata_alerts';
/** Android `res/raw` name (no extension). */
const ANDROID_SOUND = 'bybata_notification';
/** iOS main-bundle sound filename. */
const IOS_SOUND = 'bybata.caf';

@Injectable()
export class PushNotificationService {
  private readonly logger = new Logger(PushNotificationService.name);
  private firebaseApp?: admin.app.App;
  /** Shared across Nest instances (ChatModule used to register a duplicate provider). */
  private static sharedFirebaseApp?: admin.app.App;
  /** After a failed init, skip re-parse attempts (avoids log spam per device token). */
  private firebaseInitFailed = false;
  private static sharedInitFailed = false;
  private firebaseConfigWarned = false;
  private static sharedConfigWarned = false;
  /** Allow another Firebase init attempt after a temporary credential failure. */
  private static nextInitRetryAt = 0;

  constructor(private prisma: PrismaService) {}

  /**
   * Send push notification to a specific user
   */
  async sendNotification(
    userId: string,
    payload: PushNotificationPayload
  ): Promise<boolean> {
    try {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          email: true,
        },
      });

      if (!user) {
        this.logger.warn(`User not found: ${userId}`);
        return false;
      }

      const settings = await this.prisma.notificationSettings.findUnique({
        where: { userId },
      });
      if (settings && settings.pushEnabled === false) {
        this.logger.debug(`Push disabled for user ${userId}, skipping send.`);
        // Skipped by preference — not a delivery success for callers counting pushes.
        return false;
      }
      const typeHint =
        (payload.data?.sourceType as string | undefined) ||
        (payload.data?.type as string | undefined) ||
        (payload.data?.notificationType as string | undefined) ||
        (payload.data?.kind as string | undefined);
      if (
        settings?.typeSettings &&
        !this.isTypeEnabledForPush(settings.typeSettings, typeHint)
      ) {
        this.logger.debug(
          `Push disabled for notification type ${typeHint} (user ${userId}).`,
        );
        return false;
      }

      const tokens = await this.prisma.userDeviceToken.findMany({
        where: { userId },
        select: { token: true },
      });

      if (tokens.length === 0) {
        this.logger.warn(`No device tokens registered for user ${userId}`);
        return false;
      }

      const results = await Promise.allSettled(
        tokens.map((t) => this.sendToDevice(t.token, payload)),
      );

      const successfulTokens: string[] = [];
      for (let i = 0; i < results.length; i++) {
        const result = results[i];
        const token = tokens[i].token;
        if (result.status === 'fulfilled' && result.value === true) {
          successfulTokens.push(token);
        }
      }

      if (successfulTokens.length > 0) {
        await this.prisma.userDeviceToken.updateMany({
          where: { userId, token: { in: successfulTokens } },
          data: { lastUsedAt: new Date() },
        });
      }

      await this.logNotification(userId, payload);

      if (successfulTokens.length === 0) {
        this.logger.warn(
          `Push failed for user ${userId}: 0/${tokens.length} device token(s) accepted by FCM`,
        );
      }

      return successfulTokens.length > 0;
    } catch (error) {
      this.logger.error(
        `Failed to send push notification to user ${userId}:`,
        error,
      );
      return false;
    }
  }

  /**
   * Send chat-specific notification to offline user
   */
  async sendChatNotification(
    userId: string,
    chatData: ChatNotificationData
  ): Promise<boolean> {
    try {
      const payload = await this.buildChatNotificationPayload(userId, chatData);
      return await this.sendNotification(userId, payload);
    } catch (error) {
      this.logger.error(
        `Failed to send chat notification to user ${userId}:`,
        error
      );
      return false;
    }
  }

  /**
   * Send bulk notifications to multiple users
   */
  async sendBulkNotifications(
    userIds: string[],
    payload: PushNotificationPayload
  ): Promise<{ success: number; failed: number }> {
    const results = await Promise.allSettled(
      userIds.map((userId) => this.sendNotification(userId, payload))
    );

    const success = results.filter(
      (result) => result.status === 'fulfilled' && result.value === true
    ).length;
    const failed = results.length - success;

    this.logger.log(
      `Bulk notification sent: ${success} successful, ${failed} failed`
    );

    return { success, failed };
  }

  /**
   * Register a device token for push notifications
   */
  async registerDeviceToken(
    userId: string,
    deviceToken: string,
    deviceType: 'ios' | 'android' | 'web'
  ): Promise<void> {
    try {
      // Check if user exists
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, email: true },
      });

      if (!user) {
        throw new Error('User not found');
      }

      await this.prisma.userDeviceToken.upsert({
        where: { token: deviceToken },
        update: {
          userId,
          deviceType: deviceType.toUpperCase() as any,
          lastUsedAt: new Date(),
        },
        create: {
          userId,
          token: deviceToken,
          deviceType: deviceType.toUpperCase() as any,
          lastUsedAt: new Date(),
        },
      });

      this.logger.log(
        `Device token registered for user ${userId}: ${deviceType} - ${deviceToken.substring(0, 8)}...`
      );
    } catch (error) {
      this.logger.error(
        `Failed to register device token for user ${userId}:`,
        error
      );
      throw error;
    }
  }

  /**
   * Remove a device token (e.g., when user logs out)
   */
  async removeDeviceToken(
    userId: string,
    deviceToken: string
  ): Promise<void> {
    try {
      // Check if user exists
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, email: true },
      });

      if (!user) return;

      await this.prisma.userDeviceToken.deleteMany({
        where: { userId, token: deviceToken },
      });
      this.logger.log(`Device token removed for user ${userId} - ${deviceToken.substring(0, 8)}...`);
    } catch (error) {
      this.logger.error(
        `Failed to remove device token for user ${userId}:`,
        error
      );
    }
  }

  /**
   * Build notification payload for chat messages
   */
  private async buildChatNotificationPayload(
    userId: string,
    chatData: ChatNotificationData
  ): Promise<PushNotificationPayload> {
    let title: string;
    let body: string;

    switch (chatData.type) {
      case 'new_message':
        title = chatData.senderName;
        body = chatData.messageContent
          ? (chatData.messageContent.length > 100
              ? `${chatData.messageContent.substring(0, 100)}...`
              : chatData.messageContent)
          : 'Sent a message';
        break;

      case 'message_reaction':
        title = 'Message Reaction';
        body = `${chatData.senderName} reacted to your message`;
        break;

      case 'typing':
        // Typically wouldn't send push notifications for typing
        title = 'Typing';
        body = `${chatData.senderName} is typing...`;
        break;

      case 'mention':
        title = 'Mentioned in Chat';
        body = `${chatData.senderName} mentioned you in a conversation`;
        break;

      default:
        title = 'New Chat Activity';
        body = `${chatData.senderName} sent a message`;
    }

    // Get unread message count for badge
    const unreadCount = await this.getUnreadMessageCount(userId);

    return {
      userId,
      title,
      body,
      badge: unreadCount,
      sound: IOS_SOUND,
      clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      data: {
        type: 'CHAT',
        notificationType: 'CHAT',
        sourceType: 'chat_message',
        chatType: chatData.type,
        conversationId: chatData.conversationId,
        messageId: chatData.messageId,
        senderId: chatData.senderId,
        actionUrl: `/chat/${chatData.conversationId}`,
      },
    };
  }

  /**
   * Get unread message count for badge
   */
  private async getUnreadMessageCount(userId: string): Promise<number> {
    try {
      // Get all conversations user participates in
      const participations = await this.prisma.conversationParticipant.findMany({
        where: {
          userId,
          leftAt: null,
        },
        select: {
          conversationId: true,
          lastReadAt: true,
        },
      });

      let totalUnread = 0;

      for (const participation of participations) {
        const unreadCount = await this.prisma.message.count({
          where: {
            conversationId: participation.conversationId,
            createdAt: {
              gt: participation.lastReadAt || new Date(0),
            },
            senderId: {
              not: userId, // Don't count own messages
            },
            deletedAt: null,
          },
        });

        totalUnread += unreadCount;
      }

      return totalUnread;
    } catch (error) {
      this.logger.error(
        `Failed to get unread message count for user ${userId}:`,
        error
      );
      return 0;
    }
  }

  /**
   * Send notification to a specific device
   */
  private async sendToDevice(
    deviceToken: string,
    payload: PushNotificationPayload
  ): Promise<boolean> {
    try {
      const app = this.getFirebaseApp();
      if (!app) {
        if (!this.firebaseConfigWarned) {
          this.firebaseConfigWarned = true;
          PushNotificationService.sharedConfigWarned = true;
          this.logger.warn(
            'Firebase not configured — push notifications are skipped. Set FIREBASE_SERVICE_ACCOUNT_JSON (minified JSON or base64) or FIREBASE_SERVICE_ACCOUNT_PATH on Railway.',
          );
        }
        return false;
      }

      const dataPayload = payload.data
        ? Object.fromEntries(
            Object.entries(payload.data)
              .filter(([, v]) => v != null && String(v).length > 0)
              .map(([k, v]) => [k, String(v)]),
          )
        : undefined;

      // Include title/body in data so Flutter can show a local notification
      // even when the OS suppresses the system tray in some states.
      const enrichedData = {
        ...(dataPayload || {}),
        title: payload.title,
        body: payload.body,
      };

      const message: admin.messaging.Message = {
        token: deviceToken,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: enrichedData,
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
          payload: {
            aps: {
              alert: {
                title: payload.title,
                body: payload.body,
              },
              badge: payload.badge,
              sound: payload.sound || IOS_SOUND,
              contentAvailable: true,
            },
          },
        },
        android: {
          priority: 'high',
          notification: {
            channelId: FCM_CHANNEL_ID,
            // Must be an Android intent action — deep links go in `data.actionUrl`.
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            priority: 'high',
            sound: ANDROID_SOUND,
            defaultSound: false,
          },
        },
      };

      await admin.messaging(app).send(message);
      return true;
    } catch (error) {
      const code =
        (error as { code?: string; errorInfo?: { code?: string } })?.code ||
        (error as { errorInfo?: { code?: string } })?.errorInfo?.code;

      if (this.isUnrecoverableTokenError(code)) {
        this.logger.warn(
          `Removing invalid FCM token ${deviceToken.substring(0, 12)}… (${code})`,
        );
        try {
          await this.prisma.userDeviceToken.deleteMany({
            where: { token: deviceToken },
          });
        } catch (deleteError) {
          this.logger.error('Failed to delete invalid device token:', deleteError);
        }
      } else {
        this.logger.error(
          `Failed to send push to device ${deviceToken.substring(0, 12)}…:`,
          error,
        );
      }
      return false;
    }
  }

  private isUnrecoverableTokenError(code?: string): boolean {
    if (!code) return false;
    return (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token' ||
      code === 'messaging/invalid-argument'
    );
  }

  /**
   * Log notification in database for analytics
   */
  private async logNotification(
    userId: string,
    payload: PushNotificationPayload
  ): Promise<void> {
    try {
      // TODO: Create notification log table and record
      /*
      await this.prisma.notificationLog.create({
        data: {
          userId,
          type: 'push',
          title: payload.title,
          content: payload.body,
          data: payload.data,
          status: 'sent',
        },
      });
      */

      this.logger.debug(
        `[MOCK] Notification logged for user ${userId}: ${payload.title}`
      );
    } catch (error) {
      this.logger.error('Failed to log notification:', error);
      // Don't throw - logging failure shouldn't break notification sending
    }
  }

  private getFirebaseApp(): admin.app.App | null {
    const existingGlobal = admin.apps.find((a) => a?.name === '[DEFAULT]');
    if (existingGlobal) {
      this.firebaseApp = existingGlobal;
      PushNotificationService.sharedFirebaseApp = existingGlobal;
      return existingGlobal;
    }
    if (PushNotificationService.sharedFirebaseApp) {
      this.firebaseApp = PushNotificationService.sharedFirebaseApp;
      return this.firebaseApp;
    }
    if (this.firebaseApp) return this.firebaseApp;
    if (this.firebaseInitFailed || PushNotificationService.sharedInitFailed) {
      if (Date.now() < PushNotificationService.nextInitRetryAt) {
        return null;
      }
      // Transient misconfig (empty env on first boot) — try again later.
      this.firebaseInitFailed = false;
      PushNotificationService.sharedInitFailed = false;
      this.firebaseConfigWarned = false;
      PushNotificationService.sharedConfigWarned = false;
    }

    const serviceAccount = this.loadServiceAccountCredentials();
    if (!serviceAccount) {
      this.firebaseInitFailed = true;
      PushNotificationService.sharedInitFailed = true;
      PushNotificationService.nextInitRetryAt = Date.now() + 5 * 60 * 1000;
      return null;
    }

    try {
      const existing = admin.apps.find((a) => a?.name === '[DEFAULT]');
      const app =
        existing ??
        admin.initializeApp({
          credential: admin.credential.cert(
            serviceAccount as admin.ServiceAccount,
          ),
        });
      this.firebaseApp = app;
      PushNotificationService.sharedFirebaseApp = app;
      this.logger.log(
        `Firebase Admin SDK initialized (project: ${(serviceAccount as { project_id?: string }).project_id ?? 'unknown'})`,
      );
      return app;
    } catch (error) {
      const recovered = admin.apps.find((a) => a?.name === '[DEFAULT]');
      if (recovered) {
        this.firebaseApp = recovered;
        PushNotificationService.sharedFirebaseApp = recovered;
        return recovered;
      }
      this.firebaseInitFailed = true;
      PushNotificationService.sharedInitFailed = true;
      this.logger.error('Failed to initialize Firebase Admin SDK:', error);
      return null;
    }
  }

  private isTypeEnabledForPush(
    typeSettings: unknown,
    notificationType?: string,
  ): boolean {
    if (!notificationType || typeof typeSettings !== 'object' || typeSettings === null) {
      return true;
    }
    const settings = typeSettings as Record<string, boolean>;
    const t = notificationType.toUpperCase();

    // Nearby discovery alerts — dedicated opt-out; fall back to category flags.
    if (t.includes('NEARBY')) {
      if (typeof settings.nearby === 'boolean') return settings.nearby;
      if (t.includes('TRADE')) return settings.trade !== false;
      if (t.includes('GIFT')) return settings.gift !== false;
      if (t.includes('CAMPAIGN') || t.includes('DONATION')) {
        return settings.campaign !== false;
      }
      return settings.system !== false;
    }

    // Admin broadcasts
    if (t === 'BROADCAST') {
      if (typeof settings.broadcast === 'boolean') return settings.broadcast;
      return settings.system !== false;
    }

    // Chat (sourceType chat_message / type CHAT) — never match SYSTEM_ANNOUNCEMENT here.
    if (
      t === 'CHAT' ||
      t === 'CHAT_MESSAGE' ||
      t === 'MESSAGE' ||
      t === 'NEW_MESSAGE' ||
      t === 'MENTION'
    ) {
      return settings.message !== false;
    }

    // Wallet / BYC transfer
    if (
      t === 'TRANSFER' ||
      t.includes('TRANSFER') ||
      t === 'WALLET' ||
      t.includes('WALLET') ||
      t === 'ACCOUNT_SECURITY' ||
      t === 'BYC_TRANSFER'
    ) {
      if (typeof settings.wallet === 'boolean') return settings.wallet;
      return settings.system !== false;
    }

    if (t.includes('TRADE')) return settings.trade !== false;
    if (t.includes('GIFT') || t === 'GIFT_REQUEST') return settings.gift !== false;
    if (t.includes('DONATION') || t.includes('CAMPAIGN')) {
      return settings.campaign !== false;
    }
    if (t.includes('KARMA') || t.includes('ACHIEVEMENT') || t.includes('REFERRAL')) {
      return settings.achievement !== false;
    }

    // Community / admin / generic system rows
    if (
      t.includes('COMMUNITY') ||
      t === 'AD_SCHEDULE' ||
      t === 'USER_REPORT' ||
      t.includes('SYSTEM_ANNOUNCEMENT')
    ) {
      return settings.system !== false;
    }

    // Avoid treating SYSTEM_ANNOUNCEMENT as message via accidental "MESSAGE" substring.
    if (t.includes('MESSAGE') && !t.includes('SYSTEM')) {
      return settings.message !== false;
    }

    return settings.system !== false;
  }

  /**
   * Load Firebase service account from env. Handles common Railway misconfigurations:
   * double-wrapped `{{...}}`, outer quotes, base64, or a filesystem path by mistake.
   */
  private loadServiceAccountCredentials(): Record<string, unknown> | null {
    const jsonEnv = process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim();
    const pathEnv =
      process.env.FIREBASE_SERVICE_ACCOUNT_PATH?.trim() ||
      process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim();

    if (!jsonEnv && !pathEnv) {
      return null;
    }

    if (pathEnv) {
      const fromFile = this.readServiceAccountFile(pathEnv);
      if (fromFile) return fromFile;
    }

    if (!jsonEnv) {
      this.logCredentialParseFailure(
        'FIREBASE_SERVICE_ACCOUNT_PATH points to a missing or invalid file.',
      );
      return null;
    }

    // Env value may be a path to the JSON file (common copy-paste mistake).
    if (
      (jsonEnv.endsWith('.json') || jsonEnv.startsWith('/')) &&
      fs.existsSync(jsonEnv)
    ) {
      const fromFile = this.readServiceAccountFile(jsonEnv);
      if (fromFile) return fromFile;
    }

    const parsed = this.parseServiceAccountJson(jsonEnv);
    if (parsed) return parsed;

    this.logCredentialParseFailure(
      'FIREBASE_SERVICE_ACCOUNT_JSON is set but is not valid JSON. Use a single-line minified service account JSON or base64-encode the file.',
    );
    return null;
  }

  private readServiceAccountFile(filePath: string): Record<string, unknown> | null {
    try {
      const resolved = path.isAbsolute(filePath)
        ? filePath
        : path.resolve(process.cwd(), filePath);
      if (!fs.existsSync(resolved)) return null;
      const raw = fs.readFileSync(resolved, 'utf8');
      return this.parseServiceAccountJson(raw);
    } catch (error) {
      this.logger.error(`Failed to read Firebase credentials file ${filePath}:`, error);
      return null;
    }
  }

  private parseServiceAccountJson(raw: string): Record<string, unknown> | null {
    const candidates = this.buildJsonParseCandidates(raw);
    let lastError: unknown;

    for (const candidate of candidates) {
      try {
        let parsed: unknown = JSON.parse(candidate);
        if (typeof parsed === 'string') {
          parsed = JSON.parse(parsed);
        }
        if (this.isServiceAccount(parsed)) {
          return parsed;
        }
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError) {
      const hint =
        raw.trimStart().startsWith('{{') ?
          ' (detected leading "{{" — remove extra braces from Railway env value)'
        : '';
      this.logger.error(
        `Firebase service account JSON parse failed${hint}:`,
        lastError,
      );
    }
    return null;
  }

  private buildJsonParseCandidates(raw: string): string[] {
    let s = raw.replace(/^\uFEFF/, '').trim();
    const out: string[] = [];

    const push = (v: string) => {
      const t = v.trim();
      if (t && !out.includes(t)) out.push(t);
    };

    push(s);

    // Railway / compose template sometimes double-wraps: {{ { ... } }}
    if (s.startsWith('{{') && s.endsWith('}}')) {
      push(s.slice(1, -1));
    }

    // Outer single/double quotes around entire JSON blob
    if (
      (s.startsWith("'") && s.endsWith("'")) ||
      (s.startsWith('"') && s.endsWith('"') && s.length > 2 && s[1] === '{')
    ) {
      push(s.slice(1, -1));
    }

    // Base64-encoded JSON (safe for Railway multiline secrets)
    if (!s.startsWith('{')) {
      try {
        const decoded = Buffer.from(s, 'base64').toString('utf8').trim();
        push(decoded);
        if (decoded.startsWith('{{') && decoded.endsWith('}}')) {
          push(decoded.slice(1, -1));
        }
      } catch {
        // not base64
      }
    }

    return out;
  }

  private isServiceAccount(value: unknown): value is Record<string, unknown> {
    if (!value || typeof value !== 'object') return false;
    const v = value as Record<string, unknown>;
    return (
      v.type === 'service_account' &&
      typeof v.project_id === 'string' &&
      typeof v.private_key === 'string' &&
      typeof v.client_email === 'string'
    );
  }

  private logCredentialParseFailure(message: string): void {
    if (!this.firebaseConfigWarned && !PushNotificationService.sharedConfigWarned) {
      this.firebaseConfigWarned = true;
      PushNotificationService.sharedConfigWarned = true;
      this.logger.warn(message);
    }
  }
}

// Service factory for easy testing and mocking
export class MockPushNotificationService extends PushNotificationService {
  private readonly mockLogger = new Logger(MockPushNotificationService.name);

  async sendNotification(
    userId: string,
    payload: PushNotificationPayload
  ): Promise<boolean> {
    this.mockLogger.log(
      `[MOCK] Push notification sent to user ${userId}: ${payload.title} - ${payload.body}`
    );
    return true;
  }
}
