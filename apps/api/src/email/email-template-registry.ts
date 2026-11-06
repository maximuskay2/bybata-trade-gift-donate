import { EmailEventName } from './email-events';
import { EmailTemplateSpec } from './email.types';

export const EMAIL_TEMPLATE_REGISTRY: Record<EmailEventName, EmailTemplateSpec> = {
  [EmailEventName.AuthSignupWelcome]: {
    templateId: 'auth/signup-welcome',
    requiredVars: ['firstName', 'displayName', 'appName', 'supportEmail', 'loginUrl'],
  },
  [EmailEventName.AuthEmailVerify]: {
    templateId: 'auth/email-verify',
    requiredVars: ['displayName', 'verificationLink', 'expiresAt', 'appName'],
  },
  [EmailEventName.AuthEmailVerified]: {
    templateId: 'auth/email-verified',
    requiredVars: ['displayName', 'appName', 'loginUrl'],
  },
  [EmailEventName.AuthPasswordResetRequest]: {
    templateId: 'auth/password-reset-request',
    requiredVars: ['displayName', 'resetLink', 'expiresAt', 'appName'],
  },
  [EmailEventName.AuthPasswordChanged]: {
    templateId: 'auth/password-changed',
    requiredVars: ['displayName', 'changedAt', 'supportEmail'],
  },
  [EmailEventName.AuthLoginNewDevice]: {
    templateId: 'auth/login-new-device',
    requiredVars: ['displayName', 'deviceName', 'location', 'loginAt', 'supportEmail'],
  },
  [EmailEventName.AuthAccountLocked]: {
    templateId: 'auth/account-locked',
    requiredVars: ['displayName', 'unlockSteps', 'supportEmail'],
  },
  [EmailEventName.AuthAccountDeleteRequest]: {
    templateId: 'auth/account-delete-request',
    requiredVars: ['displayName', 'requestedAt', 'supportEmail'],
  },
  [EmailEventName.AuthAccountDeletedConfirm]: {
    templateId: 'auth/account-deleted-confirm',
    requiredVars: ['displayName', 'deletedAt', 'supportEmail'],
  },

  [EmailEventName.TradeRequestReceived]: {
    templateId: 'trade/request-received',
    requiredVars: ['targetName', 'actorName', 'tradeTitle', 'tradeId', 'tradeUrl'],
  },
  [EmailEventName.TradeRequestAccepted]: {
    templateId: 'trade/request-accepted',
    requiredVars: ['actorName', 'targetName', 'tradeTitle', 'tradeId', 'tradeUrl'],
  },
  [EmailEventName.TradeRequestRejected]: {
    templateId: 'trade/request-rejected',
    requiredVars: ['actorName', 'targetName', 'tradeTitle', 'tradeId', 'tradeUrl'],
  },
  [EmailEventName.TradeCounterOfferReceived]: {
    templateId: 'trade/counter-offer-received',
    requiredVars: ['targetName', 'actorName', 'tradeTitle', 'counterOfferSummary', 'tradeUrl'],
  },
  [EmailEventName.TradeCompleted]: {
    templateId: 'trade/completed',
    requiredVars: ['actorName', 'targetName', 'tradeTitle', 'tradeId', 'completedAt', 'tradeUrl'],
  },
  [EmailEventName.TradeCanceled]: {
    templateId: 'trade/canceled',
    requiredVars: ['actorName', 'targetName', 'tradeTitle', 'canceledBy', 'tradeUrl'],
  },
  [EmailEventName.TradeReminderPending]: {
    templateId: 'trade/reminder-pending',
    requiredVars: ['actorName', 'tradeTitle', 'daysPending', 'tradeUrl'],
  },

  [EmailEventName.GiftOfferReceived]: {
    templateId: 'gift/offer-received',
    requiredVars: ['targetName', 'actorName', 'giftTitle', 'giftUrl'],
  },
  [EmailEventName.GiftAccepted]: {
    templateId: 'gift/accepted',
    requiredVars: ['actorName', 'targetName', 'giftTitle', 'giftUrl'],
  },
  [EmailEventName.GiftClaimed]: {
    templateId: 'gift/claimed',
    requiredVars: ['actorName', 'targetName', 'giftTitle', 'claimedAt', 'giftUrl'],
  },
  [EmailEventName.GiftExpired]: {
    templateId: 'gift/expired',
    requiredVars: ['actorName', 'giftTitle', 'expiredAt'],
  },
  [EmailEventName.GiftThankYouPrompt]: {
    templateId: 'gift/thank-you-prompt',
    requiredVars: ['targetName', 'actorName', 'giftTitle', 'giftUrl'],
  },

  [EmailEventName.CampaignCreated]: {
    templateId: 'campaign/created',
    requiredVars: ['actorName', 'campaignTitle', 'campaignUrl'],
  },
  [EmailEventName.CampaignPublished]: {
    templateId: 'campaign/published',
    requiredVars: ['actorName', 'campaignTitle', 'campaignUrl'],
  },
  [EmailEventName.CampaignApproved]: {
    templateId: 'campaign/approved',
    requiredVars: ['actorName', 'campaignTitle', 'campaignUrl'],
  },
  [EmailEventName.CampaignRejected]: {
    templateId: 'campaign/rejected',
    requiredVars: ['actorName', 'campaignTitle', 'reason', 'supportEmail'],
  },
  [EmailEventName.DonationReceived]: {
    templateId: 'donation/received',
    requiredVars: ['targetName', 'donorName', 'amount', 'currency', 'campaignTitle', 'campaignUrl'],
  },
  [EmailEventName.DonationReceipt]: {
    templateId: 'donation/receipt',
    requiredVars: ['actorName', 'amount', 'currency', 'campaignTitle', 'receiptId', 'campaignUrl'],
  },
  [EmailEventName.CampaignMilestoneReached]: {
    templateId: 'campaign/milestone-reached',
    requiredVars: ['targetName', 'campaignTitle', 'milestone', 'campaignUrl'],
  },
  [EmailEventName.CampaignExpiring]: {
    templateId: 'campaign/expiring',
    requiredVars: ['targetName', 'campaignTitle', 'daysLeft', 'campaignUrl'],
  },
  [EmailEventName.CampaignEnded]: {
    templateId: 'campaign/ended',
    requiredVars: ['targetName', 'campaignTitle', 'totalRaised', 'campaignUrl'],
  },
  [EmailEventName.CampaignPaused]: {
    templateId: 'campaign/paused',
    requiredVars: ['targetName', 'campaignTitle', 'campaignUrl'],
  },
  [EmailEventName.DonationFailed]: {
    templateId: 'donation/failed',
    requiredVars: ['actorName', 'amount', 'currency', 'campaignTitle', 'reason', 'supportEmail'],
  },

  [EmailEventName.WalletFunded]: {
    templateId: 'wallet/funded',
    requiredVars: ['actorName', 'amount', 'currency', 'balance', 'fundedAt'],
  },
  [EmailEventName.WalletFundingFailed]: {
    templateId: 'wallet/funding-failed',
    requiredVars: ['actorName', 'amount', 'currency', 'reason', 'supportEmail'],
  },
  [EmailEventName.WalletBycSent]: {
    templateId: 'wallet/byc-sent',
    requiredVars: ['actorName', 'amount', 'recipientName', 'balance', 'txId'],
  },
  [EmailEventName.WalletBycReceived]: {
    templateId: 'wallet/byc-received',
    requiredVars: ['targetName', 'amount', 'senderName', 'balance', 'txId'],
  },
  [EmailEventName.WalletPromotionReceipt]: {
    templateId: 'wallet/promotion-receipt',
    requiredVars: ['actorName', 'amount', 'currency', 'itemTitle', 'purchaseId', 'purchasedAt'],
  },
  [EmailEventName.WalletBoostReceipt]: {
    templateId: 'wallet/boost-receipt',
    requiredVars: ['actorName', 'amount', 'currency', 'itemTitle', 'purchaseId', 'purchasedAt'],
  },
  [EmailEventName.WalletRefunded]: {
    templateId: 'wallet/refund',
    requiredVars: ['actorName', 'amount', 'currency', 'reason', 'refundedAt'],
  },
  [EmailEventName.WalletWithdrawalRequested]: {
    templateId: 'wallet/withdrawal-requested',
    requiredVars: ['actorName', 'amount', 'currency', 'withdrawalId', 'createdAt'],
  },
  [EmailEventName.WalletWithdrawalCompleted]: {
    templateId: 'wallet/withdrawal-completed',
    requiredVars: ['actorName', 'amount', 'currency', 'withdrawalId', 'completedAt'],
  },
  [EmailEventName.WalletWithdrawalRejected]: {
    templateId: 'wallet/withdrawal-rejected',
    requiredVars: ['actorName', 'amount', 'currency', 'withdrawalId', 'status', 'reason'],
  },
  [EmailEventName.WalletWithdrawalFailed]: {
    templateId: 'wallet/withdrawal-failed',
    requiredVars: ['actorName', 'amount', 'currency', 'withdrawalId', 'status', 'reason'],
  },
  [EmailEventName.WalletWithdrawalCancelled]: {
    templateId: 'wallet/withdrawal-cancelled',
    requiredVars: ['actorName', 'amount', 'currency', 'withdrawalId', 'status', 'reason'],
  },
  [EmailEventName.WalletRateUpdated]: {
    templateId: 'wallet/rate-updated',
    requiredVars: ['actorName', 'oldRate', 'newRate', 'effectiveAt'],
  },
  [EmailEventName.WalletPinResetRequest]: {
    templateId: 'auth/password-reset-request',
    requiredVars: ['displayName', 'resetLink', 'expiresAt', 'appName'],
  },

  [EmailEventName.CommunityInviteReceived]: {
    templateId: 'community/invite-received',
    requiredVars: ['targetName', 'communityName', 'inviterName', 'inviteUrl'],
  },
  [EmailEventName.CommunityInviteAccepted]: {
    templateId: 'community/invite-accepted',
    requiredVars: ['actorName', 'targetName', 'communityName'],
  },
  [EmailEventName.CommunityInviteDeclined]: {
    templateId: 'community/invite-declined',
    requiredVars: ['actorName', 'targetName', 'communityName'],
  },
  [EmailEventName.CommunityJoinRequestApproved]: {
    templateId: 'community/join-request-approved',
    requiredVars: ['targetName', 'communityName', 'communityUrl'],
  },
  [EmailEventName.CommunityJoinRequestRejected]: {
    templateId: 'community/join-request-rejected',
    requiredVars: ['targetName', 'communityName', 'reason'],
  },
  [EmailEventName.CommunityNewPostDigest]: {
    templateId: 'community/new-post-digest',
    requiredVars: ['targetName', 'communityName', 'postCount', 'digestUrl'],
  },
  [EmailEventName.CommunityMention]: {
    templateId: 'community/mention',
    requiredVars: ['targetName', 'actorName', 'communityName', 'postUrl'],
  },

  [EmailEventName.ChatNewMessage]: {
    templateId: 'chat/new-message',
    requiredVars: ['targetName', 'actorName', 'snippet', 'chatUrl'],
  },
  [EmailEventName.ChatNewConversation]: {
    templateId: 'chat/new-conversation',
    requiredVars: ['targetName', 'actorName', 'contextTitle', 'chatUrl'],
  },
  [EmailEventName.ChatReaction]: {
    templateId: 'chat/reaction',
    requiredVars: ['targetName', 'actorName', 'emoji', 'chatUrl'],
  },
  [EmailEventName.ChatMention]: {
    templateId: 'chat/mention',
    requiredVars: ['targetName', 'actorName', 'snippet', 'chatUrl'],
  },

  [EmailEventName.ProfileUpdated]: {
    templateId: 'profile/updated',
    requiredVars: ['actorName', 'updatedAt'],
  },
  [EmailEventName.VerificationSubmitted]: {
    templateId: 'verification/submitted',
    requiredVars: ['actorName', 'submittedAt'],
  },
  [EmailEventName.VerificationApproved]: {
    templateId: 'verification/approved',
    requiredVars: ['actorName', 'approvedAt', 'trustLevel'],
  },
  [EmailEventName.VerificationRejected]: {
    templateId: 'verification/rejected',
    requiredVars: ['actorName', 'reason', 'supportEmail'],
  },
  [EmailEventName.KarmaLevelUp]: {
    templateId: 'karma/level-up',
    requiredVars: ['actorName', 'newLevel', 'points'],
  },

  [EmailEventName.AdSubmitted]: {
    templateId: 'ads/submitted',
    requiredVars: ['actorName', 'adTitle', 'adId'],
  },
  [EmailEventName.AdApproved]: {
    templateId: 'ads/approved',
    requiredVars: ['actorName', 'adTitle', 'startDate', 'adUrl'],
  },
  [EmailEventName.AdRejected]: {
    templateId: 'ads/rejected',
    requiredVars: ['actorName', 'adTitle', 'reason'],
  },
  [EmailEventName.AdStarted]: {
    templateId: 'ads/started',
    requiredVars: ['actorName', 'adTitle', 'startDate', 'adUrl'],
  },
  [EmailEventName.AdBudgetLow]: {
    templateId: 'ads/budget-low',
    requiredVars: ['actorName', 'adTitle', 'remainingBudget', 'adUrl'],
  },
  [EmailEventName.AdBudgetDepleted]: {
    templateId: 'ads/budget-depleted',
    requiredVars: ['actorName', 'adTitle', 'adUrl'],
  },
  [EmailEventName.AdEnded]: {
    templateId: 'ads/ended',
    requiredVars: ['actorName', 'adTitle', 'spent', 'adUrl'],
  },

  [EmailEventName.SystemMaintenanceScheduled]: {
    templateId: 'system/maintenance-scheduled',
    requiredVars: ['windowStart', 'windowEnd', 'statusUrl'],
  },
  [EmailEventName.SystemPolicyUpdated]: {
    templateId: 'system/policy-updated',
    requiredVars: ['effectiveAt', 'policyUrl'],
  },
  [EmailEventName.SystemWeeklySummary]: {
    templateId: 'system/weekly-summary',
    requiredVars: ['actorName', 'summaryItems', 'summaryUrl'],
  },
  [EmailEventName.PromotionPerformanceSummary]: {
    templateId: 'promotion/performance-summary',
    requiredVars: ['actorName', 'summaryItems', 'summaryUrl'],
  },
};
