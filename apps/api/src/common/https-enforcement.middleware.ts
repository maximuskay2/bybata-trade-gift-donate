import { Injectable, NestMiddleware, Logger } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

/**
 * HTTPS Enforcement Middleware
 * 
 * Enforces HTTPS connections in production
 * Redirects HTTP to HTTPS for GET requests
 * Rejects non-GET requests over HTTP
 */
@Injectable()
export class HttpsEnforcementMiddleware implements NestMiddleware {
  private readonly logger = new Logger(HttpsEnforcementMiddleware.name);
  private readonly isProduction = process.env.NODE_ENV === 'production';
  private readonly enforceHttps = process.env.ENFORCE_HTTPS === 'true';

  use(req: Request, res: Response, next: NextFunction) {
    // Only enforce in production or if explicitly enabled
    if (!this.isProduction && !this.enforceHttps) {
      return next();
    }

    // Check if request is secure
    const isSecure = 
      req.secure || // Direct HTTPS connection
      req.headers['x-forwarded-proto'] === 'https' || // Proxy/load balancer
      req.headers['x-forwarded-ssl'] === 'on' || // Alternative header
      req.headers['x-forwarded-scheme'] === 'https'; // Another alternative

    if (!isSecure) {
      // For GET requests, redirect to HTTPS
      if (req.method === 'GET' || req.method === 'HEAD') {
        const httpsUrl = `https://${req.get('host')}${req.originalUrl}`;
        this.logger.warn(`Redirecting insecure ${req.method} request to HTTPS: ${httpsUrl}`);
        return res.redirect(301, httpsUrl);
      }

      // For non-GET requests, reject with 403
      this.logger.error(`Rejecting insecure ${req.method} request: ${req.originalUrl}`);
      return res.status(403).json({
        error: 'HTTPS required',
        message: 'This API requires HTTPS. Please use https:// instead of http://',
        code: 'HTTPS_REQUIRED',
      });
    }

    next();
  }
}

