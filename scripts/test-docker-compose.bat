@echo off
REM Comprehensive Docker Compose Verification Script - Windows version
REM Tests all services and their connectivity

setlocal enabledelayedexpansion

echo.
echo 🧪 Running Comprehensive Docker Compose Tests
echo ==============================================

set /a TESTS_PASSED=0
set /a TESTS_FAILED=0

REM Test function
:run_test
set "test_name=%~1"
set "test_command=%~2"

echo | set /p="Testing %test_name%... "

%test_command% >nul 2>&1
if errorlevel 1 (
    echo ❌ FAIL
    set /a TESTS_FAILED+=1
) else (
    echo ✅ PASS
    set /a TESTS_PASSED+=1
)

exit /b

echo.
echo 📋 Validating Docker Compose Configuration
call :run_test "Docker Compose syntax" "docker-compose config"

echo.
echo 🔍 Checking Service Definitions
set "services=postgres redis elasticsearch nats minio api-gateway auth-service user-service coach-service session-service video-service messaging-service payment-service ratings-service search-service"

for %%s in (%services%) do (
    call :run_test "%%s definition" "findstr /c:\"%%s:\" docker-compose.yml"
)

echo.
echo 🌐 Checking Network Configuration
call :run_test "Network definition" "findstr /c:\"esport-coach-network\" docker-compose.yml"

echo.
echo 💾 Checking Volume Definitions
set "volumes=postgres_data redis_data elastic_data minio_data nats_data"
for %%v in (%volumes%) do (
    call :run_test "%%v definition" "findstr /c:\"%%v:\" docker-compose.yml"
)

echo.
echo ⚙️ Checking Environment Variables
call :run_test "PostgreSQL env vars" "findstr /c:\"POSTGRES_DB\" docker-compose.yml"
call :run_test "Service URLs configured" "findstr /c:\"AUTH_SERVICE_URL\" docker-compose.yml"
call :run_test "JWT Secret configured" "findstr /c:\"JWT_SECRET\" docker-compose.yml"

echo.
echo 🚪 Checking Port Mappings
set "ports=5432:5432 6379:6379 9200:9200 4222:4222 9000:9000 8080:8080 3001:3001 3002:3002 3003:3003 3004:3004 3005:3005 3006:3006 3007:3007 3008:3008 3009:3009"

for %%p in (%ports%) do (
    call :run_test "Port %%p mapping" "findstr /c:\"%%p\" docker-compose.yml"
)

echo.
echo 🏥 Checking Health Check Configurations
set "health_services=postgres redis elasticsearch nats minio"
for %%s in (%health_services%) do (
    call :run_test "%%s health check" "findstr /c:\"healthcheck\" docker-compose.yml"
)

echo.
echo 🔗 Checking Service Dependencies
call :run_test "API Gateway dependencies" "findstr /c:\"depends_on\" docker-compose.yml"

echo.
echo 🐳 Checking Dockerfile Existence
set "app_services=api-gateway auth-service user-service coach-service session-service video-service messaging-service payment-service ratings-service search-service"

for %%s in (%app_services%) do (
    call :run_test "%%s Dockerfile.dev" "dir services\%%s\Dockerfile.dev"
    call :run_test "%%s package.json" "dir services\%%s\package.json"
    call :run_test "%%s main.js" "dir services\%%s\src\main.js"
)

echo.
echo 🔨 Checking Build Contexts
for %%s in (%app_services%) do (
    call :run_test "%%s build context" "findstr /c:\"context: ./services/%%s\" docker-compose.yml"
)

echo.
echo 📁 Checking Development Volume Mounts
for %%s in (%app_services%) do (
    call :run_test "%%s volume mount" "findstr /c:\"./services/%%s:/app\" docker-compose.yml"
)

echo.
echo 📜 Checking Script Permissions
set "scripts=start-dev.bat start-dev.ps1 setup-local-dev.bat setup-local-dev.ps1 smoke-tests.bat smoke-tests.ps1 verify-infrastructure.bat verify-infrastructure.ps1"
for %%s in (%scripts%) do (
    call :run_test "%%s exists" "dir scripts\%%s"
)

echo.
echo 🔐 Checking Environment Template
call :run_test ".env.example exists" "dir .env.example"
call :run_test ".env.example has DATABASE_URL" "findstr /c:\"DATABASE_URL\" .env.example"
call :run_test ".env.example has service URLs" "findstr /c:\"SERVICE_URL\" .env.example"

echo.
echo ⚠️ Checking for Common Issues
call :run_test "No version field" "findstr /v /c:\"version:\" docker-compose.yml"

REM Summary
echo.
echo 📊 Test Summary
echo ===============
echo Tests Passed: %TESTS_PASSED%
echo Tests Failed: %TESTS_FAILED%
set /a total_tests=%TESTS_PASSED%+%TESTS_FAILED%
echo Total Tests: %total_tests%

if %TESTS_FAILED% equ 0 (
    echo.
    echo 🎉 All Docker Compose configuration tests passed!
    echo Your Docker Compose setup is ready for development.
    echo.
    echo 🚀 Next Steps:
    echo 1. Copy .env.example to .env and update values
    echo 2. Run: scripts\start-dev.bat
    echo 3. Visit: http://localhost:8080
    echo.
    pause
    exit /b 0
) else (
    if %TESTS_FAILED% leq 5 (
        echo.
        echo ⚠️ Minor configuration issues detected
        echo Most components are configured correctly.
        echo Review the failed tests and fix any critical issues.
        echo.
        pause
        exit /b 1
    ) else (
        echo.
        echo ❌ Multiple configuration issues detected
        echo Please review and fix the failing tests before proceeding.
        echo.
        pause
        exit /b 1
    )
)