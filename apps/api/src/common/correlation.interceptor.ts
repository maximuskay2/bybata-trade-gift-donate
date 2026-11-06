import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import * as crypto from 'crypto';

@Injectable()
export class CorrelationIdInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const req = context.switchToHttp().getRequest();
    const res = context.switchToHttp().getResponse();
    const incoming = (req.headers['x-correlation-id'] as string) || (req.headers['x-request-id'] as string);
    const cid = incoming || crypto.randomUUID();
    req['correlationId'] = cid;
    res.setHeader('x-correlation-id', cid);
    return next.handle().pipe(
      tap(() => {
        // No-op; downstream services can read req['correlationId'] for structured logs
      }),
    );
  }
}
