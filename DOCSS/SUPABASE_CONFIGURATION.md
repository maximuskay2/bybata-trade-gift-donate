# Supabase Configuration Guide

## Overview

This project uses **Supabase** for:
- **Database**: PostgreSQL (via Supabase)
- **Storage**: Supabase Storage (S3-compatible)
- **Server**: Supabase Cloud Server
- **Real-time**: Supabase Realtime (optional, currently using Socket.IO)

---

## Supabase Setup

### 1. Create Supabase Project

1. Go to https://supabase.com
2. Create a new project
3. Note your project credentials:
   - Project URL: `https://your-project.supabase.co`
   - Anon Key: `your-anon-key`
   - Service Role Key: `your-service-role-key`
   - Database Password: `your-database-password`

### 2. Database Connection

Supabase provides a PostgreSQL database. The connection string format is:

```
postgresql://postgres:[YOUR-PASSWORD]@db.[YOUR-PROJECT-REF].supabase.co:5432/postgres
```

Or use the connection pooler (recommended for serverless):
```
postgresql://postgres.[YOUR-PROJECT-REF]:[YOUR-PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres?pgbouncer=true
```

---

## Environment Variables

### API Service (`apps/api/.env`)

```env
# ============================================
# Supabase Configuration
# ============================================
# Supabase Project URL
SUPABASE_URL=https://your-project.supabase.co

# Supabase Anon Key (for client-side operations)
SUPABASE_ANON_KEY=your-anon-key

# Supabase Service Role Key (for server-side operations)
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Database Connection (Supabase PostgreSQL)
# Use connection pooler for better performance
DATABASE_URL=postgresql://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres?pgbouncer=true

# Direct connection (for migrations, use this)
DATABASE_URL_DIRECT=postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres

# ============================================
# Supabase Storage (S3-compatible)
# ============================================
# Supabase Storage endpoint (S3-compatible)
STORAGE_ENDPOINT=https://[PROJECT-REF].supabase.co/storage/v1

# Storage bucket name
STORAGE_BUCKET=bybata-uploads

# Storage access (use service role key for server-side)
STORAGE_ACCESS_KEY_ID=your-service-role-key
STORAGE_SECRET_ACCESS_KEY=your-service-role-key

# Storage region (Supabase uses us-east-1)
STORAGE_REGION=us-east-1

# Signed URL TTL in seconds
STORAGE_SIGNED_URL_TTL_SECONDS=300

# ============================================
# Application Configuration
# ============================================
NODE_ENV=production
PORT=3000
APP_PUBLIC_URL=https://your-app-domain.com

# CORS Origins (include your Supabase project URL if needed)
CORS_ORIGINS=https://your-app-domain.com,https://your-project.supabase.co

# ============================================
# JWT Authentication
# ============================================
# Use Supabase JWT secret or generate your own
JWT_ACCESS_SECRET=your-jwt-secret
JWT_REFRESH_SECRET=your-refresh-secret
JWT_REFRESH_EXPIRES_IN=30d

# ============================================
# Email Configuration
# ============================================
EMAIL_PROVIDER=resend
RESEND_API_KEY=your-resend-key
EMAIL_FROM=no-reply@yourdomain.com

# ============================================
# Error Tracking & Logging
# ============================================
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id
LOG_LEVEL=info
```

---

## Prisma Configuration

### Connection Pooling

Supabase recommends using connection pooling for serverless/server applications. Update `apps/api/src/common/prisma.service.ts`:

```typescript
constructor() {
  super({
    datasources: {
      db: {
        // Use connection pooler URL
        url: process.env.DATABASE_URL,
      },
    },
    // Connection pool settings for Supabase
    log: [
      { level: 'warn', emit: 'stdout' },
      { level: 'error', emit: 'stdout' },
    ],
  });
}
```

### Migrations

For migrations, use the direct connection URL:

```bash
# Set direct connection for migrations
DATABASE_URL=postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres

# Run migrations
npx prisma migrate deploy
```

---

## Supabase Storage Configuration

### Storage Service Update

Update `apps/api/src/storage/storage.service.ts` to work with Supabase Storage:

