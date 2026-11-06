import { Module, Global } from '@nestjs/common';
import { LoggerService } from './logger.service';
import { SentryService } from './sentry.service';

/**
 * Global logging module
 * Provides structured logging and error tracking services
 */
@Global()
@Module({
  providers: [LoggerService, SentryService],
  exports: [LoggerService, SentryService],
})
export class LoggingModule {}

