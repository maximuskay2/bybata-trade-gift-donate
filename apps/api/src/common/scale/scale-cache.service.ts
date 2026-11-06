import { Inject, Injectable, Logger } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import type { Cache } from 'cache-manager';
import { ScaleDefaults } from './scale.constants';

/**
 * Thin cache facade for hot paths at multi-million scale.
 * Uses Redis when REDIS_URL is configured; otherwise Nest in-memory store.
 */
@Injectable()
export class ScaleCacheService {
  private readonly logger = new Logger(ScaleCacheService.name);

  constructor(@Inject(CACHE_MANAGER) private readonly cache: Cache) {}

  /** cache-manager v6 expects TTL in milliseconds. */
  private ttlMs(seconds: number): number {
    return Math.max(1, seconds) * 1000;
  }

  async getJson<T>(key: string): Promise<T | null> {
    try {
      const value = await this.cache.get<T>(key);
      return value ?? null;
    } catch (err: any) {
      this.logger.warn(`cache get failed for ${key}: ${err?.message || err}`);
      return null;
    }
  }

  async setJson(
    key: string,
    value: unknown,
    ttlSeconds: number = ScaleDefaults.meCacheTtlSec,
  ): Promise<void> {
    try {
      await this.cache.set(key, value, this.ttlMs(ttlSeconds));
    } catch (err: any) {
      this.logger.warn(`cache set failed for ${key}: ${err?.message || err}`);
    }
  }

  async del(key: string): Promise<void> {
    try {
      await this.cache.del(key);
    } catch (err: any) {
      this.logger.warn(`cache del failed for ${key}: ${err?.message || err}`);
    }
  }

  async delMany(keys: string[]): Promise<void> {
    await Promise.all(keys.map((k) => this.del(k)));
  }
}
