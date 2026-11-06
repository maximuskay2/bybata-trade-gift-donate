# Log Aggregation Setup Guide

## Overview

This document describes the log aggregation setup for the BYBATA application. Currently, the application uses Winston for structured logging with file-based storage. For production deployments, a centralized log aggregation solution is recommended.

---

## Current Setup

### File-Based Logging (Winston)

**Location:** `apps/api/logs/`

**Log Files:**
- `error.log` - Error-level logs only
- `combined.log` - All logs
- `exceptions.log` - Unhandled exceptions
- `rejections.log` - Unhandled promise rejections

**Features:**
- JSON format in production
- Human-readable format in development
- Log rotation (5MB max, 5 files)
- Correlation ID support

---

## Production Log Aggregation Options

### Option 1: AWS CloudWatch (Recommended for AWS Deployments)

**Setup:**
1. Install AWS SDK: `npm install @aws-sdk/client-cloudwatch-logs`
2. Configure Winston CloudWatch transport
3. Set up IAM roles with CloudWatch Logs permissions
4. Create log groups and streams

**Pros:**
- Native AWS integration
- Automatic log retention
- Built-in search and filtering
- Cost-effective for AWS deployments

**Cons:**
- AWS-specific
- Requires AWS account

**Configuration:**
```typescript
import { CloudWatchLogs } from '@aws-sdk/client-cloudwatch-logs';
import WinstonCloudWatch from 'winston-cloudwatch';

const cloudwatch = new CloudWatchLogs({
  region: process.env.AWS_REGION,
});

transports.push(
  new WinstonCloudWatch({
    logGroupName: 'bybata-api',
    logStreamName: process.env.NODE_ENV,
    awsRegion: process.env.AWS_REGION,
  })
);
```

---

### Option 2: Datadog

**Setup:**
1. Create Datadog account
2. Install Datadog agent or use API
3. Configure Winston Datadog transport
4. Set up API key

**Pros:**
- Comprehensive monitoring and logging
- Great UI and search capabilities
- APM integration
- Alerting features

**Cons:**
- Paid service (free tier available)
- Requires external service

**Configuration:**
```typescript
import winston from 'winston';
import DatadogWinston from 'datadog-winston';

transports.push(
  new DatadogWinston({
    apiKey: process.env.DATADOG_API_KEY,
    hostname: process.env.HOSTNAME,
    service: 'bybata-api',
    ddsource: 'nodejs',
    ddtags: `env:${process.env.NODE_ENV}`,
  })
);
```

---

### Option 3: Sentry (Already Integrated)

**Setup:**
1. Sentry is already integrated for error tracking
2. Can be extended for log aggregation
3. Configure Sentry breadcrumbs for logging

**Pros:**
- Already integrated
- Great for error tracking
- Free tier available

**Cons:**
- Primarily for errors, not general logging
- Limited log search capabilities

**Usage:**
```typescript
import { SentryService } from './common/sentry.service';

// Add breadcrumb for logging
sentryService.addBreadcrumb({
  message: 'User action',
  level: 'info',
  data: { userId: '123' },
});
```

---

### Option 4: ELK Stack (Self-Hosted)

**Setup:**
1. Deploy Elasticsearch, Logstash, and Kibana
2. Configure Logstash to read log files
3. Set up filebeat or similar to ship logs
4. Configure Kibana dashboards

**Pros:**
- Full control
- Powerful search and visualization
- Open source

**Cons:**
- Requires infrastructure
- More complex setup
- Maintenance overhead

---

### Option 5: Loki + Grafana (Self-Hosted)

**Setup:**
1. Deploy Loki and Grafana
2. Configure Promtail to ship logs
3. Set up Grafana dashboards

**Pros:**
- Lightweight
- Great for Grafana users
- Efficient storage

**Cons:**
- Requires infrastructure
- Less mature than ELK

---

## Recommended Approach

### For Development/Staging
- **Use:** File-based logging (current setup)
- **Reason:** Simple, no external dependencies

### For Production (AWS)
- **Use:** CloudWatch Logs
- **Reason:** Native integration, cost-effective, easy setup

### For Production (Other Cloud Providers)
- **Use:** Datadog or Sentry
- **Reason:** Cloud-agnostic, comprehensive features

### For Self-Hosted
- **Use:** ELK Stack or Loki + Grafana
- **Reason:** Full control, no external dependencies

---

## Implementation Steps

### Step 1: Choose Solution
Based on deployment environment, choose appropriate solution.

### Step 2: Install Dependencies
```bash
# For CloudWatch
npm install @aws-sdk/client-cloudwatch-logs winston-cloudwatch

# For Datadog
npm install datadog-winston

# For ELK (filebeat)
# Install filebeat on server
```

### Step 3: Configure Transport
Update `apps/api/src/common/logger.service.ts` to add chosen transport.

### Step 4: Set Environment Variables
Add required environment variables to `.env`:
```env
# CloudWatch
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret

# Datadog
DATADOG_API_KEY=your-key
HOSTNAME=api.bybata.com
```

### Step 5: Test
- Generate test logs
- Verify logs appear in aggregation system
- Test search and filtering

---

## Log Format

All logs follow this structure:
```json
{
  "timestamp": "2025-12-21 14:30:00",
  "level": "info",
  "message": "User logged in",
  "context": "AuthService",
  "correlationId": "abc123-def456",
  "meta": {
    "userId": "user123",
    "ip": "192.168.1.1"
  }
}
```

---

## Best Practices

1. **Correlation IDs:** Always include correlation IDs for request tracing
2. **Structured Logging:** Use JSON format for easy parsing
3. **Log Levels:** Use appropriate levels (error, warn, info, debug)
4. **Sensitive Data:** Never log passwords, tokens, or PII
5. **Performance:** Use async logging to avoid blocking
6. **Retention:** Configure appropriate log retention policies
7. **Monitoring:** Set up alerts for error rates

---

## Troubleshooting

### Logs Not Appearing
- Check file permissions
- Verify log level configuration
- Check disk space
- Verify transport configuration

### High Log Volume
- Review log levels
- Filter unnecessary logs
- Implement log sampling
- Use log aggregation for filtering

---

## Next Steps

1. Choose log aggregation solution based on deployment
2. Implement transport in LoggerService
3. Configure environment variables
4. Test log aggregation
5. Set up dashboards and alerts
6. Document for team

---

**Last Updated:** December 21, 2025

