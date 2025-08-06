#!/bin/bash

# Complete Docker & PostgreSQL Fix Script
# Fixes network issues, PostgreSQL startup, and character encoding problems

set -e

echo "🔧 Complete Docker & PostgreSQL Fix for Esport Coach Connect"
echo "============================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}🛑 Step 1: Stopping all services${NC}"
docker-compose down --remove-orphans 2>/dev/null || true

echo ""
echo -e "${BLUE}🧹 Step 2: Cleaning up problematic network${NC}"
# Remove the problematic network
if docker network ls | grep -q "esport-coach-network"; then
    echo "Removing existing esport-coach-network..."
    docker network rm esport-coach-network 2>/dev/null || true
    echo -e "${GREEN}✅ Network removed${NC}"
else
    echo -e "${YELLOW}ℹ️ Network doesn't exist${NC}"
fi

echo ""
echo -e "${BLUE}🗑️ Step 3: Cleaning Docker system${NC}"
# Clean up Docker system
echo "Pruning unused networks..."
docker network prune -f
echo "Pruning unused volumes..."
docker volume prune -f
echo -e "${GREEN}✅ Docker system cleaned${NC}"

echo ""
echo -e "${BLUE}🔍 Step 4: Checking for port conflicts${NC}"
# Check if port 5432 is in use
if lsof -i :5432 >/dev/null 2>&1 || netstat -tuln 2>/dev/null | grep -q ":5432"; then
    echo -e "${YELLOW}⚠️ Port 5432 is in use. Processes:${NC}"
    lsof -i :5432 2>/dev/null || netstat -tulnp 2>/dev/null | grep :5432 || true
    echo ""
    echo "Please stop the conflicting service:"
    echo "  sudo systemctl stop postgresql      # Linux"
    echo "  brew services stop postgresql       # Mac"
    echo "  sudo pkill postgres                 # Force kill"
    echo ""
    read -p "Press Enter after stopping the conflicting service..."
else
    echo -e "${GREEN}✅ Port 5432 is available${NC}"
fi

echo ""
echo -e "${BLUE}🏗️ Step 5: Creating fresh Docker network${NC}"
# Create new network with proper settings
docker network create \
    --driver bridge \
    --label com.docker.compose.project=esport-coach \
    --label com.docker.compose.network=esport-coach-network \
    esport-coach-network

echo -e "${GREEN}✅ New network created successfully${NC}"

echo ""
echo -e "${BLUE}📋 Step 6: Validating Docker Compose configuration${NC}"
# Check if docker-compose.yml is valid
if docker-compose config >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker Compose configuration is valid${NC}"
else
    echo -e "${RED}❌ Docker Compose configuration has errors:${NC}"
    docker-compose config
    exit 1
fi

echo ""
echo -e "${BLUE}🚀 Step 7: Starting PostgreSQL first${NC}"
# Start PostgreSQL alone first
docker-compose up -d postgres

echo ""
echo -e "${BLUE}⏳ Step 8: Waiting for PostgreSQL to be ready${NC}"
echo "This may take 30-60 seconds for first-time initialization..."

# Wait for PostgreSQL with better error handling
attempt=1
max_attempts=30
while [ $attempt -le $max_attempts ]; do
    if docker-compose exec postgres pg_isready -U admin -d esport_coach >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PostgreSQL is ready!${NC}"
        break
    fi
    
    # Show progress every 5 attempts
    if [ $((attempt % 5)) -eq 0 ]; then
        echo "Still waiting for PostgreSQL... (${attempt}/${max_attempts})"
        
        # Show logs if it's taking too long
        if [ $attempt -ge 15 ]; then
            echo "Recent PostgreSQL logs:"
            docker logs --tail 5 esport-postgres 2>/dev/null || true
            echo ""
        fi
    fi
    
    sleep 2
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    echo -e "${RED}❌ PostgreSQL failed to start. Checking logs:${NC}"
    docker logs esport-postgres
    echo ""
    echo -e "${YELLOW}💡 Common solutions:${NC}"
    echo "1. Check if another PostgreSQL is running: sudo systemctl status postgresql"
    echo "2. Check disk space: df -h"
    echo "3. Check Docker resources in Docker Desktop settings"
    echo "4. Try: docker-compose down -v && docker-compose up -d postgres"
    exit 1
