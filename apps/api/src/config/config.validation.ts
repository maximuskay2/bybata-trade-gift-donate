import { Logger } from '@nestjs/common';

/**
 * Configuration validation utility
 * 
 * Validates required environment variables on startup
 * Fails fast in production if critical variables are missing
 * Allows fallbacks only in development mode
 */
export class ConfigValidation {
  private static readonly logger = new Logger(ConfigValidation.name);
  private static validated = false;
  private static readonly requiredVars: Map<string, string> = new Map();

  /**
   * Get a required environment variable
   * In production: throws error if missing
   * In development: returns fallback or throws error
   * 
   * @param key - Environment variable name
   * @param description - Human-readable description for error messages
   * @param fallback - Optional fallback value (only used in development)
   * @returns The environment variable value
   * @throws Error if variable is missing in production or if no fallback in development
   */
  static getRequired(key: string, description: string, fallback?: string): string {
    const value = process.env[key];
    const isProduction = process.env.NODE_ENV === 'production';

    if (value && value.trim().length > 0) {
      // Track validated variables
      this.requiredVars.set(key, description);
      return value;
    }

    // In production, never allow fallbacks
    if (isProduction) {
      this.logger.error(`❌ Missing required environment variable: ${key}`);
      this.logger.error(`   Description: ${description}`);
      throw new Error(
        `Missing required environment variable: ${key}\n` +
        `Description: ${description}\n` +
        `This variable is required for production. Please set it in your environment.`
      );
    }

    // In development, allow fallback if provided
    if (fallback !== undefined) {
      this.logger.warn(`⚠️  Using fallback for ${key} (development mode only)`);
      this.logger.warn(`   Description: ${description}`);
      this.logger.warn(`   Fallback: ${fallback.substring(0, 10)}...`);
      return fallback;
    }

    // No value and no fallback - error even in development
    this.logger.error(`❌ Missing required environment variable: ${key}`);
    this.logger.error(`   Description: ${description}`);
    throw new Error(
      `Missing required environment variable: ${key}\n` +
      `Description: ${description}\n` +
      `Please set this variable in your .env file or environment.`
    );
  }

  /**
   * Get an optional environment variable
   * 
   * @param key - Environment variable name
   * @param defaultValue - Default value if not set
   * @returns The environment variable value or default
   */
  static getOptional(key: string, defaultValue: string): string {
    return process.env[key] || defaultValue;
  }

  /**
   * Get an optional boolean environment variable
   * 
   * @param key - Environment variable name
   * @param defaultValue - Default value if not set
   * @returns The boolean value
   */
  static getOptionalBoolean(key: string, defaultValue: boolean): boolean {
    const value = process.env[key];
    if (!value) return defaultValue;
    return value.toLowerCase() === 'true';
  }

  /**
   * Get an optional number environment variable
   * 
   * @param key - Environment variable name
   * @param defaultValue - Default value if not set
   * @returns The number value
   */
  static getOptionalNumber(key: string, defaultValue: number): number {
    const value = process.env[key];
    if (!value) return defaultValue;
    const num = Number(value);
    return isNaN(num) ? defaultValue : num;
  }

  /**
   * Validate all critical environment variables on startup
   * Call this in main.ts before starting the application
   */
  static validateCritical(): void {
    if (this.validated) {
      return; // Already validated
    }

    this.logger.log('🔍 Validating critical environment variables...');
    const isProduction = process.env.NODE_ENV === 'production';
    const errors: string[] = [];

    // Critical variables that are always required
    const criticalVars = [
      { key: 'DATABASE_URL', description: 'PostgreSQL database connection string' },
    ];

    // Production-only required variables
    const productionVars = [
      { key: 'JWT_ACCESS_SECRET', description: 'JWT access token signing secret' },
      { key: 'JWT_REFRESH_SECRET', description: 'JWT refresh token signing secret' },
      { key: 'CORS_ORIGINS', description: 'Comma-separated list of allowed CORS origins' },
    ];

    // Validate critical variables
    for (const { key, description } of criticalVars) {
      try {
        const value = process.env[key];
        if (!value || value.trim().length === 0) {
          errors.push(`Missing ${key}: ${description}`);
        } else {
          this.logger.log(`✅ ${key} is set`);
        }
      } catch (error) {
        errors.push(`Error validating ${key}: ${error}`);
      }
    }

    // Validate production-only variables
    if (isProduction) {
      for (const { key, description } of productionVars) {
        try {
          const value = process.env[key];
          if (!value || value.trim().length === 0) {
            errors.push(`Missing ${key}: ${description} (required in production)`);
          } else if (key === 'JWT_ACCESS_SECRET' && value === 'dev-secret') {
            errors.push(`Invalid ${key}: Using development default in production is not allowed`);
          } else if (key === 'JWT_REFRESH_SECRET' && value === 'dev-refresh') {
            errors.push(`Invalid ${key}: Using development default in production is not allowed`);
          } else if (key === 'CORS_ORIGINS') {
            // Validate CORS origins format
            const origins = value.split(',').map(s => s.trim()).filter(Boolean);
            if (origins.length === 0) {
              errors.push(`Invalid ${key}: Must contain at least one origin`);
            } else {
              // Validate origin format
              const invalidOrigins = origins.filter(origin => {
                if (origin.startsWith('*.')) return false; // Wildcard subdomain is OK
                try {
                  const url = new URL(origin);
                  return !['http:', 'https:'].includes(url.protocol);
                } catch {
                  return true; // Invalid URL format
                }
              });
              if (invalidOrigins.length > 0) {
                errors.push(`Invalid ${key}: Invalid origin format(s): ${invalidOrigins.join(', ')}`);
              } else {
                this.logger.log(`✅ ${key} is set with ${origins.length} origin(s)`);
              }
            }
          } else {
            this.logger.log(`✅ ${key} is set`);
          }
        } catch (error) {
          errors.push(`Error validating ${key}: ${error}`);
        }
      }
    } else {
      // In development, warn if production vars are missing but don't fail
      for (const { key, description } of productionVars) {
        const value = process.env[key];
        if (!value || value.trim().length === 0) {
          this.logger.warn(`⚠️  ${key} not set (using fallback in development): ${description}`);
        } else if (key === 'JWT_ACCESS_SECRET' && value === 'dev-secret') {
          this.logger.warn(`⚠️  ${key} using development default: ${description}`);
        } else if (key === 'JWT_REFRESH_SECRET' && value === 'dev-refresh') {
          this.logger.warn(`⚠️  ${key} using development default: ${description}`);
        } else {
          this.logger.log(`✅ ${key} is set`);
        }
      }
    }

    // If there are errors, fail startup
    if (errors.length > 0) {
      this.logger.error('❌ Configuration validation failed:');
      errors.forEach((error) => this.logger.error(`   - ${error}`));
      throw new Error(
        `Configuration validation failed:\n${errors.join('\n')}\n\n` +
        `Please check your .env file and ensure all required variables are set.`
      );
    }

    this.validated = true;
    this.logger.log('✅ All critical environment variables validated');
  }

  /**
   * Get validation status
   */
  static getValidationStatus(): {
    validated: boolean;
    requiredVars: Map<string, string>;
  } {
    return {
      validated: this.validated,
      requiredVars: new Map(this.requiredVars),
    };
  }
}
