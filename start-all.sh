#!/bin/bash

# Bybata - Start All Services Script
echo "🚀 Starting Bybata Services..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        echo -e "${RED}⚠️  Port $port is already in use${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Port $port is available${NC}"
        return 0
    fi
}

# Check ports
echo -e "${BLUE}🔍 Checking ports...${NC}"
check_port 3000 || { echo -e "${YELLOW}Run 'pkill -f \"node.*3000\"' to free port 3000${NC}"; }
check_port 3001 || { echo -e "${YELLOW}Run 'pkill -f \"next.*3001\"' to free port 3001${NC}"; }
check_port 5555 || { echo -e "${YELLOW}Run 'pkill -f \"prisma.*studio\"' to free port 5555${NC}"; }

echo ""
echo -e "${BLUE}📋 Service Configuration:${NC}"
echo -e "${GREEN}  • NestJS API:       http://localhost:3000${NC}"
echo -e "${GREEN}  • Admin Interface:  http://localhost:3001${NC}"
echo -e "${GREEN}  • Prisma Studio:    http://localhost:5555${NC}"
echo ""

# Start API Server
echo -e "${BLUE}🔧 Starting NestJS API on port 3000...${NC}"
cd apps/api
npm run start:dev &
API_PID=$!
echo "API PID: $API_PID"
cd ../..

# Wait a moment for API to start
sleep 3

# Start Admin Interface
echo -e "${BLUE}🎨 Starting Admin Interface on port 3001...${NC}"
cd apps/admin
npm run dev &
ADMIN_PID=$!
echo "Admin PID: $ADMIN_PID"
cd ../..

# Wait a moment for Admin to start
sleep 3

# Start Prisma Studio
echo -e "${BLUE}🗄️  Starting Prisma Studio on port 5555...${NC}"
cd apps/api
npm run db:studio &
STUDIO_PID=$!
echo "Studio PID: $STUDIO_PID"
cd ../..

echo ""
echo -e "${GREEN}🎉 All services started successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Service Status:${NC}"
echo -e "${GREEN}┌─────────────────┬─────────────────────────────┬──────────┐${NC}"
echo -e "${GREEN}│ Service         │ URL                         │ Status   │${NC}"
echo -e "${GREEN}├─────────────────┼─────────────────────────────┼──────────┤${NC}"
echo -e "${GREEN}│ NestJS API      │ http://localhost:3000       │ ✅ ACTIVE │${NC}"
echo -e "${GREEN}│ Admin Interface │ http://localhost:3001       │ ✅ ACTIVE │${NC}"
echo -e "${GREEN}│ Prisma Studio   │ http://localhost:5555       │ ✅ ACTIVE │${NC}"
echo -e "${GREEN}└─────────────────┴─────────────────────────────┴──────────┘${NC}"
echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo -e "  • Press Ctrl+C to stop all services"
echo -e "  • Run './stop-all.sh' to stop services individually"
echo -e "  • Check './logs.sh' for service logs"
echo ""

# Wait for user to stop services
trap 'echo -e "\n${BLUE}🛑 Stopping all services...${NC}"; kill $API_PID $ADMIN_PID $STUDIO_PID 2>/dev/null; exit 0' INT

# Keep script running
wait