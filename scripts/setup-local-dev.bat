@echo off
REM Setup script for local development environment - Windows version
REM This script sets up the complete Esport Coach Connect platform locally

setlocal enabledelayedexpansion

echo.
echo 🚀 Setting up Esport Coach Connect - Local Development Environment
echo ==================================================================

echo.
echo 📋 Checking prerequisites...

REM Check Docker Desktop
docker --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker is not installed. Please install Docker Desktop first.
    echo    Download from: https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
) else (
    echo ✅ Docker is installed
)

REM Check Docker Compose
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker Compose is not available. Please ensure Docker Desktop is properly installed.
    pause
    exit /b 1
) else (
    echo ✅ Docker Compose is available
)

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker is not running. Please start Docker Desktop first.
    pause
    exit /b 1
) else (
    echo ✅ Docker is running
)

REM Create kind cluster for local Kubernetes (optional)
echo.
echo 🔧 Setting up local development environment...

REM Create network if it doesn't exist
echo.
echo 📡 Creating Docker network...
docker network create esport-coach-network >nul 2>&1
if errorlevel 1 (
    echo ℹ️ Network already exists or creation failed
) else (
    echo ✅ Network created successfully
)

REM Stop any existing containers
echo.
echo 🛑 Stopping existing containers...
docker-compose down >nul 2>&1

REM Remove orphaned containers
echo.
echo 🧹 Cleaning up orphaned containers...
docker-compose down --remove-orphans >nul 2>&1

REM Pull latest images
echo.
echo 📥 Pulling latest base images...
docker-compose pull postgres redis elasticsearch nats minio

REM Start infrastructure services
echo.
echo 🐳 Starting infrastructure services...
docker-compose up -d postgres redis elasticsearch nats minio

REM Wait for services to be ready
echo.
echo ⏳ Waiting for infrastructure services to be healthy...
echo This may take 60-120 seconds...

REM Simple wait loop for services to start
set /a count=0
set /a max_count=30

:wait_loop
timeout /t 2 >nul
set /a count+=1

docker-compose ps postgres | find "Up (healthy)" >nul
if errorlevel 1 (
    if %count% lss %max_count% (
        echo Still waiting for PostgreSQL... (%count%/30)
        goto wait_loop
    ) else (
        echo ⚠️ PostgreSQL may not be fully ready, but continuing...
    )
) else (
    echo ✅ PostgreSQL is ready
)

REM Check other services
echo.
echo 🏥 Checking infrastructure service health...

set "services=redis nats"
for %%s in (%services%) do (
    docker-compose ps %%s | find "Up" >nul
    if errorlevel 1 (
        echo ⚠️ %%s might not be ready yet
    ) else (
        echo ✅ %%s is running
    )
)

REM Check Elasticsearch separately (may take longer)
echo Checking Elasticsearch...
set /a es_count=0
set /a es_max=60

:check_elasticsearch
curl -s http://localhost:9200/_cluster/health >nul 2>&1
if errorlevel 1 (
    set /a es_count+=1
    if !es_count! lss %es_max% (
        if !es_count! == 10 (
            echo Still waiting for Elasticsearch... this can take 1-2 minutes
        )
        timeout /t 3 >nul
        goto check_elasticsearch
    ) else (
        echo ⚠️ Elasticsearch may not be fully ready, but continuing...
    )
) else (
    echo ✅ Elasticsearch is ready
)

REM Start application services
echo.
echo ☸️ Starting application services...
docker-compose up -d

REM Wait for application services
echo.
echo ⏳ Waiting for application services to start...
timeout /t 10 >nul

REM Display access information
echo.
echo 🎉 Setup complete! Here's how to access your services:
echo ==================================================
echo.
echo Local Services:
echo   📊 PostgreSQL:        localhost:5432 (admin/admin123)
echo   🚀 Redis:             localhost:6379
echo   🔍 Elasticsearch:     http://localhost:9200
echo   💬 NATS Monitoring:   http://localhost:8222
echo   📦 MinIO Console:     http://localhost:9001 (admin/admin123)
echo.
echo Application Services:
echo   🚪 API Gateway:       http://localhost:8080/api
echo   🔐 Auth Service:      http://localhost:3001/health
echo   👤 User Service:      http://localhost:3002/health
echo   🎮 Coach Service:     http://localhost:3003/health
echo   📅 Session Service:   http://localhost:3004/health
echo   📹 Video Service:     http://localhost:3005/health
echo   💬 Messaging Service: http://localhost:3006/health
echo   💳 Payment Service:   http://localhost:3007/health
echo   ⭐ Ratings Service:   http://localhost:3008/health
echo   🔍 Search Service:    http://localhost:3009/health
echo.
echo Useful Commands:
echo   🔍 Check service status:    docker-compose ps
echo   📊 View logs:               docker-compose logs -f [service]
echo   🔄 Restart service:         docker-compose restart [service]
echo   🛑 Stop all:                docker-compose down
echo   🧪 Run tests:               scripts\smoke-tests.bat
echo.
echo 🛠️ Development:
echo   • Services are available for local development
echo   • Modify code in services\ directory
echo   • Use 'docker-compose restart [service]' to reload changes
echo.
echo 📚 Documentation: See docs\ directory for detailed guides
echo.
echo Happy coding! 🚀

REM Run quick verification
echo.
echo 🧪 Running quick verification...
timeout /t 5 >nul
call scripts\smoke-tests.bat localhost:8080 http

pause
exit /b 0