import { Injectable, Logger } from '@nestjs/common';
import * as Sentry from '@sentry/node';
import { nodeProfilingIntegration } from '@sentry/profiling-node';

/**
 * Sentry error tracking service
 * 
 * Provides centralized error tracking and monitoring
 * Integrates with Sentry for production error tracking
 */
@Injectable()
export class SentryService {
  private readonly logger = new Logger(SentryService.name);
  private initialized = false;

  /**
   * Initialize Sentry
   * Call this in main.ts before starting the application
   */
  initialize() {
    const dsn = process.env.SENTRY_DSN;
    const environment = process.env.NODE_ENV || 'development';
    const release = process.env.npm_package_version || '0.0.1';

    if (!dsn) {
      this.logger.warn('Sentry DSN not configured. Error tracking disabled.');
      return;
    }

    try {
      Sentry.init({
        dsn,
        environment,
        release,
        integrations: [
          // Profiling integration for performance monitoring
          nodeProfilingIntegration(),
          // HTTP integration for request tracking (automatically included in @sentry/node)
          // Express integration is automatically handled by @sentry/node
        ],
        // Performance monitoring
        tracesSampleRate: environment === 'production' ? 0.1 : 1.0, // 10% in production, 100% in dev
        // Profiling sample rate
        profilesSampleRate: environment === 'production' ? 0.1 : 1.0,
        // Before send hook to filter/modify events
        beforeSend(event, hint) {
          // Filter out certain errors in development
          if (environment === 'development') {
            // Optionally filter out known non-critical errors
            return event;
          }
          return event;
        },
      });

      this.initialized = true;
      this.logger.log('✅ Sentry initialized successfully');
    } catch (error) {
      this.logger.error('Failed to initialize Sentry', error);
    }
  }

  /**
   * Capture an exception
   */
  captureException(exception: any, context?: any, correlationId?: string) {
    if (!this.initialized) {
      this.logger.warn('Sentry not initialized. Error not tracked:', exception);
      return;
    }

    Sentry.withScope((scope) => {
      if (correlationId) {
        scope.setTag('correlationId', correlationId);
      }
      if (context) {
        scope.setContext('context', context);
      }
      Sentry.captureException(exception);
    });
  }

  /**
   * Capture a message
   */
  captureMessage(message: string, level: Sentry.SeverityLevel = 'info', context?: any, correlationId?: string) {
    if (!this.initialized) {
      this.logger.warn('Sentry not initialized. Message not tracked:', message);
      return;
    }

    Sentry.withScope((scope) => {
      if (correlationId) {
        scope.setTag('correlationId', correlationId);
      }
      if (context) {
        scope.setContext('context', context);
      }
      scope.setLevel(level);
      Sentry.captureMessage(message);
    });
  }

  /**
   * Add breadcrumb
   */
  addBreadcrumb(breadcrumb: Sentry.Breadcrumb) {
    if (!this.initialized) return;
    Sentry.addBreadcrumb(breadcrumb);
  }

  /**
   * Set user context
   */
  setUser(user: { id?: string; email?: string; username?: string }) {
    if (!this.initialized) return;
    Sentry.setUser(user);
  }

  /**
   * Set tag
   */
  setTag(key: string, value: string) {
    if (!this.initialized) return;
    Sentry.setTag(key, value);
  }

  /**
   * Set context
   */
  setContext(key: string, context: Record<string, any>) {
    if (!this.initialized) return;
    Sentry.setContext(key, context);
  }

  /**
   * Check if Sentry is initialized
   */
  isInitialized(): boolean {
    return this.initialized;
  }
}

