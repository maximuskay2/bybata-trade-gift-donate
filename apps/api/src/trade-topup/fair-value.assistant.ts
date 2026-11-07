import { Inject, Injectable, Logger } from '@nestjs/common';
import { LLM_CLIENT, LlmClient } from '../ai/llm-client';
import {
  FairValueResult,
  TradeSideInput,
  applyAiQuote,
  fairValueSchema,
  fallbackFairValue,
} from './fair-value';

@Injectable()
export class FairValueAssistant {
  private readonly logger = new Logger(FairValueAssistant.name);

  constructor(@Inject(LLM_CLIENT) private readonly llm: LlmClient) {}

  async suggest(owner: TradeSideInput, bidder: TradeSideInput): Promise<FairValueResult> {
    const baseline = fallbackFairValue(owner, bidder);
    if (!process.env.OPENAI_API_KEY?.trim()) return baseline;
    try {
      const response = await this.llm.generateJson({
        schemaName: 'trade_topup',
        zodSchema: fairValueSchema,
        systemPrompt: [
          'You even out item-for-item barter trades.',
          'Compare the two items and suggest one USD cash top-up so the trade is fair.',
          'The payer is the person whose item is worth less.',
          'Use only the titles, categories, conditions, and photo references given.',
          'Keep the reason to one or two plain sentences.',
          'confidence is from 0 to 1.',
          'Do not invent shipping, fees, or a second payment.',
        ].join(' '),
        userPrompt: JSON.stringify({
          currency: 'USD',
          owner: describeSide(owner),
          bidder: describeSide(bidder),
        }),
        timeoutMs: Number(process.env.TRADE_TOPUP_TIMEOUT_MS || 8000),
        maxTokens: 250,
        model: process.env.TRADE_TOPUP_MODEL?.trim() || undefined,
      });
      return applyAiQuote(baseline, response.json);
    } catch (error) {
      this.logger.warn(`Fair-value model failed, using price bands: ${(error as Error).message}`);
      return baseline;
    }
  }
}

function describeSide(side: TradeSideInput) {
  return {
    role: side.role,
    title: side.title,
    category: side.category || 'OTHERS',
    condition: side.condition || 'good',
    photoCount: side.photos?.length ?? 0,
    photos: (side.photos || []).slice(0, 4),
  };
}
