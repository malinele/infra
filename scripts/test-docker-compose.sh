#!/bin/bash

# Comprehensive Docker Compose Verification Script
# Tests all services and their connectivity

set -e

echo "🧪 Running Comprehensive Docker Compose Tests"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing $test_name... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Check if Docker Compose files are valid
echo -e "${BLUE}📋 Validating Docker Compose Configuration${NC}"
run_test "Main Docker Compose syntax" "docker-compose config > /dev/null"
run_test "Override file syntax" "docker-compose -f docker-compose.yml -f docker-compose.override.yml config > /dev/null"
run_test "Production file syntax" "docker-compose -f docker-compose.yml -f docker-compose.prod.yml config > /dev/null"

# Check service definitions
echo -e "${BLUE}🔍 Checking Service Definitions${NC}"
services=("postgres" "redis" "elasticsearch" "nats" "minio" "api-gateway" "auth-service" "user-service" "coach-service" "session-service" "video-service" "messaging-service" "payment-service" "ratings-service" "search-service")

for service in "${services[@]}"; do
    run_test "$service definition" "docker-compose config | grep -q '$service:'"
done

# Check network configuration
echo -e "${BLUE}🌐 Checking Network Configuration${NC}"
run_test "Network definition" "docker-compose config | grep -q 'esport-coach-network'"

# Check volume definitions
echo -e "${BLUE}💾 Checking Volume Definitions${NC}"
volumes=("postgres_data" "redis_data" "elastic_data" "minio_data" "nats_data")
for volume in "${volumes[@]}"; do
    run_test "$volume definition" "docker-compose config | grep -q '$volume:'"
done

# Check environment variables
echo -e "${BLUE}⚙️  Checking Environment Variables${NC}"
run_test "PostgreSQL env vars" "docker-compose config | grep -q 'POSTGRES_DB'"
run_test "Service URLs configured" "docker-compose config | grep -q 'AUTH_SERVICE_URL'"
run_test "JWT Secret configured" "docker-compose config | grep -q 'JWT_SECRET'"

# Check port mappings
echo -e "${BLUE}🚪 Checking Port Mappings${NC}"
ports=("5432:5432" "6379:6379" "9200:9200" "4222:4222" "9000:9000" "8080:8080" "3001:3001" "3002:3002" "3003:3003" "3004:3004" "3005:3005" "3006:3006" "3007:3007" "3008:3008" "3009:3009")

for port in "${ports[@]}"; do
    service_name=$(echo $port | cut -d':' -f2)
    run_test "Port $port mapping" "docker-compose config | grep -q '$port'"
done

# Check health check configurations
echo -e "${BLUE}🏥 Checking Health Check Configurations${NC}"
health_services=("postgres" "redis" "elasticsearch" "nats" "minio")
for service in "${health_services[@]}"; do
    run_test "$service health check" "docker-compose config | grep -A5 '$service:' | grep -q 'healthcheck'"
done

# Check dependencies
echo -e "${BLUE}🔗 Checking Service Dependencies${NC}"
run_test "API Gateway dependencies" "docker-compose config | grep -A10 'api-gateway:' | grep -q 'depends_on'"
run_test "Auth service dependencies" "docker-compose config | grep -A10 'auth-service:' | grep -q 'depends_on'"
run_test "User service dependencies" "docker-compose config | grep -A10 'user-service:' | grep -q 'depends_on'"

# Test Dockerfile existence
echo -e "${BLUE}🐳 Checking Dockerfile Existence${NC}"
app_services=("api-gateway" "auth-service" "user-service" "coach-service" "session-service" "video-service" "messaging-service" "payment-service" "ratings-service" "search-service")

for service in "${app_services[@]}"; do
    run_test "$service Dockerfile.dev" "test -f services/$service/Dockerfile.dev"
    run_test "$service package.json" "test -f services/$service/package.json"
    run_test "$service main.js" "test -f services/$service/src/main.js"
done

# Test build contexts
echo -e "${BLUE}🔨 Checking Build Contexts${NC}"
for service in "${app_services[@]}"; do
    run_test "$service build context" "docker-compose config | grep -A5 '$service:' | grep -q 'context: ./services/$service'"
