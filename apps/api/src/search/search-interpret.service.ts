import { Inject, Injectable, Logger } from '@nestjs/common';
import { createHash } from 'crypto';
import { CategoryAllowListService } from '../ai/category-allow-list.service';
import { ASSISTANT_TARGETS, AssistantTarget, buildIntentZod } from '../ai/intent-schema';
import { buildIntentSystemPrompt } from '../ai/intent-prompt';
import { LLM_CLIENT, LlmClient } from '../ai/llm-client';
import { PrismaService } from '../common/prisma.service';
import { ScaleCacheService } from '../common/scale/scale-cache.service';
import {
  AssistantGuidance,
  IntentCohort,
  SearchInterpretResult,
  clampRadiusKm,
  emptyInterpret,
  asksForGuidance,
  interpretWithRules,
  isHighConfidenceRules,
} from './intent-rules';
import { decideIntentCohort, parseRolloutPercent, rolloutCity } from './intent-rollout';

export type { SearchInterpretResult, SearchInterpretModule } from './intent-rules';

export interface InterpretContext {
  userId?: string;
  /** Accepted for callers. Never forwarded to the model. */
  lat?: number;
  lng?: number;
  locale?: string;
  /** JWT role. Staff stay in the AI arm during a partial rollout. */
  role?: string;
  /** Refinement chips re-query with rules only. */
  forceRules?: boolean;
}

const INTENT_EVENTS = new Set([
  'ai_intent_shown',
  'ai_intent_cleared',
  'ai_intent_fallback',
  'ai_intent_slot_tap',
  'ai_intent_conversion',
]);

const CACHE_TTL_SEC = 24 * 60 * 60;
const RATE_LIMIT_PER_MINUTE = 30;
const LOG_RETENTION_MS = 30 * 24 * 60 * 60 * 1000;
const AI_SETTING_KEY = 'AI_INTENT_ENABLED';
const ROLLOUT_PERCENT_KEY = 'AI_INTENT_ROLLOUT_PERCENT';
const ROLLOUT_CITY_KEY = 'AI_INTENT_ROLLOUT_CITY';

@Injectable()
export class SearchInterpretService {
  private readonly logger = new Logger(SearchInterpretService.name);
  private lastLogPrune = 0;

  constructor(
    @Inject(LLM_CLIENT) private readonly llm: LlmClient,
    private readonly cache: ScaleCacheService,
    private readonly categories: CategoryAllowListService,
    private readonly prisma: PrismaService,
  ) {}

  /**
   * Rules first. Obvious item searches skip the model. Questions and advice
   * still call it, so the reply can explain gifts, trades, and campaigns.
   * The kill switch, API key, cache, and rate limit still apply.
   */
  async interpret(raw: string, ctx: InterpretContext = {}): Promise<SearchInterpretResult> {
    const started = Date.now();
    const sanitized = sanitizeQuery(raw);
    if (sanitized.length < 2) return emptyInterpret(sanitized);

    const rules = interpretWithRules(sanitized);
    const enabled = await this.isAiEnabled();
    const cohort: IntentCohort = enabled ? await this.assignCohort(ctx) : 'rules';
    const skipModel = isHighConfidenceRules(rules) && !asksForGuidance(sanitized);
    if (ctx.forceRules || skipModel) {
      const result = { ...rules, cohort: ctx.forceRules ? 'rules' : cohort };
      this.logInterpret(result, Date.now() - started);
      return result;
    }

    const apiKey = process.env.OPENAI_API_KEY?.trim();
    if (!enabled || !apiKey) {
      return this.rulesFallback(
        rules,
        !apiKey ? 'missing_api_key' : 'disabled',
        started,
        undefined,
        'rules',
      );
    }

    if (cohort === 'rules') {
      return this.rulesFallback(rules, 'rollout', started, undefined, 'rules');
    }

    const cacheKey = `ai:intent:v2:${sha1(normalizeQuery(sanitized))}`;
    const cached = await this.cache.getJson<SearchInterpretResult>(cacheKey);
    if (cached && cached.source === 'ai') {
      const hit = { ...cached, cohort: 'ai' as const, cached: true };
      this.logInterpret(hit, Date.now() - started);
      return hit;
    }

    if (await this.rateLimited(ctx.userId)) {
      return this.rulesFallback(rules, 'rate_limited', started, undefined, 'ai');
    }

    const timeoutMs = timeoutFromEnv();
    try {
      const allow = await this.categories.list();
      const schema = buildIntentZod(allow);
      const llmResult = await Promise.race([
        this.llm.generateJson({
          schemaName: 'search_intent',
          zodSchema: schema,
          systemPrompt: buildIntentSystemPrompt(allow, ctx.locale || 'en-NG'),
          userPrompt: promptForModel(sanitized),
          timeoutMs,
          maxTokens: 450,
        }),
        rejectAfter(timeoutMs),
      ]);

      const validated = schema.safeParse(llmResult.json);
      const payload = validated.success
        ? validated.data
        : readLooseIntent(llmResult.json);
      if (!payload) {
        return this.rulesFallback(rules, 'invalid_json', started, llmResult, 'ai');
      }

      const ai = this.fromModel(payload, allow, rules);
      await this.cache.setJson(cacheKey, ai, CACHE_TTL_SEC);
      this.logInterpret(ai, Date.now() - started, llmResult.promptTokens, llmResult.completionTokens);
      return ai;
    } catch (err: any) {
      const message = String(err?.message || err);
      const reason = /timeout/i.test(message)
        ? 'timeout'
        : /invalid_json|schema/i.test(message)
          ? 'invalid_json'
          : 'error';
      if (reason === 'error') {
        this.logger.warn(`AI intent call failed: ${message.slice(0, 300)}`);
      }
      return this.rulesFallback(rules, reason, started, undefined, 'ai');
    }
  }

