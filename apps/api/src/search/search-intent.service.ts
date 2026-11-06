import { Injectable } from '@nestjs/common';
import { IntentHub } from '../ai/intent-schema';
import { CategoryAllowListService } from '../ai/category-allow-list.service';
import { SearchService } from './search.service';
import { SearchInterpretService } from './search-interpret.service';
import {
  HubPriority,
  IntentLayout,
  SearchInterpretResult,
  resolveIntentRadius,
} from './intent-rules';

const HUBS: IntentHub[] = ['gift', 'trade', 'campaign'];
const PRIORITY_WEIGHT: Record<HubPriority, number> = { high: 6, medium: 3, low: 1 };
const TOTAL_ITEMS = 20;

export interface IntentSearchBody {
  query: string;
  lat?: number;
  lng?: number;
  radiusKm?: number;
  /** City or saved place. Used only by the existing geo text match, never by the model. */
  location?: string;
  categories?: string[];
  skipAi?: boolean;
  locale?: string;
  userId?: string;
  role?: string;
  /** User asked to widen the area. Do not apply the model's narrow radius. */
  widenRadius?: boolean;
}

@Injectable()
export class SearchIntentService {
  constructor(
    private readonly interpretService: SearchInterpretService,
    private readonly search: SearchService,
    private readonly categories: CategoryAllowListService,
  ) {}

  async searchByIntent(body: IntentSearchBody) {
    const interpret = await this.interpretService.interpret(body.query, {
      userId: body.userId,
      lat: body.lat,
      lng: body.lng,
      locale: body.locale,
      role: body.role,
      forceRules: body.skipAi === true,
    });

    if (body.categories?.length) {
      const allow = await this.categories.list();
      interpret.categories = this.categories.filterKnown(body.categories, allow);
    }

    const radiusKm = resolveIntentRadius(body.radiusKm, interpret, body.widenRadius === true);
    if (interpret.assistant?.showListings === false && !body.categories?.length) {
      return {
        interpret,
        results: { gift: [], trade: [], campaign: [] },
        layout: interpret.layout,
        radiusKm,
        liquidityExhausted: false,
      };
    }
    const modules = this.requestedHubs(interpret);
    const sizes = allocatePage(modules, interpret);
    const textQuery = this.textQuery(interpret);

    const entries = await Promise.all(
      modules.map(async (hub) => {
        const items = await this.searchHub(hub, textQuery, interpret, radiusKm, sizes[hub] ?? 1, body);
        return [hub, items] as const;
      }),
    );

    const results = {
      gift: [] as any[],
      trade: [] as any[],
      campaign: [] as any[],
    };
    for (const [hub, items] of entries) results[hub] = items;

    const liquidityExhausted = modules.every((hub) => results[hub].length === 0);

    return {
      interpret,
      results,
      layout: interpret.layout,
      radiusKm,
      liquidityExhausted,
    };
  }

  private async searchHub(
    hub: IntentHub,
    textQuery: string,
    interpret: SearchInterpretResult,
    radiusKm: number,
    size: number,
    body: IntentSearchBody,
  ) {
    const geo = {
      lat: body.lat,
      lng: body.lng,
      radiusKm,
      location: body.location,
    };
    const keywords = interpret.keywords;
    const categories = interpret.categories;
    const first = await this.callHub(hub, textQuery, { ...geo, keywords, categories }, size, body.userId);
    if (first.items.length > 0 || categories.length === 0) {
      return tag(hub, first.items);
    }
    const recovered = await this.callHub(
      hub,
      textQuery,
      { ...geo, keywords, categories: [] },
      size,
      body.userId,
    );
    return tag(hub, recovered.items);
  }

  private callHub(
    hub: IntentHub,
    textQuery: string,
    filters: Record<string, unknown>,
    size: number,
    userId?: string,
  ) {
    if (hub === 'trade') return this.search.searchTrades(textQuery, filters, 1, size, userId);
    if (hub === 'gift') return this.search.searchGifts(textQuery, filters, 1, size, userId);
    return this.search.searchCampaigns(textQuery, filters, 1, size, userId);
  }

  private requestedHubs(interpret: SearchInterpretResult): IntentHub[] {
    const hubs = interpret.modules.filter((m): m is IntentHub => HUBS.includes(m as IntentHub));
    return hubs.length > 0 ? hubs : [...HUBS];
  }

  private textQuery(interpret: SearchInterpretResult): string {
    if (interpret.query.trim().length >= 2) return interpret.query.trim();
    if (interpret.keywords.length > 0) return interpret.keywords.join(' ');
    return interpret.intentLabel;
  }

}

function allocatePage(
  modules: IntentHub[],
  interpret: SearchInterpretResult,
): Record<IntentHub, number> {
  const sizes = { gift: 0, trade: 0, campaign: 0 };
  if (modules.length === 0) return sizes;
  const weights = modules.map((hub) => PRIORITY_WEIGHT[interpret.hubs[hub]?.priority ?? 'medium']);
  const sum = weights.reduce((total, weight) => total + weight, 0) || modules.length;
  const raw = modules.map((hub, index) => ({
    hub,
    size: Math.max(1, Math.floor((TOTAL_ITEMS * weights[index]) / sum)),
  }));
  let used = raw.reduce((total, row) => total + row.size, 0);
  while (used > TOTAL_ITEMS) {
    const reducible = raw.filter((row) => row.size > 1).sort((a, b) => b.size - a.size)[0];
    if (!reducible) break;
    reducible.size -= 1;
    used -= 1;
  }
  const primary = raw.find((row) => row.hub === interpret.layout.primary) ?? raw[0];
  while (used < TOTAL_ITEMS) {
    primary.size += 1;
    used += 1;
  }
  for (const row of raw) sizes[row.hub] = row.size;
  return sizes;
}

function tag(hub: IntentHub, items: any[]): any[] {
  return items.map((item) => ({ ...item, type: hub }));
}

export type { IntentLayout };