done

# Check volume mounts for development
echo -e "${BLUE}📁 Checking Development Volume Mounts${NC}"
for service in "${app_services[@]}"; do
    run_test "$service volume mount" "docker-compose config | grep -A10 '$service:' | grep -q './services/$service:/app'"
done

# Test script permissions
echo -e "${BLUE}📜 Checking Script Permissions${NC}"
scripts=("start-dev.sh" "setup-local-dev.sh" "deploy-prod.sh" "smoke-tests.sh" "verify-infrastructure.sh")
for script in "${scripts[@]}"; do
    run_test "$script executable" "test -x scripts/$script"
done

# Validate JSON files
echo -e "${BLUE}📄 Validating JSON Configuration Files${NC}"
find services -name "package.json" | while read json_file; do
    service_name=$(echo $json_file | cut -d'/' -f2)
    run_test "$service_name package.json valid JSON" "python3 -m json.tool '$json_file' >/dev/null"
done

# Test environment template
echo -e "${BLUE}🔐 Checking Environment Template${NC}"
run_test ".env.example exists" "test -f .env.example"
run_test ".env.example has DATABASE_URL" "grep -q 'DATABASE_URL' .env.example"
run_test ".env.example has service URLs" "grep -q 'SERVICE_URL' .env.example"

# Check for common Docker Compose issues
echo -e "${BLUE}⚠️  Checking for Common Issues${NC}"
run_test "No port conflicts (8080)" "! docker-compose config | grep -c '8080:8080' | grep -q '[2-9]'"
run_test "All services use same network" "docker-compose config | grep -A50 networks: | grep -c esport-coach-network | grep -q '[0-9][0-9]'"
run_test "No duplicate container names" "docker-compose config | grep 'container_name:' | sort | uniq -d | wc -l | grep -q '^0$'"

# Test override file functionality
echo -e "${BLUE}🔄 Testing Override File Functionality${NC}"
run_test "Override file loads correctly" "docker-compose -f docker-compose.yml -f docker-compose.override.yml config > /dev/null"
run_test "Production override loads correctly" "docker-compose -f docker-compose.yml -f docker-compose.prod.yml config > /dev/null"

# Check resource constraints in production
echo -e "${BLUE}💻 Checking Production Resource Constraints${NC}"
run_test "Production memory limits" "docker-compose -f docker-compose.yml -f docker-compose.prod.yml config | grep -q 'memory:'"
run_test "Production CPU limits" "docker-compose -f docker-compose.yml -f docker-compose.prod.yml config | grep -q 'cpus:'"

# Advanced connectivity tests (if Docker is running)
if docker info > /dev/null 2>&1; then
    echo -e "${BLUE}🔌 Advanced Docker Tests${NC}"
    
    # Test network creation
    run_test "Docker network creation" "docker network create test-network-$$ 2>/dev/null && docker network rm test-network-$$"
    
    # Test image pulls (for base images)
    base_images=("postgres:15-alpine" "redis:7-alpine" "node:20-alpine")
    for image in "${base_images[@]}"; do
        run_test "$image pullable" "docker pull $image > /dev/null 2>&1"
    done
else
    echo -e "${YELLOW}⚠️  Docker not running - skipping advanced tests${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}📊 Test Summary${NC}"
echo "==============="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 All Docker Compose configuration tests passed!${NC}"
    echo "Your Docker Compose setup is ready for development."
    echo ""
    echo -e "${BLUE}🚀 Next Steps:${NC}"
    echo "1. Copy .env.example to .env and update values"
    echo "2. Run: ./scripts/start-dev.sh"
    echo "3. Visit: http://localhost:8080"
    echo ""
    exit 0
elif [ $TESTS_FAILED -le 5 ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Minor configuration issues detected${NC}"
    echo "Most components are configured correctly."
    echo "Review the failed tests and fix any critical issues."
    echo ""
    exit 1
else
    echo ""
    echo -e "${RED}❌ Multiple configuration issues detected${NC}"
    echo "Please review and fix the failing tests before proceeding."
    echo ""
    exit 1
fi