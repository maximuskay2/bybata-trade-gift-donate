import { AssistantTarget, IntentHub } from '../ai/intent-schema';

export type SearchInterpretModule = IntentHub | 'discover';
export type HubPriority = 'high' | 'medium' | 'low';

export interface HubDirective {
  priority: HubPriority;
  tags: string[];
}

export interface IntentLayout {
  primary: IntentHub;
  secondary: IntentHub;
  banner: IntentHub;
}

export type IntentCohort = 'ai' | 'rules';

export interface AssistantGuidance {
  reply: string;
  steps: string[];
  actions: Array<{ target: AssistantTarget; label: string }>;
  /** False when the query is a need or a how-to, not a search for items. */
  showListings: boolean;
}

export interface SearchInterpretResult {
  modules: SearchInterpretModule[];
  query: string;
  locationHint: string | null;
  verifiedOnly: boolean;
  source: 'rules' | 'ai';
  intentLabel: string;
  confidence: number;
  categories: string[];
  keywords: string[];
  hubs: Record<IntentHub, HubDirective>;
  layout: IntentLayout;
  radiusKm: number | null;
  fallbackReason: string | null;
  /** ai = this user may call the model. rules = rollout or kill switch kept them on rules. */
  cohort: IntentCohort;
  /** True when this payload was served from the intent cache. */
  cached: boolean;
  /** Model-written guidance. Null on rules results; the app has its own rules guidance. */
  assistant: AssistantGuidance | null;
}

const DONATION_WORDS = [
  'donate',
  'donation',
  'campaign',
  'fund',
  'fundraiser',
  'charity',
  'crowdfund',
  'surgery',
  'rent',
  'school',
];
const TRADE_WORDS = ['trade', 'swap', 'barter', 'exchange', 'offer', 'sell'];
const GIFT_WORDS = ['gift', 'give', 'free', 'share'];
const STOP = new Set([
  'the',
  'and',
  'for',
  'with',
  'this',
  'that',
  'your',
  'from',
  'near',
  'some',
  'need',
  'want',
  'help',
  'my',
  'a',
  'an',
  'to',
  'of',
  'in',
  'on',
]);

