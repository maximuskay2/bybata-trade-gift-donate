import { Injectable, NestMiddleware, Logger } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

/**
 * Security middleware for enforcing HTTPS and other security headers
 */
@Injectable()
export class SecurityMiddleware implements NestMiddleware {
  private readonly logger = new Logger(SecurityMiddleware.name);

  use(req: Request, res: Response, next: NextFunction) {
    const isProduction = process.env.NODE_ENV === 'production';
    const enforceHttps = process.env.ENFORCE_HTTPS === 'true' || isProduction;

    // HTTPS Enforcement
    if (enforceHttps) {
      // Check if request is secure (HTTPS)
      const isSecure = req.secure || 
                       req.headers['x-forwarded-proto'] === 'https' ||
                       req.headers['x-forwarded-ssl'] === 'on';

      if (!isSecure) {
        // Redirect to HTTPS
        const httpsUrl = `https://${req.get('host')}${req.originalUrl}`;
        this.logger.warn(`Redirecting HTTP request to HTTPS: ${httpsUrl}`);
        return res.redirect(301, httpsUrl);
      }
    }

    // Additional security headers (helmet handles most, but we add custom ones)
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    res.setHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');

    next();
  }
}

