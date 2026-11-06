import { IsString, IsOptional, IsEnum, IsInt, Min, Max } from 'class-validator';

export enum SourceType {
  TRADE = 'TRADE',
  GIFT = 'GIFT',
  REQUEST = 'REQUEST',
  CAMPAIGN = 'CAMPAIGN',
}

export class ExpressInterestDto {
  @IsString()
  @IsOptional()
  message?: string;
}

export class CompleteInteractionDto {
  @IsInt()
  @Min(1)
  @Max(5)
  @IsOptional()
  rating?: number;

  @IsString()
  @IsOptional()
  comment?: string;
}

export interface InteractionResponse {
  conversationId: string;
  itemId: string;
  itemTitle: string;
  itemType: SourceType;
  ownerId: string;
  ownerName: string;
}
