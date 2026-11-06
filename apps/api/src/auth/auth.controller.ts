import { Body, Controller, HttpCode, HttpStatus, Post, Req, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { EmailDto, LoginDto, RefreshDto, RegisterDto, ResetDto, VerifyDto, PhoneDto, PhoneVerifyDto, GoogleAuthDto, AppleAuthDto } from './dto/auth.dto';
import type { Request } from 'express';
import { LocaleHints, normalizeCountryCode } from '../common/currency.util';
import { DeviceInfoUtil } from '../common/device-info.util';
import {
  buildDeviceFingerprint,
  extractLoginMeta,
} from '../common/request-meta.util';
import { JwtAuthGuard } from './jwt.guard';
import { CurrentUser } from './current-user.decorator';

function localeHintsFromRequest(
  req: Request,
  body?: { countryCode?: string; preferredFiatCurrency?: string; timezone?: string; location?: string },
): LocaleHints {
  const cfCountry = normalizeCountryCode(req.headers['cf-ipcountry'] as string);
  return {
    countryCode: body?.countryCode ?? cfCountry,
    preferredFiatCurrency: body?.preferredFiatCurrency,
    timezone: body?.timezone,
    location: body?.location,
    acceptLanguage: req.headers['accept-language'] as string,
  };
}

function loginMetaFromRequest(
  req: Request,
  body?: { location?: string },
) {
  const client = DeviceInfoUtil.parseClientHeaders(
    req.headers as Record<string, unknown>,
  );
  const ua = req.headers['user-agent'] as string | undefined;
  const device = DeviceInfoUtil.resolveDeviceInfo(ua, client);
  const fingerprint = buildDeviceFingerprint({
    deviceName: client.deviceName ?? device.deviceName,
    deviceOs: client.os ?? device.os,
    devicePlatform: client.platform,
    ua,
  });

  return extractLoginMeta(req, body, {
    deviceName: client.deviceName ?? device.deviceName,
    os: client.os ?? device.os,
    platform: client.platform,
    fingerprint,
  });
}

@Controller('v1/auth')
export class AuthController {
  constructor(private auth: AuthService) {}

  @Throttle({ default: { limit: 5, ttl: 60000 } }) // 5 registrations per minute
  @Post('register')
  async register(@Body() dto: RegisterDto, @Req() req: Request) {
    return this.auth.register(dto.email, dto.password, dto.displayName, dto.username, {
      ...loginMetaFromRequest(req, dto),
      referralCode: dto.referralCode,
      localeHints: localeHintsFromRequest(req, dto),
      location: dto.location,
    });
  }

  @Throttle({ default: { limit: 10, ttl: 60000 } }) // 10 login attempts per minute
  @HttpCode(HttpStatus.OK)
  @Post('login')
  async login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.auth.login(dto.email, dto.password, loginMetaFromRequest(req, dto));
  }

  @Post('google')
  async googleLogin(@Body() dto: GoogleAuthDto, @Req() req: Request) {
    return this.auth.googleLogin(dto.idToken, {
      ...loginMetaFromRequest(req, dto),
      localeHints: localeHintsFromRequest(req, dto),
      location: dto.location,
    });
  }

  @Post('apple')
  async appleLogin(@Body() dto: AppleAuthDto, @Req() req: Request) {
    return this.auth.appleLogin(
      dto.identityToken,
      { email: dto.email, displayName: dto.displayName },
      {
        ...loginMetaFromRequest(req, dto),
        localeHints: localeHintsFromRequest(req, dto),
        location: dto.location,
      },
    );
  }

  @Post('refresh')
  async refresh(@Body() dto: RefreshDto) {
    return this.auth.refresh(dto.refreshToken);
  }

  @Post('logout')
  async logout(@Body() body: { userId: string }, @Req() req: Request) {
    return this.auth.logout(body.userId, loginMetaFromRequest(req));
  }

  // Email verification + forgot/reset stubs
  @Post('verify-request')
  async verifyRequest(@Body() dto: EmailDto, @Req() req: Request) {
    return this.auth.verifyRequest(dto.email, loginMetaFromRequest(req));
  }

  @Post('verify-confirm')
  async verifyConfirm(@Body() dto: VerifyDto, @Req() req: Request) {
    return this.auth.verifyConfirm(dto.token, loginMetaFromRequest(req));
  }

  // Phone verification endpoints (authenticated — OTP via admin messaging config)
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @Post('phone-verify-request')
  async phoneVerifyRequest(
    @CurrentUser() user: any,
    @Body() dto: PhoneDto,
    @Req() req: Request,
  ) {
    return this.auth.phoneVerifyRequest(
      user.sub,
      dto.phoneNumber,
      loginMetaFromRequest(req),
    );
  }

  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Post('phone-verify-confirm')
  async phoneVerifyConfirm(
    @CurrentUser() user: any,
    @Body() dto: PhoneVerifyDto,
    @Req() req: Request,
  ) {
    return this.auth.phoneVerifyConfirm(
      user.sub,
      dto.code,
      loginMetaFromRequest(req),
    );
  }

  @Throttle({ default: { limit: 3, ttl: 60000 } }) // 3 forgot password requests per minute
  @Post('forgot')
  async forgot(@Body() dto: EmailDto, @Req() req: Request) {
    return this.auth.forgot(dto.email, loginMetaFromRequest(req));
  }

  @Post('reset')
  async reset(@Body() dto: ResetDto, @Req() req: Request) {
    return this.auth.reset(dto.token, dto.password, loginMetaFromRequest(req));
  }
}
