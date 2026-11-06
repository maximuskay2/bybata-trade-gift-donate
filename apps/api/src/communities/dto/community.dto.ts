import { IsString, IsOptional, IsEnum, IsArray, IsBoolean, IsInt, Min, IsDateString } from 'class-validator';
import { 
  CommunityCategory, 
  CommunityType, 
  PostType, 
  EventType,
  CommunityRole 
} from '@prisma/client';

export class CreateCommunityDto {
  @IsString()
  name: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  shortDescription?: string;

  @IsOptional()
  @IsEnum(CommunityCategory)
  category?: CommunityCategory;

  @IsOptional()
  @IsEnum(CommunityType)
  type?: CommunityType;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  tags?: string[];

  @IsOptional()
  @IsString()
  rules?: string;

  @IsOptional()
  @IsString()
  location?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  mediaKeys?: string[];

  @IsOptional()
  @IsString()
  avatarKey?: string;

  @IsOptional()
  @IsString()
  bannerKey?: string;

  @IsOptional()
  center_latitude?: number;

  @IsOptional()
  center_longitude?: number;

  @IsOptional()
  @IsString()
  imageUrl?: string;
}

export class UpdateCommunityDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  shortDescription?: string;

  @IsOptional()
  @IsEnum(CommunityCategory)
  category?: CommunityCategory;

  @IsOptional()
  @IsEnum(CommunityType)
  type?: CommunityType;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  tags?: string[];

  @IsOptional()
  @IsString()
  rules?: string;

  @IsOptional()
  @IsString()
  location?: string;

  @IsOptional()
  @IsString()
  avatarKey?: string;

  @IsOptional()
  @IsString()
  bannerKey?: string;
}

export class CreatePostDto {
  @IsOptional()
  @IsString()
  title?: string;

  @IsString()
  content: string;

  @IsOptional()
  @IsEnum(PostType)
  type?: PostType;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  mediaKeys?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  tags?: string[];
}

export class UpdatePostDto {
  @IsOptional()
  @IsString()
  title?: string;

  @IsOptional()
  @IsString()
  content?: string;

  @IsOptional()
  @IsEnum(PostType)
  type?: PostType;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  tags?: string[];
}

export class CreateEventDto {
  @IsString()
  title: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsEnum(EventType)
  type?: EventType;

  @IsOptional()
  @IsString()
  location?: string;

  @IsOptional()
  @IsBoolean()
  isOnline?: boolean;

  @IsOptional()
  @IsString()
  onlineLink?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  mediaKeys?: string[];

  @IsOptional()
  @IsInt()
  @Min(1)
  maxAttendees?: number;

  @IsOptional()
  @IsString()
  price?: string;

  @IsOptional()
  @IsString()
  currency?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  tags?: string[];

  @IsDateString()
  startDate: string;

  @IsDateString()
  endDate: string;

  @IsOptional()
  @IsDateString()
  registrationDeadline?: string;
}

export class UpdateEventDto {
  @IsOptional()
  @IsString()
  title?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsEnum(EventType)
  type?: EventType;

  @IsOptional()
  @IsString()
  location?: string;

  @IsOptional()
  @IsBoolean()
  isOnline?: boolean;

  @IsOptional()
  @IsString()
  onlineLink?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  maxAttendees?: number;

  @IsOptional()
  @IsString()
  price?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  tags?: string[];

  @IsOptional()
  @IsDateString()
  startDate?: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;

  @IsOptional()
  @IsDateString()
  registrationDeadline?: string;
}

export class JoinCommunityDto {
  @IsOptional()
  @IsString()
  inviteCode?: string;
}

export class InviteCommunityMemberDto {
  @IsOptional()
  @IsString()
  userId?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  userIds?: string[];

  @IsOptional()
  @IsString()
  email?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  emails?: string[];

  @IsOptional()
  @IsString()
  username?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  usernames?: string[];

  @IsOptional()
  @IsString()
  message?: string;

  @IsOptional()
  @IsDateString()
  expiresAt?: string;

  @IsOptional()
  @IsString()
  templateKey?: string;
}

export class RevokeInviteDto {
  @IsOptional()
  @IsString()
  userId?: string;

  @IsOptional()
  @IsString()
  inviteId?: string;

  @IsOptional()
  @IsString()
  email?: string;
}

export class ResendInviteDto {
  @IsOptional()
  @IsString()
  inviteId?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  inviteIds?: string[];

  @IsOptional()
  @IsString()
  templateKey?: string;
}

export class UpdateMemberRoleDto {
  @IsEnum(CommunityRole)
  role: CommunityRole;
}

export class CreateCommentDto {
  @IsString()
  content: string;

  @IsOptional()
  @IsString()
  parentId?: string;
}
