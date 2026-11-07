import { z } from 'zod';

/** USD midpoints used when no OpenAI key is configured. */
export const CATEGORY_BANDS_USD: Record<string, number> = {
  ELECTRONICS: 180,
  BOOKS: 18,
  CLOTHING: 35,
  FASHION: 55,
  HOME_GARDEN: 70,
  SPORTS: 45,
  TOOLS: 60,
  AUTOMOTIVE: 140,
  COLLECTIBLES: 90,
  OTHERS: 30,
};

export const CONDITION_MULTIPLIERS: Record<string, number> = {
  new: 1,
  like_new: 0.85,
  good: 0.7,
  fair: 0.45,
  poor: 0.25,
};

export const fairValueSchema = z.object({
  amountUsd: z.number().finite(),
  payer: z.enum(['owner', 'bidder']),
  reason: z.string().min(1).max(500),
  confidence: z.number().finite(),
});

export type FairValueQuote = z.infer<typeof fairValueSchema>;

export interface TradeSideInput {
  title: string;
  category?: string | null;
  condition?: string | null;
  photos?: string[];
  role: 'owner' | 'bidder';
}

export interface FairValueResult {
  amount: number;
  currency: 'USD';
  payerRole: 'owner' | 'bidder';
  reason: string;
  confidence: number;
  source: 'ai' | 'fallback';
  capped: boolean;
  capUsd: number;
  ownerValue: number;
  bidderValue: number;
}

export function topUpCapUsd(): number {
  const raw = Number(process.env.TRADE_TOPUP_CAP_USD ?? 500);
  if (!Number.isFinite(raw) || raw <= 0) return 500;
  return Math.min(raw, 5000);
}

export function normalizeCondition(value?: string | null): string {
  const key = (value || 'good').trim().toLowerCase().replace(/[\s-]+/g, '_');
  return CONDITION_MULTIPLIERS[key] != null ? key : 'good';
}

export function sideValueUsd(side: TradeSideInput): number {
  const category = (side.category || 'OTHERS').trim().toUpperCase().replace(/[\s-]+/g, '_');
  const band = CATEGORY_BANDS_USD[category] ?? CATEGORY_BANDS_USD.OTHERS;
  const multiplier = CONDITION_MULTIPLIERS[normalizeCondition(side.condition)];
  return roundMoney(band * multiplier);
}

export function fallbackFairValue(
  owner: TradeSideInput,
  bidder: TradeSideInput,
  capUsd = topUpCapUsd(),
): FairValueResult {
  const ownerValue = sideValueUsd(owner);
  const bidderValue = sideValueUsd(bidder);
  const raw = roundMoney(Math.abs(ownerValue - bidderValue));
  const payerRole: 'owner' | 'bidder' = ownerValue < bidderValue ? 'owner' : 'bidder';
  const capped = raw > capUsd;
  const amount = capped ? roundMoney(capUsd) : raw;
  const known =
    Boolean(owner.category) &&
    Boolean(bidder.category) &&
    owner.category!.toUpperCase() !== 'OTHERS' &&
    bidder.category!.toUpperCase() !== 'OTHERS';
  let confidence = known ? 0.62 : 0.42;
  if ((owner.photos?.length ?? 0) > 0 && (bidder.photos?.length ?? 0) > 0) {
    confidence = Math.min(0.7, confidence + 0.05);
  }

  const higher = ownerValue >= bidderValue ? owner : bidder;
  const lower = payerRole === 'owner' ? owner : bidder;
  const reason =
    amount === 0
      ? `${owner.title} and ${bidder.title} are already close in value, so no cash top-up is needed.`
      : `${lower.title} is worth about $${lower === owner ? ownerValue : bidderValue} and ${higher.title} is worth about $${higher === owner ? ownerValue : bidderValue}. ${labelRole(payerRole)} adds $${amount} so the trade is even.${capped ? ` The suggestion is capped at $${capUsd}.` : ''}`;

  return {
    amount,
    currency: 'USD',
    payerRole,
    reason,
    confidence: roundConfidence(confidence),
    source: 'fallback',
    capped,
    capUsd,
    ownerValue,
    bidderValue,
  };
}

/** Clamp a model quote onto the same guardrails as the price-band fallback. */
export function applyAiQuote(
  baseline: FairValueResult,
  raw: unknown,
): FairValueResult {
  const parsed = fairValueSchema.safeParse(raw);
  if (!parsed.success) return baseline;
  const quote = parsed.data;
  const capped = quote.amountUsd > baseline.capUsd;
  const amount = roundMoney(Math.min(quote.amountUsd, baseline.capUsd));
  const reason = capped
    ? `${quote.reason.trim()} The suggestion is capped at $${baseline.capUsd}.`
    : quote.reason.trim();
  return {
    ...baseline,
    amount,
    payerRole: quote.payer,
    reason: reason.slice(0, 500),
    confidence: roundConfidence(quote.confidence),
    source: 'ai',
    capped,
  };
}

export function roundMoney(value: number): number {
  if (!Number.isFinite(value) || value <= 0) return 0;
  return Math.round(value * 100) / 100;
}

export function roundConfidence(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.round(Math.min(1, Math.max(0, value)) * 100) / 100;
}

function labelRole(role: 'owner' | 'bidder'): string {
  return role === 'owner' ? 'The listing owner' : 'The person making the offer';
}
