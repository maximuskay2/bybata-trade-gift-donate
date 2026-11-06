/** Central karma earn amounts — defaults are startup-conservative; admin overrides via AppSetting. */

export type KarmaPointsConfig = {
  tradeComplete: number;
  giftGiven: number;
  giftDefaultReward: number;
  giftRewardMin: number;
  giftRewardMax: number;
  /** Percent of BYC donated converted to karma (e.g. 5 = 5%). */
  donationKarmaPercent: number;
  /** Flat karma for earn-guide donation action (legacy manual claim). */
  makeDonation: number;
  createPost: number;
  helpCommunity: number;
  getVerified: number;
  referFriend: number;
  dailyLogin: number;
  joinEvent: number;
  positiveReview: number;
  negativeReview: number;
  profileLike: number;
  seedingBonus: number;
  referralSignup: number;
  referralFirstTrade: number;
  referralFirstDonation: number;
  referralFirstGift: number;
  actionCompleted: number;
  shareContent: number;
  reportIssue: number;
  receiveReview: number;
  mentorUser: number;
};

export type KarmaPointsFieldMeta = {
  key: keyof KarmaPointsConfig;
  label: string;
  description: string;
  group: 'core' | 'social' | 'referrals' | 'other';
  min: number;
  max: number;
  step?: number;
  unit?: 'points' | 'percent';
};

export const KARMA_POINTS_SETTING_PREFIX = 'KARMA_POINTS_';

export const KARMA_POINTS_SETTING_KEYS: Record<keyof KarmaPointsConfig, string> = {
  tradeComplete: 'KARMA_POINTS_TRADE_COMPLETE',
  giftGiven: 'KARMA_POINTS_GIFT_GIVEN',
  giftDefaultReward: 'KARMA_POINTS_GIFT_DEFAULT_REWARD',
  giftRewardMin: 'KARMA_POINTS_GIFT_REWARD_MIN',
  giftRewardMax: 'KARMA_POINTS_GIFT_REWARD_MAX',
  donationKarmaPercent: 'KARMA_POINTS_DONATION_PERCENT',
  makeDonation: 'KARMA_POINTS_MAKE_DONATION',
  createPost: 'KARMA_POINTS_CREATE_POST',
  helpCommunity: 'KARMA_POINTS_HELP_COMMUNITY',
  getVerified: 'KARMA_POINTS_GET_VERIFIED',
  referFriend: 'KARMA_POINTS_REFER_FRIEND',
  dailyLogin: 'KARMA_POINTS_DAILY_LOGIN',
  joinEvent: 'KARMA_POINTS_JOIN_EVENT',
  positiveReview: 'KARMA_POINTS_POSITIVE_REVIEW',
  negativeReview: 'KARMA_POINTS_NEGATIVE_REVIEW',
  profileLike: 'KARMA_POINTS_PROFILE_LIKE',
  seedingBonus: 'KARMA_POINTS_SEEDING_BONUS',
  referralSignup: 'KARMA_POINTS_REFERRAL_SIGNUP',
  referralFirstTrade: 'KARMA_POINTS_REFERRAL_FIRST_TRADE',
  referralFirstDonation: 'KARMA_POINTS_REFERRAL_FIRST_DONATION',
  referralFirstGift: 'KARMA_POINTS_REFERRAL_FIRST_GIFT',
  actionCompleted: 'KARMA_POINTS_ACTION_COMPLETED',
  shareContent: 'KARMA_POINTS_SHARE_CONTENT',
  reportIssue: 'KARMA_POINTS_REPORT_ISSUE',
  receiveReview: 'KARMA_POINTS_RECEIVE_REVIEW',
  mentorUser: 'KARMA_POINTS_MENTOR_USER',
};

