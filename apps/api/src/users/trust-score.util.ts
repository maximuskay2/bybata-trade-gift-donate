import { TrustLevel } from '@prisma/client';

export type TrustScoreInput = {
  averageRating: number;
  totalReviews: number;
  karmaPoints: number;
  trustLevel: TrustLevel;
  isVerified: boolean;
  completedTrades: number;
  totalGifts: number;
  totalDonations: number;
};

export type TrustScoreResult = {
  /** Display score on a 0–5 scale (matches profile TrustScore UI). */
  score: number;
  /** 0–1 normalized score for TrustIndicator widgets. */
  normalized: number;
  /** Karma tier index 1–7 (Newcomer → Legend). */
  level: number;
  trustLevel: TrustLevel;
  levelName: string;
  badges: { id: string; name: string; description: string; icon: string }[];
  lastUpdated: string;
};

const TIER_ORDER: TrustLevel[] = [
  TrustLevel.NEWCOMER,
  TrustLevel.BRONZE,
  TrustLevel.SILVER,
  TrustLevel.GOLD,
  TrustLevel.PLATINUM,
  TrustLevel.DIAMOND,
  TrustLevel.LEGEND,
];

function tierIndex(tier: TrustLevel): number {
  const i = TIER_ORDER.indexOf(tier);
  return i >= 0 ? i + 1 : 1;
}

function levelNameFromScore(score: number): string {
  if (score >= 4.8) return 'Trusted Expert';
  if (score >= 4.5) return 'Highly Trusted';
  if (score >= 4.0) return 'Trusted';
  if (score >= 3.5) return 'Reliable';
  if (score >= 2.5) return 'Building Trust';
  return 'New Member';
}

/**
 * Composite trust score (0–5) from community signals:
 * - Reviews (40%): average star rating
 * - KARMA tier (25%): earned reputation
 * - Verification (15%): identity verified
 * - Activity (20%): completed trades, gifts given, donations made
 */
export function calculateTrustScore(input: TrustScoreInput): TrustScoreResult {
  const ratingBase =
    input.totalReviews > 0
      ? Math.min(5, Math.max(0, input.averageRating))
      : 2.5; // neutral prior for unrated members

  const tierIdx = tierIndex(input.trustLevel);
  const karmaComponent = (tierIdx / TIER_ORDER.length) * 5 * 0.25;
  const karmaPointsBoost = Math.min(0.35, (input.karmaPoints / 10000) * 0.35);
  const verifyComponent = input.isVerified ? 5 * 0.15 : 0;

  const activityUnits =
    input.completedTrades + input.totalGifts + input.totalDonations;
  const activityComponent = Math.min(5 * 0.2, (activityUnits / 50) * (5 * 0.2));

  const raw =
    ratingBase * 0.4 +
    karmaComponent +
    karmaPointsBoost +
    verifyComponent +
    activityComponent;

  const score = Math.round(Math.min(5, Math.max(0, raw)) * 10) / 10;
  const normalized = Math.round((score / 5) * 100) / 100;

  const badges: TrustScoreResult['badges'] = [];
  if (input.isVerified) {
    badges.push({
      id: 'verified',
      name: 'Verified',
      description: 'Identity verified',
      icon: 'verified',
    });
  }
  if (tierIdx >= 4) {
    badges.push({
      id: 'karma_gold_plus',
      name: 'Gold+ Member',
      description: 'High KARMA tier',
      icon: 'star',
    });
  }
  if (input.totalReviews >= 5 && input.averageRating >= 4.5) {
    badges.push({
      id: 'top_rated',
      name: 'Top Rated',
      description: 'Consistently high reviews',
      icon: 'thumb_up',
    });
  }

  return {
    score,
    normalized,
    level: tierIdx,
    trustLevel: input.trustLevel,
    levelName: levelNameFromScore(score),
    badges,
    lastUpdated: new Date().toISOString(),
  };
}