  async recordEvent(
    body: {
      event?: string;
      cohort?: string;
      module?: string;
      size?: string;
      reason?: string;
      kind?: string;
      latencyMs?: number;
      cached?: boolean;
    },
    userId?: string,
  ): Promise<{ ok: boolean }> {
    const event = body.event?.trim() ?? '';
    const cohort = body.cohort === 'ai' ? 'ai' : body.cohort === 'rules' ? 'rules' : '';
    if (!INTENT_EVENTS.has(event) || !cohort) return { ok: false };
    if (await this.rateLimited(userId, 'event', 60)) return { ok: false };
    const size = body.size === 'hero' || body.size === 'standard' || body.size === 'compact' ? body.size : null;
    const latencyMs = Number(body.latencyMs);
    try {
      await this.prisma.aiIntentEvent.create({
        data: {
          event,
          cohort,
          module: clip(body.module, 40),
          size,
          reason: clip(body.reason, 40),
          kind: clip(body.kind, 40),
          cached: body.cached === true,
          latencyMs: Number.isFinite(latencyMs) && latencyMs >= 0 && latencyMs <= 60000
            ? Math.round(latencyMs)
            : null,
        },
      });
      return { ok: true };
    } catch (err: any) {
      this.logger.warn(`ai intent event skipped: ${err?.message || err}`);
      return { ok: false };
    }
  }

  private fromModel(
    data: {
      modules: Array<'gift' | 'trade' | 'campaign'>;
      query: string;
      locationHint: string | null;
      verifiedOnly: boolean;
      intentLabel: string;
      confidence: number;
      categories: string[];
      keywords: string[];
      hubs: SearchInterpretResult['hubs'];
      layout: SearchInterpretResult['layout'];
      radiusKm: number | null;
      assistant?: unknown;
    },
    allow: string[],
    rules: SearchInterpretResult,
  ): SearchInterpretResult {
    const categories = this.categories.filterKnown(data.categories, allow);
    const mayNarrow = data.locationHint === 'near me' || data.locationHint === 'around campus';
    const radiusKm =
      mayNarrow && data.radiusKm != null ? clampRadiusKm(data.radiusKm) : null;
    const query = data.query.trim().length >= 2 ? data.query.trim() : rules.query;
    return {
      modules: data.modules,
      query,
      locationHint: data.locationHint,
      verifiedOnly: data.verifiedOnly,
      source: 'ai',
      intentLabel: data.intentLabel.trim().slice(0, 80) || rules.intentLabel,
      confidence: data.confidence,
      categories,
      keywords: data.keywords.map((k) => k.trim()).filter((k) => k.length >= 2).slice(0, 8),
      hubs: data.hubs,
      layout: data.layout,
      radiusKm,
      fallbackReason: null,
      cohort: 'ai',
      cached: false,
      assistant: readAssistant(data.assistant),
    };
  }

