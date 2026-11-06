import { readFileSync } from 'fs';
import { join } from 'path';
import { SearchInterpretService } from './search-interpret.service';
import { interpretWithRules } from './intent-rules';
import { LlmJsonResponse } from '../ai/llm-client';

const ALLOW = ['ELECTRONICS', 'BOOKS', 'CLOTHING', 'HOME_GARDEN', 'FOOD', 'EDUCATION', 'HEALTH', 'SPORTS'];

function aiPayload(partial: {
  modules: string[];
  categories?: string[];
  query?: string;
  intentLabel?: string;
  confidence?: number;
}) {
  const primary = partial.modules[0] || 'gift';
  return {
    modules: partial.modules,
    query: partial.query ?? 'desk',
    locationHint: null,
    verifiedOnly: false,
    intentLabel: partial.intentLabel ?? 'Desk',
    confidence: partial.confidence ?? 0.9,
    categories: partial.categories ?? [],
    keywords: ['desk'],
    hubs: {
      gift: { priority: primary === 'gift' ? 'high' : 'low', tags: [] },
      trade: { priority: primary === 'trade' ? 'high' : 'medium', tags: [] },
      campaign: { priority: primary === 'campaign' ? 'high' : 'low', tags: [] },
    },
    layout: {
      primary,
      secondary: primary === 'gift' ? 'trade' : 'gift',
      banner: 'campaign',
    },
    radiusKm: null,
  };
}

