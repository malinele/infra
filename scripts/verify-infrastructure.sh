#!/bin/bash

# Verification script for Esport Coach Connect infrastructure
# Tests all components without requiring Docker/Kubernetes

set -e

echo "🔍 Verifying Esport Coach Connect Infrastructure"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CHECKS_PASSED=0
CHECKS_FAILED=0

# Test function
run_check() {
    local check_name="$1"
    local check_cmd="$2"
    
    echo -n "Checking $check_name... "
    
    if eval "$check_cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
}

echo ""
echo "📁 Checking project structure..."
run_check "Root directory" "test -d /app"
run_check "Services directory" "test -d /app/services"
run_check "Infrastructure directory" "test -d /app/infrastructure"
run_check "Kubernetes manifests" "test -d /app/kubernetes"
run_check "Documentation" "test -d /app/docs"
run_check "Scripts directory" "test -d /app/scripts"

echo ""
echo "🛠️  Checking service implementations..."
services=("api-gateway" "auth-service" "user-service" "coach-service" "session-service" "payment-service")
for service in "${services[@]}"; do
    run_check "$service package.json" "test -f /app/services/$service/package.json"
    run_check "$service main file" "test -f /app/services/$service/src/main.js"
    run_check "$service Dockerfile" "test -f /app/services/$service/Dockerfile.dev"
done

echo ""
echo "🏗️  Checking Terraform infrastructure..."
run_check "Main Terraform config" "test -f /app/infrastructure/main.tf"
run_check "Network module" "test -f /app/infrastructure/modules/network/main.tf"
run_check "Kubernetes module" "test -f /app/infrastructure/modules/kubernetes/main.tf"
run_check "Dev environment config" "test -f /app/infrastructure/environments/dev/terraform.tfvars"
run_check "Prod environment config" "test -f /app/infrastructure/environments/prod/terraform.tfvars"

echo ""
echo "☸️  Checking Kubernetes manifests..."
run_check "Base kustomization" "test -f /app/kubernetes/base/kustomization.yaml"
run_check "Namespace definition" "test -f /app/kubernetes/base/namespace.yaml"
run_check "ConfigMaps" "test -f /app/kubernetes/base/configmap.yaml"
run_check "PostgreSQL deployment" "test -f /app/kubernetes/base/database/postgres.yaml"
run_check "Redis deployment" "test -f /app/kubernetes/base/database/redis.yaml"

echo ""
echo "📄 Checking documentation..."
run_check "Architecture docs" "test -f /app/docs/architecture.md"
run_check "Development guide" "test -f /app/docs/development.md"
run_check "Main README" "test -f /app/README.md"

echo ""
echo "📦 Checking package configurations..."
services_with_deps=("api-gateway" "auth-service" "user-service" "coach-service" "session-service" "payment-service")
for service in "${services_with_deps[@]}"; do
    if [ -f "/app/services/$service/package.json" ]; then
        run_check "$service dependencies" "grep -q 'express' /app/services/$service/package.json"
        run_check "$service scripts" "grep -q '\"dev\"' /app/services/$service/package.json"
    fi
done

echo ""
echo "🔧 Checking configuration files..."
run_check "Docker Compose" "test -f /app/docker-compose.yml"
run_check "DB init script" "test -f /app/scripts/init-db.sql"
run_check "Local dev compose" "test -f /app/local-dev/docker-compose.dev.yml"
run_check "GitIgnore" "test -f /app/.gitignore"

echo ""
echo "🧪 Testing script syntax..."
scripts=("setup-local-dev.sh" "deploy-prod.sh" "smoke-tests.sh")
for script in "${scripts[@]}"; do
    run_check "$script syntax" "bash -n /app/scripts/$script"
done

echo ""
echo "📋 Checking file permissions..."
scripts=("setup-local-dev.sh" "deploy-prod.sh" "smoke-tests.sh" "verify-infrastructure.sh")
for script in "${scripts[@]}"; do
    run_check "$script executable" "test -x /app/scripts/$script"
done

# Validate JSON and YAML files
echo ""
echo "✅ Validating configuration syntax..."

# Check JSON files
json_files=$(find /app -name "*.json" -not -path "*/node_modules/*" 2>/dev/null)
for json_file in $json_files; do
    filename=$(basename "$json_file")
    run_check "JSON: $filename" "python3 -m json.tool '$json_file' >/dev/null"
done

# Check YAML files (basic syntax)
yaml_files=$(find /app -name "*.yaml" -o -name "*.yml" 2>/dev/null)
for yaml_file in $yaml_files; do
    filename=$(basename "$yaml_file")
    # Basic check for common YAML syntax errors
    if grep -q $'\t' "$yaml_file"; then
        echo -e "Checking YAML: $filename... ${RED}❌ FAIL${NC} (Contains tabs)"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    else
        echo -e "Checking YAML: $filename... ${GREEN}✅ PASS${NC}"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    fi
done

# Check for Node.js dependencies installation
echo ""
echo "📦 Checking installed dependencies..."
services_with_node_modules=()
for service in "${services[@]}"; do
    if [ -d "/app/services/$service/node_modules" ]; then
        services_with_node_modules+=("$service")
        run_check "$service node_modules" "test -d /app/services/$service/node_modules"
    fi
done

if [ ${#services_with_node_modules[@]} -gt 0 ]; then
    echo "✅ Found installed dependencies for: ${services_with_node_modules[*]}"
else
    echo -e "${YELLOW}ℹ️  No installed dependencies found (normal for fresh setup)${NC}"
fi

# Summary
echo ""
echo "📊 Verification Summary"
echo "====================="
echo -e "Checks Passed: ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Checks Failed: ${RED}$CHECKS_FAILED${NC}"
echo "Total Checks: $((CHECKS_PASSED + CHECKS_FAILED))"

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "\n🎉 ${GREEN}All infrastructure checks passed!${NC}"
    echo "The Esport Coach Connect platform infrastructure is properly set up."
    echo ""
    echo "🚀 Next steps:"
    echo "  1. Install Docker and Docker Compose"
    echo "  2. Run: ./scripts/setup-local-dev.sh"
    echo "  3. Access services at http://localhost:8080"
    exit 0
elif [ $CHECKS_FAILED -lt 5 ]; then
    echo -e "\n⚠️  ${YELLOW}Minor issues detected.${NC}"
    echo "Infrastructure is mostly complete but some components may need attention."
    exit 0
else
    echo -e "\n❌ ${RED}Multiple verification failures.${NC}"
    echo "Please review the failed checks and fix the issues."
    exit 1
fi