import { Injectable, UnauthorizedException, BadRequestException, NotFoundException, Inject, forwardRef, ForbiddenException, ConflictException } from '@nestjs/common';
import { Prisma, Profile } from '@prisma/client';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../common/prisma.service';
import { EmailService } from '../common/email.service';
import { MessagingService } from '../common/messaging.service';
import { EmailLinkRouterService } from '../shared/services/email-link-router.service';
import { EmailEventName } from '../email/email-events';
import { NotificationsService } from '../notifications/notifications.service';
import { ReferralsService } from '../referrals/referrals.service';
import { DeviceInfoUtil } from '../common/device-info.util';
import {
  buildDeviceFingerprint,
  fingerprintFromAuditUa,
  formatAuditUa,
  LoginMeta,
} from '../common/request-meta.util';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';
import { ConfigValidation } from '../config/config.validation';
import { OAuth2Client } from 'google-auth-library';
import * as appleSigninAuth from 'apple-signin-auth';
import {
  LocaleHints,
  buildProfileSettings,
  resolveProfileCurrency,
} from '../common/currency.util';
import {
  profileHasUsableLocation,
  resolveRegistrationLocation,
} from '../common/profile-location.util';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private email: EmailService,
    private messaging: MessagingService,
    private emailLinkRouter: EmailLinkRouterService,
    private notifications: NotificationsService,
    @Inject(forwardRef(() => ReferralsService))
    private referralsService: ReferralsService,
  ) {}

  private deferProfileLocationUpdate(
    userId: string,
    profile: Profile | null,
    opts: { clientLocation?: string | null; ip?: string; countryCode?: string | null },
  ) {
    void this.maybeUpdateProfileLocation(userId, profile, opts).catch(() => {});
  }

  private withTimeout<T>(promise: Promise<T>, ms: number, message: string): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(message)), ms);
      promise
        .then((value) => {
          clearTimeout(timer);
          resolve(value);
        })
        .catch((err) => {
          clearTimeout(timer);
          reject(err);
        });
    });
  }

  private async audit(type: string, userId?: string, meta?: LoginMeta) {
    try {
      await this.prisma.auditLog.create({
        data: {
          type,
          userId,
          ip: meta?.ip,
          ua: formatAuditUa(meta),
        },
      });
    } catch {}
  }

  private async isNewLoginDevice(userId: string, fingerprint: string): Promise<boolean> {
    const prior = await this.prisma.auditLog.findMany({
      where: {
        userId,
        type: { in: ['LOGIN', 'LOGIN_GOOGLE', 'LOGIN_APPLE'] },
      },
      select: { ua: true },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });

    if (prior.length === 0) return true;

    const known = new Set(
      prior
        .map((row) => fingerprintFromAuditUa(row.ua))
        .filter((fp): fp is string => !!fp),
    );
    return !known.has(fingerprint);
  }

  private async maybeNotifyNewLoginDevice(
    user: { id: string; email: string; profile?: { displayName?: string | null } | null },
    meta: LoginMeta,
  ) {
    const fingerprint =
      meta.deviceFingerprint ??
      buildDeviceFingerprint({
        deviceName: meta.deviceName,
        deviceOs: meta.deviceOs,
        devicePlatform: meta.devicePlatform,
        ua: meta.ua,
      });

    const isNewDevice = await this.isNewLoginDevice(user.id, fingerprint);
    if (!isNewDevice) return;

    const deviceInfo = DeviceInfoUtil.resolveDeviceInfo(meta.ua, {
      platform: meta.devicePlatform,
      deviceName: meta.deviceName,
      os: meta.deviceOs,
    });
    const geo = await DeviceInfoUtil.getLocationFromIP(meta.ip);
    const location = DeviceInfoUtil.formatLoginLocation({
      geo,
      ip: meta.ip,
      clientLocation: meta.location,
    });

    this.email.dispatchInBackground({
      eventName: EmailEventName.AuthLoginNewDevice,
      recipient: { email: user.email, userId: user.id },
      vars: {
        displayName: user.profile?.displayName || user.email,
        deviceName: deviceInfo.deviceName,
        location,
        loginAt: new Date().toLocaleString('en-US', {
          dateStyle: 'full',
          timeStyle: 'long',
          timeZone: 'UTC',
        }),
        supportEmail: process.env.SUPPORT_EMAIL || 'support@bybata.com',
      },
    });
  }

  private async hash(data: string) {
    return bcrypt.hash(data, 10);
  }

  private async compare(data: string, hash: string) {
    if (!hash) return false;
    try {
      return await bcrypt.compare(data, hash);
    } catch {
      // Corrupt / non-bcrypt hashes must not become HTTP 500s.
      return false;
    }
  }

  private getAppleAudiences(): string[] {
    const raw = process.env.APPLE_CLIENT_ID ?? '';
    const fromEnv = raw
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    // Native iOS Sign in with Apple uses the app bundle ID as JWT `aud`, not the
    // web Services ID (e.g. com.bybata.signin). Always allow the bundle ID.
    const iosBundleId = (
      process.env.APPLE_IOS_BUNDLE_ID ?? 'com.bybata.bybata'
    ).trim();
    return [...new Set([...fromEnv, ...(iosBundleId ? [iosBundleId] : [])])];
  }

  private isPrismaUniqueViolation(err: unknown): boolean {
    return err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002';
  }

  private profileCurrencyFields(hints?: LocaleHints) {
    return resolveProfileCurrency(hints);
  }

  /** Backfill location when missing (existing users, OAuth, login). */
  private async maybeUpdateProfileLocation(
    userId: string,
    profile: Profile | null,
    opts: { clientLocation?: string | null; ip?: string; countryCode?: string | null },
  ): Promise<Profile | null> {
    if (!profile || profileHasUsableLocation(profile.location)) return profile;
    const location = await resolveRegistrationLocation({
      clientLocation: opts.clientLocation,
      ip: opts.ip,
      countryCode: opts.countryCode ?? profile.countryCode,
    });
    if (!location) return profile;
    return this.prisma.profile.update({
      where: { userId },
      data: { location },
    });
  }

  private async registrationLocation(
    meta?: { ip?: string; localeHints?: LocaleHints; location?: string },
    countryCode?: string | null,
  ): Promise<string | null> {
    return resolveRegistrationLocation({
      clientLocation: meta?.location ?? meta?.localeHints?.location,
      ip: meta?.ip,
      countryCode,
    });
  }

  /** Backfill country/currency for OAuth users created before hints were sent. */
  private async maybeUpdateProfileLocale(
    userId: string,
    profile: Profile | null,
    hints?: LocaleHints,
  ): Promise<Profile | null> {
    if (!profile || !hints) return profile;
    if (profile.countryCode) return profile;
    const resolved = resolveProfileCurrency(hints);
    return this.prisma.profile.update({
      where: { userId },
      data: {
        countryCode: resolved.countryCode ?? profile.countryCode,
        preferredFiatCurrency: profile.preferredFiatCurrency || resolved.preferredFiatCurrency,
        timezone: profile.timezone || resolved.timezone || 'UTC',
      },
    });
  }

  private mapUserResponse(user: {
    id: string;
    email: string;
    role: string;
    profile: any;
  }) {
    const profile = user.profile
      ? {
          ...user.profile,
          settings: buildProfileSettings(user.profile),
        }
      : null;
    return {
      user: { id: user.id, email: user.email, role: user.role, profile },
    };
  }

  private async generateUniqueUsername(base: string) {
    const normalized = this.normalizeUsername(base || 'user');
    const prefix = normalized.replace(/[^a-z0-9_]/g, '') || 'user';
    let candidate = prefix.slice(0, 18);
    let suffix = 0;
    while (true) {
      const exists = await this.prisma.profile.findFirst({
        where: { username: { equals: candidate, mode: 'insensitive' } },
        select: { id: true },
      });
      if (!exists) return candidate;
      suffix += 1;
      const next = `${prefix.slice(0, 16)}${suffix}`;
      candidate = next;
    }
  }

  private signAccessToken(user: { id: string; email: string; role: string }) {
    // Use ConfigValidation which handles production vs development appropriately
    const secret = ConfigValidation.getRequired(
      'JWT_ACCESS_SECRET',
      'JWT access token signing secret',
      'dev-secret' // Fallback only allowed in development
    );

    const expiresIn = process.env.JWT_ACCESS_EXPIRES_IN || '60h';
    return this.jwt.sign({ sub: user.id, email: user.email, role: user.role }, {
      secret,
      expiresIn,
    });
  }

  private signRefreshToken(user: { id: string; email: string }) {
    // Use ConfigValidation which handles production vs development appropriately
    const secret = ConfigValidation.getRequired(
      'JWT_REFRESH_SECRET',
      'JWT refresh token signing secret',
      'dev-refresh' // Fallback only allowed in development
    );

    const exp = process.env.JWT_REFRESH_EXPIRES_IN || '30d';
    return this.jwt.sign({ sub: user.id, email: user.email }, {
      secret,
      expiresIn: exp,
    });
  }

  async register(
    email: string,
    password: string,
    displayName: string,
    username: string,
    meta?: { ip?: string; ua?: string; referralCode?: string; localeHints?: LocaleHints; location?: string },
  ) {
    const exists = await this.prisma.user.findUnique({ where: { email } });
    if (exists) throw new BadRequestException('Email already in use');
    const normalized = this.normalizeUsername(username);
    this.validateUsername(normalized);
    const usernameExists = await this.prisma.profile.findFirst({
      where: { username: { equals: normalized, mode: 'insensitive' } },
      select: { id: true },
    });
    if (usernameExists) throw new BadRequestException('Username already in use');
    const passwordHash = await this.hash(password);
    const currencyFields = this.profileCurrencyFields(meta?.localeHints);
    const location = await this.registrationLocation(meta, currencyFields.countryCode);
    const user = await this.prisma.user.create({
      data: {
        email,
        passwordHash,
        profile: {
          create: {
            displayName,
            username: normalized,
            preferredFiatCurrency: currencyFields.preferredFiatCurrency,
            countryCode: currencyFields.countryCode,
            timezone: currencyFields.timezone ?? 'UTC',
            ...(location ? { location } : {}),
          },
        },
      },
      include: { profile: true },
    });
    const accessToken = this.signAccessToken({ id: user.id, email: user.email, role: user.role });
    const refreshToken = this.signRefreshToken({ id: user.id, email: user.email });
    await this.saveRefreshSession(user.id, refreshToken);
    await this.audit('REGISTER', user.id, meta);

    // Send initial email verification code
    await this.verifyRequest(user.email, meta);

    // Optional: Send welcome email (non-blocking)
    const emailEnabled = (process.env.WELCOME_EMAIL_ENABLED ?? 'true').toLowerCase() === 'true';
    if (emailEnabled) {
      try {
        const displayName = user.profile?.displayName || 'there';
        this.email.dispatchInBackground({
          eventName: EmailEventName.AuthSignupWelcome,
          recipient: { email: user.email, displayName, userId: user.id },
          vars: {
            firstName: displayName.split(' ')[0] || displayName,
            displayName,
            appName: 'bYbata',
            supportEmail: process.env.SUPPORT_EMAIL || 'support@bybata.com',
            loginUrl: this.emailLinkRouter.getAppOpenLink(),
          },
        });
      } catch (_) {
        // Swallow email errors to avoid blocking registration
      }
    }

    // Optional: Create in-app welcome notification
    const notifEnabled = (process.env.WELCOME_NOTIFICATION_ENABLED ?? 'true').toLowerCase() === 'true';
    if (notifEnabled) {
      try {
        await this.notifications.notifyWelcome(user.id, user.profile?.displayName || 'there');
      } catch (_) {}
    }
    
    // Process referral if code was provided
    if (meta?.referralCode && meta.referralCode.trim()) {
      try {
        const lookup = await this.referralsService.lookupReferrerByCode(meta.referralCode);
        if (lookup && lookup.referrerId !== user.id) {
          const referrerCode = await this.referralsService.getOrCreateReferralCode(lookup.referrerId);
          await this.referralsService.createReferral(lookup.referrerId, user.id, referrerCode);
        }
      } catch (_) {
        // Swallow referral errors to avoid blocking registration
      }
    }

    return { user: { id: user.id, email: user.email, role: user.role, profile: user.profile }, accessToken, refreshToken };
  }

  private normalizeUsername(input: string) {
    return input.trim().replace(/^@/, '').toLowerCase();
  }

  private validateUsername(username: string) {
    if (!/^[a-z0-9_]{3,20}$/.test(username)) {
      throw new BadRequestException(
        'Username must be 3-20 characters and contain only letters, numbers, or underscores',
      );
    }
  }

  async login(email: string, password: string, meta?: LoginMeta) {
    let user = await this.prisma.user.findUnique({ where: { email }, include: { profile: true } });
    if (!user) throw new UnauthorizedException('Invalid credentials');
    const ok = await this.compare(password, user.passwordHash);
    if (!ok) throw new UnauthorizedException('Invalid credentials');
    if (!user.emailVerifiedAt) {
      // Do not auto-send another verification email here; the initial one is
      // dispatched on registration, and the client can explicitly request
      // additional resends via the verify-request endpoint.
      throw new ForbiddenException({
        code: 'EMAIL_VERIFICATION_REQUIRED',
        message: 'Email verification required',
        email: user.email,
        phone: user.profile?.phone ?? null,
      });
    }
    const accessToken = this.signAccessToken({ id: user.id, email: user.email, role: user.role });
    const refreshToken = this.signRefreshToken({ id: user.id, email: user.email });
    await this.saveRefreshSession(user.id, refreshToken);
    void this.maybeNotifyNewLoginDevice(user, meta ?? {}).catch(() => {});
    await this.audit('LOGIN', user.id, meta);

    this.deferProfileLocationUpdate(user.id, user.profile, {
      clientLocation: meta?.location,
      ip: meta?.ip,
      countryCode: user.profile?.countryCode,
    });

    return { user: { id: user.id, email: user.email, role: user.role, profile: user.profile }, accessToken, refreshToken };
  }

  async googleLogin(idToken: string, meta?: LoginMeta & { localeHints?: LocaleHints }) {
    const clientIds = [
      process.env.GOOGLE_CLIENT_ID_ANDROID,
      process.env.GOOGLE_CLIENT_ID_IOS,
      process.env.GOOGLE_CLIENT_ID_WEB,
    ].filter(Boolean) as string[];
    if (clientIds.length === 0) {
      throw new BadRequestException('Google client ID not configured');
    }
    const client = new OAuth2Client();
    let ticket;
    try {
      ticket = await this.withTimeout(
        client.verifyIdToken({
          idToken,
          audience: clientIds,
        }),
        8000,
        'Google token verification timed out',
      );
    } catch {
      throw new UnauthorizedException('Google sign-in timed out. Please try again.');
    }
    const payload = ticket.getPayload();
    if (!payload?.email) throw new BadRequestException('Google token missing email');
    if (!payload.email_verified) throw new ForbiddenException('Google email not verified');
    const googleSub = payload.sub;
    const email = payload.email;

    let user = await this.prisma.user.findFirst({
      where: { OR: [{ googleSub }, { email }] },
      include: { profile: true },
    });
    const currencyFields = this.profileCurrencyFields(meta?.localeHints);
    if (!user) {
      const displayName = payload.name || email;
      const username = await this.generateUniqueUsername(email.split('@')[0]);
      const location = await this.registrationLocation(meta, currencyFields.countryCode);
      user = await this.prisma.user.create({
        data: {
          email,
          passwordHash: await this.hash(randomBytes(16).toString('hex')),
          googleSub,
          emailVerifiedAt: new Date(),
          profile: {
            create: {
              displayName,
              username,
              preferredFiatCurrency: currencyFields.preferredFiatCurrency,
              countryCode: currencyFields.countryCode,
              timezone: currencyFields.timezone ?? 'UTC',
              ...(location ? { location } : {}),
            },
          },
        },
        include: { profile: true },
      });
      await this.audit('REGISTER_GOOGLE', user.id, meta);
    } else {
      if (!user.googleSub) {
        user = await this.prisma.user.update({
          where: { id: user.id },
          data: { googleSub, emailVerifiedAt: user.emailVerifiedAt ?? new Date() },
          include: { profile: true },
        });
      }
      const refreshedProfile = await this.maybeUpdateProfileLocale(
        user.id,
        user.profile,
        meta?.localeHints,
      );
      if (refreshedProfile) user = { ...user, profile: refreshedProfile };
      this.deferProfileLocationUpdate(user.id, user.profile, {
        clientLocation: meta?.location,
        ip: meta?.ip,
        countryCode: user.profile?.countryCode,
      });
    }

    if (!user) throw new BadRequestException('Google sign-in failed');
    const accessToken = this.signAccessToken({ id: user.id, email: user.email, role: user.role });
    const refreshToken = this.signRefreshToken({ id: user.id, email: user.email });
    await this.saveRefreshSession(user.id, refreshToken);
    void this.maybeNotifyNewLoginDevice(user, meta ?? {}).catch(() => {});
    await this.audit('LOGIN_GOOGLE', user.id, meta);
    return { ...this.mapUserResponse(user), accessToken, refreshToken };
  }

  async appleLogin(
    identityToken: string,
    input: { email?: string; displayName?: string },
    meta?: LoginMeta & { localeHints?: LocaleHints },
  ) {
    const audiences = this.getAppleAudiences();
    if (audiences.length === 0) {
      throw new BadRequestException(
        'Apple Sign-In is not configured. Set APPLE_CLIENT_ID to your iOS bundle ID (e.g. com.bybata.bybata).',
      );
    }

    let payload: appleSigninAuth.AppleIdTokenType;
    try {
      payload = await this.withTimeout(
        appleSigninAuth.verifyIdToken(identityToken, {
          audience: audiences.length === 1 ? audiences[0] : audiences,
          ignoreExpiration: false,
        }),
        8000,
        'Apple token verification timed out',
      );
    } catch {
      throw new UnauthorizedException(
        'Apple sign-in timed out or token invalid. Please try again.',
      );
    }

    const appleSub = payload.sub;
    const email = payload.email || input.email;

    let user = await this.prisma.user.findFirst({
      where: { appleSub },
      include: { profile: true },
    });

    if (!user && email) {
      user = await this.prisma.user.findFirst({
        where: { email },
        include: { profile: true },
      });
    }

    if (!user) {
      if (!email) {
        throw new BadRequestException(
          'Apple did not share an email. Remove Bybata under Settings > Apple ID > Sign in with Apple, then try again.',
        );
      }
      const displayName = input.displayName || email;
      const username = await this.generateUniqueUsername(email.split('@')[0]);
      const currencyFields = this.profileCurrencyFields(meta?.localeHints);
      const location = await this.registrationLocation(meta, currencyFields.countryCode);
      try {
        user = await this.prisma.user.create({
          data: {
            email,
            passwordHash: await this.hash(randomBytes(16).toString('hex')),
            appleSub,
            emailVerifiedAt: new Date(),
            profile: {
              create: {
                displayName,
                username,
                preferredFiatCurrency: currencyFields.preferredFiatCurrency,
                countryCode: currencyFields.countryCode,
                timezone: currencyFields.timezone ?? 'UTC',
                ...(location ? { location } : {}),
              },
            },
          },
          include: { profile: true },
        });
      } catch (err) {
        if (this.isPrismaUniqueViolation(err)) {
          throw new ConflictException(
            'Unable to create account. This email or Apple ID may already be registered.',
          );
        }
        throw err;
      }
      await this.audit('REGISTER_APPLE', user.id, meta);
    } else {
      if (!user.appleSub) {
        try {
          user = await this.prisma.user.update({
            where: { id: user.id },
            data: { appleSub, emailVerifiedAt: user.emailVerifiedAt ?? new Date() },
            include: { profile: true },
          });
        } catch (err) {
          if (this.isPrismaUniqueViolation(err)) {
            throw new ConflictException('This Apple account is already linked to another user.');
          }
          throw err;
        }
      }
      const refreshedProfile = await this.maybeUpdateProfileLocale(
        user.id,
        user.profile,
        meta?.localeHints,
      );
      if (refreshedProfile) user = { ...user, profile: refreshedProfile };
      this.deferProfileLocationUpdate(user.id, user.profile, {
        clientLocation: meta?.location,
        ip: meta?.ip,
        countryCode: user.profile?.countryCode,
      });
    }

    if (!user) throw new BadRequestException('Apple sign-in failed');
    const accessToken = this.signAccessToken({ id: user.id, email: user.email, role: user.role });
    const refreshToken = this.signRefreshToken({ id: user.id, email: user.email });
    await this.saveRefreshSession(user.id, refreshToken);
    void this.maybeNotifyNewLoginDevice(user, meta ?? {}).catch(() => {});
    await this.audit('LOGIN_APPLE', user.id, meta);
    return { ...this.mapUserResponse(user), accessToken, refreshToken };
  }

  async refresh(oldRefreshToken: string) {
    try {
      // Use ConfigValidation which handles production vs development appropriately
      const refreshSecret = ConfigValidation.getRequired(
        'JWT_REFRESH_SECRET',
        'JWT refresh token signing secret',
        'dev-refresh' // Fallback only allowed in development
      );
      const payload = await this.jwt.verifyAsync(oldRefreshToken, { secret: refreshSecret });
      const session = await this.prisma.session.findFirst({ where: { userId: payload.sub } });
      if (!session) throw new UnauthorizedException();
      const matches = await this.compare(oldRefreshToken, session.refreshTokenHash);
      if (!matches) throw new UnauthorizedException();
      const user = await this.prisma.user.findUnique({ where: { id: payload.sub }, include: { profile: true } });
      if (!user) throw new UnauthorizedException();
      // rotate refresh
      await this.prisma.session.deleteMany({ where: { userId: user.id } });
      const newRefreshToken = this.signRefreshToken({ id: user.id, email: user.email });
      await this.saveRefreshSession(user.id, newRefreshToken);
      const accessToken = this.signAccessToken({ id: user.id, email: user.email, role: user.role });
      await this.audit('REFRESH', user.id);
      return { accessToken, refreshToken: newRefreshToken };
    } catch {
      throw new UnauthorizedException();
    }
  }

  async logout(userId: string, meta?: { ip?: string; ua?: string }) {
    await this.prisma.session.deleteMany({ where: { userId } });
    await this.audit('LOGOUT', userId, meta);
    return { success: true };
  }

  async forgot(email: string, meta?: { ip?: string; ua?: string }) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) return { success: true };
    await this.audit('FORGOT_REQUEST', user.id, meta);

    // Generate a 6-digit numeric OTP code for password reset instead of a
    // long URL token. We still store it in the PasswordResetToken table and
    // reuse the existing /v1/auth/reset endpoint which accepts `token`.
    let code: string;
    while (true) {
      code = (Math.floor(100000 + Math.random() * 900000)).toString();
      const existing = await this.prisma.passwordResetToken.findUnique({ where: { token: code } });
      if (!existing) break;
    }

    const expires = new Date(Date.now() + 1000 * 60 * 60); // 1h
    await this.prisma.passwordResetToken.create({
      data: { userId: user.id, token: code, expiresAt: expires },
    });

    try {
      this.email.dispatchInBackground({
        eventName: EmailEventName.AuthPasswordResetRequest,
        recipient: { email: user.email, userId: user.id },
        vars: {
          displayName: user.email,
          // We reuse the existing template var name `resetLink`, but it now
          // represents the one-time code the user must enter in the app.
          resetLink: code,
          expiresAt: expires.toISOString(),
          appName: 'bYbata',
        },
      });
    } catch (_) {}
    return { success: true };
  }

  async reset(token: string, password: string, meta?: { ip?: string; ua?: string }) {
    const record = await this.prisma.passwordResetToken.findUnique({ where: { token } });
    if (!record || record.usedAt || record.expiresAt < new Date()) throw new UnauthorizedException('Invalid token');
    const hash = await this.hash(password);
    await this.prisma.$transaction([
      this.prisma.user.update({ where: { id: record.userId }, data: { passwordHash: hash } }),
      this.prisma.passwordResetToken.update({ where: { token }, data: { usedAt: new Date() } }),
    ]);
    await this.audit('RESET_PASSWORD', record.userId, meta);
    try {
      const user = await this.prisma.user.findUnique({ where: { id: record.userId } });
      if (user) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.AuthPasswordChanged,
          recipient: { email: user.email, userId: user.id },
          vars: {
            displayName: user.email,
            changedAt: new Date().toISOString(),
            supportEmail: process.env.SUPPORT_EMAIL || 'support@bybata.com',
          },
        });
      }
    } catch (_) {}
    return { success: true };
  }

  async verifyRequest(email: string, meta?: { ip?: string; ua?: string }) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) return { success: true };
    await this.audit('VERIFY_REQUEST', user.id, meta);
    // Generate 6-digit OTP code and send via email (instead of link)
    const code = (Math.floor(100000 + Math.random() * 900000)).toString();
    const ttlMinutes = Number(process.env.VERIFY_CODE_TTL_MINUTES ?? 15);
    const expires = new Date(Date.now() + ttlMinutes * 60 * 1000);
    await this.prisma.emailVerificationToken.create({ data: { userId: user.id, token: code, expiresAt: expires } });
    try {
      this.email.dispatchInBackground({
        eventName: EmailEventName.AuthEmailVerify,
        recipient: { email: user.email, userId: user.id },
        vars: {
          displayName: user.email,
          verificationLink: code,
          expiresAt: expires.toISOString(),
          appName: 'bYbata',
        },
      });
    } catch (_) {}
    return { success: true };
  }

  async verifyConfirm(token: string, meta?: { ip?: string; ua?: string }) {
    const record = await this.prisma.emailVerificationToken.findUnique({ where: { token } });
    if (!record || record.usedAt || record.expiresAt < new Date()) throw new UnauthorizedException('Invalid token');
    await this.prisma.$transaction([
      this.prisma.user.update({ where: { id: record.userId }, data: { emailVerifiedAt: new Date() } }),
      this.prisma.emailVerificationToken.update({ where: { token }, data: { usedAt: new Date() } }),
    ]);
    await this.audit('VERIFY_CONFIRM', record.userId, meta);
    try {
      const user = await this.prisma.user.findUnique({ where: { id: record.userId } });
      if (user) {
        this.email.dispatchInBackground({
          eventName: EmailEventName.AuthEmailVerified,
          recipient: { email: user.email, userId: user.id },
          vars: {
            displayName: user.email,
            appName: 'bYbata',
            loginUrl: this.emailLinkRouter.getAppOpenLink(),
          },
        });
      }
    } catch (_) {}
    return { success: true };
  }

  // Phone verification — OTP delivered via admin-configured SMS/WhatsApp providers.
  async phoneVerifyRequest(
    userId: string,
    phoneNumber: string,
    meta?: { ip?: string; ua?: string },
  ) {
    const normalized = this.messaging.normalizePhone(phoneNumber);
    const ttlMinutes = Number(process.env.VERIFY_CODE_TTL_MINUTES ?? 15);
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expires = new Date(Date.now() + ttlMinutes * 60 * 1000);

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user?.profile) {
      throw new NotFoundException('User profile not found');
    }

    // Keep profile phone in sync with the number being verified.
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        profile: {
          update: {
            phone: normalized.startsWith('+') ? normalized : `+${normalized}`,
            phoneVerificationCode: code,
            phoneVerificationExpiresAt: expires,
            phoneVerifiedAt: null,
          },
        },
      },
    });

    const delivery = await this.messaging.sendOtp({
      phoneNumber: normalized,
      code,
      ttlMinutes,
    });

    await this.audit('PHONE_VERIFY_REQUEST', userId, meta);
    return {
      success: true,
      channelsSent: delivery.channelsSent,
      channelsAttempted: delivery.channelsAttempted,
    };
  }

  async phoneVerifyConfirm(
    userId: string,
    code: string,
    meta?: { ip?: string; ua?: string },
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user?.profile) {
      throw new NotFoundException('User profile not found');
    }

    const expected = user.profile.phoneVerificationCode;
    const expiresAt = user.profile.phoneVerificationExpiresAt;
    if (
      !expected ||
      !expiresAt ||
      expected !== code.trim() ||
      expiresAt.getTime() < Date.now()
    ) {
      throw new UnauthorizedException('Invalid or expired verification code');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        profile: {
          update: {
            phoneVerificationCode: null,
            phoneVerificationExpiresAt: null,
            phoneVerifiedAt: new Date(),
          },
        },
      },
    });

    await this.audit('PHONE_VERIFY_CONFIRM', userId, meta);
    return { success: true };
  }

  private async saveRefreshSession(userId: string, refreshToken: string) {
    const hash = await this.hash(refreshToken);
    await this.prisma.$transaction(async (tx) => {
      await tx.session.deleteMany({ where: { userId } });
      await tx.session.create({
        data: {
          userId,
          refreshTokenHash: hash,
          expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30),
        },
      });
    });
  }
}