describe('SearchInterpretService', () => {
  const originalEnv = { ...process.env };

  afterEach(() => {
    process.env = { ...originalEnv };
  });

  function create(options: {
    llm?: { generateJson: (req: unknown) => Promise<LlmJsonResponse> };
    cache?: Map<string, unknown>;
    enabled?: boolean;
    settings?: Record<string, { value: string } | null>;
  }) {
    const cacheStore = options.cache ?? new Map<string, unknown>();
    const llm = options.llm ?? {
      generateJson: async () => {
        throw new Error('llm should not be called');
      },
    };
    const service = new SearchInterpretService(
      llm as any,
      {
        getJson: async (key: string) => (cacheStore.has(key) ? cacheStore.get(key) : null),
        setJson: async (key: string, value: unknown) => {
          cacheStore.set(key, value);
        },
      } as any,
      {
        list: async () => ALLOW,
        filterKnown: (categories: string[], allow: string[]) =>
          categories.filter((category) => allow.includes(category)),
      } as any,
      {
        appSetting: {
          findUnique: async ({ where }: { where: { key: string } }) => {
            if (options.settings) return options.settings[where.key] ?? null;
            return options.enabled === false ? { value: 'false' } : { value: 'true' };
          },
        },
        aiIntentQueryLog: {
          create: async () => ({}),
          deleteMany: async () => ({ count: 0 }),
        },
        aiIntentEvent: {
          create: async () => ({}),
          deleteMany: async () => ({ count: 0 }),
        },
      } as any,
    );
    return { service, cacheStore };
  }

  it('returns the rules result when the model times out', async () => {
    process.env.OPENAI_API_KEY = 'test-key';
    process.env.AI_INTENT_TIMEOUT_MS = '80';
    let calls = 0;
    const { service } = create({
      llm: {
        generateJson: () => {
          calls += 1;
          return new Promise(() => undefined);
        },
      },
    });

    const result = await service.interpret("I'm setting up a dorm room on a budget");

    expect(calls).toBe(1);
    expect(result.source).toBe('rules');
    expect(result.fallbackReason).toBe('timeout');
    expect(result.modules.length).toBeGreaterThan(0);
  });

  it('falls back to rules when the model returns JSON that does not match the schema', async () => {
    process.env.OPENAI_API_KEY = 'test-key';
    const { service } = create({
      llm: {
        generateJson: async () => ({ json: { nope: true }, latencyMs: 5 }),
      },
    });

    const result = await service.interpret('something for the new place');

    expect(result.source).toBe('rules');
    expect(result.fallbackReason).toBe('invalid_json');
  });

  it('passes model guidance through and drops targets the app cannot open', async () => {
    process.env.OPENAI_API_KEY = 'test-key';
    const { service } = create({
      llm: {
        generateJson: async () => ({
          json: {
            ...aiPayload({ modules: ['campaign'], query: 'money', intentLabel: 'Raise money' }),
            assistant: {
              reply: `  Start a fundraising campaign. ${'x'.repeat(400)}`,
              steps: ['Tap Start a campaign', 42, ''],
              actions: [
                { target: 'campaign_create', label: 'Start a campaign' },
                { target: 'open_bank_app', label: 'Get cash' },
                { target: 'campaign_create', label: 'Again' },
                { target: 'campaign_browse', label: 'See campaigns' },
              ],
              showListings: false,
            },
          },
          latencyMs: 5,
        }),
      },
    });

    const result = await service.interpret('I need money');

    expect(result.source).toBe('ai');
    expect(result.assistant?.reply.startsWith('Start a fundraising campaign.')).toBe(true);
    expect(result.assistant?.reply.length).toBeLessThanOrEqual(320);
    expect(result.assistant?.steps).toEqual(['Tap Start a campaign']);
    expect(result.assistant?.actions).toEqual([
      { target: 'campaign_create', label: 'Start a campaign' },
      { target: 'campaign_browse', label: 'See campaigns' },
    ]);
    expect(result.assistant?.showListings).toBe(false);
  });

  it('leaves assistant empty on rules results so the app uses its own guidance', async () => {
    const { service } = create({ enabled: false });

    const result = await service.interpret('I need money');

    expect(result.source).toBe('rules');
    expect(result.assistant).toBeNull();
  });

  it('drops categories outside the allow-list', async () => {
    process.env.OPENAI_API_KEY = 'test-key';
    const { service } = create({
      llm: {
        generateJson: async () => ({
          json: aiPayload({
            modules: ['gift'],
            categories: ['NOT_A_REAL_ONE', 'ELECTRONICS'],
            query: 'phone',
            intentLabel: 'Phone',
          }),
          latencyMs: 5,
        }),
      },
    });

    const result = await service.interpret('I need something for my room');

    expect(result.source).toBe('ai');
    expect(result.categories).toEqual(['ELECTRONICS']);
    expect(result.fallbackReason).toBeNull();
  });

  it('serves a repeated query from cache and does not call the model again', async () => {
    process.env.OPENAI_API_KEY = 'test-key';
    let calls = 0;
    const { service } = create({
      llm: {
        generateJson: async () => {
          calls += 1;
          return {
            json: aiPayload({
              modules: ['gift'],
              categories: ['ELECTRONICS'],
              query: 'phone',
              intentLabel: 'Free phone',
            }),
            latencyMs: 5,
          };
        },
      },
    });

    const started = Date.now();
    const first = await service.interpret('I need a phone for my room');
    const second = await service.interpret('I need a phone for my room');

    expect(first.source).toBe('ai');
    expect(first.cached).toBe(false);
    expect(second.source).toBe('ai');
    expect(second.cached).toBe(true);
    expect(second.intentLabel).toBe('Free phone');
    expect(calls).toBe(1);
    expect(Date.now() - started).toBeLessThan(400);
  });

  it('keeps the rules result for an obvious hub keyword without calling the model', async () => {
    process.env.OPENAI_API_KEY = 'test-key';
    let calls = 0;
    const { service } = create({
      llm: {
        generateJson: async () => {
          calls += 1;
          return { json: {}, latencyMs: 1 };
        },
      },
    });

    const result = await service.interpret('swap my PS4');

    expect(calls).toBe(0);
    expect(result.source).toBe('rules');
    expect(result.modules).toContain('trade');
    expect(result.fallbackReason).toBeNull();
  });

  it('still asks the model when an obvious query is a question', async () => {
    process.env.OPENAI_API_KEY = 'test-key';
    let calls = 0;
    const { service } = create({
      llm: {
        generateJson: async () => {
          calls += 1;
          return {
            json: {
              ...aiPayload({
                modules: ['gift'],
                query: 'gift',
                intentLabel: 'How gifts work',
              }),
              assistant: {
                reply: 'A gift is free. The giver approves one request.',
                steps: ['Open a gift'],
                actions: [{ target: 'gift_browse', label: 'Browse gifts' }],
                showListings: false,
              },
            },
            latencyMs: 5,
          };
        },
      },
    });

    const result = await service.interpret('how do I request a gift');

    expect(calls).toBe(1);
    expect(result.source).toBe('ai');
    expect(result.assistant?.showListings).toBe(false);
    expect(result.assistant?.actions[0].target).toBe('gift_browse');
  });

  it('keeps a non-staff user on rules when the rollout percent is 0', async () => {
    process.env.OPENAI_API_KEY = 'test-key';
    let calls = 0;
    const { service } = create({
      settings: {
        AI_INTENT_ENABLED: { value: 'true' },
        AI_INTENT_ROLLOUT_PERCENT: { value: '0' },
      },
      llm: {
        generateJson: async () => {
          calls += 1;
          return { json: {}, latencyMs: 1 };
        },
      },
    });

    const result = await service.interpret("I'm setting up a dorm room on a budget", {
      userId: 'user-1',
      role: 'USER',
    });

    expect(calls).toBe(0);
    expect(result.cohort).toBe('rules');
    expect(result.fallbackReason).toBe('rollout');
  });

  it('still calls the model for an admin when the rollout percent is 0', async () => {
    process.env.OPENAI_API_KEY = 'test-key';
    let calls = 0;
    const { service } = create({
      settings: {
        AI_INTENT_ENABLED: { value: 'true' },
        AI_INTENT_ROLLOUT_PERCENT: { value: '0' },
      },
      llm: {
        generateJson: async () => {
          calls += 1;
          return {
            json: aiPayload({ modules: ['gift'], query: 'dorm furniture', intentLabel: 'Dorm setup' }),
            latencyMs: 5,
          };
        },
      },
    });

    const result = await service.interpret("I'm setting up a dorm room on a budget", {
      userId: 'admin-1',
      role: 'ADMIN',
    });

    expect(calls).toBe(1);
    expect(result.cohort).toBe('ai');
    expect(result.source).toBe('ai');
  });
});

