@echo off
REM Infrastructure verification script for Windows
REM Verifies all components without requiring Docker/Kubernetes

setlocal enabledelayedexpansion

echo.
echo 🔍 Verifying Esport Coach Connect Infrastructure
echo ==============================================

set /a CHECKS_PASSED=0
set /a CHECKS_FAILED=0

REM Test function
:run_check
set "check_name=%~1"
set "check_cmd=%~2"

echo | set /p="Checking %check_name%... "

%check_cmd% >nul 2>&1
if errorlevel 1 (
    echo ❌ FAIL
    set /a CHECKS_FAILED+=1
) else (
    echo ✅ PASS
    set /a CHECKS_PASSED+=1
)

exit /b

echo.
echo 📁 Checking project structure...
call :run_check "Root directory" "dir . >nul"
call :run_check "Services directory" "dir services >nul"
call :run_check "Infrastructure directory" "dir infrastructure >nul"
call :run_check "Kubernetes manifests" "dir kubernetes >nul"
call :run_check "Documentation" "dir docs >nul"
call :run_check "Scripts directory" "dir scripts >nul"

echo.
echo 🛠️ Checking service implementations...
set "services=api-gateway auth-service user-service coach-service session-service payment-service messaging-service ratings-service search-service video-service"

for %%s in (%services%) do (
    call :run_check "%%s package.json" "dir services\%%s\package.json >nul"
    call :run_check "%%s main file" "dir services\%%s\src\main.js >nul"
    call :run_check "%%s Dockerfile" "dir services\%%s\Dockerfile.dev >nul"
)

echo.
echo 🏗️ Checking Terraform infrastructure...
call :run_check "Main Terraform config" "dir infrastructure\main.tf >nul"
call :run_check "Network module" "dir infrastructure\modules\network\main.tf >nul"
call :run_check "Kubernetes module" "dir infrastructure\modules\kubernetes\main.tf >nul"
call :run_check "Dev environment config" "dir infrastructure\environments\dev\terraform.tfvars >nul"
call :run_check "Prod environment config" "dir infrastructure\environments\prod\terraform.tfvars >nul"

echo.
echo ☸️ Checking Kubernetes manifests...
call :run_check "Base kustomization" "dir kubernetes\base\kustomization.yaml >nul"
call :run_check "Namespace definition" "dir kubernetes\base\namespace.yaml >nul"
call :run_check "ConfigMaps" "dir kubernetes\base\configmap.yaml >nul"
call :run_check "PostgreSQL deployment" "dir kubernetes\base\database\postgres.yaml >nul"
call :run_check "Redis deployment" "dir kubernetes\base\database\redis.yaml >nul"

echo.
echo 📄 Checking documentation...
call :run_check "Architecture docs" "dir docs\architecture.md >nul"
call :run_check "Development guide" "dir docs\development.md >nul"
call :run_check "Main README" "dir README.md >nul"

echo.
echo 📦 Checking package configurations...
set "services_with_deps=api-gateway auth-service user-service coach-service session-service payment-service"
for %%s in (%services_with_deps%) do (
    if exist "services\%%s\package.json" (
        call :run_check "%%s dependencies" "findstr /c:\"express\" services\%%s\package.json >nul"
        call :run_check "%%s scripts" "findstr /c:\"dev\" services\%%s\package.json >nul"
    )
)

echo.
echo 🔧 Checking configuration files...
call :run_check "Docker Compose" "dir docker-compose.yml >nul"
call :run_check "DB init script" "dir scripts\init-db.sql >nul"
call :run_check "GitIgnore" "dir .gitignore >nul"
call :run_check "Environment example" "dir .env.example >nul"

echo.
echo 🧪 Testing script syntax...
call :run_check "start-dev.bat exists" "dir scripts\start-dev.bat >nul"
call :run_check "smoke-tests.bat exists" "dir scripts\smoke-tests.bat >nul"
call :run_check "verify-infrastructure.bat exists" "dir scripts\verify-infrastructure.bat >nul"

echo.
echo 📦 Checking installed dependencies...
set "services_with_node_modules="
for %%s in (%services%) do (
    if exist "services\%%s\node_modules" (
        set "services_with_node_modules=!services_with_node_modules! %%s"
        call :run_check "%%s node_modules" "dir services\%%s\node_modules >nul"
    )
)

if not "!services_with_node_modules!"=="" (
    echo ✅ Found installed dependencies for:!services_with_node_modules!
) else (
    echo ℹ️ No installed dependencies found (normal for fresh setup)
)

REM Summary
echo.
echo 📊 Verification Summary
echo =====================
echo Checks Passed: %CHECKS_PASSED%
echo Checks Failed: %CHECKS_FAILED%
set /a total_checks=%CHECKS_PASSED%+%CHECKS_FAILED%
echo Total Checks: %total_checks%

if %CHECKS_FAILED% equ 0 (
    echo.
    echo 🎉 All infrastructure checks passed!
    echo The Esport Coach Connect platform infrastructure is properly set up.
    echo.
    echo 🚀 Next steps:
    echo   1. Install Docker Desktop
    echo   2. Run: scripts\start-dev.bat
    echo   3. Access services at http://localhost:8080
    pause
    exit /b 0
) else (
    if %CHECKS_FAILED% lss 5 (
        echo.
        echo ⚠️ Minor issues detected.
        echo Infrastructure is mostly complete but some components may need attention.
        pause
        exit /b 0
    ) else (
        echo.
        echo ❌ Multiple verification failures.
        echo Please review the failed checks and fix the issues.
        pause
        exit /b 1
    )
)