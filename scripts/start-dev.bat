@echo off
REM Enhanced development startup script for Windows
REM This script starts all services in the correct order for development

setlocal enabledelayedexpansion

echo.
echo 🚀 Starting Esport Coach Connect - Development Environment
echo ==========================================================

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker is not running. Please start Docker Desktop first.
    pause
    exit /b 1
)

REM Create network if it doesn't exist
echo.
echo 📡 Creating Docker network...
docker network create esport-coach-network >nul 2>&1
if errorlevel 1 (
    echo ⚠️  Network already exists or creation failed
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

REM Build application images
echo.
echo 🔨 Building application services...
docker-compose build --parallel

REM Start infrastructure services first
echo.
echo 🏗️  Starting infrastructure services...
docker-compose up -d postgres redis elasticsearch nats minio

REM Wait for infrastructure to be healthy
echo.
echo ⏳ Waiting for infrastructure services to be healthy...
echo This may take 30-60 seconds...

REM Function to check service health (simplified for Windows)
set /a attempt=1
set /a max_attempts=30

:check_postgres
docker-compose ps postgres | find "Up (healthy)" >nul
if errorlevel 1 (
    if !attempt! lss %max_attempts% (
        echo Checking PostgreSQL health... attempt !attempt!/30
        timeout /t 2 >nul
        set /a attempt+=1
        goto check_postgres
    ) else (
        echo ❌ PostgreSQL health check timeout
        goto error_exit
    )
) else (
    echo ✅ PostgreSQL is healthy
)

REM Reset attempt counter for Redis
set /a attempt=1

:check_redis
docker-compose ps redis | find "Up (healthy)" >nul
if errorlevel 1 (
    if !attempt! lss %max_attempts% (
        echo Checking Redis health... attempt !attempt!/30
        timeout /t 2 >nul
        set /a attempt+=1
        goto check_redis
    ) else (
        echo ❌ Redis health check timeout
        goto error_exit
    )
) else (
    echo ✅ Redis is healthy
)

REM Reset attempt counter for NATS
set /a attempt=1

:check_nats
docker-compose ps nats | find "Up (healthy)" >nul
if errorlevel 1 (
    if !attempt! lss %max_attempts% (
        echo Checking NATS health... attempt !attempt!/30
        timeout /t 2 >nul
        set /a attempt+=1
        goto check_nats
    ) else (
        echo ❌ NATS health check timeout
        goto error_exit
    )
) else (
    echo ✅ NATS is healthy
)

REM Check Elasticsearch (may take longer)
echo Checking Elasticsearch health (this may take up to 2 minutes)...
set /a attempt=1
set /a max_attempts=60

:check_elasticsearch
curl -s http://localhost:9200/_cluster/health | find "green" >nul
if errorlevel 1 (
    curl -s http://localhost:9200/_cluster/health | find "yellow" >nul
    if errorlevel 1 (
        if !attempt! lss %max_attempts% (
            echo Checking Elasticsearch... attempt !attempt!/60
            timeout /t 3 >nul
            set /a attempt+=1
            goto check_elasticsearch
        ) else (
            echo ⚠️  Elasticsearch may not be fully ready, but continuing...
        )
    ) else (
        echo ✅ Elasticsearch is healthy (yellow status is OK for development)
    )
) else (
    echo ✅ Elasticsearch is healthy
)

REM Start application services
echo.
echo 🚀 Starting application services...
docker-compose up -d

REM Wait for application services
echo.
echo ⏳ Waiting for application services to start...
timeout /t 10 >nul

REM Check application service health
echo.
echo 🏥 Checking application service health...

set "services=api-gateway auth-service user-service coach-service session-service video-service payment-service"

for %%s in (%services%) do (
    docker ps --format "table {{.Names}}" | find "esport-%%s" >nul
    if errorlevel 1 (
        echo ⚠️  %%s may not be running
    ) else (
        echo ✅ %%s is running
    )
)

REM Display service URLs
echo.
echo 🎉 Development environment is ready!
echo ====================================
echo.
echo 📍 Service URLs:
echo   🌐 API Gateway:        http://localhost:8080
echo   🔐 Auth Service:       http://localhost:3001
echo   👤 User Service:       http://localhost:3002
echo   🎮 Coach Service:      http://localhost:3003
echo   📅 Session Service:    http://localhost:3004
echo   📹 Video Service:      http://localhost:3005
echo   💬 Messaging Service:  http://localhost:3006
echo   💳 Payment Service:    http://localhost:3007
echo   ⭐ Ratings Service:    http://localhost:3008
echo   🔍 Search Service:     http://localhost:3009
echo.
echo 🗄️  Infrastructure Services:
echo   📊 PostgreSQL:        localhost:5432 (admin/admin123)
echo   🚀 Redis:             localhost:6379
echo   🔍 Elasticsearch:     http://localhost:9200
echo   💬 NATS:              localhost:4222 (Monitor: http://localhost:8222)
echo   📦 MinIO:             http://localhost:9000 (Console: http://localhost:9001, admin/admin123)
echo.
echo 🛠️  Development Commands:
echo   📊 Service status:     docker-compose ps
echo   📋 Service logs:       docker-compose logs -f [service-name]
echo   🔄 Restart service:    docker-compose restart [service-name]
echo   🛑 Stop all:           docker-compose down
echo   🧪 Run tests:          scripts\smoke-tests.bat
echo.

REM Run smoke tests
echo 🧪 Running smoke tests...
timeout /t 5 >nul
call scripts\smoke-tests.bat localhost:8080 http

echo.
echo ✨ Development environment ready! Happy coding! 🚀
echo.
echo 💡 Tip: Use 'docker-compose logs -f' to monitor all service logs
pause
exit /b 0

:error_exit
echo.
echo ❌ Setup failed. Please check Docker Desktop and try again.
echo.
echo 🔧 Troubleshooting:
echo   1. Make sure Docker Desktop is running
echo   2. Check available disk space
echo   3. Restart Docker Desktop
echo   4. Run: docker-compose down -v
echo.
pause
exit /b 1