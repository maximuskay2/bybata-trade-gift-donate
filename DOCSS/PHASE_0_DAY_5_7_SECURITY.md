# Phase 0, Day 5-7: Security Basics - Implementation Guide

**Date:** December 21, 2025  
**Status:** 🟡 **IN PROGRESS**

---

## Overview

This document outlines the security implementations for Phase 0, Day 5-7, ensuring all security measures work with Supabase cloud server.

---

## 1. CORS Configuration ✅

### Implementation

**Location:** `apps/api/src/main.ts`

**Features:**
- ✅ Production CORS_ORIGINS validation (required in production)
- ✅ Wildcard subdomain support (e.g., `*.example.com`)
- ✅ Development mode allows all origins if CORS_ORIGINS not set
- ✅ Credentials support enabled
- ✅ Proper headers configuration
- ✅ Preflight handling

**Configuration:**
```env
# Comma-separated list of allowed origins
CORS_ORIGINS=https://app.bybata.com,https://admin.bybata.com,https://*.bybata.com
```

**Supabase Compatibility:**
- ✅ Works with Supabase cloud server
- ✅ Supports Supabase project URLs
- ✅ Handles proxy/load balancer headers

**Example for Supabase:**
```env
CORS_ORIGINS=https://your-project.supabase.co,https://your-app-domain.com
```

---

## 2. HTTPS Enforcement ✅

### Implementation

**Location:** `apps/api/src/main.ts` (inline middleware)

**Features:**
- ✅ Redirects GET requests to HTTPS (301)
- ✅ Rejects non-GET requests over HTTP (403)
- ✅ Supports proxy headers (`x-forwarded-proto`, `x-forwarded-ssl`)
- ✅ Configurable via `ENFORCE_HTTPS` environment variable
- ✅ Automatic in production mode

**Configuration:**
```env
# Enable HTTPS enforcement (default: enabled in production)
ENFORCE_HTTPS=true
```

**Supabase Compatibility:**
- ✅ Supabase handles HTTPS at platform level
- ✅ Middleware provides additional enforcement
- ✅ Works with Supabase's proxy/load balancer headers

**Behavior:**
- **GET/HEAD requests:** Redirected to HTTPS (301)
- **Other methods:** Rejected with 403 error
- **Development:** Can be disabled for local testing

---

## 3. Rate Limiting Tuning ✅

### Implementation

**Location:** `apps/api/src/app.module.ts`

**Configuration:**
Three-tier rate limiting system:

1. **Short-term (1 minute):**
   - Production: 60 requests/minute
   - Development: 100 requests/minute

2. **Medium-term (5 minutes):**
   - Production: 200 requests/5 minutes
   - Development: 500 requests/5 minutes

3. **Long-term (15 minutes):**
   - Production: 1000 requests/15 minutes
   - Development: 2000 requests/15 minutes

**Environment Variables:**
```env
# Customize rate limits (optional)
RATE_LIMIT_SHORT=60
RATE_LIMIT_MEDIUM=200
RATE_LIMIT_LONG=1000
```

**Usage in Controllers:**
```typescript
import { Throttle } from '@nestjs/throttler';

@Throttle({ short: { ttl: 60000, limit: 10 } }) // Override for specific endpoint
@Controller('auth')
export class AuthController {
  // ...
}
```

**Supabase Compatibility:**
- ✅ Works with Supabase serverless functions
- ✅ Rate limiting is per-instance (consider distributed rate limiting for scale)
- ✅ Can be combined with Supabase's built-in rate limiting

**Recommendations:**
- Monitor rate limit hits in production
- Adjust limits based on traffic patterns
- Consider Redis-based distributed rate limiting for high scale

---

## 4. Input Sanitization ✅

### Implementation

**Service:** `apps/api/src/common/input-sanitizer.service.ts`  
**Interceptor:** `apps/api/src/common/input-sanitization.interceptor.ts`

**Features:**
- ✅ HTML sanitization (XSS prevention) using DOMPurify
- ✅ Plain text sanitization (removes all HTML)
- ✅ URL sanitization (validates protocols)
- ✅ SQL injection pattern detection (Prisma handles this, but extra safety)
- ✅ Object/array recursive sanitization
- ✅ Global interceptor for automatic sanitization

**XSS Prevention:**
- Sanitizes all string inputs
- Removes dangerous HTML tags
- Allows safe tags (p, br, strong, em, etc.)
- Validates URLs to prevent malicious redirects

**SQL Injection Protection:**
- Prisma uses parameterized queries (primary protection)
- Additional pattern detection for extra safety
- Validates input before database operations

