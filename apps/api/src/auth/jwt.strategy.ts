import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigValidation } from '../config/config.validation';
import { PrismaService } from '../common/prisma.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private prisma: PrismaService) {
    // Use ConfigValidation which handles production vs development appropriately
    const secret = ConfigValidation.getRequired(
      'JWT_ACCESS_SECRET',
      'JWT access token signing secret',
      'dev-secret' // Fallback only allowed in development
    );

    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: secret,
    });
  }

  async validate(payload: any) {
    // Ensure payload has required fields
    if (!payload || (!payload.sub && !payload.id)) {
      throw new Error('Invalid token payload: missing user identifier');
    }
    
    // Use payload.sub if available, otherwise fall back to payload.id
    const userId = payload.sub || payload.id;

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { banned: true, bannedUntil: true, emailVerifiedAt: true },
    });
    if (user?.banned) {
      if (user.bannedUntil && user.bannedUntil.getTime() <= Date.now()) {
        await this.prisma.user.update({
          where: { id: userId },
          data: { banned: false, banNote: null, bannedUntil: null },
        });
      } else {
        throw new UnauthorizedException('Account is banned');
      }
    }
    if (!user?.emailVerifiedAt) {
      throw new UnauthorizedException('Email verification required');
    }
    
    // Expose both `id` and `sub` so that downstream code that expects either
    // shape (req.user.id or req.user.sub) continues to work.
    return {
      id: userId,
      sub: userId,
      email: payload.email,
      role: payload.role,
    };
  }
}