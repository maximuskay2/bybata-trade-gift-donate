import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { InputSanitizerService } from './input-sanitizer.service';

/**
 * Input Sanitization Interceptor
 * 
 * Automatically sanitizes request body, query, and params
 * to prevent XSS and SQL injection attacks
 */
@Injectable()
export class InputSanitizationInterceptor implements NestInterceptor {
  constructor(private readonly sanitizer: InputSanitizerService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();

    // Sanitize request body
    if (request.body && typeof request.body === 'object') {
      request.body = this.sanitizeObject(request.body);
    }

    // Sanitize query parameters (modify in-place since query is read-only)
    if (request.query && typeof request.query === 'object') {
      this.sanitizeObjectInPlace(request.query);
    }

    // Sanitize route parameters (modify in-place since params is read-only)
    if (request.params && typeof request.params === 'object') {
      this.sanitizeObjectInPlace(request.params);
    }

    return next.handle().pipe(
      map((data) => {
        // Optionally sanitize response data (be careful not to break valid HTML)
        // For now, we only sanitize input, not output
        return data;
      })
    );
  }

  private sanitizeObject(obj: any): any {
    if (!obj || typeof obj !== 'object') {
      return obj;
    }

    if (Array.isArray(obj)) {
      return obj.map((item) => this.sanitizeValue(item));
    }

    const sanitized: any = {};
    for (const key in obj) {
      if (Object.prototype.hasOwnProperty.call(obj, key)) {
        sanitized[key] = this.sanitizeValue(obj[key]);
      }
    }

    return sanitized;
  }

  private sanitizeValue(value: any): any {
    if (typeof value === 'string') {
      // Sanitize strings as plain text (removes HTML)
      return this.sanitizer.sanitizeText(value);
    }

    if (typeof value === 'object' && value !== null) {
      return this.sanitizeObject(value);
    }

    return value;
  }

  /**
   * Sanitize object properties in-place (for read-only objects like request.query and request.params)
   * This modifies the existing object rather than creating a new one
   */
  private sanitizeObjectInPlace(obj: any): void {
    if (!obj || typeof obj !== 'object' || Array.isArray(obj)) {
      return;
    }

    for (const key in obj) {
      if (Object.prototype.hasOwnProperty.call(obj, key)) {
        const value = obj[key];
        if (typeof value === 'string') {
          // Sanitize strings in-place
          obj[key] = this.sanitizer.sanitizeText(value);
        } else if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
          // Recursively sanitize nested objects
          this.sanitizeObjectInPlace(value);
        } else if (Array.isArray(value)) {
          // Sanitize array elements
          obj[key] = value.map((item) => {
            if (typeof item === 'string') {
              return this.sanitizer.sanitizeText(item);
            } else if (typeof item === 'object' && item !== null) {
              const sanitized = { ...item };
              this.sanitizeObjectInPlace(sanitized);
              return sanitized;
            }
            return item;
          });
        }
      }
    }
  }
}

