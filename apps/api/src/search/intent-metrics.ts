import { PrismaService } from '../common/prisma.service';

export interface IntentMetrics {
  available: boolean;
  windowDays: number;
  sources: Array<{
    source: string;
    count: number;
    p95LatencyMs: number;
    promptTokens: number;
    completionTokens: number;
    tokensPerThousand: number | null;
  }>;
  cohorts: Array<{
    cohort: string;
    shown: number;
    taps: number;
    conversions: number;
    fallbacks: number;
    ctr: number | null;
    conversionRate: number | null;
  }>;
  slots: Array<{
    cohort: string;
    module: string;
    size: string;
    taps: number;
  }>;
  latency: Array<{
    bucket: string;
    count: number;
    p95LatencyMs: number;
    sloMs: number | null;
    slo: 'pass' | 'fail' | null;
  }>;
}

/** Cache and rules share 400ms. Live model calls get the 1500ms server timeout. Shown cache hits are 600ms end to end. */
export const INTENT_SLO_MS = {
  cache: 400,
  rules: 400,
  ai: 1500,
  shownCache: 600,
} as const;

export function intentSlo(bucket: string, p95LatencyMs: number): { sloMs: number | null; slo: 'pass' | 'fail' | null } {
  const sloMs =
    bucket === 'cache' || bucket === 'rules'
      ? INTENT_SLO_MS.cache
      : bucket === 'ai'
        ? INTENT_SLO_MS.ai
        : bucket === 'shownCache'
          ? INTENT_SLO_MS.shownCache
          : null;
  if (sloMs == null) return { sloMs: null, slo: null };
  return { sloMs, slo: p95LatencyMs <= sloMs ? 'pass' : 'fail' };
}

export async function loadIntentMetrics(prisma: PrismaService): Promise<IntentMetrics> {
  const empty: IntentMetrics = {
    available: false,
    windowDays: 7,
    sources: [],
    cohorts: [],
    slots: [],
    latency: [],
  };
  try {
    const sources = await prisma.$queryRaw<Array<{
      source: string;
      n: number;
      p95: number;
      prompt: number;
      completion: number;
    }>>`
      SELECT CASE
          WHEN source = 'ai' AND cached THEN 'cache'
          WHEN source = 'ai' THEN 'ai'
          ELSE source
        END AS source,
        COUNT(*)::int AS n,
        COALESCE(percentile_cont(0.95) WITHIN GROUP (ORDER BY "latencyMs"), 0)::float AS p95,
        COALESCE(SUM("promptTokens"), 0)::float AS prompt,
        COALESCE(SUM("completionTokens"), 0)::float AS completion
      FROM "AiIntentQueryLog"
      WHERE "createdAt" > NOW() - INTERVAL '7 days'
      GROUP BY 1
    `;
    const shown = await prisma.$queryRaw<Array<{ n: number; p95: number }>>`
      SELECT COUNT(*)::int AS n,
        COALESCE(percentile_cont(0.95) WITHIN GROUP (ORDER BY "latencyMs"), 0)::float AS p95
      FROM "AiIntentEvent"
      WHERE "createdAt" > NOW() - INTERVAL '7 days'
        AND event = 'ai_intent_shown'
        AND cached = true
        AND "latencyMs" IS NOT NULL
    `;
    const events = await prisma.$queryRaw<Array<{ cohort: string; event: string; n: number }>>`
      SELECT cohort, event, COUNT(*)::int AS n
      FROM "AiIntentEvent"
      WHERE "createdAt" > NOW() - INTERVAL '7 days'
      GROUP BY cohort, event
    `;
    const slots = await prisma.$queryRaw<Array<{
      cohort: string;
      module: string;
      size: string;
      n: number;
    }>>`
      SELECT cohort,
        COALESCE(module, 'unknown') AS module,
        COALESCE(size, 'unknown') AS size,
        COUNT(*)::int AS n
      FROM "AiIntentEvent"
      WHERE "createdAt" > NOW() - INTERVAL '7 days'
        AND event = 'ai_intent_slot_tap'
      GROUP BY cohort, module, size
      ORDER BY n DESC
    `;
    return {
      available: true,
      windowDays: 7,
      slots: slots.map((row) => ({
        cohort: row.cohort,
        module: row.module,
        size: row.size,
        taps: Number(row.n) || 0,
      })),
      latency: [
        ...sources.map((row) => {
          const p95LatencyMs = Math.round(Number(row.p95) || 0);
          return {
            bucket: row.source,
            count: Number(row.n) || 0,
            p95LatencyMs,
            ...intentSlo(row.source, p95LatencyMs),
          };
        }),
        ...shown
          .filter((row) => Number(row.n) > 0)
          .map((row) => {
            const p95LatencyMs = Math.round(Number(row.p95) || 0);
            return {
              bucket: 'shownCache',
              count: Number(row.n) || 0,
              p95LatencyMs,
              ...intentSlo('shownCache', p95LatencyMs),
            };
          }),
      ],
      sources: sources.map((row) => {
        const count = Number(row.n) || 0;
        const prompt = Number(row.prompt) || 0;
        const completion = Number(row.completion) || 0;
        return {
          source: row.source,
          count,
          p95LatencyMs: Math.round(Number(row.p95) || 0),
          promptTokens: Math.round(prompt),
          completionTokens: Math.round(completion),
          tokensPerThousand: count > 0 ? Math.round(((prompt + completion) * 1000) / count) : null,
        };
      }),
      cohorts: summarizeCohorts(events),
    };
  } catch {
    return empty;
  }
}

function summarizeCohorts(events: Array<{ cohort: string; event: string; n: number }>) {
  const names = ['ai', 'rules'];
  return names.map((cohort) => {
    const count = (event: string) =>
      Number(events.find((row) => row.cohort === cohort && row.event === event)?.n) || 0;
    const shown = count('ai_intent_shown');
    const taps = count('ai_intent_slot_tap');
    const conversions = count('ai_intent_conversion');
    return {
      cohort,
      shown,
      taps,
      conversions,
      fallbacks: count('ai_intent_fallback'),
      ctr: shown > 0 ? taps / shown : null,
      conversionRate: shown > 0 ? conversions / shown : null,
    };
  });
}
