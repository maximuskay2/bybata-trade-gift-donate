#!/bin/bash

# Redis Setup for Railway Production
# This script sets up Redis locally and configures the backend for Redis usage

set -e

echo "🚀 Bybata Redis Setup Script"
echo "========================================"
echo ""

# Check if docker is running
if ! docker ps > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Step 1: Check if Redis dependencies are installed
echo "📦 Checking Redis dependencies..."
cd "$(dirname "$0")/../apps/api"

if ! npm list cache-manager-ioredis-yet > /dev/null 2>&1; then
    echo "⬇️  Installing cache-manager-ioredis-yet and ioredis..."
    npm install cache-manager-ioredis-yet ioredis
    echo "✅ Dependencies installed"
else
    echo "✅ Dependencies already installed"
fi

# Step 2: Create .env.local if it doesn't exist
cd "$(dirname "$0")/.."

if [ ! -f ".env.local" ]; then
    echo "Creating .env.local with Redis configuration..."
    cat > .env.local << 'EOF'
# Redis Configuration
REDIS_URL=redis://:bybata@localhost:6379

# Cache Settings
CACHE_TTL_SECONDS=30
CACHE_MAX_ITEMS=500

# Service-Specific TTLs
GIFT_FEED_CACHE_TTL_S=30
CAMPAIGNS_CACHE_TTL_S=30
TRADES_CACHE_TTL_S=30
WALLET_RATES_CACHE_TTL_S=300
EOF
    echo "✅ .env.local created"
else
    # Check if REDIS_URL is already in .env.local
    if ! grep -q "REDIS_URL" .env.local; then
        echo "⚠️  Adding REDIS_URL to .env.local..."
        echo "" >> .env.local
        echo "# Redis Configuration" >> .env.local
        echo "REDIS_URL=redis://:bybata@localhost:6379" >> .env.local
        echo "CACHE_TTL_SECONDS=30" >> .env.local
        echo "CACHE_MAX_ITEMS=500" >> .env.local
        echo "✅ REDIS_URL added to .env.local"
    else
        echo "✅ REDIS_URL already configured in .env.local"
    fi
fi

# Step 3: Start Docker services
echo ""
echo "🐳 Starting Docker services..."
docker-compose up -d

# Wait for Redis to be healthy
echo "⏳ Waiting for Redis to be healthy..."
for i in {1..30}; do
    if docker exec bybata_redis redis-cli -a bybata ping > /dev/null 2>&1; then
        echo "✅ Redis is healthy"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Redis failed to start. Check logs with: docker logs bybata_redis"
        exit 1
    fi
    sleep 1
done

# Step 4: Verify Redis connection
echo ""
echo "🔍 Verifying Redis connection..."
redis_output=$(docker exec bybata_redis redis-cli -a bybata PING)
if [ "$redis_output" = "PONG" ]; then
    echo "✅ Redis is responding correctly"
else
    echo "❌ Redis is not responding. Output: $redis_output"
    exit 1
fi

# Step 5: Print summary
echo ""
echo "========================================"
echo "✅ Redis Setup Complete!"
echo "========================================"
echo ""
echo "📊 Service Status:"
echo "  - PostgreSQL: http://localhost:5442"
echo "  - MinIO:      http://localhost:9001"
echo "  - Redis:      localhost:6379 (password: bybata)"
echo ""
echo "🚀 Next Steps:"
echo "  1. Start your API: cd apps/api && npm start"
echo "  2. API will auto-detect REDIS_URL and use Redis caching"
echo "  3. Check logs for: 'Using Redis cache' message"
echo ""
echo "🔗 For Railway Production Setup:"
echo "  1. Go to: https://railway.app/dashboard"
echo "  2. Click 'Create' → 'Database' → 'Redis'"
echo "  3. Add REDIS_URL to your Railway variables"
echo "  4. Redeploy: railway up"
echo ""
echo "📖 Documentation:"
echo "  - Redis Setup Guide: docs/REDIS_SETUP_RAILWAY.md"
echo "  - Caching Audit:     docs/CACHING_IMPLEMENTATION_AUDIT.md"
echo ""
