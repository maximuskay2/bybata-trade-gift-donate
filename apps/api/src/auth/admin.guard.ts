import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { JwtAuthGuard } from './jwt.guard';

@Injectable()
export class AdminGuard extends JwtAuthGuard implements CanActivate {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    // First check if user is authenticated
    const isAuthenticated = await super.canActivate(context);
    if (!isAuthenticated) {
      return false;
    }

    // Then check if user is admin
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user || (user.role !== 'ADMIN' && user.role !== 'MODERATOR')) {
      throw new ForbiddenException('Admin access required');
    }

    return true;
  }
}