**Usage:**
```typescript
// Automatic via interceptor (all requests sanitized)
// Or manual usage:
constructor(private sanitizer: InputSanitizerService) {}

sanitizeInput(input: string) {
  return this.sanitizer.sanitizeText(input);
}
```

**Supabase Compatibility:**
- ✅ Works with Supabase PostgreSQL
- ✅ Prisma's parameterized queries provide SQL injection protection
- ✅ Input sanitization adds extra layer of security

---

## Security Headers (Helmet) ✅

### Implementation

**Location:** `apps/api/src/main.ts`

**Configuration:**
- ✅ Content Security Policy (CSP) in production
- ✅ HSTS (HTTP Strict Transport Security)
- ✅ X-Frame-Options
- ✅ X-Content-Type-Options
- ✅ Referrer-Policy

**Supabase Compatibility:**
- ✅ Works with Supabase cloud server
- ✅ Headers are set at application level
- ✅ Can be combined with Supabase's edge function headers

---

## Validation Pipe ✅

### Implementation

**Location:** `apps/api/src/main.ts`

**Features:**
- ✅ Whitelist mode (strips unknown properties)
- ✅ Forbid non-whitelisted properties
- ✅ Automatic transformation
- ✅ Type conversion

**Usage:**
```typescript
// DTOs with class-validator decorators
export class CreateTradeDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  title: string;

  @IsString()
  @IsOptional()
  description?: string;
}
```

**Supabase Compatibility:**
- ✅ Works with all Supabase services
- ✅ Validates input before database operations
- ✅ Prevents invalid data from reaching Prisma

---

## Environment Variables

### Required for Production

```env
# CORS Configuration (REQUIRED in production)
CORS_ORIGINS=https://app.bybata.com,https://admin.bybata.com

# HTTPS Enforcement (optional, defaults to true in production)
ENFORCE_HTTPS=true

# Rate Limiting (optional, has defaults)
RATE_LIMIT_SHORT=60
RATE_LIMIT_MEDIUM=200
RATE_LIMIT_LONG=1000
```

---

## Testing Security Measures

### CORS Testing
```bash
# Test from allowed origin
curl -H "Origin: https://app.bybata.com" \
     -H "Access-Control-Request-Method: POST" \
     -X OPTIONS \
     http://localhost:3000/v1/auth/login

# Test from disallowed origin (should fail in production)
curl -H "Origin: https://evil.com" \
     -H "Access-Control-Request-Method: POST" \
     -X OPTIONS \
     http://localhost:3000/v1/auth/login
```

### HTTPS Enforcement Testing
```bash
# Test HTTP request (should redirect or reject)
curl -v http://localhost:3000/health

# Test HTTPS request (should work)
curl -v https://your-api-domain.com/health
```

### Rate Limiting Testing
```bash
# Make multiple rapid requests (should hit rate limit)
for i in {1..100}; do
  curl http://localhost:3000/health
done
```

### Input Sanitization Testing
```bash
# Test XSS attempt
curl -X POST http://localhost:3000/v1/trades \
  -H "Content-Type: application/json" \
  -d '{"title": "<script>alert(\"XSS\")</script>"}'

# Should be sanitized to plain text
```

---

## Supabase-Specific Considerations

### 1. CORS
- Include Supabase project URL in CORS_ORIGINS if needed
- Supabase handles CORS at edge level, but app-level CORS provides additional control

### 2. HTTPS
- Supabase provides HTTPS by default
- Middleware provides additional enforcement
- Works with Supabase's proxy headers

### 3. Rate Limiting
- Supabase has built-in rate limiting
- Application-level rate limiting adds extra protection
- Consider distributed rate limiting for high scale

### 4. Input Sanitization
- Works with Supabase PostgreSQL via Prisma
- Prisma's parameterized queries prevent SQL injection
- Input sanitization adds XSS protection

---

## Best Practices

1. **CORS:**
   - Always specify exact origins in production
   - Avoid wildcards in production
   - Test CORS configuration thoroughly

2. **HTTPS:**
   - Always enforce HTTPS in production
   - Use HSTS headers
   - Monitor for insecure requests

3. **Rate Limiting:**
   - Monitor rate limit hits
   - Adjust limits based on usage
   - Consider per-endpoint limits for sensitive operations

4. **Input Sanitization:**
   - Sanitize all user input
   - Use validation pipes
   - Log suspicious input patterns

---

## Next Steps

1. ✅ Complete CORS configuration
2. ✅ Improve HTTPS enforcement
3. ✅ Document rate limiting
4. ✅ Integrate input sanitization interceptor
5. ⏳ Test all security measures
6. ⏳ Update .env.example with security variables
7. ⏳ Create security testing guide

---

**Last Updated:** December 21, 2025