  private rulesFallback(
    rules: SearchInterpretResult,
    fallbackReason: string,
    started: number,
    usage?: { promptTokens?: number; completionTokens?: number },
    cohort: IntentCohort = 'rules',
  ): SearchInterpretResult {
    const result: SearchInterpretResult = { ...rules, source: 'rules', fallbackReason, cohort };
    this.logInterpret(result, Date.now() - started, usage?.promptTokens, usage?.completionTokens);
    return result;
  }

  private async isAiEnabled(): Promise<boolean> {
    const value = await this.readSetting(AI_SETTING_KEY);
    if (value === 'true' || value === 'false') return value === 'true';
    return (process.env.AI_INTENT_ENABLED ?? 'false').toLowerCase() === 'true';
  }

  private async assignCohort(ctx: InterpretContext): Promise<IntentCohort> {
    const percentRaw = (await this.readSetting(ROLLOUT_PERCENT_KEY)) ?? process.env.AI_INTENT_ROLLOUT_PERCENT;
    const cityRaw = (await this.readSetting(ROLLOUT_CITY_KEY)) ?? process.env.AI_INTENT_ROLLOUT_CITY;
    return decideIntentCohort({
      percent: parseRolloutPercent(percentRaw),
      city: rolloutCity(cityRaw),
      userId: ctx.userId,
      role: ctx.role,
      lat: ctx.lat,
      lng: ctx.lng,
    });
  }

  private async readSetting(key: string): Promise<string | null> {
    try {
      const row = await this.prisma.appSetting.findUnique({ where: { key } });
      return row?.value ?? null;
    } catch (err: any) {
      this.logger.warn(`AI setting read failed: ${err?.message || err}`);
      return null;
    }
  }

  private async rateLimited(userId?: string, bucketName = 'rate', limit = RATE_LIMIT_PER_MINUTE): Promise<boolean> {
    const bucket = Math.floor(Date.now() / 60000);
    const who = userId?.trim() || 'anon';
    const key = `ai:intent:${bucketName}:${who}:${bucket}`;
    const current = (await this.cache.getJson<number>(key)) ?? 0;
    if (current >= limit) return true;
    await this.cache.setJson(key, current + 1, 60);
    return false;
  }

  private logInterpret(
    result: SearchInterpretResult,
    latencyMs: number,
    promptTokens?: number,
    completionTokens?: number,
  ): void {
    const entry = {
      msg: 'ai_intent',
      source: result.source,
      cohort: result.cohort,
      cached: result.cached === true,
      latencyMs,
      confidence: result.confidence,
      fallbackReason: result.fallbackReason,
      promptTokens: promptTokens ?? null,
      completionTokens: completionTokens ?? null,
      query: normalizeQuery(result.query).slice(0, 200),
    };
    this.logger.log(JSON.stringify(entry));
    void this.persistLog(entry);
  }

  private async persistLog(entry: {
    query: string;
    source: string;
    cohort: IntentCohort;
    cached: boolean;
    latencyMs: number;
    confidence: number;
    fallbackReason: string | null;
    promptTokens: number | null;
    completionTokens: number | null;
  }): Promise<void> {
    try {
      await this.prisma.aiIntentQueryLog.create({
        data: {
          query: entry.query,
          source: entry.source,
          cohort: entry.cohort,
          cached: entry.cached,
          latencyMs: entry.latencyMs,
          confidence: entry.confidence,
          fallbackReason: entry.fallbackReason,
          promptTokens: entry.promptTokens,
          completionTokens: entry.completionTokens,
        },
      });
      const now = Date.now();
      if (now - this.lastLogPrune > 60 * 60 * 1000) {
        this.lastLogPrune = now;
        await this.prisma.aiIntentQueryLog.deleteMany({
          where: { createdAt: { lt: new Date(now - LOG_RETENTION_MS) } },
        });
        try {
          await this.prisma.aiIntentEvent.deleteMany({
            where: { createdAt: { lt: new Date(now - LOG_RETENTION_MS) } },
          });
        } catch (pruneErr: any) {
          this.logger.warn(`ai intent event prune skipped: ${pruneErr?.message || pruneErr}`);
        }
      }
    } catch (err: any) {
      this.logger.warn(`ai intent log skipped: ${err?.message || err}`);
    }
  }
}

export function sanitizeQuery(raw: string): string {
  return raw.replace(/[\u0000-\u001F]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 500);
}

