import { Module } from '@nestjs/common';
import { CategoryAllowListService } from './category-allow-list.service';
import { LLM_CLIENT } from './llm-client';
import { OpenAiLlmClient } from './openai-llm.client';

@Module({
  providers: [
    OpenAiLlmClient,
    { provide: LLM_CLIENT, useExisting: OpenAiLlmClient },
    CategoryAllowListService,
  ],
  exports: [LLM_CLIENT, OpenAiLlmClient, CategoryAllowListService],
})
export class AiModule {}