/** Built-in defaults (startup-conservative; trade/gift = 1; donation = 1 karma per 10 BYC). */
export const DEFAULT_KARMA_POINTS: KarmaPointsConfig = {
  tradeComplete: 1,
  giftGiven: 1,
  giftDefaultReward: 1,
  giftRewardMin: 1,
  giftRewardMax: 1,
  /** 10% of BYC donated → 10 BYC = 1 karma, 60 BYC = 6 karma. */
  donationKarmaPercent: 10,
  makeDonation: 1,
  createPost: 5,
  helpCommunity: 10,
  getVerified: 50,
  referFriend: 1,
  dailyLogin: 5,
  joinEvent: 8,
  positiveReview: 10,
  negativeReview: 5,
  profileLike: 2,
  seedingBonus: 15,
  referralSignup: 1,
  referralFirstTrade: 1,
  referralFirstDonation: 1,
  referralFirstGift: 1,
  actionCompleted: 5,
  shareContent: 3,
  reportIssue: 10,
  receiveReview: 10,
  mentorUser: 15,
};

/** Previous hardcoded values — shown in admin for comparison. */
export const LEGACY_KARMA_POINTS: Partial<KarmaPointsConfig> = {
  tradeComplete: 50,
  giftGiven: 30,
  giftDefaultReward: 30,
  giftRewardMin: 10,
  giftRewardMax: 100,
  donationKarmaPercent: 10,
  makeDonation: 40,
  createPost: 10,
  helpCommunity: 20,
  getVerified: 100,
  referFriend: 75,
  dailyLogin: 10,
  joinEvent: 15,
  positiveReview: 25,
  negativeReview: 15,
  profileLike: 5,
  seedingBonus: 50,
  referralSignup: 75,
  referralFirstTrade: 50,
  referralFirstDonation: 40,
  referralFirstGift: 30,
};

export const KARMA_POINTS_FIELD_META: KarmaPointsFieldMeta[] = [
  {
    key: 'tradeComplete',
    label: 'Trade completed',
    description: 'Karma when a trade is marked complete',
    group: 'core',
    min: 0,
    max: 500,
  },
  {
    key: 'giftGiven',
    label: 'Gift completed (giver)',
    description: 'Karma when giver marks a gift complete',
    group: 'core',
    min: 0,
    max: 500,
  },
  {
    key: 'giftDefaultReward',
    label: 'Gift listing default',
    description: 'Default karma shown on new gifts if not specified',
    group: 'core',
    min: 0,
    max: 500,
  },
  {
    key: 'giftRewardMin',
    label: 'Gift reward minimum',
    description: 'Lowest karma a giver can set on a gift',
    group: 'core',
    min: 0,
    max: 500,
  },
  {
    key: 'giftRewardMax',
    label: 'Gift reward maximum',
    description: 'Highest karma a giver can set on a gift',
    group: 'core',
    min: 1,
    max: 1000,
  },
  {
    key: 'donationKarmaPercent',
    label: 'Donation karma %',
    description:
      'Percent of BYC donated awarded as karma (floored). 10% ⇒ 10 BYC = 1 karma, 60 BYC = 6 karma.',
    group: 'core',
    min: 0,
    max: 100,
    step: 0.5,
    unit: 'percent',
  },
  {
    key: 'makeDonation',
    label: 'Donation (earn guide)',
    description: 'Flat karma for earn-guide donation action only (real donations use %)',
    group: 'core',
    min: 0,
    max: 500,
  },
  {
    key: 'createPost',
    label: 'Community post',
    description: 'Karma for creating a community post',
    group: 'social',
    min: 0,
    max: 200,
  },
  {
    key: 'helpCommunity',
    label: 'Help community',
    description: 'Karma for community help actions',
    group: 'social',
    min: 0,
    max: 200,
  },
  {
    key: 'positiveReview',
    label: 'Positive review received',
    description: 'Karma for 4–5 star reviews',
    group: 'social',
    min: 0,
    max: 200,
  },
  {
    key: 'negativeReview',
    label: 'Negative review received',
    description: 'Karma deducted for 1–2 star reviews',
    group: 'social',
    min: 0,
    max: 200,
  },
  {
    key: 'profileLike',
    label: 'Profile like',
    description: 'Karma when someone likes a profile',
    group: 'social',
    min: 0,
    max: 50,
  },
  {
    key: 'getVerified',
    label: 'Identity verified',
    description: 'One-time karma for verification',
    group: 'other',
    min: 0,
    max: 500,
  },
  {
    key: 'referFriend',
    label: 'Refer a friend (guide)',
    description: 'Earn-guide referral action',
    group: 'other',
    min: 0,
    max: 500,
  },
  {
    key: 'dailyLogin',
    label: 'Daily login',
    description: 'Daily login streak claim',
    group: 'other',
    min: 0,
    max: 100,
  },
  {
    key: 'joinEvent',
    label: 'Join event',
    description: 'Community event attendance',
    group: 'other',
    min: 0,
    max: 200,
  },
  {
    key: 'seedingBonus',
    label: 'Seeding listing bonus',
    description: 'Bonus for ecosystem seeding trade/gift listings',
    group: 'other',
    min: 0,
    max: 500,
  },
  {
    key: 'referralSignup',
    label: 'Referral — signup',
    description: 'Referrer karma when invitee signs up',
    group: 'referrals',
    min: 0,
    max: 500,
  },
  {
    key: 'referralFirstTrade',
    label: 'Referral — first trade',
    description: 'Referrer karma on invitee first trade',
    group: 'referrals',
    min: 0,
    max: 500,
  },
  {
    key: 'referralFirstDonation',
    label: 'Referral — first donation',
    description: 'Referrer karma on invitee first donation',
    group: 'referrals',
    min: 0,
    max: 500,
  },
  {
    key: 'referralFirstGift',
    label: 'Referral — first gift',
    description: 'Referrer karma on invitee first gift',
    group: 'referrals',
    min: 0,
    max: 500,
  },
  {
    key: 'actionCompleted',
    label: 'Generic action',
    description: 'Fallback for unspecified earn actions',
    group: 'other',
    min: 0,
    max: 100,
  },
  {
    key: 'shareContent',
    label: 'Share content',
    description: 'Karma for sharing content',
    group: 'other',
    min: 0,
    max: 50,
  },
  {
    key: 'reportIssue',
    label: 'Report issue',
    description: 'Karma for reporting issues',
    group: 'other',
    min: 0,
    max: 100,
  },
  {
    key: 'receiveReview',
    label: 'Receive review (action)',
    description: 'Manual earn action for reviews',
    group: 'other',
    min: 0,
    max: 200,
  },
  {
    key: 'mentorUser',
    label: 'Mentor user',
    description: 'Manual earn action for mentoring',
    group: 'other',
    min: 0,
    max: 200,
  },
];

