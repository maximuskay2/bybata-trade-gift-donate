import { IsOptional, IsEnum, IsInt, Min } from 'class-validator';
import { Type } from 'class-transformer';

export enum IntentType {
  OFFER = 'OFFER',
  ASK = 'ASK',
  NONE = 'NONE',
}

export enum IntentSubType {
  TRADE = 'TRADE',
  GIVE = 'GIVE',
  REQUEST = 'REQUEST',
  HELP_CAMPAIGN = 'HELP_CAMPAIGN',
  NONE = 'NONE',
}

export enum FeedSourceType {
  TRADE = 'TRADE',
  GIFT = 'GIFT',
  POST = 'POST',
  CAMPAIGN = 'CAMPAIGN',
}

export class GetHomeFeedDto {
  @IsOptional()
  @IsEnum(IntentType)
  intentType?: IntentType;

  @IsOptional()
  @IsEnum(IntentSubType)
  intentSubType?: IntentSubType;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  size?: number = 20;
}

export interface FeedItemDto {
  id: string;
  sourceType: FeedSourceType;
  intentType: IntentType;
  intentSubType: IntentSubType;
  title: string;
  summary: string;
  imageUrl?: string;
  location?: string;
  // Optional taxonomy surfaced so the new 3D Glass ListingCard can show
  // "Category • Location" under the title. Falls back to null/undefined
  // when the underlying entity does not have a category (e.g. posts).
  category?: string | null;
  createdAt: Date;
  author: {
    id: string;
    name: string;
    avatar?: string;
    // Cached average rating for the owner/giver/founder of this listing.
    // Precomputed in batch by the feed service so the card can render
    // stars without issuing per-item user-stats calls.
    averageRating?: number | null;
  };
  status: string;
  metadata?: any;
}

export interface HomeFeedResponseDto {
  items: FeedItemDto[];
  total: number;
  page: number;
  size: number;
  totalPages: number;
}
