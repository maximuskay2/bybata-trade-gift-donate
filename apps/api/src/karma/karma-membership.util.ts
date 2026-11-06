import { TrustLevel } from '@prisma/client';

export const KARMA_TIER_THRESHOLDS: { tier: TrustLevel; minPoints: number }[] = [
  { tier: TrustLevel.LEGEND, minPoints: 50000 },
  { tier: TrustLevel.DIAMOND, minPoints: 25000 },
  { tier: TrustLevel.PLATINUM, minPoints: 10000 },
  { tier: TrustLevel.GOLD, minPoints: 5000 },
  { tier: TrustLevel.SILVER, minPoints: 2000 },
  { tier: TrustLevel.BRONZE, minPoints: 500 },
  { tier: TrustLevel.NEWCOMER, minPoints: 0 },
];

export const PREMIUM_KARMA_TIERS: TrustLevel[] = [
  TrustLevel.GOLD,
  TrustLevel.PLATINUM,
  TrustLevel.DIAMOND,
  TrustLevel.LEGEND,
];

export const MEMBERSHIP_FEATURES = [
  { key: 'premium_trade_filters', minPoints: 100, label: 'Premium Trade Filters' },
  { key: 'gift_scheduling', minPoints: 150, label: 'Gift Scheduling' },
  { key: 'community_creation', minPoints: 200, label: 'Exclusive Communities' },
  { key: 'bulk_trading', minPoints: 250, label: 'Higher Trading Limits' },
  { key: 'priority_support', minPoints: 600, label: 'Priority Support' },
] as const;

export function trustLevelForPoints(points: number): TrustLevel {
  for (const row of KARMA_TIER_THRESHOLDS) {
    if (points >= row.minPoints) return row.tier;
  }
  return TrustLevel.NEWCOMER;
}

export function membershipLabel(tier: TrustLevel): string {
  switch (tier) {
    case TrustLevel.LEGEND:
      return 'Legend';
    case TrustLevel.DIAMOND:
      return 'Diamond';
    case TrustLevel.PLATINUM:
      return 'Platinum';
    case TrustLevel.GOLD:
      return 'Gold';
    case TrustLevel.SILVER:
      return 'Silver';
    case TrustLevel.BRONZE:
      return 'Bronze';
    default:
      return 'Newcomer';
  }
}

export function isPremiumMember(tier: TrustLevel, currentPoints: number): boolean {
  return PREMIUM_KARMA_TIERS.includes(tier) || currentPoints >= 5000;
}

export function unlockedFeatureKeys(currentPoints: number): string[] {
  return MEMBERSHIP_FEATURES.filter((f) => currentPoints >= f.minPoints).map(
    (f) => f.key,
  );
}

export function nextTierInfo(currentPoints: number): {
  nextTier: TrustLevel | null;
  pointsNeeded: number;
} {
  const sorted = [...KARMA_TIER_THRESHOLDS].sort(
    (a, b) => a.minPoints - b.minPoints,
  );
  for (const row of sorted) {
    if (currentPoints < row.minPoints) {
      return {
        nextTier: row.tier,
        pointsNeeded: row.minPoints - currentPoints,
      };
    }
  }
  return { nextTier: null, pointsNeeded: 0 };
}

export function enrichKarmaAccount(account: {
  id: string;
  userId: string;
  currentPoints: number;
  totalPointsEarned: number;
  level: number;
  trustLevel: TrustLevel;
  streak: number;
  lastActivityAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}) {
  const tier = account.trustLevel;
  const premium = isPremiumMember(tier, account.currentPoints);
  const next = nextTierInfo(account.currentPoints);
  return {
    ...account,
    membership: {
      tier,
      label: membershipLabel(tier),
      isPremium: premium,
      planName: premium ? 'Premium (KARMA)' : membershipLabel(tier),
      nextTier: next.nextTier,
      nextTierLabel: next.nextTier ? membershipLabel(next.nextTier) : null,
      pointsToNextTier: next.pointsNeeded,
    },
    unlockedFeatures: unlockedFeatureKeys(account.currentPoints),
  };
}
