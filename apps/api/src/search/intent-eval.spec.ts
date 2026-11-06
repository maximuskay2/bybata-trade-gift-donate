/**
 * Nightly live eval. `npm test` skips this unless INTENT_EVAL_LIVE=1
 * and OPENAI_API_KEY is set. The mocked run lives in search-interpret.service.spec.ts.
 */
import { readFileSync } from 'fs';
import { join } from 'path';
import { OpenAiLlmClient } from '../ai/openai-llm.client';
import { SearchInterpretService } from './search-interpret.service';

const live = process.env.INTENT_EVAL_LIVE === '1' && !!process.env.OPENAI_API_KEY?.trim();
const run = live ? describe : describe.skip;

run('intent eval against the live model', () => {
  it('reaches 90% module accuracy', async () => {
    const fixture = JSON.parse(
      readFileSync(join(__dirname, '../../test/fixtures/intent-eval.json'), 'utf8'),
    ) as Array<{ query: string; modules: string[] }>;
    const allow = ['ELECTRONICS', 'BOOKS', 'CLOTHING', 'HOME_GARDEN', 'FOOD', 'EDUCATION', 'HEALTH', 'SPORTS'];
    const service = new SearchInterpretService(
      new OpenAiLlmClient(),
      { getJson: async () => null, setJson: async () => undefined } as any,
      {
        list: async () => allow,
        filterKnown: (categories: string[], known: string[]) =>
          categories.filter((category) => known.includes(category)),
      } as any,
      {
        appSetting: { findUnique: async () => ({ value: 'true' }) },
        aiIntentQueryLog: { create: async () => ({}), deleteMany: async () => ({ count: 0 }) },
      } as any,
    );

    let hits = 0;
    for (const row of fixture) {
      const result = await service.interpret(row.query, { locale: 'en-NG' });
      if (result.modules.includes(row.modules[0] as any)) hits += 1;
    }
    expect(hits / fixture.length).toBeGreaterThanOrEqual(0.9);
  }, 180000);
});