describe('intent eval fixture', () => {
  const fixture = JSON.parse(
    readFileSync(join(__dirname, '../../test/fixtures/intent-eval.json'), 'utf8'),
  ) as Array<{ query: string; modules: string[]; categories: string[]; obvious: boolean }>;

  it('holds at least 100 queries and the mocked model stays on the expected module', async () => {
    expect(fixture.length).toBeGreaterThanOrEqual(100);
    process.env.OPENAI_API_KEY = 'test-key';
    process.env.AI_INTENT_ENABLED = 'true';

    const byQuery = new Map(fixture.map((row) => [row.query, row]));
    const cacheStore = new Map<string, unknown>();
    const service = new SearchInterpretService(
      {
        generateJson: async (req: { userPrompt: string }) => {
          const row = byQuery.get(req.userPrompt);
          if (!row) throw new Error('missing fixture');
          return {
            json: aiPayload({
              modules: row.modules,
              categories: row.categories,
              query: row.query,
              intentLabel: row.query.slice(0, 80),
            }),
            latencyMs: 1,
          };
        },
      } as any,
      {
        getJson: async (key: string) => (cacheStore.has(key) ? cacheStore.get(key) : null),
        setJson: async (key: string, value: unknown) => {
          cacheStore.set(key, value);
        },
      } as any,
      {
        list: async () => ALLOW,
        filterKnown: (categories: string[], allow: string[]) =>
          categories.filter((category) => allow.includes(category)),
      } as any,
      {
        appSetting: { findUnique: async () => ({ value: 'true' }) },
        aiIntentQueryLog: {
          create: async () => ({}),
          deleteMany: async () => ({ count: 0 }),
        },
        aiIntentEvent: {
          create: async () => ({}),
          deleteMany: async () => ({ count: 0 }),
        },
      } as any,
    );

    let hits = 0;
    for (const row of fixture) {
      const result = await service.interpret(row.query);
      const expected = row.modules[0];
      if (result.modules.includes(expected as any)) hits += 1;
    }
    expect(hits / fixture.length).toBeGreaterThanOrEqual(0.9);
  });

  it('rules cover the obvious keyword queries', () => {
    const obvious = fixture.filter((row) => row.obvious);
    expect(obvious.length).toBeGreaterThan(20);
    let hits = 0;
    for (const row of obvious) {
      const result = interpretWithRules(row.query);
      if (result.modules.includes(row.modules[0] as any)) hits += 1;
    }
    expect(hits / obvious.length).toBeGreaterThanOrEqual(0.9);
  });
});

describe('rules query text', () => {
  it('drops conversational lead-ins so only the item is searched', () => {
    expect(interpretWithRules('I need a car').query).toBe('car');
    expect(interpretWithRules('i am looking for a laptop').query).toBe('laptop');
    expect(interpretWithRules('Do you have a fridge?').query).toBe('fridge');
    expect(interpretWithRules('can i get a free desk').query).toBe('desk');
  });

  it('keeps the whole sentence when nothing is left to search', () => {
    expect(interpretWithRules('i want to swap').query).toBe('i want to swap');
  });
});
