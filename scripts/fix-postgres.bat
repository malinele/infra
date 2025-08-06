@echo off
REM PostgreSQL Troubleshooting Script for Windows
REM This script helps diagnose and fix PostgreSQL startup issues

setlocal enabledelayedexpansion

echo.
echo 🔧 PostgreSQL Troubleshooting for Esport Coach Connect
echo =====================================================

echo.
echo 📋 Checking PostgreSQL Status

REM Check if container exists
docker ps -a --format "table {{.Names}}" | find "esport-postgres" >nul
if errorlevel 1 (
    echo ❌ PostgreSQL container does not exist
    goto :create_container
) else (
    echo ✅ PostgreSQL container exists
)

REM Check if it's running
docker ps --format "table {{.Names}}" | find "esport-postgres" >nul
if errorlevel 1 (
    echo ❌ PostgreSQL container is not running
) else (
    echo ✅ PostgreSQL container is running
)

REM Show health status
for /f "tokens=*" %%i in ('docker inspect esport-postgres --format="{{.State.Health.Status}}" 2^>nul') do set health_status=%%i
if defined health_status (
    echo Health Status: %health_status%
) else (
    echo Health Status: no-health-check
)

echo.
echo 📋 PostgreSQL Container Logs
echo Last 20 lines of PostgreSQL logs:
echo ==================================
docker logs --tail 20 esport-postgres 2>nul || echo No logs available

echo.
echo 🔍 Common Issues Diagnosis

REM Check if port 5432 is in use
netstat -an | find ":5432" >nul
if not errorlevel 1 (
    echo ⚠️ Port 5432 is in use by another process
    echo Processes using port 5432:
    netstat -ano | find ":5432"
    echo.
    echo 💡 Solution:
    echo 1. Stop the conflicting PostgreSQL service:
    echo    net stop postgresql-x64-14 ^(or similar^)
    echo 2. Or change the port in docker-compose.yml to 5433:5432
) else (
    echo ✅ Port 5432 is available
)

REM Check Docker daemon
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker daemon is not running
    echo 💡 Solution: Start Docker Desktop
    pause
    exit /b 1
) else (
    echo ✅ Docker daemon is running
)

echo.
echo 🛠️ Troubleshooting Steps
echo 1. Clean up and restart PostgreSQL:
echo    docker-compose stop postgres
echo    docker-compose rm -f postgres
echo    docker-compose up -d postgres
echo.
echo 2. Check logs in real-time:
echo    docker-compose logs -f postgres
echo.
echo 3. Connect to PostgreSQL ^(once running^):
echo    docker exec -it esport-postgres psql -U admin -d esport_coach
echo.
echo 4. Reset everything if needed:
echo    docker-compose down -v
echo    docker-compose up -d
echo.

REM Automated fix attempt
echo 🔧 Attempting Automated Fix
echo Would you like to try an automated fix? ^(y/N^)
set /p response=
if /i "%response%"=="y" goto :fix_attempt
if /i "%response%"=="yes" goto :fix_attempt
goto :manual_fix

:fix_attempt
echo.
echo 🔄 Stopping and cleaning PostgreSQL...

REM Stop the service
docker-compose stop postgres >nul 2>&1

REM Remove container
docker-compose rm -f postgres >nul 2>&1

REM Ask about removing volume
echo ⚠️ This will delete all PostgreSQL data. Continue? ^(y/N^)
set /p confirm=
if /i not "%confirm%"=="y" goto :manual_fix
if /i not "%confirm%"=="yes" goto :manual_fix

REM Remove volume
for /f "tokens=*" %%i in ('docker volume ls -q ^| find "postgres_data"') do (
    docker volume rm %%i >nul 2>&1
)

echo 🚀 Starting fresh PostgreSQL...
docker-compose up -d postgres

echo ⏳ Waiting for PostgreSQL to be ready...
timeout /t 15 >nul

REM Check if it's working
docker-compose exec postgres pg_isready -U admin -d esport_coach >nul 2>&1
if errorlevel 1 (
    echo ❌ PostgreSQL is still not responding. Please check logs:
    echo docker-compose logs postgres
    goto :end
)

echo 🎉 PostgreSQL is now running successfully!
echo.
echo ✅ Connection Details:
echo Host: localhost
echo Port: 5432
echo Database: esport_coach
echo Username: admin
echo Password: admin123
goto :end

:create_container
echo 💡 Creating PostgreSQL container...
docker-compose up -d postgres
timeout /t 10 >nul
goto :end

:manual_fix
echo ⚠️ Manual fix required. Please follow the steps above.

:end
echo.
echo 📚 Additional Resources
echo 1. PostgreSQL Docker Hub: https://hub.docker.com/_/postgres
echo 2. Check our docs\troubleshooting.md for more solutions
echo 3. PostgreSQL logs: docker-compose logs postgres
echo.
echo ✨ Troubleshooting complete!
pause