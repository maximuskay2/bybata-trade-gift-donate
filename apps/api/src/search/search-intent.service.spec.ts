import { SearchIntentService } from './search-intent.service';
import { SearchInterpretResult } from './intent-rules';

function interpret(partial: Partial<SearchInterpretResult> = {}): SearchInterpretResult {
  return {
    modules: ['gift', 'trade', 'campaign'],
    query: 'desk',
    locationHint: 'near me',
    verifiedOnly: false,
    source: 'rules',
    intentLabel: 'Desk',
    confidence: 0.9,
    categories: ['FURNITURE'],
    keywords: ['desk'],
    hubs: {
      gift: { priority: 'high', tags: [] },
      trade: { priority: 'medium', tags: [] },
      campaign: { priority: 'low', tags: [] },
    },
    layout: { primary: 'gift', secondary: 'trade', banner: 'campaign' },
    radiusKm: 25,
    fallbackReason: null,
    cohort: 'rules',
    cached: false,
    assistant: null,
    ...partial,
  };
}

describe('SearchIntentService', () => {
  function create(search: {
    searchTrades: jest.Mock;
    searchGifts: jest.Mock;
    searchCampaigns: jest.Mock;
  }, result = interpret()) {
    const service = new SearchIntentService(
      { interpret: async () => result } as any,
      search as any,
      { list: async () => ['FURNITURE'], filterKnown: (values: string[]) => values } as any,
    );
    return service;
  }

  it('passes the city label into the existing geo filter and not into a second model call', async () => {
    const calls: Array<Record<string, unknown>> = [];
    const search = {
      searchTrades: jest.fn(async (_q: string, filters: Record<string, unknown>) => {
        calls.push(filters);
        return { items: [{ id: 't' }] };
      }),
      searchGifts: jest.fn(async (_q: string, filters: Record<string, unknown>) => {
        calls.push(filters);
        return { items: [{ id: 'g' }] };
      }),
      searchCampaigns: jest.fn(async (_q: string, filters: Record<string, unknown>) => {
        calls.push(filters);
        return { items: [{ id: 'c' }] };
      }),
    };
    const service = create(search);

    const payload = await service.searchByIntent({
      query: 'a desk near me',
      lat: 5.04,
      lng: 7.91,
      location: 'Uyo, Akwa Ibom',
    });

    expect(calls.every((filters) => filters.location === 'Uyo, Akwa Ibom')).toBe(true);
    expect(calls.every((filters) => filters.radiusKm === 25)).toBe(true);
    expect(payload.results.gift).toEqual([{ id: 'g', type: 'gift' }]);
  });

  it('retries a hub once without categories when the category filter is empty', async () => {
    const giftFilters: Array<Record<string, unknown>> = [];
    const search = {
      searchTrades: jest.fn(async () => ({ items: [{ id: 't' }] })),
      searchGifts: jest.fn(async (_q: string, filters: Record<string, unknown>) => {
        giftFilters.push(filters);
        return { items: filters.categories && (filters.categories as string[]).length ? [] : [{ id: 'g' }] };
      }),
      searchCampaigns: jest.fn(async () => ({ items: [{ id: 'c' }] })),
    };
    const service = create(search);

    const payload = await service.searchByIntent({ query: 'desk' });

    expect(giftFilters).toHaveLength(2);
    expect(giftFilters[0].categories).toEqual(['FURNITURE']);
    expect(giftFilters[1].categories).toEqual([]);
    expect(payload.results.gift).toEqual([{ id: 'g', type: 'gift' }]);
    expect(payload.liquidityExhausted).toBe(false);
  });

  it('keeps a widened radius instead of the near-me cap', async () => {
    let radius = 0;
    const search = {
      searchTrades: jest.fn(async () => ({ items: [] })),
      searchGifts: jest.fn(async (_q: string, filters: Record<string, unknown>) => {
        radius = filters.radiusKm as number;
        return { items: [] };
      }),
      searchCampaigns: jest.fn(async () => ({ items: [] })),
    };
    const service = create(search);

    const payload = await service.searchByIntent({
      query: 'desk near me',
      radiusKm: 500,
      widenRadius: true,
    });

    expect(radius).toBe(500);
    expect(payload.liquidityExhausted).toBe(true);
  });

  it('skips listing queries when the assistant says the query is a need, not a search', async () => {
    const search = {
      searchTrades: jest.fn(async () => ({ items: [{ id: 't' }] })),
      searchGifts: jest.fn(async () => ({ items: [{ id: 'g' }] })),
      searchCampaigns: jest.fn(async () => ({ items: [{ id: 'c' }] })),
    };
    const service = create(
      search,
      interpret({
        assistant: {
          reply: 'Start a campaign.',
          steps: [],
          actions: [{ target: 'campaign_create', label: 'Start a campaign' }],
          showListings: false,
        },
      }),
    );

    const payload = await service.searchByIntent({ query: 'I need money' });

    expect(search.searchTrades).not.toHaveBeenCalled();
    expect(search.searchGifts).not.toHaveBeenCalled();
    expect(search.searchCampaigns).not.toHaveBeenCalled();
    expect(payload.results).toEqual({ gift: [], trade: [], campaign: [] });
    expect(payload.liquidityExhausted).toBe(false);
    expect(payload.interpret.assistant?.reply).toBe('Start a campaign.');
  });
});
