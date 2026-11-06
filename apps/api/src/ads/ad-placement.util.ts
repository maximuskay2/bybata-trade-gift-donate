/**
 * Canonical feed placement keys used in the mobile app (AdPlacementSection).
 * Admin AdPlacement rows must use these keys (donation_feed is an alias for campaign_feed).
 */
export const APP_AD_PLACEMENT_KEYS = [
  'home_feed',
  'trade_feed',
  'gift_feed',
  'campaign_feed',
  'community_feed',
  'search_feed',
] as const;

/** Keys that resolve to the same feed surface when querying ads. */
export const PLACEMENT_QUERY_ALIASES: Record<string, string[]> = {
  home_feed: ['home_feed'],
  trade_feed: ['trade_feed'],
  gift_feed: ['gift_feed'],
  campaign_feed: ['campaign_feed', 'donation_feed'],
  donation_feed: ['donation_feed', 'campaign_feed'],
  community_feed: ['community_feed'],
  search_feed: ['search_feed'],
};

export function resolvePlacementQueryKeys(placementKey: string): string[] {
  const normalized = placementKey.trim();
  const aliases = PLACEMENT_QUERY_ALIASES[normalized];
  if (aliases) return [...new Set(aliases)];
  return [normalized];
}

export function placementMatchFilter(placementKey: string) {
  const keys = resolvePlacementQueryKeys(placementKey);
  return {
    OR: keys.flatMap((key) => [
      { placementKey: key },
      { placementKeys: { has: key } },
    ]),
  };
}
