/**
 * Scale defaults sized for multi-million MAU with horizontal API replicas.
 * Override via env; never raise PRISMA_CONNECTION_LIMIT without checking
 * (replicas × limit) < Postgres max_connections behind PgBouncer.
 */
export const ScaleDefaults = {
  /** Per-process Prisma pool (behind PgBouncer). */
  prismaConnectionLimit: 5,
  prismaPoolTimeoutSec: 20,
  /** Hot profile payload TTL (seconds). */
  meCacheTtlSec: 60,
  /** Light session profile TTL (seconds). */
  meLightCacheTtlSec: 120,
  /** In-memory fallback max keys when Redis is down (dev only). */
  cacheMaxItems: 10_000,
  /** Default list/feed cache TTL (seconds). */
  feedCacheTtlSec: 30,
} as const;

export const ScaleCacheKeys = {
  me: (userId: string) => `scale:user:me:v1:${userId}`,
  meLight: (userId: string) => `scale:user:me-light:v1:${userId}`,
} as const;
