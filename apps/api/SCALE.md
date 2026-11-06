# Scale checklist — treat production as multi-million MAU

This API is configured so horizontal scale does **not** multiply Postgres connections.

## Architecture

```
Flutter / clients
       │
       ▼
 API replicas (N)  ── each Prisma pool ≤ PRISMA_CONNECTION_LIMIT (default 5)
       │
       ├── Redis (REDIS_URL) — shared /me + feed cache across replicas
       │
       ▼
 PgBouncer / pooler (DATABASE_POOL_URL)
       │
       ▼
 Postgres primary (DATABASE_URL for migrations only)
```

**Rule:** `API_REPLICAS × PRISMA_CONNECTION_LIMIT < Postgres max_connections`  
Leave headroom for migrations, admin, and replicas.

## Required Railway / production env

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | **Direct** Postgres URL (migrations, prisma CLI) |
| `DATABASE_POOL_URL` | **PgBouncer / pooler** URL used by the running Nest app |
| `PRISMA_PGBOUNCER=true` | Force `pgbouncer=true` on the pool URL if needed |
| `PRISMA_CONNECTION_LIMIT=5` | Per-process Prisma pool size |
| `REDIS_URL` | Shared cache across replicas (required for scale) |
| `ME_CACHE_TTL_S=60` | Hot `/v1/users/me` cache |
| `ME_LIGHT_CACHE_TTL_S=120` | Login/session light profile cache |

## What the code does

1. **Single global PrismaClient** — never re-provide `PrismaService` in feature modules.
2. **Pool caps** — `connection_limit` + optional `pgbouncer=true` on the runtime URL.
3. **`GET /v1/users/me?light=1`** — one DB round-trip for login/session restore.
4. **Cached `/me`** — Redis-backed (or memory fallback in dev).
5. **Cache invalidation** on profile update.

## Ops steps after deploy

1. Add a **Redis** plugin on Railway → copy `REDIS_URL` into the API service.
2. Add **PgBouncer** (or Railway Postgres pooler) → set `DATABASE_POOL_URL`.
3. Keep `DATABASE_URL` as the **direct** connection for `prisma migrate deploy`.
4. Set `PRISMA_CONNECTION_LIMIT=5` (raise only after mathing replicas × limit).
5. Redeploy API and restart once to drop leaked connections.
6. Confirm logs show: `Prisma connected (... pooler=yes)` and `[Cache] Redis connected`.

## What still comes later (true 5M+)

- Read replicas for feeds/search
- Job queues (BullMQ) for email, push, karma side-effects
- Chat presence / receipts via Redis pub-sub
- CDN for all media (already mostly in place)

Those are incremental; the items above stop connection meltdown and make login survive concurrency.