/** Rules keep the original query. The model only sees the stripped text. */
export function promptForModel(raw: string): string {
  const stripped = raw
    .replace(
      /\b(ignore|disregard|forget)\b(?:\s+\w+){0,6}\s*(previous|above|all|prior|system)?\s*(instructions?|prompts?|rules)\b/gi,
      ' ',
    )
    .replace(/\b(system prompt|you are now|act as|jailbreak)\b/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return stripped.length >= 2 ? stripped : raw;
}

export function normalizeQuery(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s₦]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function clip(value: string | undefined, max: number): string | null {
  const trimmed = value?.trim() ?? '';
  if (!trimmed) return null;
  return trimmed.slice(0, max);
}

function sha1(value: string): string {
  return createHash('sha1').update(value).digest('hex');
}

function timeoutFromEnv(): number {
  const parsed = Number(process.env.AI_INTENT_TIMEOUT_MS ?? 1500);
  if (!Number.isFinite(parsed) || parsed < 50) return 1500;
  return parsed;
}

/** Keeps a usable intent when the model adds a category outside the allow-list. */
export function readLooseIntent(json: unknown): {
  modules: Array<'gift' | 'trade' | 'campaign'>;
  query: string;
  locationHint: string | null;
  verifiedOnly: boolean;
  intentLabel: string;
  confidence: number;
  categories: string[];
  keywords: string[];
  hubs: SearchInterpretResult['hubs'];
  layout: SearchInterpretResult['layout'];
  radiusKm: number | null;
  assistant?: unknown;
} | null {
  if (!json || typeof json !== 'object') return null;
  const data = json as Record<string, unknown>;
  const modules = Array.isArray(data.modules)
    ? data.modules.filter(
        (m): m is 'gift' | 'trade' | 'campaign' =>
          m === 'gift' || m === 'trade' || m === 'campaign',
      )
    : [];
  if (modules.length === 0) return null;
  const layout = data.layout as SearchInterpretResult['layout'] | undefined;
  const hubs = data.hubs as SearchInterpretResult['hubs'] | undefined;
  if (!layout || !hubs) return null;
  if (!isHub(layout.primary) || !isHub(layout.secondary) || !isHub(layout.banner)) return null;
  const confidence = Number(data.confidence);
  if (!Number.isFinite(confidence)) return null;
  return {
    modules,
    query: typeof data.query === 'string' ? data.query : '',
    locationHint: typeof data.locationHint === 'string' ? data.locationHint : null,
    verifiedOnly: data.verifiedOnly === true,
    intentLabel: typeof data.intentLabel === 'string' ? data.intentLabel : '',
    confidence: Math.min(1, Math.max(0, confidence)),
    categories: Array.isArray(data.categories)
      ? data.categories.filter((c): c is string => typeof c === 'string')
      : [],
    keywords: Array.isArray(data.keywords)
      ? data.keywords.filter((k): k is string => typeof k === 'string')
      : [],
    hubs,
    layout,
    radiusKm: typeof data.radiusKm === 'number' ? data.radiusKm : null,
    assistant: data.assistant,
  };
}

/** Trims model guidance and drops targets the app cannot open. Null when there is no reply. */
export function readAssistant(raw: unknown): AssistantGuidance | null {
  if (!raw || typeof raw !== 'object') return null;
  const data = raw as Record<string, unknown>;
  const reply = typeof data.reply === 'string' ? data.reply.trim().slice(0, 320) : '';
  if (!reply) return null;
  const steps = Array.isArray(data.steps)
    ? data.steps
        .filter((s): s is string => typeof s === 'string')
        .map((s) => s.trim().slice(0, 140))
        .filter(Boolean)
        .slice(0, 4)
    : [];
  const actions: AssistantGuidance['actions'] = [];
  for (const item of Array.isArray(data.actions) ? data.actions : []) {
    if (!item || typeof item !== 'object') continue;
    const { target, label } = item as Record<string, unknown>;
    if (typeof target !== 'string' || typeof label !== 'string') continue;
    if (!(ASSISTANT_TARGETS as readonly string[]).includes(target)) continue;
    if (actions.some((a) => a.target === target) || !label.trim()) continue;
    actions.push({ target: target as AssistantTarget, label: label.trim().slice(0, 40) });
    if (actions.length >= 3) break;
  }
  return { reply, steps, actions, showListings: data.showListings !== false };
}

function isHub(value: unknown): value is 'gift' | 'trade' | 'campaign' {
  return value === 'gift' || value === 'trade' || value === 'campaign';
}

function rejectAfter(timeoutMs: number): Promise<never> {
  return new Promise((_, reject) => {
    const timer = setTimeout(() => reject(new Error('timeout')), timeoutMs);
    timer.unref?.();
  });
}
