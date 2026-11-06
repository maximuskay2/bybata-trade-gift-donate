import { z } from 'zod';

export const INTENT_HUBS = ['gift', 'trade', 'campaign'] as const;
export type IntentHub = (typeof INTENT_HUBS)[number];

export const hubDirectiveSchema = z.object({
  priority: z.enum(['high', 'medium', 'low']),
  tags: z.array(z.string().max(40)).max(6),
});

/** Screens the assistant may send a user to. The app maps each one to a route. */
export const ASSISTANT_TARGETS = [
  'trade_browse',
  'trade_create',
  'gift_browse',
  'gift_create',
  'campaign_browse',
  'campaign_create',
  'wallet',
  'wallet_fund',
  'karma',
  'earn_karma',
  'community',
  'messages',
  'promotions',
  'profile',
  'settings',
  'support',
] as const;
export type AssistantTarget = (typeof ASSISTANT_TARGETS)[number];

export const assistantSchema = z.object({
  reply: z.string().max(320),
  steps: z.array(z.string().max(140)).max(4),
  actions: z
    .array(
      z.object({
        target: z.enum(ASSISTANT_TARGETS),
        label: z.string().max(40),
      }),
    )
    .max(3),
  showListings: z.boolean(),
});

/**
 * Structured-output schema. Categories are an enum so the model cannot invent
 * values outside the allow-list. Built per request because the list comes from
 * the database.
 */
export function buildIntentZod(categories: string[]) {
  const unique = [...new Set(categories.map((c) => c.trim()).filter(Boolean))];
  const categorySchema =
    unique.length > 0
      ? z.enum(unique as [string, ...string[]])
      : z.string().max(40);

  return z.object({
    modules: z.array(z.enum(INTENT_HUBS)).min(1).max(3),
    query: z.string().max(200),
    locationHint: z.string().max(80).nullable(),
    verifiedOnly: z.boolean(),
    intentLabel: z.string().max(80),
    confidence: z.number().min(0).max(1),
    categories: z.array(categorySchema).max(8),
    keywords: z.array(z.string().max(40)).max(8),
    hubs: z.object({
      gift: hubDirectiveSchema,
      trade: hubDirectiveSchema,
      campaign: hubDirectiveSchema,
    }),
    layout: z.object({
      primary: z.enum(INTENT_HUBS),
      secondary: z.enum(INTENT_HUBS),
      banner: z.enum(INTENT_HUBS),
    }),
    radiusKm: z.number().min(1).max(500).nullable(),
    assistant: assistantSchema,
  });
}

export type IntentZod = ReturnType<typeof buildIntentZod>;
export type IntentModelOutput = z.infer<IntentZod>;
