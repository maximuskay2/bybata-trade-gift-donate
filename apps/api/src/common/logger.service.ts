import { Injectable, LoggerService as NestLoggerService } from '@nestjs/common';
import * as winston from 'winston';
import { Request } from 'express';

/**
 * Structured logging service using Winston with correlation ID support
 * 
 * Features:
 * - Structured JSON logging
 * - Correlation ID tracking
 * - Log levels (error, warn, info, debug)
 * - File and console transports
 * - Environment-based configuration
 */
@Injectable()
export class LoggerService implements NestLoggerService {
  private logger: winston.Logger;
  private context?: string;

  constructor() {
    const isProduction = process.env.NODE_ENV === 'production';
    const logLevel = process.env.LOG_LEVEL || (isProduction ? 'info' : 'debug');

    // Define log format
    const logFormat = winston.format.combine(
      winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
      winston.format.errors({ stack: true }),
      winston.format.splat(),
      winston.format.json(),
      winston.format.printf(({ timestamp, level, message, context, correlationId, ...meta }) => {
        const logEntry: any = {
          timestamp,
          level,
          message,
        };
        if (context) {
          logEntry.context = context;
        }
        if (correlationId) {
          logEntry.correlationId = correlationId;
        }
        if (Object.keys(meta).length > 0) {
          logEntry.meta = meta;
        }
        return JSON.stringify(logEntry);
      })
    );

    // Console format for development (more readable)
    const consoleFormat = winston.format.combine(
      winston.format.colorize(),
      winston.format.timestamp({ format: 'HH:mm:ss' }),
      winston.format.printf(({ timestamp, level, message, context, correlationId, ...meta }) => {
        const contextStr = context ? `[${context}]` : '';
        const correlationStr = correlationId && typeof correlationId === 'string' ? `[${correlationId.substring(0, 8)}]` : '';
        const metaStr = Object.keys(meta).length > 0 ? ` ${JSON.stringify(meta)}` : '';
        return `${timestamp} ${level} ${contextStr}${correlationStr} ${message}${metaStr}`;
      })
    );

    // Create transports
    const transports: winston.transport[] = [
      // Console transport (always enabled)
      new winston.transports.Console({
        format: isProduction ? logFormat : consoleFormat,
      }),
    ];

    // File transport for production
    if (isProduction) {
      transports.push(
        // Error log file
        new winston.transports.File({
          filename: 'logs/error.log',
          level: 'error',
          format: logFormat,
          maxsize: 5242880, // 5MB
          maxFiles: 5,
        }),
        // Combined log file
        new winston.transports.File({
          filename: 'logs/combined.log',
          format: logFormat,
          maxsize: 5242880, // 5MB
          maxFiles: 5,
        })
      );
    }

    this.logger = winston.createLogger({
      level: logLevel,
      format: logFormat,
      transports,
      // Handle exceptions and rejections
      exceptionHandlers: isProduction
        ? [
            new winston.transports.File({ filename: 'logs/exceptions.log' }),
          ]
        : [new winston.transports.Console()],
      rejectionHandlers: isProduction
        ? [
            new winston.transports.File({ filename: 'logs/rejections.log' }),
          ]
        : [new winston.transports.Console()],
    });
  }

  /**
   * Set context for subsequent log messages
   */
  setContext(context: string) {
    this.context = context;
  }

  /**
   * Get correlation ID from request
   */
  private getCorrelationId(req?: Request): string | undefined {
    return req?.['correlationId'] as string | undefined;
  }

  /**
   * Log with correlation ID from request
   */
  logWithRequest(message: string, req?: Request, meta?: any) {
    const correlationId = this.getCorrelationId(req);
    this.logger.info(message, {
      context: this.context,
      correlationId,
      ...meta,
    });
  }

  /**
   * Log error with correlation ID from request
   */
  errorWithRequest(message: string, trace?: string, req?: Request, meta?: any) {
    const correlationId = this.getCorrelationId(req);
    this.logger.error(message, {
      context: this.context,
      correlationId,
      trace,
      ...meta,
    });
  }

  /**
   * NestJS LoggerService interface implementation
   */
  log(message: any, context?: string, correlationId?: string) {
    this.logger.info(message, {
      context: context || this.context,
      correlationId,
    });
  }

  error(message: any, trace?: string, context?: string, correlationId?: string) {
    this.logger.error(message, {
      context: context || this.context,
      correlationId,
      trace,
    });
  }

  warn(message: any, context?: string, correlationId?: string) {
    this.logger.warn(message, {
      context: context || this.context,
      correlationId,
    });
  }

  debug(message: any, context?: string, correlationId?: string) {
    this.logger.debug(message, {
      context: context || this.context,
      correlationId,
    });
  }

  verbose(message: any, context?: string, correlationId?: string) {
    this.logger.verbose(message, {
      context: context || this.context,
      correlationId,
    });
  }
}

