import { Module } from '@nestjs/common';
import { AdminUsersController } from './admin_users.controller';
import { PrismaModule } from '../common/prisma.module';
import { AdminTradesController } from './admin_trades.controller';
import { AdminWalletController } from './admin_wallet.controller';
import { AdminWalletCreditController } from './admin_wallet_credit.controller';
import { AdminRatesController } from './admin_rates.controller';
import { AdminFundingPackagesController } from './admin_funding_packages.controller';
import { AdminPromotionsController } from './admin_promotions.controller';
import { AdminBoostTypesController } from './admin_boost_types.controller';
import { AdminAdPlacementsController } from './admin_ad_placements.controller';
import { AdminBoostConfigsController } from './admin_boost_configs.controller';
import { AdminAdsController } from './admin_ads.controller';
import { AdminNegotiationsController } from './admin_negotiations.controller';
import { AdminNegotiationsService } from './admin_negotiations.service';
import { AdminGiftsController } from './admin_gifts.controller';
import { AdminCampaignsController } from './admin_campaigns.controller';
import { AdminCommunitiesController } from './admin_communities.controller';
import { AdminAuditController } from './admin_audit.controller';
import { CommunitiesModule } from '../communities/communities.module';
import { AdminAnalyticsController } from './admin_analytics.controller';
import { AdminGatewayConfigController } from './admin_gateway_config.controller';
import { AdminVerificationController } from './admin_verification.controller';
import { AdminMapSettingsController } from './admin_map_settings.controller';
import { AdminAiIntentSettingsController } from './admin_ai_intent_settings.controller';
import { AdminAdPricingController } from './admin_ad_pricing.controller';
import { AdminCommunitySettingsController } from './admin_community_settings.controller';
import { AdminWebhooksController } from './admin_webhooks.controller';
import { PaymentsModule } from '../payments/payments.module';
import { WalletModule } from '../wallet/wallet.module';
import { AdminEmailConfigController } from './admin_email_config.controller';
import { AdminMessagingConfigController } from './admin_messaging_config.controller';
import { EmailService } from '../common/email.service';
import { AdminWalletWithdrawalsController } from './admin_wallet_withdrawals.controller';
import { AdminEmailLogController } from './admin_email_log.controller';
import { AdminKarmaSettingsController } from './admin_karma_settings.controller';
import { AdminUserReportsController } from './admin_user_reports.controller';
import { AdminUserAppealsController } from './admin_user_appeals.controller';
import { AdminReferralsController } from './admin_referrals.controller';
import { AdminListingModerationService } from './admin_listing_moderation.service';
import { SharedModule } from '../shared/shared.module';
import { StorageModule } from '../storage/storage.module';
import { KarmaModule } from '../karma/karma.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [PrismaModule, PaymentsModule, CommunitiesModule, WalletModule, SharedModule, StorageModule, KarmaModule, NotificationsModule],
  controllers: [AdminUsersController, AdminTradesController, AdminWalletController, AdminRatesController, AdminFundingPackagesController, AdminPromotionsController, AdminBoostTypesController, AdminAdPlacementsController, AdminBoostConfigsController, AdminAdsController, AdminNegotiationsController, AdminGiftsController, AdminCampaignsController, AdminCommunitiesController, AdminWalletCreditController, AdminWalletWithdrawalsController, AdminAuditController, AdminAnalyticsController, AdminGatewayConfigController, AdminVerificationController, AdminMapSettingsController, AdminAiIntentSettingsController, AdminAdPricingController, AdminCommunitySettingsController, AdminWebhooksController, AdminEmailConfigController, AdminMessagingConfigController, AdminEmailLogController, AdminKarmaSettingsController, AdminUserReportsController, AdminUserAppealsController, AdminReferralsController],
  providers: [AdminNegotiationsService, EmailService, AdminListingModerationService],
})
export class AdminModule {}
