import { Injectable, Logger } from '@nestjs/common';
import OpenAI from 'openai';
import { zodResponseFormat } from 'openai/helpers/zod';
import type { ZodTypeAny } from 'zod';
import { LlmClient, LlmJsonRequest, LlmJsonResponse } from './llm-client';

/**
 * OpenAI adapter. The model id and timeout come from the environment.
 * maxRetries is 0 so a slow call falls through to the rules result.
 */
@Injectable()
export class OpenAiLlmClient extends LlmClient {
  private readonly logger = new Logger(OpenAiLlmClient.name);
  private client: OpenAI | null = null;
  private clientKey: string | null = null;

  async generateJson(request: LlmJsonRequest): Promise<LlmJsonResponse> {
    const apiKey = process.env.OPENAI_API_KEY?.trim();
    if (!apiKey) {
      throw new Error('missing_api_key');
    }

    const timeoutMs = request.timeoutMs;
    const model = (request.model || process.env.AI_INTENT_MODEL || 'gpt-4.1-mini').trim();
    const client = this.getClient(apiKey, timeoutMs);
    const started = Date.now();

    const maxTokens = request.maxTokens ?? 300;
    const sampling = isReasoningModel(model)
      ? {
          reasoning_effort: 'minimal' as const,
          max_completion_tokens: maxTokens + REASONING_TOKEN_HEADROOM,
        }
      : { temperature: 0, max_completion_tokens: maxTokens };

    const completion = await client.chat.completions.parse(
      {
        model,
        ...sampling,
        messages: [
          { role: 'system', content: request.systemPrompt },
          { role: 'user', content: request.userPrompt },
        ],
        response_format: zodResponseFormat(
          request.zodSchema as ZodTypeAny,
          request.schemaName,
        ),
      },
      { timeout: timeoutMs, maxRetries: 0 },
    );

    const parsed = completion.choices[0]?.message?.parsed;
    if (parsed == null) {
      this.logger.warn('OpenAI returned an empty parsed payload');
      throw new Error('invalid_json');
    }

    return {
      json: parsed,
      latencyMs: Date.now() - started,
      promptTokens: completion.usage?.prompt_tokens,
      completionTokens: completion.usage?.completion_tokens,
    };
  }

  private getClient(apiKey: string, timeoutMs: number): OpenAI {
    if (!this.client || this.clientKey !== apiKey) {
      this.client = new OpenAI({
        apiKey,
        timeout: timeoutMs,
        maxRetries: 0,
      });
      this.clientKey = apiKey;
    }
    return this.client;
  }
}

/** Reasoning models reject `temperature` and `max_tokens`, and spend part of the budget thinking. */
const REASONING_TOKEN_HEADROOM = 700;

export function isReasoningModel(model: string): boolean {
  return /^(gpt-5|o\d)/i.test(model.trim());
}
