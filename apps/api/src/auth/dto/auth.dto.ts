import { IsEmail, IsNotEmpty, IsOptional, MinLength, IsString } from 'class-validator';

export class RegisterDto {
  @IsEmail()
  email!: string;

  @MinLength(8)
  password!: string;

  @IsNotEmpty()
  displayName!: string;

  @IsNotEmpty()
  @IsString()
  username!: string;

  @IsOptional()
  @IsString()
  referralCode?: string;

  /** ISO 3166-1 alpha-2 (e.g. NG, US). Used with preferredFiatCurrency or to infer currency. */
  @IsOptional()
  @IsString()
  countryCode?: string;

  @IsOptional()
  @IsString()
  preferredFiatCurrency?: string;

  @IsOptional()
  @IsString()
  timezone?: string;

  @IsOptional()
  @IsString()
  location?: string;
}

export class LoginDto {
  @IsEmail()
  email!: string;

  @IsNotEmpty()
  password!: string;

  @IsOptional()
  @IsString()
  location?: string;
}

export class RefreshDto {
  @IsNotEmpty()
  refreshToken!: string;
}

export class EmailDto {
  @IsEmail()
  email!: string;
}

export class ResetDto {
  @IsNotEmpty()
  token!: string;
  @MinLength(8)
  password!: string;
}

export class VerifyDto {
  @IsNotEmpty()
  token!: string;
}

export class PhoneDto {
  @IsNotEmpty()
  @IsString()
  phoneNumber!: string;
}

export class PhoneVerifyDto {
  @IsNotEmpty()
  @IsString()
  code!: string;
}

export class GoogleAuthDto {
  @IsNotEmpty()
  @IsString()
  idToken!: string;

  @IsOptional()
  @IsString()
  countryCode?: string;

  @IsOptional()
  @IsString()
  preferredFiatCurrency?: string;

  @IsOptional()
  @IsString()
  timezone?: string;

  @IsOptional()
  @IsString()
  location?: string;
}

export class AppleAuthDto {
  @IsNotEmpty()
  @IsString()
  identityToken!: string;

  @IsOptional()
  @IsString()
  email?: string;

  @IsOptional()
  @IsString()
  displayName?: string;

  @IsOptional()
  @IsString()
  countryCode?: string;

  @IsOptional()
  @IsString()
  preferredFiatCurrency?: string;

  @IsOptional()
  @IsString()
  timezone?: string;

  @IsOptional()
  @IsString()
  location?: string;
}