const LEADING_FILLER = [
  /^(please|pls|abeg|biko|hi|hello|hey|ok|okay|so)\b[ ,]*/i,
  /^(i|we) (really |just |also |still )?(need|want|wanna|would like|'d like|dey find|wan|am looking for|'m looking for)( to)?( (get|buy|have|find|see|browse))?\b ?/i,
  /^(i'?m|im) (looking|searching) for\b ?/i,
  /^(looking|searching) for\b ?/i,
  /^(can|could|may) (i|we|you) (please )?(get|find|have|see|show me|help me find)\b ?/i,
  /^(do|does) (you|anyone|anybody|someone) (have|has|get|got)\b ?/i,
  /^(is|are) there\b ?/i,
  /^(anyone|anybody|someone|who) (have|has|get|got)\b ?/i,
  /^(where|how) (can|do) (i|we) (get|find|buy)\b ?/i,
  /^(help me|show me|find me|get me|give me)( (find|get|see))?\b ?/i,
];

/** "I need a car" → "car". Conversational lead-ins are not product names. */
export function stripFiller(raw: string): string {
  let rest = raw.trim().replace(/[?!.]+$/g, '');
  let changed = true;
  while (changed) {
    changed = false;
    for (const filler of LEADING_FILLER) {
      const next = rest.replace(filler, '').trim();
      if (next !== rest) {
        rest = next;
        changed = true;
      }
    }
  }
  rest = rest.replace(/^(a|an|some|any|the)\s+/i, '').trim();
  return rest.length >= 2 ? rest : raw.trim();
}

export function emptyInterpret(query: string): SearchInterpretResult {
  return {
    modules: ['discover'],
    query,
    locationHint: null,
    verifiedOnly: false,
    source: 'rules',
    intentLabel: query || 'Search',
    confidence: 0,
    categories: [],
    keywords: [],
    hubs: defaultHubs('gift'),
    layout: { primary: 'gift', secondary: 'trade', banner: 'campaign' },
    radiusKm: null,
    fallbackReason: null,
    cohort: 'rules',
    cached: false,
    assistant: null,
  };
}

/** Synchronous rules interpreter. This is the safety net for every AI failure. */
export function interpretWithRules(raw: string): SearchInterpretResult {
  const trimmed = raw.trim();
  const lower = trimmed.toLowerCase();

  const modules = new Set<SearchInterpretModule>();
  if (DONATION_WORDS.some((w) => hasWord(lower, w))) modules.add('campaign');
  if (TRADE_WORDS.some((w) => hasWord(lower, w))) modules.add('trade');
  if (GIFT_WORDS.some((w) => hasWord(lower, w))) modules.add('gift');
  if (modules.size === 0) modules.add('discover');

  const locationHint = locationFrom(lower);
  const verifiedOnly = hasWord(lower, 'verified') || hasWord(lower, 'trusted');

  let query = stripFiller(trimmed);
  for (const noise of [
    ...DONATION_WORDS,
    ...TRADE_WORDS,
    ...GIFT_WORDS,
    'near me',
    'nearby',
    'around me',
    'around campus',
    'campus',
    'local',
    'verified',
    'trusted',
  ]) {
    query = query.replace(new RegExp(`\\b${noise}\\b`, 'gi'), ' ');
  }
  query = query.replace(/\s+/g, ' ').trim();
  if (query.length < 2) query = trimmed;

  const hubs = presentHubs(modules);
  const layout = layoutFor(hubs);
  const keywords = keywordsFrom(query);
  const confidence = scoreRules(hubs, keywords);

  return {
    modules: Array.from(modules),
    query,
    locationHint,
    verifiedOnly,
    source: 'rules',
    intentLabel: (query.length >= 2 ? query : trimmed).slice(0, 80),
    confidence,
    categories: [],
    keywords,
    hubs: hubWeights(layout),
    layout,
    radiusKm: radiusFor(locationHint),
    fallbackReason: null,
    cohort: 'rules',
    cached: false,
    assistant: null,
  };
}

/** Explicit hub keyword plus a concrete noun. Skip the model on these. */
export function isHighConfidenceRules(result: SearchInterpretResult): boolean {
  const hasHub = result.modules.some((m) => m === 'gift' || m === 'trade' || m === 'campaign');
  return hasHub && result.confidence >= 0.85;
}

/**
 * A question or a request for advice. These still call the model when the
 * rules are confident, so "how do I request a gift" is answered in words
 * instead of being treated as a keyword search.
 */
const GUIDANCE_QUESTION =
  /(\?|\b(how|what|why|when|where|which)\b|\b(can|could|should|would) (i|we|you)\b|\b(explain|advice|advise|suggest|recommend|difference)\b)/i;

export function asksForGuidance(raw: string): boolean {
  return GUIDANCE_QUESTION.test(raw.trim());
}

export function clampRadiusKm(value: number): number {
  if (!Number.isFinite(value)) return 50;
  return Math.min(500, Math.max(1, value));
}

/**
 * Default radius stays 50km (or the caller's radius). The model may only
 * narrow it, and only when the query asked for somewhere nearby.
 * A widened search is the user's choice and is not narrowed again.
 */
export function resolveIntentRadius(
  requested: number | undefined,
  interpret: Pick<SearchInterpretResult, 'locationHint' | 'radiusKm'>,
  widen: boolean,
): number {
  if (widen) return clampRadiusKm(requested ?? 500);
  const base = clampRadiusKm(requested ?? 50);
  const hint = interpret.locationHint;
  if (hint !== 'near me' && hint !== 'around campus') return base;
  let cap = base;
  if (hint === 'around campus') {
    const configured = Number(process.env.AI_INTENT_CAMPUS_RADIUS_KM ?? 15);
    cap = Math.min(cap, clampRadiusKm(Number.isFinite(configured) ? configured : 15));
  }
  if (interpret.radiusKm == null) return cap;
  return Math.min(cap, clampRadiusKm(interpret.radiusKm));
}

function hasWord(haystack: string, word: string): boolean {
  return new RegExp(`\\b${word}\\b`, 'i').test(haystack);
}

function locationFrom(lower: string): string | null {
  if (/\baround campus\b|\bon campus\b|\bcampus\b/.test(lower)) return 'around campus';
  if (/\bnear me\b|\bnearby\b|\baround me\b|\blocal\b/.test(lower)) return 'near me';
  return null;
}

function radiusFor(locationHint: string | null): number | null {
  if (locationHint === 'around campus') return 15;
  if (locationHint === 'near me') return 25;
  return null;
}

function presentHubs(modules: Set<SearchInterpretModule>): IntentHub[] {
  return (['campaign', 'trade', 'gift'] as IntentHub[]).filter((m) => modules.has(m));
}

function layoutFor(hubs: IntentHub[]): IntentLayout {
  const primary = hubs[0] ?? 'gift';
  const rest = (['gift', 'trade', 'campaign'] as IntentHub[]).filter((m) => m !== primary);
  const banner =
    hubs.includes('campaign') && primary !== 'campaign' ? 'campaign' : rest[rest.length - 1];
  const secondary =
    hubs.find((m) => m !== primary && m !== banner) ??
    rest.find((m) => m !== banner) ??
    rest[0];
  return { primary, secondary, banner };
}

function hubWeights(layout: IntentLayout): Record<IntentHub, HubDirective> {
  const priorityOf = (hub: IntentHub): HubPriority => {
    if (hub === layout.primary) return 'high';
    if (hub === layout.secondary) return 'medium';
    return 'low';
  };
  return {
    gift: { priority: priorityOf('gift'), tags: [] },
    trade: { priority: priorityOf('trade'), tags: [] },
    campaign: { priority: priorityOf('campaign'), tags: [] },
  };
}

function defaultHubs(primary: IntentHub): Record<IntentHub, HubDirective> {
  return hubWeights({
    primary,
    secondary: primary === 'gift' ? 'trade' : 'gift',
    banner: 'campaign',
  });
}

function keywordsFrom(query: string): string[] {
  const out: string[] = [];
  for (const token of query.toLowerCase().split(/[^a-z0-9₦]+/i)) {
    if (token.length < 3 || STOP.has(token) || out.includes(token)) continue;
    out.push(token);
    if (out.length >= 8) break;
  }
  return out;
}

function scoreRules(hubs: IntentHub[], keywords: string[]): number {
  if (hubs.length > 0 && keywords.length > 0) return 0.92;
  if (hubs.length > 0) return 0.55;
  if (keywords.length > 0) return 0.35;
  return 0.2;
}