/** Donation karma scales with BYC: percent floored (default 10% → 10 BYC = 1 karma). */
export function calculateDonationKarmaFromConfig(
  amount: number,
  percent: number,
): number {
  if (amount <= 0 || percent <= 0) return 0;
  return Math.floor(amount * (percent / 100));
}

export function clampGiftReward(
  value: number | undefined,
  config: KarmaPointsConfig,
): number {
  const base = value ?? config.giftDefaultReward;
  const min = Math.min(config.giftRewardMin, config.giftRewardMax);
  const max = Math.max(config.giftRewardMin, config.giftRewardMax);
  return Math.min(max, Math.max(min, base));
}

export function parsePointsConfigValue(
  key: keyof KarmaPointsConfig,
  raw: string | null | undefined,
): number {
  if (raw == null || raw.trim() === '') {
    return DEFAULT_KARMA_POINTS[key];
  }
  const n = Number(raw);
  if (!Number.isFinite(n)) {
    return DEFAULT_KARMA_POINTS[key];
  }
  const meta = KARMA_POINTS_FIELD_META.find((f) => f.key === key);
  if (!meta) return n;
  return Math.min(meta.max, Math.max(meta.min, n));
}

export function pointsForGuideKeyFromConfig(
  key: string,
  config: KarmaPointsConfig,
): number {
  const map: Record<string, number> = {
    COMPLETE_TRADE: config.tradeComplete,
    GIVE_GIFT: config.giftGiven,
    MAKE_DONATION: config.makeDonation,
    CREATE_POST: config.createPost,
    HELP_COMMUNITY: config.helpCommunity,
    GET_VERIFIED: config.getVerified,
    REFER_FRIEND: config.referFriend,
    DAILY_LOGIN: config.dailyLogin,
    JOIN_EVENT: config.joinEvent,
    SECURE_ACCOUNT: 0,
  };
  return map[key] ?? config.actionCompleted;
}
