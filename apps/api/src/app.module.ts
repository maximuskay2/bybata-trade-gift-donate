import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { CacheModule } from '@nestjs/cache-manager';
import { APP_GUARD } from '@nestjs/core';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './common/prisma.module';
import { ScaleCacheModule } from './common/scale/scale-cache.module';
import { ScaleDefaults } from './common/scale/scale.constants';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { StorageModule } from './storage/storage.module';
import { AdminModule } from './admin/admin.module';
import { WalletModule } from './wallet/wallet.module';
import { TradesModule } from './trades/trades.module';
import { TradeTopUpModule } from './trade-topup/trade-topup.module';
import { GiftsModule } from './gifts/gifts.module';
import { CampaignsModule } from './campaigns/campaigns.module';
import { CommunitiesModule } from './communities/communities.module';
import { KarmaModule } from './karma/karma.module';
import { NotificationsModule } from './notifications/notifications.module';
import { SearchModule } from './search/search.module';
import { ChatModule } from './chat/chat.module';
import { PaymentsModule } from './payments/payments.module';
import { SettingsModule } from './settings/settings.module';
import { FeedModule } from './feed/feed.module';
import { InteractionsModule } from './interactions/interactions.module';
import { LoggingModule } from './common/logging.module';
import { InputSanitizerService } from './common/input-sanitizer.service';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { InputSanitizationInterceptor } from './common/input-sanitization.interceptor';
import { AdsModule } from './ads/ads.module';
import { PublicBrowseModule } from './public/public_browse.module';
import { ReferralsModule } from './referrals/referrals.module';
import { SupportModule } from './support/support.module';
import { ScheduleModule } from '@nestjs/schedule';
import { EmailSchedulerService } from './email/email.scheduler';
import { EmailService } from './common/email.service';
import { SharedModule } from './shared/shared.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: [
        '.env',
        '.env.local',
        ...(process.env.NODE_ENV === 'production' ? [] : ['.env.development']),
        'prisma/.env',
      ],
    }),
    ReferralsModule,
    SupportModule,
    // Global cache: Redis required for multi-million scale; memory is fallback only.
    CacheModule.registerAsync({
      isGlobal: true,
      useFactory: async () => {
        const redisUrl = process.env.REDIS_URL || process.env.REDIS_SOCKET_IO_URL;
        const ttlSec = Number(
          process.env.CACHE_TTL_SECONDS ?? ScaleDefaults.feedCacheTtlSec,
        );
        const maxItems = Number(
          process.env.CACHE_MAX_ITEMS ?? ScaleDefaults.cacheMaxItems,
        );

        if (process.env.NODE_ENV === 'production' && !redisUrl) {
          console.warn(
            '[Cache] REDIS_URL is not set in production. In-memory cache will not scale across replicas — add Redis before multi-million traffic.',
          );
        }

        if (redisUrl) {
          try {
            // Dynamic import so the app can still run without Redis packages installed.
            // NOTE: install cache-manager-ioredis-yet and ioredis in production.
            // eslint-disable-next-line @typescript-eslint/no-var-requires
            const { redisStore } = await import('cache-manager-ioredis-yet');
            const store = await redisStore({
              url: redisUrl,
              // Add connection retry and error handling configuration
              retryStrategy: (times: number) => {
                // Stop retrying after 3 attempts (logged once in catch block)
                if (times > 3) return null;
                return Math.min(times * 1000, 5000);
              },
              enableOfflineQueue: false, // Don't queue commands when offline
              lazyConnect: true, // Don't connect immediately
              // Handle connection errors gracefully
              connectTimeout: 5000,
              maxRetriesPerRequest: 1,
            });

            // Get the underlying ioredis client and handle errors
            const client = (store as any).client;
            if (client) {
              // Suppress noisy error/reconnecting logs during connection attempts;
              // we log once when falling back to memory cache
              client.on('error', () => {});
              client.on('reconnecting', () => {});
              client.on('connect', () => {
                console.log('[Cache] Redis connected successfully');
              });

              // Attempt to connect
              try {
                await client.connect();
              } catch (connectError: any) {
                console.warn('[Cache] Redis unavailable, using memory cache:', connectError?.message || 'connection failed');
                // Return memory cache instead
                return {
                  ttl: ttlSec * 1000,
                  max: maxItems,
                };
              }
            }

            return {
              store,
              ttl: ttlSec * 1000,
            } as any;
          } catch (e: any) {
            // Fallback to in-memory cache if Redis store cannot be loaded.
            console.warn('[Cache] Failed to initialize Redis store, falling back to memory:', e?.message || e);
          }
        } else {
          // No REDIS_URL set - use in-memory cache (normal for dev; in prod, add Redis for scaling)
          console.log('[Cache] Using in-memory cache (REDIS_URL not set)');
        }
        return {
          ttl: ttlSec * 1000,
          max: maxItems,
        };
      },
    }),
    ScaleCacheModule,
    ScheduleModule.forRoot(),
    // Production-ready rate limiting configuration
    // Three tiers: short (1 min), medium (5 min), long (15 min)
    // Limits are configurable via environment variables
    ThrottlerModule.forRoot([
      {
        name: 'short',
        ttl: 60000, // 1 minute
        limit: Number(process.env.RATE_LIMIT_SHORT) || (process.env.NODE_ENV === 'production' ? 60 : 100),
      },
      {
        name: 'medium',
        ttl: 300000, // 5 minutes
        limit: Number(process.env.RATE_LIMIT_MEDIUM) || (process.env.NODE_ENV === 'production' ? 200 : 500),
      },
      {
        name: 'long',
        ttl: 900000, // 15 minutes
        limit: Number(process.env.RATE_LIMIT_LONG) || (process.env.NODE_ENV === 'production' ? 1000 : 2000),
      },
    ]),
    LoggingModule,
    PrismaModule,
    SharedModule,
    AuthModule,
    UsersModule,
    StorageModule,
    AdminModule,
    WalletModule,
    TradesModule,
    TradeTopUpModule,
    GiftsModule,
    CampaignsModule,
    CommunitiesModule,
    KarmaModule,
    NotificationsModule,
    AdsModule,
    SearchModule,
    ChatModule,
    PaymentsModule,
    SettingsModule,
    FeedModule,
    InteractionsModule,
    PublicBrowseModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    InputSanitizerService,
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: InputSanitizationInterceptor,
    },
    EmailService,
    EmailSchedulerService,
  ],
  exports: [InputSanitizerService],
})
export class AppModule {}
