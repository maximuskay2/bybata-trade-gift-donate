#!/bin/bash

# BYBATA VPS Deployment Script
# This script helps automate the deployment process on a VPS server
# Run this script on your VPS server after initial setup

set -e  # Exit on error

echo "=========================================="
echo "BYBATA VPS Deployment Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo -e "${RED}Please do not run this script as root. Use a regular user with sudo privileges.${NC}"
   exit 1
fi

# Variables
PROJECT_DIR="/home/$(whoami)/bybata"
API_DIR="$PROJECT_DIR/apps/api"
ADMIN_DIR="$PROJECT_DIR/apps/admin"

echo -e "${GREEN}Step 1: Checking prerequisites...${NC}"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js is not installed. Please install Node.js 20.x first.${NC}"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 20 ]; then
    echo -e "${RED}Node.js version 20 or higher is required. Current version: $(node -v)${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Node.js $(node -v) is installed${NC}"

# Check PostgreSQL
if ! command -v psql &> /dev/null; then
    echo -e "${RED}PostgreSQL is not installed. Please install PostgreSQL first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PostgreSQL is installed${NC}"

# Check PM2
if ! command -v pm2 &> /dev/null; then
    echo -e "${YELLOW}PM2 is not installed. Installing...${NC}"
    sudo npm install -g pm2
fi

echo -e "${GREEN}✓ PM2 is installed${NC}"

# Check if project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}Project directory not found. Please clone the repository first.${NC}"
    echo "Run: git clone <your-repo-url> $PROJECT_DIR"
    exit 1
fi

echo -e "${GREEN}✓ Project directory exists${NC}"

echo ""
echo -e "${GREEN}Step 2: Installing dependencies...${NC}"

# Install API dependencies
if [ -d "$API_DIR" ]; then
    echo "Installing API dependencies..."
    cd "$API_DIR"
    npm install
    echo -e "${GREEN}✓ API dependencies installed${NC}"
else
    echo -e "${RED}API directory not found: $API_DIR${NC}"
    exit 1
fi

# Install Admin dependencies
if [ -d "$ADMIN_DIR" ]; then
    echo "Installing Admin dependencies..."
    cd "$ADMIN_DIR"
    npm install
    echo -e "${GREEN}✓ Admin dependencies installed${NC}"
else
    echo -e "${YELLOW}Admin directory not found: $ADMIN_DIR${NC}"
fi

echo ""
echo -e "${GREEN}Step 3: Setting up environment variables...${NC}"

# Check if .env exists for API
if [ ! -f "$API_DIR/.env" ]; then
    echo -e "${YELLOW}API .env file not found. Please create it manually.${NC}"
    echo "See docs/VPS_DEPLOYMENT_GUIDE.md for required environment variables"
else
    echo -e "${GREEN}✓ API .env file exists${NC}"
fi

# Check if .env.local exists for Admin
if [ ! -f "$ADMIN_DIR/.env.local" ]; then
    echo -e "${YELLOW}Admin .env.local file not found. Please create it manually.${NC}"
else
    echo -e "${GREEN}✓ Admin .env.local file exists${NC}"
fi

echo ""
echo -e "${GREEN}Step 4: Running database migrations...${NC}"

cd "$API_DIR"

# Generate Prisma client
echo "Generating Prisma client..."
npx prisma generate

# Run migrations
echo "Running database migrations..."
npx prisma migrate deploy || npx prisma db push

echo -e "${GREEN}✓ Database migrations completed${NC}"

echo ""
echo -e "${GREEN}Step 5: Building applications...${NC}"

# Build API
echo "Building API..."
cd "$API_DIR"
npm run build
echo -e "${GREEN}✓ API built successfully${NC}"

# Build Admin
if [ -d "$ADMIN_DIR" ]; then
    echo "Building Admin dashboard..."
    cd "$ADMIN_DIR"
    npm run build
    echo -e "${GREEN}✓ Admin dashboard built successfully${NC}"
fi

echo ""
echo -e "${GREEN}Step 6: Starting applications with PM2...${NC}"

# Start API
cd "$API_DIR"
pm2 delete bybata-api 2>/dev/null || true
pm2 start npm --name "bybata-api" -- start:prod
echo -e "${GREEN}✓ API started with PM2${NC}"

# Start Admin
if [ -d "$ADMIN_DIR" ]; then
    cd "$ADMIN_DIR"
    pm2 delete bybata-admin 2>/dev/null || true
    pm2 start npm --name "bybata-admin" -- start
    echo -e "${GREEN}✓ Admin dashboard started with PM2${NC}"
fi

# Save PM2 configuration
pm2 save

echo ""
echo -e "${GREEN}Step 7: Setting up PM2 startup...${NC}"

# Setup PM2 startup (if not already done)
if ! pm2 startup | grep -q "already"; then
    echo -e "${YELLOW}Run the command shown above to enable PM2 startup${NC}"
    pm2 startup
else
    echo -e "${GREEN}✓ PM2 startup already configured${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Deployment completed successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Configure Nginx reverse proxy (see docs/VPS_DEPLOYMENT_GUIDE.md)"
echo "2. Set up SSL certificates with Certbot"
echo "3. Configure DNS records for your domain"
echo "4. Verify services are running: pm2 list"
echo "5. Check logs: pm2 logs"
echo ""
echo -e "${GREEN}Useful commands:${NC}"
echo "  pm2 list              - View all processes"
echo "  pm2 logs              - View logs"
echo "  pm2 restart all       - Restart all processes"
echo "  pm2 monit             - Monitor processes"
echo ""