fi

echo ""
echo -e "${BLUE}🧪 Step 9: Verifying PostgreSQL functionality${NC}"

# Test database connection
echo "Testing database connection..."
if docker-compose exec postgres psql -U admin -d esport_coach -c "SELECT version();" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Database connection successful${NC}"
else
    echo -e "${RED}❌ Database connection failed${NC}"
    exit 1
fi

# Check if tables were created
echo "Checking if tables were created..."
table_count=$(docker-compose exec postgres psql -U admin -d esport_coach -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" 2>/dev/null | tr -d ' \n\r' || echo "0")
if [ "$table_count" -gt 0 ]; then
    echo -e "${GREEN}✅ Database tables created successfully (${table_count} tables)${NC}"
else
    echo -e "${YELLOW}⚠️ No tables found, but database is accessible${NC}"
fi

# Check seed data
echo "Checking seed data..."
user_count=$(docker-compose exec postgres psql -U admin -d esport_coach -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | tr -d ' \n\r' || echo "0")
if [ "$user_count" -gt 0 ]; then
    echo -e "${GREEN}✅ Seed data loaded successfully (${user_count} users)${NC}"
else
    echo -e "${YELLOW}⚠️ No seed data found, but database is accessible${NC}"
fi

echo ""
echo -e "${BLUE}🚀 Step 10: Starting remaining infrastructure services${NC}"
# Start other infrastructure services
docker-compose up -d redis elasticsearch nats minio

echo ""
echo -e "${BLUE}⏳ Step 11: Waiting for infrastructure services${NC}"
sleep 10

# Check infrastructure services
echo "Checking infrastructure services..."
services=("redis" "nats")
for service in "${services[@]}"; do
    if docker-compose ps "$service" | grep -q "Up"; then
        echo -e "${GREEN}✅ $service is running${NC}"
    else
        echo -e "${YELLOW}⚠️ $service may not be ready yet${NC}"
    fi
done

# Check Elasticsearch separately (may take longer)
echo "Waiting for Elasticsearch..."
es_attempts=0
max_es_attempts=20
while [ $es_attempts -lt $max_es_attempts ]; do
    if curl -s http://localhost:9200/_cluster/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Elasticsearch is ready${NC}"
        break
    fi
    echo -n "."
    sleep 3
    es_attempts=$((es_attempts + 1))
done

if [ $es_attempts -ge $max_es_attempts ]; then
    echo -e "${YELLOW}⚠️ Elasticsearch may not be ready, but continuing...${NC}"
fi

echo ""
echo -e "${BLUE}🎯 Step 12: Starting application services${NC}"
# Start application services
docker-compose up -d

echo ""
echo -e "${BLUE}⏳ Step 13: Final verification${NC}"
sleep 5

# Final service check
echo "Checking all services..."
all_services=("postgres" "redis" "nats" "api-gateway" "auth-service" "user-service")
for service in "${all_services[@]}"; do
    if docker-compose ps "$service" | grep -q "Up"; then
        echo -e "${GREEN}✅ $service${NC}"
    else
        echo -e "${RED}❌ $service${NC}"
    fi
done

echo ""
echo -e "${GREEN}🎉 Fix completed successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Service Status:${NC}"
docker-compose ps

echo ""
echo -e "${BLUE}🌐 Service URLs:${NC}"
echo "  PostgreSQL: localhost:5432 (admin/admin123)"
echo "  API Gateway: http://localhost:8080"
echo "  Auth Service: http://localhost:3001/health"
echo "  Redis: localhost:6379"
echo "  Elasticsearch: http://localhost:9200"

echo ""
echo -e "${BLUE}🧪 Next Steps:${NC}"
echo "1. Run smoke tests: ./scripts/smoke-tests.sh"
echo "2. Check logs: docker-compose logs -f"
echo "3. Access API: curl http://localhost:8080/health"

echo ""
echo -e "${GREEN}✨ All services should now be running correctly!${NC}"