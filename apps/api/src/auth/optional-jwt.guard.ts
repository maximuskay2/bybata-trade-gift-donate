import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/** Attaches the JWT user when a bearer token is present. Anonymous calls still pass. */
@Injectable()
export class OptionalJwtAuthGuard extends AuthGuard('jwt') {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest();
    const header = req?.headers?.authorization;
    if (!header) return true;
    try {
      const result = await super.canActivate(context);
      return result !== false;
    } catch {
      return true;
    }
  }

  handleRequest(err: any, user: any) {
    if (err || !user) return null;
    if (!user.sub && user.id) user.sub = user.id;
    return user;
  }
}
