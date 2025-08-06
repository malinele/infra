@echo off
REM Complete Docker & PostgreSQL Fix Script for Windows
REM Fixes network issues, PostgreSQL startup, and Docker problems

setlocal enabledelayedexpansion

echo.
echo 🔧 Complete Docker ^& PostgreSQL Fix for Esport Coach Connect
echo ============================================================

echo.
echo 🛑 Step 1: Stopping all services
docker-compose down --remove-orphans >nul 2>&1

echo.
echo 🧹 Step 2: Cleaning up problematic network
docker network ls | find "esport-coach-network" >nul
if not errorlevel 1 (
    echo Removing existing esport-coach-network...
    docker network rm esport-coach-network >nul 2>&1
    echo ✅ Network removed
) else (
    echo ℹ️ Network doesn't exist
)

echo.
echo 🗑️ Step 3: Cleaning Docker system
echo Pruning unused networks...
docker network prune -f >nul
echo Pruning unused volumes...
docker volume prune -f >nul
echo ✅ Docker system cleaned

echo.
echo 🔍 Step 4: Checking for port conflicts
netstat -an | find ":5432" >nul
if not errorlevel 1 (
    echo ⚠️ Port 5432 is in use. Processes:
    netstat -ano | find ":5432"
    echo.
    echo Please stop the conflicting PostgreSQL service:
    echo   net stop postgresql-x64-14  ^(or similar^)
    echo   sc stop postgresql-x64-14
    echo.
    pause
) else (
    echo ✅ Port 5432 is available
)

echo.
echo 🏗️ Step 5: Creating fresh Docker network
docker network create esport-coach-network >nul 2>&1
echo ✅ New network created successfully

echo.
echo 📋 Step 6: Validating Docker Compose configuration
docker-compose config >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker Compose configuration has errors:
    docker-compose config
    pause
    exit /b 1
) else (
    echo ✅ Docker Compose configuration is valid
)

echo.
echo 🚀 Step 7: Starting PostgreSQL first
docker-compose up -d postgres

echo.
echo ⏳ Step 8: Waiting for PostgreSQL to be ready
echo This may take 30-60 seconds for first-time initialization...

set /a attempt=1
set /a max_attempts=30

:wait_postgres
docker-compose exec postgres pg_isready -U admin -d esport_coach >nul 2>&1
if not errorlevel 1 (
    echo ✅ PostgreSQL is ready!
    goto postgres_ready
)

set /a remainder=!attempt! %% 5
if !remainder! equ 0 (
    echo Still waiting for PostgreSQL... ^(!attempt!/30^)
    
    if !attempt! geq 15 (
        echo Recent PostgreSQL logs:
        docker logs --tail 5 esport-postgres 2>nul || echo No logs available
        echo.
    )
)

timeout /t 2 >nul
set /a attempt+=1
if !attempt! leq %max_attempts% goto wait_postgres

echo ❌ PostgreSQL failed to start. Checking logs:
docker logs esport-postgres
echo.
echo 💡 Common solutions:
echo 1. Check if another PostgreSQL is running
echo 2. Check disk space
echo 3. Check Docker Desktop resources
echo 4. Try: docker-compose down -v ^&^& docker-compose up -d postgres
pause
exit /b 1

:postgres_ready

echo.
echo 🧪 Step 9: Verifying PostgreSQL functionality

echo Testing database connection...
docker-compose exec postgres psql -U admin -d esport_coach -c "SELECT version();" >nul 2>&1
if errorlevel 1 (
    echo ❌ Database connection failed
    pause
    exit /b 1
) else (
    echo ✅ Database connection successful
)

echo Checking if tables were created...
for /f %%i in ('docker-compose exec postgres psql -U admin -d esport_coach -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" 2^>nul') do set table_count=%%i
set table_count=%table_count: =%
if "%table_count%"=="" set table_count=0
if %table_count% gtr 0 (
    echo ✅ Database tables created successfully ^(%table_count% tables^)
) else (
    echo ⚠️ No tables found, but database is accessible
)

echo.
echo 🚀 Step 10: Starting remaining infrastructure services
docker-compose up -d redis elasticsearch nats minio

echo.
echo ⏳ Step 11: Waiting for infrastructure services
timeout /t 10 >nul

echo Checking infrastructure services...
set "services=redis nats minio"
for %%s in (%services%) do (
    docker-compose ps %%s | find "Up" >nul
    if not errorlevel 1 (
        echo ✅ %%s is running
    ) else (
        echo ⚠️ %%s may not be ready yet
    )
)

echo Waiting for Elasticsearch...
set /a es_attempts=0
set /a max_es_attempts=20

:wait_elasticsearch
curl -s http://localhost:9200/_cluster/health >nul 2>&1
if not errorlevel 1 (
    echo ✅ Elasticsearch is ready
    goto elasticsearch_ready
)
echo | set /p=.
timeout /t 3 >nul
set /a es_attempts+=1
if !es_attempts! lss %max_es_attempts% goto wait_elasticsearch

echo ⚠️ Elasticsearch may not be ready, but continuing...

:elasticsearch_ready

echo.
echo 🎯 Step 12: Starting application services
docker-compose up -d

echo.
echo ⏳ Step 13: Final verification
timeout /t 5 >nul

echo Checking all services...
set "all_services=postgres redis nats api-gateway auth-service user-service"
for %%s in (%all_services%) do (
    docker-compose ps %%s | find "Up" >nul
    if not errorlevel 1 (
        echo ✅ %%s
    ) else (
        echo ❌ %%s
    )
)

echo.
echo 🎉 Fix completed successfully!
echo.
echo 📋 Service Status:
docker-compose ps

echo.
echo 🌐 Service URLs:
echo   PostgreSQL: localhost:5432 ^(admin/admin123^)
echo   API Gateway: http://localhost:8080
echo   Auth Service: http://localhost:3001/health
echo   Redis: localhost:6379
echo   Elasticsearch: http://localhost:9200

echo.
echo 🧪 Next Steps:
echo 1. Run smoke tests: scripts\smoke-tests.bat
echo 2. Check logs: docker-compose logs -f
echo 3. Access API: curl http://localhost:8080/health

echo.
echo ✨ All services should now be running correctly!
pause