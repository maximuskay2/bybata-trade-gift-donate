import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { ScaleDefaults } from './scale/scale.constants';

/**
 * Resolve the runtime DB URL for app traffic.
 * Prefer DATABASE_POOL_URL (PgBouncer / pooler) when set; fall back to DATABASE_URL.
 * Migrations should use DATABASE_URL_DIRECT (see schema.prisma directUrl).
 */
function resolveRuntimeDatabaseUrl(): string | undefined {
  const raw =
    process.env.DATABASE_POOL_URL?.trim() ||
    process.env.DATABASE_URL?.trim();
  if (!raw) return raw;
  return withPoolLimits(raw);
}

function withPoolLimits(rawUrl: string): string {
  try {
    const url = new URL(rawUrl);
    const limit = Math.max(
      1,
      Math.min(
        20,
        Number.parseInt(
          process.env.PRISMA_CONNECTION_LIMIT ||
            String(ScaleDefaults.prismaConnectionLimit),
          10,
        ) || ScaleDefaults.prismaConnectionLimit,
      ),
    );

    if (!url.searchParams.has('connection_limit')) {
      url.searchParams.set('connection_limit', String(limit));
    }
    if (!url.searchParams.has('pool_timeout')) {
      url.searchParams.set(
        'pool_timeout',
        process.env.PRISMA_POOL_TIMEOUT ||
          String(ScaleDefaults.prismaPoolTimeoutSec),
      );
    }
    if (!url.searchParams.has('connect_timeout')) {
      url.searchParams.set('connect_timeout', '10');
    }

    // PgBouncer transaction pooling requires disabling prepared statements.
    const forcePgBouncer =
      process.env.PRISMA_PGBOUNCER === 'true' ||
      process.env.PRISMA_PGBOUNCER === '1' ||
      url.port === '6543' ||
      url.hostname.includes('pooler') ||
      url.searchParams.get('pgbouncer') === 'true';

    if (forcePgBouncer && !url.searchParams.has('pgbouncer')) {
      url.searchParams.set('pgbouncer', 'true');
    }

    return url.toString();
  } catch {
    return rawUrl;
  }
}

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    const url = resolveRuntimeDatabaseUrl();
    super({
      datasources: {
        db: {
          url,
        },
      },
      log: [
        { level: 'warn', emit: 'stdout' },
        { level: 'error', emit: 'stdout' },
      ],
    });
  }

  async onModuleInit() {
    await this.$connect();
    const limit =
      process.env.PRISMA_CONNECTION_LIMIT ||
      String(ScaleDefaults.prismaConnectionLimit);
    const usingPool =
      !!(process.env.DATABASE_POOL_URL?.trim()) ||
      process.env.PRISMA_PGBOUNCER === 'true';
    this.logger.log(
      `Prisma connected (connection_limit≈${limit}, pooler=${usingPool ? 'yes' : 'no'})`,
    );
    if (
      process.env.NODE_ENV === 'production' &&
      !process.env.DATABASE_POOL_URL &&
      process.env.PRISMA_PGBOUNCER !== 'true'
    ) {
      this.logger.warn(
        'DATABASE_POOL_URL not set — for multi-million scale, put PgBouncer in front of Postgres and point DATABASE_POOL_URL at it.',
      );
    }
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
