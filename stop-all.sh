#!/bin/bash

# Bybata - Stop All Services Script
echo "🛑 Stopping Bybata Services..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to stop process on port
stop_port() {
    local port=$1
    local service_name=$2
    
    echo -e "${BLUE}🔍 Stopping $service_name on port $port...${NC}"
    
    # Find and kill processes using the port
    local pids=$(lsof -ti:$port)
    
    if [ -n "$pids" ]; then
        for pid in $pids; do
            echo -e "${YELLOW}  Killing PID: $pid${NC}"
            kill -TERM $pid 2>/dev/null
            
            # Wait a moment then force kill if still running
            sleep 2
            if kill -0 $pid 2>/dev/null; then
                echo -e "${RED}  Force killing PID: $pid${NC}"
                kill -KILL $pid 2>/dev/null
            fi
        done
        echo -e "${GREEN}✅ $service_name stopped${NC}"
    else
        echo -e "${YELLOW}⚠️  No $service_name running on port $port${NC}"
    fi
}

# Stop all services
stop_port 3000 "NestJS API"
stop_port 3001 "Admin Interface"
stop_port 5555 "Prisma Studio"

# Also kill any remaining node processes related to our project
echo -e "${BLUE}🧹 Cleaning up any remaining processes...${NC}"
pkill -f "nest start" 2>/dev/null && echo -e "${GREEN}  Stopped remaining Nest processes${NC}"
pkill -f "next dev" 2>/dev/null && echo -e "${GREEN}  Stopped remaining Next processes${NC}"
pkill -f "prisma studio" 2>/dev/null && echo -e "${GREEN}  Stopped remaining Prisma Studio processes${NC}"

echo ""
echo -e "${GREEN}🎉 All services stopped successfully!${NC}"
echo ""
echo -e "${BLUE}📋 To restart all services, run:${NC}"
echo -e "${YELLOW}  ./start-all.sh${NC}"