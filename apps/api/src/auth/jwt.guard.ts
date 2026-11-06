import { AuthGuard } from '@nestjs/passport';
import { Injectable, ExecutionContext, UnauthorizedException } from '@nestjs/common';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    try {
      const result = await super.canActivate(context);
      if (result === false) {
        throw new UnauthorizedException('Authentication required');
      }
      return result as boolean;
    } catch (error) {
      // If it's already an UnauthorizedException, rethrow it
      if (error instanceof UnauthorizedException) {
        throw error;
      }
      // Otherwise, wrap it in an UnauthorizedException
      throw new UnauthorizedException('Authentication failed');
    }
  }

  handleRequest(err: any, user: any, info: any, context: ExecutionContext) {
    // If there's an error or no user, throw UnauthorizedException
    if (err) {
      throw err instanceof UnauthorizedException ? err : new UnauthorizedException('Authentication failed');
    }

    if (!user) {
      throw new UnauthorizedException('Authentication required');
    }

    // Ensure user has required properties
    if (!user.sub && !user.id) {
      throw new UnauthorizedException('Invalid token: missing user identifier');
    }

    // Normalize user object to always have both id and sub
    if (!user.sub && user.id) {
      user.sub = user.id;
    } else if (!user.id && user.sub) {
      user.id = user.sub;
    }

    return user;
  }
}