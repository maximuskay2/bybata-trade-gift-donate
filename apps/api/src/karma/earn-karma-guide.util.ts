/** Canonical earn-guide definitions — point amounts loaded from admin config at runtime. */
export const KARMA_ACTION_POINTS: Record<string, number> = {
  COMPLETE_TRADE: 15,
  GIVE_GIFT: 10,
  MAKE_DONATION: 10,
  CREATE_POST: 10,
  HELP_COMMUNITY: 20,
  GET_VERIFIED: 100,
  REFER_FRIEND: 75,
  DAILY_LOGIN: 10,
  JOIN_EVENT: 15,
};

export type EarnGuideRoute =
  | 'create_trade'
  | 'browse_trades'
  | 'refer_friend'
  | 'verification'
  | 'settings_security'
  | 'community_discover'
  | 'create_gift'
  | 'browse_donations'
  | 'leaderboard'
  | 'achievements'
  | 'claim_daily';

export interface EarnGuideMethodDef {
  id: string;
  category: string;
  title: string;
  description: string;
  pointsKey: keyof typeof KARMA_ACTION_POINTS | 'SECURE_ACCOUNT';
  iconKey: string;
  route: EarnGuideRoute;
  actionLabel: string;
  isRecurring: boolean;
  /** When set, tapping "Go" calls POST /v1/karma/actions/earn instead of navigating. */
  claimActionType?: string;
}

export const EARN_GUIDE_METHODS: EarnGuideMethodDef[] = [
  {
    id: 'first_trade',
    category: 'Trading',
    title: 'Complete your first trade',
    description: 'List an item and complete a successful swap.',
    pointsKey: 'COMPLETE_TRADE',
    iconKey: 'swap_horiz',
    route: 'create_trade',
    actionLabel: 'Start trading',
    isRecurring: false,
  },
  {
    id: 'trade_regular',
    category: 'Trading',
    title: 'Trade regularly',
    description: 'Earn KARMA each time you complete a trade.',
    pointsKey: 'COMPLETE_TRADE',
    iconKey: 'bar_chart',
    route: 'browse_trades',
    actionLabel: 'Browse trades',
    isRecurring: true,
  },
  {
    id: 'give_gift',
    category: 'Trading',
    title: 'Give a gift',
    description: 'Share something with the community and earn KARMA.',
    pointsKey: 'GIVE_GIFT',
    iconKey: 'card_giftcard',
    route: 'create_gift',
    actionLabel: 'Create gift',
    isRecurring: true,
  },
  {
    id: 'make_donation',
    category: 'Trading',
    title: 'Make a donation',
    description: 'Support a campaign and earn KARMA for giving back.',
    pointsKey: 'MAKE_DONATION',
    iconKey: 'volunteer_activism',
    route: 'browse_donations',
    actionLabel: 'Browse campaigns',
    isRecurring: true,
  },
  {
    id: 'refer_friend',
    category: 'Referrals',
    title: 'Invite a friend',
    description: 'Share your code — earn when they join and complete actions.',
    pointsKey: 'REFER_FRIEND',
    iconKey: 'person_add',
    route: 'refer_friend',
    actionLabel: 'Share invite',
    isRecurring: true,
  },
  {
    id: 'get_verified',
    category: 'Verification',
    title: 'Verify your identity',
    description: 'Unlock higher limits and a trusted badge.',
    pointsKey: 'GET_VERIFIED',
    iconKey: 'verified_user',
    route: 'verification',
    actionLabel: 'Verify now',
    isRecurring: false,
  },
  {
    id: 'secure_account',
    category: 'Verification',
    title: 'Secure your wallet',
    description: 'Set a wallet PIN in security settings.',
    pointsKey: 'SECURE_ACCOUNT',
    iconKey: 'security',
    route: 'settings_security',
    actionLabel: 'Open security',
    isRecurring: false,
  },
  {
    id: 'community_join',
    category: 'Social',
    title: 'Join a community',
    description: 'Discover groups near you and connect with members.',
    pointsKey: 'HELP_COMMUNITY',
    iconKey: 'forum',
    route: 'community_discover',
    actionLabel: 'Explore',
    isRecurring: true,
  },
  {
    id: 'create_post',
    category: 'Social',
    title: 'Share an insight',
    description: 'Post tips or stories that help the community.',
    pointsKey: 'CREATE_POST',
    iconKey: 'lightbulb',
    route: 'community_discover',
    actionLabel: 'Create post',
    isRecurring: true,
  },
  {
    id: 'daily_login',
    category: 'Social',
    title: 'Daily login streak',
    description: 'Open the app daily to keep your streak alive.',
    pointsKey: 'DAILY_LOGIN',
    iconKey: 'local_fire_department',
    route: 'claim_daily',
    actionLabel: 'Claim today',
    isRecurring: true,
    claimActionType: 'DAILY_LOGIN',
  },
  {
    id: 'leaderboard',
    category: 'Events',
    title: 'Climb the leaderboard',
    description: 'Compete with top members and track your rank.',
    pointsKey: 'COMPLETE_TRADE',
    iconKey: 'emoji_events',
    route: 'leaderboard',
    actionLabel: 'View leaderboard',
    isRecurring: true,
  },
  {
    id: 'achievements',
    category: 'Events',
    title: 'Unlock achievements',
    description: 'Complete milestones for bonus KARMA rewards.',
    pointsKey: 'HELP_COMMUNITY',
    iconKey: 'military_tech',
    route: 'achievements',
    actionLabel: 'View achievements',
    isRecurring: true,
  },
];

export function pointsForGuideKey(key: EarnGuideMethodDef['pointsKey']): number {
  if (key === 'SECURE_ACCOUNT') return 0;
  return KARMA_ACTION_POINTS[key] ?? 10;
}
