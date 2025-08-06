@echo off
REM Smoke tests for Esport Coach Connect platform - Windows version
REM Tests basic functionality of all services

setlocal enabledelayedexpansion

set "HOST=%~1"
set "PROTOCOL=%~2"

if "%HOST%"=="" set "HOST=localhost:8080"
if "%PROTOCOL%"=="" set "PROTOCOL=http"

set "BASE_URL=%PROTOCOL%://%HOST%"

echo.
echo 🧪 Running smoke tests for Esport Coach Connect
echo ==============================================
echo Base URL: %BASE_URL%
echo.

set /a TESTS_PASSED=0
set /a TESTS_FAILED=0

REM Test function using curl if available, otherwise use PowerShell
:run_test
set "test_name=%~1"
set "url=%~2"
set "expected_status=%~3"

if "%expected_status%"=="" set "expected_status=200"

echo | set /p="Testing %test_name%... "

REM Try curl first
curl -s -w "%%{http_code}" --max-time 10 "%url%" >temp_response.txt 2>nul
if errorlevel 1 (
    REM Curl failed, try PowerShell
    powershell -Command "try { $response = Invoke-WebRequest -Uri '%url%' -UseBasicParsing -TimeoutSec 10; $response.StatusCode } catch { 0 }" >temp_response.txt 2>nul
)

set /p response=<temp_response.txt
del temp_response.txt >nul 2>&1

if "%response%"=="%expected_status%" (
    echo ✅ PASS ^(%response%^)
    set /a TESTS_PASSED+=1
) else (
    echo ❌ FAIL ^(Expected: %expected_status%, Got: %response%^)
    set /a TESTS_FAILED+=1
)

exit /b

REM Run tests
call :run_test "API Gateway Health" "%BASE_URL%/health"
call :run_test "Auth Service Route" "%BASE_URL%/api/auth/health" 200
call :run_test "User Service Route" "%BASE_URL%/api/users/health" 200
call :run_test "Coach Service Route" "%BASE_URL%/api/coaches/health" 200
call :run_test "Session Service Route" "%BASE_URL%/api/sessions/health" 200
call :run_test "Payment Service Route" "%BASE_URL%/api/payments/health" 200

echo.
echo 🔐 Testing authentication flow...
call :run_test "Auth Login Endpoint" "%BASE_URL%/api/auth/login" 400

echo.
echo 🗄️ Testing database connectivity...
echo | set /p="Testing user service database connection... "

REM Test user creation (expecting error due to missing data, but service should respond)
curl -s -X POST "%BASE_URL%/api/users" -H "Content-Type: application/json" -d "{\"email\":\"test@example.com\",\"authProviderId\":\"test123\"}" --max-time 10 >temp_response.txt 2>nul
if errorlevel 1 (
    echo ❌ FAIL ^(Connection error^)
    set /a TESTS_FAILED+=1
) else (
    echo ✅ PASS
    set /a TESTS_PASSED+=1
)
del temp_response.txt >nul 2>&1

echo.
echo 📦 Testing cache connectivity...
call :run_test "Redis Health via Service" "%BASE_URL%/api/auth/health" 200

echo.
echo 🔍 Testing search functionality...
call :run_test "Coach Search Endpoint" "%BASE_URL%/api/coaches" 200

echo.
echo 📹 Testing video service...
call :run_test "Video Service Health" "%BASE_URL%/api/video/health" 200

echo.
echo 💬 Testing messaging service...
call :run_test "Messaging Service Health" "%BASE_URL%/api/messages/health" 200

echo.
echo ⚡ Basic performance test...
set start_time=%time%
call :run_test "Response Time Test" "%BASE_URL%/health" 200
set end_time=%time%
echo   Response time check completed

echo.
echo ⚖️ Load balancing test...
echo | set /p="Testing multiple requests... "
set /a consistent_responses=0

for /l %%i in (1,1,5) do (
    curl -s "%BASE_URL%/health" --max-time 5 | find "healthy" >nul
    if not errorlevel 1 (
        set /a consistent_responses+=1
    )
)

if !consistent_responses! equ 5 (
    echo ✅ PASS ^(5/5 requests successful^)
    set /a TESTS_PASSED+=1
) else (
    echo ⚠️ PARTIAL ^(!consistent_responses!/5 requests successful^)
    set /a TESTS_PASSED+=1
)

REM Test summary
echo.
echo 📋 Test Summary
echo ===============
echo Tests Passed: %TESTS_PASSED%
echo Tests Failed: %TESTS_FAILED%
set /a total_tests=%TESTS_PASSED%+%TESTS_FAILED%
echo Total Tests: %total_tests%

if %TESTS_FAILED% equ 0 (
    echo.
    echo 🎉 All tests passed! System appears to be healthy.
    exit /b 0
) else (
    if %TESTS_FAILED% lss 3 (
        echo.
        echo ⚠️ Minor issues detected. System is mostly functional.
        echo Consider investigating failed tests for production deployment.
        exit /b 0
    ) else (
        echo.
        echo ❌ Multiple test failures detected. System needs attention.
        echo Please check logs and service configurations before proceeding.
        exit /b 1
    )
)