import { IsBoolean, IsIn, IsOptional, IsString, MinLength } from 'class-validator';

export class ListingModerationDto {
  @IsIn(['PAUSE', 'BAN', 'RESTORE', 'DELETE'])
  action!: 'PAUSE' | 'BAN' | 'RESTORE' | 'DELETE';

  @IsString()
  @MinLength(3, { message: 'Reason must be at least 3 characters' })
  reason!: string;

  @IsOptional()
  @IsBoolean()
  notifyOwner?: boolean;
}

export type ListingType = 'trade' | 'gift' | 'campaign';
