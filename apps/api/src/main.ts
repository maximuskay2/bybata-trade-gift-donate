import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { LogLevel, ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';
import { raw } from 'body-parser';
import { CorrelationIdInterceptor } from './common/correlation.interceptor';
import { ConfigValidation } from './config/config.validation';
import { SentryService } from './common/sentry.service';

/** Nest built-in logger levels; respects LOG_LEVEL (default info in production). */
function resolveLogLevels(): LogLevel[] {
  const isProduction = process.env.NODE_ENV === 'production';
  const level = (process.env.LOG_LEVEL || (isProduction ? 'info' : 'debug')).toLowerCase();
  switch (level) {
    case 'error':
      return ['error'];
    case 'warn':
      return ['error', 'warn'];
    case 'log':
    case 'info':
      return ['error', 'warn', 'log'];
    case 'debug':
      return ['error', 'warn', 'log', 'debug'];
    case 'verbose':
      return ['error', 'warn', 'log', 'debug', 'verbose'];
    default:
      return ['error', 'warn', 'log'];
  }
}

async function bootstrap() {
  // Initialize Sentry for error tracking (if DSN is configured)
  const sentryService = new SentryService();
  sentryService.initialize();

  // Validate critical environment variables before starting the application
  // This will fail fast if required variables are missing (especially in production)
  ConfigValidation.validateCritical();

  const app = await NestFactory.create(AppModule, {
    logger: resolveLogLevels(),
  });

  // Railway / reverse proxies — needed for correct client IP in security emails.
  app.getHttpAdapter().getInstance().set('trust proxy', true);

  // Determine environment
  const isProduction = process.env.NODE_ENV === 'production';

  // Security headers with production-ready configuration
  app.use(helmet({
    contentSecurityPolicy: isProduction ? {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        scriptSrc: ["'self'"],
        imgSrc: ["'self'", 'data:', 'https:'],
        connectSrc: ["'self'"],
        fontSrc: ["'self'"],
        objectSrc: ["'none'"],
        mediaSrc: ["'self'"],
        frameSrc: ["'none'"],
      },
    } : false, // Disable CSP in development for easier debugging
    crossOriginEmbedderPolicy: false, // Disable for compatibility
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    hsts: isProduction ? {
      maxAge: 31536000, // 1 year
      includeSubDomains: true,
      preload: true,
    } : false,
  }));

  // HTTPS Enforcement middleware (if enabled)
  // Note: In production on Supabase, HTTPS is handled by the platform
  // This middleware provides additional enforcement
  if (isProduction || process.env.ENFORCE_HTTPS === 'true') {
    app.use((req, res, next) => {
      const isSecure = 
        req.secure || // Direct HTTPS connection
        req.headers['x-forwarded-proto'] === 'https' || // Proxy/load balancer
        req.headers['x-forwarded-ssl'] === 'on' || // Alternative header
        req.headers['x-forwarded-scheme'] === 'https'; // Another alternative

      if (!isSecure) {
        // For GET requests, redirect to HTTPS
        if (req.method === 'GET' || req.method === 'HEAD') {
          const httpsUrl = `https://${req.get('host')}${req.originalUrl}`;
          return res.redirect(301, httpsUrl);
        }

        // For non-GET requests, reject with 403
        return res.status(403).json({
          error: 'HTTPS required',
          message: 'This API requires HTTPS. Please use https:// instead of http://',
          code: 'HTTPS_REQUIRED',
        });
      }

      next();
    });
  }

  // Raw-body middleware for payment provider webhooks (signature verification requires exact payload)
  app.use('/v1/wallet/webhooks', raw({ type: 'application/json' }));
  app.use('/v1/trade-topups/paypal/webhook', raw({ type: 'application/json' }));

  // Global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
    })
  );

  // Correlation ID interceptor
  app.useGlobalInterceptors(new CorrelationIdInterceptor());

  // CORS Configuration - Production-ready
  const corsOrigins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  // Marketing site (campaign-support.html) must call the API from the browser.
  const marketingSiteOrigins = [
    'https://bybata.com',
    'https://www.bybata.com',
  ];
  // Railway-hosted admin + API (browser login from admin dashboard).
  const railwayPlatformOrigins = [
    'https://bybataadmin-production.up.railway.app',
    '*.up.railway.app',
  ];
  const allowedOrigins = [
    ...new Set([...corsOrigins, ...marketingSiteOrigins, ...railwayPlatformOrigins]),
  ];

  // In production, CORS_ORIGINS is required
  if (isProduction && corsOrigins.length === 0) {
    throw new Error(
      'CORS_ORIGINS environment variable is required in production. ' +
      'Please set it to a comma-separated list of allowed origins.'
    );
  }

  // Validate CORS origins format
  const originValidator = (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) {
      return callback(null, true);
    }

    // In development, allow all origins if CORS_ORIGINS is not set
    if (!isProduction && corsOrigins.length === 0) {
      return callback(null, true);
    }

    // Check if origin is in allowed list
    const isAllowed = allowedOrigins.some((allowedOrigin) => {
      // Support wildcard subdomains (e.g., *.example.com, *.up.railway.app)
      if (allowedOrigin.startsWith('*.')) {
        const domain = allowedOrigin.slice(2);
        try {
          const { hostname } = new URL(origin);
          return hostname === domain || hostname.endsWith(`.${domain}`);
        } catch {
          return origin.endsWith(`.${domain}`) || origin === `https://${domain}` || origin === `http://${domain}`;
        }
      }
      return origin === allowedOrigin;
    });

    callback(null, isAllowed);
  };

  app.enableCors({
    origin: isProduction 
      ? originValidator 
      : (corsOrigins.length > 0 ? originValidator : true),
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: [
      'Content-Type',
      'Authorization',
      'X-Correlation-ID',
      'X-Request-ID',
      'Accept',
      'Origin',
    ],
    exposedHeaders: ['X-Correlation-ID', 'X-Request-ID'],
    maxAge: 86400, // 24 hours
    preflightContinue: false,
    optionsSuccessStatus: 204,
  });

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`API listening on port ${port}`);
}
bootstrap();
