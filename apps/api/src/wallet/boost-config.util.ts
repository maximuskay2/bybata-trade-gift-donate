export type BoostConfigShape = {
  pricingModel?: string;
  baseCostBYC?: any;
  dailyCostBYC?: any;
  tiers?: any;
};

export type AdPricingRates = {
  tradeBycPerDay: number;
  giftBycPerDay: number;
  donationBycPerDay: number;
  normalBycPerDay: number;
};

export function dailyRateForPlacementKey(
  key: string,
  pricing: AdPricingRates,
): number {
  const k = key.toLowerCase();
  if (k.includes('trade')) return pricing.tradeBycPerDay;
  if (k.includes('gift')) return pricing.giftBycPerDay;
  if (k.includes('donation') || k.includes('campaign')) {
    return pricing.donationBycPerDay;
  }
  return pricing.normalBycPerDay;
}

export function computeBoostCost(config: BoostConfigShape, days: number): number {
  const model = String(config?.pricingModel || 'FIXED').toUpperCase();
  if (model === 'DAILY') {
    const daily = Number((config as any)?.dailyCostBYC ?? 0);
    return daily * days;
  }
  if (model === 'TIERED') {
    const tiers = Array.isArray((config as any)?.tiers) ? (config as any).tiers : [];
    for (const tier of tiers) {
      const minDays = Number(tier?.minDays ?? tier?.days ?? 0);
      const maxDays = Number(tier?.maxDays ?? tier?.days ?? minDays);
      if (days >= minDays && days <= maxDays) {
        return Number(tier?.cost ?? 0);
      }
    }
  }
  return Number((config as any)?.baseCostBYC ?? 0);
}

/** Total BYC for selected calendar days across one or more placements. */
export function computeBoostPurchaseTotal(
  config: BoostConfigShape,
  dayCount: number,
  placementKeys: string[],
  pricing: AdPricingRates,
): number {
  if (dayCount <= 0 || placementKeys.length === 0) return 0;

  const model = String(config?.pricingModel || 'FIXED').toUpperCase();
  if (model === 'DAILY') {
    let perDay = 0;
    for (const key of placementKeys) {
      perDay += dailyRateForPlacementKey(key, pricing);
    }
    return perDay * dayCount;
  }

  const base = computeBoostCost(config, dayCount);
  return base * placementKeys.length;
}

export function costForBoostPlacement(
  config: BoostConfigShape,
  dayCount: number,
  placementKey: string,
  pricing: AdPricingRates,
): number {
  const model = String(config?.pricingModel || 'FIXED').toUpperCase();
  if (model === 'DAILY') {
    return dailyRateForPlacementKey(placementKey, pricing) * dayCount;
  }
  return computeBoostCost(config, dayCount);
}

export function isoDateKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/** Normalize boost day list; falls back to `days` consecutive UTC dates from today. */
export function normalizeBoostDates(
  boostDatesInput: string[] | undefined,
  days: number | undefined,
): string[] {
  if (boostDatesInput?.length) {
    const unique = [
      ...new Set(
        boostDatesInput
          .map((d) => d.trim())
          .filter((d) => /^\d{4}-\d{2}-\d{2}$/.test(d)),
      ),
    ];
    unique.sort();
    return unique;
  }
  if (days && days > 0) {
    const out: string[] = [];
    const start = new Date();
    start.setUTCHours(0, 0, 0, 0);
    for (let i = 0; i < days; i++) {
      const d = new Date(start);
      d.setUTCDate(d.getUTCDate() + i);
      out.push(isoDateKey(d));
    }
    return out;
  }
  return [];
}

export function parseBoostDateUtc(dateStr: string): Date {
  const [y, m, d] = dateStr.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

export function startOfUtcDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

export function endOfUtcDay(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 23, 59, 59, 999),
  );
}

export function isBoostActiveOnDate(
  boostDates: string[] | null | undefined,
  endsAt: Date,
  at: Date,
): boolean {
  if (at > endsAt) return false;
  if (boostDates && boostDates.length > 0) {
    return boostDates.includes(isoDateKey(at));
  }
  return endsAt >= at;
}