```typescript
// Supabase Storage is S3-compatible, but uses different authentication
// Use Supabase client library or REST API
```

### Storage Buckets

Create buckets in Supabase Dashboard:
1. Go to Storage in Supabase Dashboard
2. Create buckets:
   - `bybata-uploads` - Public uploads
   - `bybata-private` - Private files
3. Set bucket policies as needed

---

## Supabase Realtime (Optional)

Currently, the project uses Socket.IO for real-time features. If you want to use Supabase Realtime:

1. Enable Realtime in Supabase Dashboard
2. Subscribe to database changes
3. Replace Socket.IO with Supabase Realtime subscriptions

---

## Health Checks

The health check endpoint (`/health`) works with Supabase:
- Database connectivity check uses Prisma (works with Supabase PostgreSQL)
- All existing health endpoints are compatible

---

## Monitoring & Logging

### Log Aggregation

For Supabase deployments, recommended log aggregation options:

1. **Supabase Logs** (Built-in)
   - Access via Supabase Dashboard
   - View API logs, database logs, auth logs
   - Limited retention

2. **External Services** (Recommended)
   - **Datadog** - Comprehensive monitoring
   - **Sentry** - Error tracking (already integrated)
   - **CloudWatch** - If using AWS
   - **Logtail** - Simple log aggregation

### Winston Logger

The Winston logger works with Supabase:
- File-based logging works on Supabase serverless functions
- For Edge Functions, use external log aggregation
- Correlation IDs work across all services

---

## Authentication

### Current Setup

The project uses custom JWT authentication. Supabase Auth can be integrated:

1. **Option 1: Keep Custom Auth** (Current)
   - Works with Supabase database
   - Full control over auth flow
   - Compatible with existing implementation

2. **Option 2: Use Supabase Auth**
   - Leverage Supabase's built-in auth
   - Email verification, OAuth, etc.
   - Requires refactoring auth service

**Recommendation:** Keep custom auth for now, migrate to Supabase Auth later if needed.

---

## Database Migrations

### Running Migrations on Supabase

```bash
# 1. Set direct connection URL
export DATABASE_URL=postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres

# 2. Run migrations
cd apps/api
npx prisma migrate deploy

# 3. Generate Prisma Client
npx prisma generate
```

### Migration Best Practices

1. **Use Direct Connection** for migrations (not pooler)
2. **Test Migrations** in staging first
3. **Backup Database** before major migrations
4. **Use Supabase Dashboard** to monitor migrations

---

## Security Considerations

### Row Level Security (RLS)

Supabase supports Row Level Security. Consider enabling RLS for:
- User data isolation
- Community access control
- Trade/gift visibility

### API Keys

- **Anon Key**: Safe for client-side, limited permissions
- **Service Role Key**: Server-side only, full permissions
- **Never expose** service role key in client code

### Connection Security

- Use SSL/TLS for all database connections
- Supabase connections are encrypted by default
- Use connection pooler for better security

---

## Performance Optimization

### Connection Pooling

- Use Supabase connection pooler for serverless/server apps
- Reduces connection overhead
- Better for high-traffic applications

### Query Optimization

- Use Prisma query optimization
- Add database indexes as needed
- Monitor slow queries in Supabase Dashboard

### Caching

- Consider Redis for caching (Supabase doesn't provide Redis)
- Use Supabase Edge Functions for edge caching
- Implement application-level caching

---

## Troubleshooting

### Connection Issues

**Problem:** Cannot connect to database
- Check DATABASE_URL format
- Verify password is correct
- Check Supabase project status
- Verify network/firewall settings

### Storage Issues

**Problem:** Cannot upload files
- Verify bucket exists
- Check bucket policies
- Verify service role key
- Check file size limits

### Migration Issues

**Problem:** Migrations fail
- Use direct connection (not pooler)
- Check Prisma schema compatibility
- Verify database permissions
- Check for existing data conflicts

---

## Next Steps

1. ✅ Update `.env.example` with Supabase variables
2. ✅ Test database connection
3. ✅ Test storage uploads
4. ✅ Run migrations
5. ✅ Test health endpoints
6. ✅ Configure monitoring
7. ✅ Set up log aggregation

---

**Last Updated:** December 21, 2025

