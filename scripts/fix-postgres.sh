#!/bin/bash

# PostgreSQL Troubleshooting Script for Esport Coach Connect
# This script helps diagnose and fix PostgreSQL startup issues

set -e

echo "🔧 PostgreSQL Troubleshooting for Esport Coach Connect"
echo "====================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}📋 Checking PostgreSQL Status${NC}"

# Check if container exists
if docker ps -a --format 'table {{.Names}}' | grep -q "esport-postgres"; then
    echo -e "${GREEN}✅ PostgreSQL container exists${NC}"
    
    # Check if it's running
    if docker ps --format 'table {{.Names}}' | grep -q "esport-postgres"; then
        echo -e "${GREEN}✅ PostgreSQL container is running${NC}"
        
        # Check health status
        health_status=$(docker inspect esport-postgres --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-health-check")
        echo -e "Health Status: ${YELLOW}$health_status${NC}"
        
    else
        echo -e "${RED}❌ PostgreSQL container is not running${NC}"
    fi
else
    echo -e "${RED}❌ PostgreSQL container does not exist${NC}"
fi

echo ""
echo -e "${BLUE}📋 PostgreSQL Container Logs${NC}"
echo "Last 20 lines of PostgreSQL logs:"
echo "=================================="
docker logs --tail 20 esport-postgres 2>/dev/null || echo -e "${RED}No logs available${NC}"

echo ""
echo -e "${BLUE}🔍 Common Issues Diagnosis${NC}"

# Check if port 5432 is already in use
if netstat -tuln 2>/dev/null | grep -q ":5432"; then
    echo -e "${YELLOW}⚠️  Port 5432 is in use by another process${NC}"
    echo "Processes using port 5432:"
    lsof -i :5432 2>/dev/null || netstat -tulnp 2>/dev/null | grep :5432 || echo "Could not determine which process is using port 5432"
    echo ""
    echo -e "${BLUE}💡 Solution:${NC}"
    echo "1. Stop the conflicting PostgreSQL service:"
    echo "   sudo systemctl stop postgresql"
    echo "   # OR"
    echo "   sudo brew services stop postgresql (on Mac)"
    echo "2. Or change the port in docker-compose.yml to 5433:5432"
else
    echo -e "${GREEN}✅ Port 5432 is available${NC}"
fi

# Check Docker daemon
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker daemon is not running${NC}"
    echo -e "${BLUE}💡 Solution: Start Docker Desktop or Docker daemon${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Docker daemon is running${NC}"
fi

# Check disk space
available_space=$(df -h . | tail -1 | awk '{print $4}')
echo "Available disk space: $available_space"

# Check memory
if command -v free >/dev/null; then
    available_memory=$(free -h | grep '^Mem:' | awk '{print $7}')
    echo "Available memory: $available_memory"
fi

echo ""
echo -e "${BLUE}🛠️  Troubleshooting Steps${NC}"

echo "1. Clean up and restart PostgreSQL:"
echo "   docker-compose stop postgres"
echo "   docker-compose rm -f postgres"
echo "   docker volume rm $(docker-compose config --volumes | grep postgres_data) 2>/dev/null || true"
echo "   docker-compose up -d postgres"
echo ""

echo "2. Check logs in real-time:"
echo "   docker-compose logs -f postgres"
echo ""

echo "3. Connect to PostgreSQL (once running):"
echo "   docker exec -it esport-postgres psql -U admin -d esport_coach"
echo ""

echo "4. Reset everything if needed:"
echo "   docker-compose down -v"
echo "   docker system prune -f"
echo "   docker-compose up -d"
echo ""

# Automated fix attempt
echo -e "${BLUE}🔧 Attempting Automated Fix${NC}"
echo "Would you like to try an automated fix? (y/N)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
    echo -e "${YELLOW}🔄 Stopping and cleaning PostgreSQL...${NC}"
    
    # Stop the service
    docker-compose stop postgres 2>/dev/null || true
    
    # Remove container
    docker-compose rm -f postgres 2>/dev/null || true
    
    # Remove volume (this will delete all data!)
    echo -e "${RED}⚠️  This will delete all PostgreSQL data. Continue? (y/N)${NC}"
    read -r confirm
    if [[ "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        # Get volume name and remove it
        volume_name=$(docker-compose config | grep postgres_data | head -1 | awk '{print $1}' | sed 's/://')
        docker volume rm "${volume_name}" 2>/dev/null || true
        
        echo -e "${YELLOW}🚀 Starting fresh PostgreSQL...${NC}"
        docker-compose up -d postgres
        
        echo -e "${YELLOW}⏳ Waiting for PostgreSQL to be ready...${NC}"
        sleep 10
        
        # Check if it's working
        if docker-compose exec postgres pg_isready -U admin -d esport_coach >/dev/null 2>&1; then
            echo -e "${GREEN}🎉 PostgreSQL is now running successfully!${NC}"
            
            # Show connection info
            echo ""
            echo -e "${GREEN}Connection Details:${NC}"
            echo "Host: localhost"
            echo "Port: 5432"
            echo "Database: esport_coach"
            echo "Username: admin"
            echo "Password: admin123"
            
        else
            echo -e "${RED}❌ PostgreSQL is still not responding. Please check logs:${NC}"
            echo "docker-compose logs postgres"
        fi
    else
        echo -e "${YELLOW}Fix cancelled. Manual intervention required.${NC}"
    fi
else
    echo -e "${YELLOW}Manual fix required. Please follow the steps above.${NC}"
fi

echo ""
echo -e "${BLUE}📚 Additional Resources${NC}"
echo "1. PostgreSQL Docker Hub: https://hub.docker.com/_/postgres"
echo "2. Check our docs/troubleshooting.md for more solutions"
echo "3. PostgreSQL logs: docker-compose logs postgres"

echo ""
echo -e "${GREEN}✨ Troubleshooting complete!${NC}"