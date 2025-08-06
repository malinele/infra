#!/bin/bash

# Enhanced development startup script
# This script starts all services in the correct order for development

set -e

echo "🚀 Starting Esport Coach Connect - Development Environment"
echo "========================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Create network if it doesn't exist
echo -e "${BLUE}📡 Creating Docker network...${NC}"
docker network create esport-coach-network 2>/dev/null || echo -e "${YELLOW}Network already exists${NC}"

# Stop any existing containers
echo -e "${BLUE}🛑 Stopping existing containers...${NC}"
docker-compose down 2>/dev/null || true

# Remove orphaned containers
echo -e "${BLUE}🧹 Cleaning up orphaned containers...${NC}"
docker-compose down --remove-orphans 2>/dev/null || true

# Pull latest images
echo -e "${BLUE}📥 Pulling latest base images...${NC}"
docker-compose pull postgres redis elasticsearch nats minio

# Build application images
echo -e "${BLUE}🔨 Building application services...${NC}"
docker-compose build --parallel

# Start infrastructure services first
echo -e "${BLUE}🏗️  Starting infrastructure services...${NC}"
docker-compose up -d postgres redis elasticsearch nats minio

# Wait for infrastructure to be healthy
echo -e "${YELLOW}⏳ Waiting for infrastructure services to be healthy...${NC}"
echo "This may take 30-60 seconds..."

# Function to check service health
check_service_health() {
    local service=$1
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose ps $service | grep -q "Up (healthy)"; then
            echo -e "${GREEN}✅ $service is healthy${NC}"
            return 0
        elif docker-compose ps $service | grep -q "Up"; then
            echo -n "."
            sleep 2
            attempt=$((attempt + 1))
        else
            echo -e "${RED}❌ $service failed to start${NC}"
            docker-compose logs $service
            return 1
        fi
    done
    
    echo -e "${RED}❌ $service health check timeout${NC}"
    return 1
}

# Check each infrastructure service
services=("postgres" "redis" "nats")
for service in "${services[@]}"; do
    echo -n "Checking $service health: "
    if check_service_health $service; then
        continue
    else
        echo -e "${RED}Failed to start $service${NC}"
        exit 1
    fi
done

# Check Elasticsearch (may take longer)
echo -n "Checking elasticsearch health: "
max_attempts=60
attempt=1
while [ $attempt -le $max_attempts ]; do
    if curl -s http://localhost:9200/_cluster/health | grep -q '"status":"green"'; then
        echo -e "${GREEN}✅ elasticsearch is healthy${NC}"
        break
    elif curl -s http://localhost:9200/_cluster/health | grep -q '"status":"yellow"'; then
        echo -e "${GREEN}✅ elasticsearch is healthy (yellow status is OK for development)${NC}"
        break
    else
        echo -n "."
        sleep 3
        attempt=$((attempt + 1))
    fi
    
    if [ $attempt -gt $max_attempts ]; then
        echo -e "${YELLOW}⚠️  elasticsearch may not be fully ready, but continuing...${NC}"
        break
    fi
done

# Check MinIO
echo -n "Checking minio health: "
if check_service_health minio; then
    continue
else
    echo -e "${YELLOW}⚠️  minio may not be fully ready, but continuing...${NC}"
fi

# Start application services
echo -e "${BLUE}🚀 Starting application services...${NC}"
docker-compose up -d

# Wait for application services
echo -e "${YELLOW}⏳ Waiting for application services to start...${NC}"
sleep 10

# Check application service health
echo -e "${BLUE}🏥 Checking application service health...${NC}"
app_services=("api-gateway" "auth-service" "user-service" "coach-service" "session-service" "video-service" "payment-service")

for service in "${app_services[@]}"; do
    container_name="esport-$service"
    if docker ps --format 'table {{.Names}}' | grep -q "$container_name"; then
        echo -e "${GREEN}✅ $service is running${NC}"
    else
        echo -e "${YELLOW}⚠️  $service may not be running${NC}"
    fi
done

# Display service URLs
echo -e "${GREEN}"
echo "🎉 Development environment is ready!"
echo "===================================="
echo -e "${NC}"

echo -e "${BLUE}📍 Service URLs:${NC}"
echo "  🌐 API Gateway:        http://localhost:8080"
echo "  🔐 Auth Service:       http://localhost:3001"
echo "  👤 User Service:       http://localhost:3002" 
echo "  🎮 Coach Service:      http://localhost:3003"
echo "  📅 Session Service:    http://localhost:3004"
echo "  📹 Video Service:      http://localhost:3005"
echo "  💬 Messaging Service:  http://localhost:3006"
echo "  💳 Payment Service:    http://localhost:3007"
echo "  ⭐ Ratings Service:    http://localhost:3008"
echo "  🔍 Search Service:     http://localhost:3009"
echo ""
echo -e "${BLUE}🗄️  Infrastructure Services:${NC}"
echo "  📊 PostgreSQL:        localhost:5432 (admin/admin123)"
echo "  🚀 Redis:             localhost:6379"
echo "  🔍 Elasticsearch:     http://localhost:9200"
echo "  💬 NATS:              localhost:4222 (Monitor: http://localhost:8222)"
echo "  📦 MinIO:             http://localhost:9000 (Console: http://localhost:9001, admin/admin123)"
echo ""
echo -e "${BLUE}🛠️  Development Commands:${NC}"
echo "  📊 Service status:     docker-compose ps"
echo "  📋 Service logs:       docker-compose logs -f [service-name]"
echo "  🔄 Restart service:    docker-compose restart [service-name]"
echo "  🛑 Stop all:           docker-compose down"
echo "  🧪 Run tests:          ./scripts/smoke-tests.sh"
echo ""

# Run smoke tests
echo -e "${BLUE}🧪 Running smoke tests...${NC}"
sleep 5  # Give services a moment to fully start
./scripts/smoke-tests.sh localhost:8080 http || echo -e "${YELLOW}⚠️  Some smoke tests failed - services may still be starting up${NC}"

echo ""
echo -e "${GREEN}✨ Development environment ready! Happy coding! 🚀${NC}"
echo ""
echo -e "${YELLOW}💡 Tip: Use 'docker-compose logs -f' to monitor all service logs${NC}"