/** Provider-agnostic JSON completion. Search code depends only on this. */
export interface LlmJsonRequest {
  schemaName: string;
  /** Zod schema. Adapters that support Structured Outputs consume it directly. */
  zodSchema: unknown;
  systemPrompt: string;
  userPrompt: string;
  timeoutMs: number;
  maxTokens?: number;
}

export interface LlmJsonResponse {
  json: unknown;
  latencyMs: number;
  promptTokens?: number;
  completionTokens?: number;
}

/** Abstract class so Nest can emit decorator metadata for the injected client. */
export abstract class LlmClient {
  abstract generateJson(request: LlmJsonRequest): Promise<LlmJsonResponse>;
}

export const LLM_CLIENT = Symbol('LLM_CLIENT');
