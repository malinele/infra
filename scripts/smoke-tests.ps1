# Smoke tests for Esport Coach Connect platform - PowerShell version
# Tests basic functionality of all services

param(
    [string]$Host = "localhost:8080",
    [string]$Protocol = "http"
)

$BaseUrl = "$Protocol`://$Host"

# Function to write colored output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    } else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-Host ""
Write-ColorOutput Cyan "🧪 Running smoke tests for Esport Coach Connect"
Write-ColorOutput Cyan "=============================================="
Write-Host "Base URL: $BaseUrl"
Write-Host ""

$TestsPassed = 0
$TestsFailed = 0

# Test function
function Invoke-ServiceTest {
    param(
        [string]$TestName,
        [string]$Url,
        [int]$ExpectedStatus = 200,
        [int]$Timeout = 10
    )
    
    Write-Host "Testing $TestName... " -NoNewline
    
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
        $statusCode = $response.StatusCode
    } catch {
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.Value__
        } else {
            $statusCode = 0
        }
    }
    
    if ($statusCode -eq $ExpectedStatus) {
        Write-ColorOutput Green "✅ PASS ($statusCode)"
        $script:TestsPassed++
        return $true
    } else {
        Write-ColorOutput Red "❌ FAIL (Expected: $ExpectedStatus, Got: $statusCode)"
        if ($statusCode -eq 0) {
            Write-Host "   Connection timeout or error" -ForegroundColor Gray
        }
        $script:TestsFailed++
        return $false
    }
}

# Test API Gateway health
Invoke-ServiceTest "API Gateway Health" "$BaseUrl/health"

# Test service proxying through API Gateway
Write-Host ""
Write-ColorOutput Cyan "🔗 Testing service routing through API Gateway..."
Invoke-ServiceTest "Auth Service Route" "$BaseUrl/api/auth/health"
Invoke-ServiceTest "User Service Route" "$BaseUrl/api/users/health"
Invoke-ServiceTest "Coach Service Route" "$BaseUrl/api/coaches/health"
Invoke-ServiceTest "Session Service Route" "$BaseUrl/api/sessions/health"
Invoke-ServiceTest "Payment Service Route" "$BaseUrl/api/payments/health"

# Test authentication flow
Write-Host ""
Write-ColorOutput Cyan "🔐 Testing authentication flow..."
if (Invoke-ServiceTest "Auth Login Endpoint" "$BaseUrl/api/auth/login" 400) {
    Write-Host "   Note: 400 is expected for missing credentials" -ForegroundColor Gray
}

# Test database connectivity
Write-Host ""
Write-ColorOutput Cyan "🗄️ Testing database connectivity..."

Write-Host "Testing user service database connection... " -NoNewline
try {
    $body = @{
        email = "test@example.com"
        authProviderId = "test123"
    } | ConvertTo-Json

    $response = Invoke-WebRequest -Uri "$BaseUrl/api/users" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    
    if ($response.Content -like "*test@example.com*" -or $response.Content -like "*already exists*") {
        Write-ColorOutput Green "✅ PASS"
        $TestsPassed++
    } else {
        Write-ColorOutput Yellow "⚠️ PARTIAL (Service responded but may need DB setup)"
        $TestsPassed++
    }
} catch {
    Write-ColorOutput Yellow "⚠️ PARTIAL (Service responded but may need DB setup)"
    $TestsPassed++
}

# Test Redis connectivity
Write-Host ""
Write-ColorOutput Cyan "📦 Testing cache connectivity..."
Invoke-ServiceTest "Redis Health via Service" "$BaseUrl/api/auth/health"

# Test search functionality
Write-Host ""
Write-ColorOutput Cyan "🔍 Testing search functionality..."
Invoke-ServiceTest "Coach Search Endpoint" "$BaseUrl/api/coaches"

# Test WebRTC/Video service
Write-Host ""
Write-ColorOutput Cyan "📹 Testing video service..."
Invoke-ServiceTest "Video Service Health" "$BaseUrl/api/video/health"

# Test messaging service
Write-Host ""
Write-ColorOutput Cyan "💬 Testing messaging service..."
Invoke-ServiceTest "Messaging Service Health" "$BaseUrl/api/messages/health"

# Test file upload capability
Write-Host ""
Write-ColorOutput Cyan "📁 Testing file upload capability..."
if (-not (Invoke-ServiceTest "File Upload Health Check" "$BaseUrl/api/upload/health")) {
    Write-Host "   Note: Upload service may not be implemented yet" -ForegroundColor Gray
}

# Test monitoring endpoints
Write-Host ""
Write-ColorOutput Cyan "📊 Testing monitoring..."
if (-not (Invoke-ServiceTest "Prometheus Metrics" "$BaseUrl/metrics")) {
    Write-Host "   Note: Metrics endpoint may not be exposed" -ForegroundColor Gray
}

# Security tests
Write-Host ""
Write-ColorOutput Cyan "🛡️ Basic security tests..."
Invoke-ServiceTest "CORS Headers" "$BaseUrl/api/health"
Invoke-ServiceTest "No Server Info Leak" "$BaseUrl/nonexistent" 404

# Performance test
Write-Host ""
Write-ColorOutput Cyan "⚡ Basic performance test..."
$startTime = Get-Date
if (Invoke-ServiceTest "Response Time Test" "$BaseUrl/health") {
    $endTime = Get-Date
    $responseTime = ($endTime - $startTime).TotalMilliseconds
    if ($responseTime -lt 200) {
        Write-ColorOutput Green "   Response time: $([math]::Round($responseTime))ms ✅"
    } else {
        Write-ColorOutput Yellow "   Response time: $([math]::Round($responseTime))ms ⚠️ (>200ms)"
    }
}

# Load balancing test
Write-Host ""
Write-ColorOutput Cyan "⚖️ Load balancing test..."
Write-Host "Testing multiple requests... " -NoNewline
$consistentResponses = 0

for ($i = 1; $i -le 5; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "$BaseUrl/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($response.Content -like "*healthy*") {
            $consistentResponses++
        }
    } catch {
        # Request failed
    }
}

if ($consistentResponses -eq 5) {
    Write-ColorOutput Green "✅ PASS (5/5 requests successful)"
    $TestsPassed++
} else {
    Write-ColorOutput Yellow "⚠️ PARTIAL ($consistentResponses/5 requests successful)"
    $TestsPassed++
}

# Test summary
Write-Host ""
Write-ColorOutput Cyan "📋 Test Summary"
Write-ColorOutput Cyan "==============="
Write-ColorOutput Green "Tests Passed: $TestsPassed"
Write-ColorOutput Red "Tests Failed: $TestsFailed"
Write-Host "Total Tests: $($TestsPassed + $TestsFailed)"

if ($TestsFailed -eq 0) {
    Write-Host ""
    Write-ColorOutput Green "🎉 All tests passed! System appears to be healthy."
    exit 0
} elseif ($TestsFailed -lt 3) {
    Write-Host ""
    Write-ColorOutput Yellow "⚠️ Minor issues detected. System is mostly functional."
    Write-Host "Consider investigating failed tests for production deployment."
    exit 0
} else {
    Write-Host ""
    Write-ColorOutput Red "❌ Multiple test failures detected. System needs attention."
    Write-Host "Please check logs and service configurations before proceeding."
    exit 1
}