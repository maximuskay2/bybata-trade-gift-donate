import { IsString, IsOptional, IsArray, MaxLength, MinLength } from 'class-validator';

export class CreateRequestDto {
  @IsString()
  @MinLength(3)
  @MaxLength(200)
  title: string;

  @IsString()
  @MinLength(10)
  @MaxLength(2000)
  content: string;

  @IsString()
  communityId: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  tags?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  mediaKeys?: string[];
}
