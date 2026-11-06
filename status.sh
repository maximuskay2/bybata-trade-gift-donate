#!/bin/bash

# Bybata - Service Status Check Script
echo "📊 Bybata Service Status"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check service status
check_service() {
    local port=$1
    local service_name=$2
    local url=$3
    
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        # Try to get HTTP status
        if command -v curl >/dev/null 2>&1; then
            local status=$(curl -s -o /dev/null -w "%{http_code}" $url 2>/dev/null)
            if [ "$status" = "200" ] || [ "$status" = "000" ]; then
                echo -e "│ ${service_name} │ ${url} │ ${GREEN}✅ ACTIVE${NC} │ HTTP ${status:-'N/A'} │"
            else
                echo -e "│ ${service_name} │ ${url} │ ${YELLOW}⚠️  RUNNING${NC} │ HTTP ${status:-'ERR'} │"
            fi
        else
            echo -e "│ ${service_name} │ ${url} │ ${GREEN}✅ ACTIVE${NC} │ Port Open │"
        fi
    else
        echo -e "│ ${service_name} │ ${url} │ ${RED}❌ STOPPED${NC} │ Port Closed │"
    fi
}

echo ""
echo -e "${BLUE}┌─────────────────┬─────────────────────────────┬──────────┬──────────────┐${NC}"
echo -e "${BLUE}│ Service         │ URL                         │ Status   │ Response     │${NC}"
echo -e "${BLUE}├─────────────────┼─────────────────────────────┼──────────┼──────────────┤${NC}"

check_service 3000 "NestJS API      " "http://localhost:3000"
check_service 3001 "Admin Interface " "http://localhost:3001"
check_service 5555 "Prisma Studio   " "http://localhost:5555"

echo -e "${BLUE}└─────────────────┴─────────────────────────────┴──────────┴──────────────┘${NC}"
echo ""

# Show running processes
echo -e "${BLUE}🔍 Related Processes:${NC}"
pids=$(lsof -ti:3000,3001,5555 2>/dev/null)
if [ -n "$pids" ]; then
    echo -e "${YELLOW}PIDs using ports 3000, 3001, 5555:${NC}"
    for pid in $pids; do
        ps -p $pid -o pid,ppid,command 2>/dev/null | tail -n +2
    done
else
    echo -e "${YELLOW}No processes found using ports 3000, 3001, 5555${NC}"
fi

echo ""
echo -e "${BLUE}💡 Management Commands:${NC}"
echo -e "  • Start all services: ${GREEN}./start-all.sh${NC}"
echo -e "  • Stop all services:  ${RED}./stop-all.sh${NC}"
echo -e "  • Check status:       ${BLUE}./status.sh${NC}"