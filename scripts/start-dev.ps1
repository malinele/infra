# Enhanced development startup script for Windows PowerShell
# This script starts all services in the correct order for development

# Enable strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
Write-ColorOutput Yellow "🚀 Starting Esport Coach Connect - Development Environment"
Write-ColorOutput Yellow "========================================================="

# Check if Docker is running
try {
    docker info | Out-Null
    Write-ColorOutput Green "✅ Docker is running"
} catch {
    Write-ColorOutput Red "❌ Docker is not running. Please start Docker Desktop first."
    Read-Host "Press Enter to exit"
    exit 1
}

# Create network if it doesn't exist
Write-Host ""
Write-ColorOutput Cyan "📡 Creating Docker network..."
try {
    docker network create esport-coach-network 2>$null | Out-Null
    Write-ColorOutput Green "✅ Network created successfully"
} catch {
    Write-ColorOutput Yellow "⚠️ Network already exists"
}

# Stop any existing containers
Write-Host ""
Write-ColorOutput Cyan "🛑 Stopping existing containers..."
docker-compose down 2>$null | Out-Null

# Remove orphaned containers
Write-Host ""
Write-ColorOutput Cyan "🧹 Cleaning up orphaned containers..."
docker-compose down --remove-orphans 2>$null | Out-Null

# Pull latest images
Write-Host ""
Write-ColorOutput Cyan "📥 Pulling latest base images..."
docker-compose pull postgres redis elasticsearch nats minio

# Build application images
Write-Host ""
Write-ColorOutput Cyan "🔨 Building application services..."
docker-compose build --parallel

# Start infrastructure services first
Write-Host ""
Write-ColorOutput Cyan "🏗️ Starting infrastructure services..."
docker-compose up -d postgres redis elasticsearch nats minio

# Wait for infrastructure to be healthy
Write-Host ""
Write-ColorOutput Yellow "⏳ Waiting for infrastructure services to be healthy..."
Write-Host "This may take 30-60 seconds..."

# Function to check service health
function Wait-ForServiceHealth {
    param($ServiceName, $MaxAttempts = 30)
    
    $attempt = 1
    while ($attempt -le $MaxAttempts) {
        $status = docker-compose ps $ServiceName | Select-String "Up \(healthy\)"
        if ($status) {
            Write-ColorOutput Green "✅ $ServiceName is healthy"
            return $true
        }
        
        Write-Host "Checking $ServiceName health... attempt $attempt/$MaxAttempts" -ForegroundColor Gray
        Start-Sleep -Seconds 2
        $attempt++
    }
    
    Write-ColorOutput Red "❌ $ServiceName health check timeout"
    return $false
}

# Check each infrastructure service
$services = @("postgres", "redis", "nats")
foreach ($service in $services) {
    if (-not (Wait-ForServiceHealth $service)) {
        Write-ColorOutput Red "Failed to start $service"
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# Check Elasticsearch (may take longer)
Write-Host "Checking Elasticsearch health (this may take up to 2 minutes)..." -ForegroundColor Yellow
$attempt = 1
$maxAttempts = 60
$esHealthy = $false

while ($attempt -le $maxAttempts) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9200/_cluster/health" -UseBasicParsing -TimeoutSec 5
        if ($response.Content -like "*green*" -or $response.Content -like "*yellow*") {
            Write-ColorOutput Green "✅ Elasticsearch is healthy"
            $esHealthy = $true
            break
        }
    } catch {
        # Connection failed, continue trying
    }
    
    Write-Host "Checking Elasticsearch... attempt $attempt/$maxAttempts" -ForegroundColor Gray
    Start-Sleep -Seconds 3
    $attempt++
}

if (-not $esHealthy) {
    Write-ColorOutput Yellow "⚠️ Elasticsearch may not be fully ready, but continuing..."
}

# Check MinIO
if (Wait-ForServiceHealth "minio") {
    # Success
} else {
    Write-ColorOutput Yellow "⚠️ MinIO may not be fully ready, but continuing..."
}

# Start application services
Write-Host ""
Write-ColorOutput Cyan "🚀 Starting application services..."
docker-compose up -d

# Wait for application services
Write-Host ""
Write-ColorOutput Yellow "⏳ Waiting for application services to start..."
Start-Sleep -Seconds 10

# Check application service health
Write-Host ""
Write-ColorOutput Cyan "🏥 Checking application service health..."
$appServices = @("api-gateway", "auth-service", "user-service", "coach-service", "session-service", "video-service", "payment-service")

foreach ($service in $appServices) {
    $containerName = "esport-$service"
    $running = docker ps --format "table {{.Names}}" | Select-String $containerName
    if ($running) {
        Write-ColorOutput Green "✅ $service is running"
    } else {
        Write-ColorOutput Yellow "⚠️ $service may not be running"
    }
}

# Display service URLs
Write-Host ""
Write-ColorOutput Green "🎉 Development environment is ready!"
Write-ColorOutput Green "===================================="
Write-Host ""

Write-ColorOutput Cyan "📍 Service URLs:"
Write-Host "  🌐 API Gateway:        http://localhost:8080"
Write-Host "  🔐 Auth Service:       http://localhost:3001"
Write-Host "  👤 User Service:       http://localhost:3002"
Write-Host "  🎮 Coach Service:      http://localhost:3003"
Write-Host "  📅 Session Service:    http://localhost:3004"
Write-Host "  📹 Video Service:      http://localhost:3005"
Write-Host "  💬 Messaging Service:  http://localhost:3006"
Write-Host "  💳 Payment Service:    http://localhost:3007"
Write-Host "  ⭐ Ratings Service:    http://localhost:3008"
Write-Host "  🔍 Search Service:     http://localhost:3009"
Write-Host ""

Write-ColorOutput Cyan "🗄️ Infrastructure Services:"
Write-Host "  📊 PostgreSQL:        localhost:5432 (admin/admin123)"
Write-Host "  🚀 Redis:             localhost:6379"
Write-Host "  🔍 Elasticsearch:     http://localhost:9200"
Write-Host "  💬 NATS:              localhost:4222 (Monitor: http://localhost:8222)"
Write-Host "  📦 MinIO:             http://localhost:9000 (Console: http://localhost:9001, admin/admin123)"
Write-Host ""

Write-ColorOutput Cyan "🛠️ Development Commands:"
Write-Host "  📊 Service status:     docker-compose ps"
Write-Host "  📋 Service logs:       docker-compose logs -f [service-name]"
Write-Host "  🔄 Restart service:    docker-compose restart [service-name]"
Write-Host "  🛑 Stop all:           docker-compose down"
Write-Host "  🧪 Run tests:          .\scripts\smoke-tests.ps1"
Write-Host ""

# Run smoke tests
Write-ColorOutput Cyan "🧪 Running smoke tests..."
Start-Sleep -Seconds 5
try {
    & ".\scripts\smoke-tests.ps1" "localhost:8080" "http"
} catch {
    Write-ColorOutput Yellow "⚠️ Smoke tests had some issues - services may still be starting up"
}

Write-Host ""
Write-ColorOutput Green "✨ Development environment ready! Happy coding! 🚀"
Write-Host ""
Write-ColorOutput Yellow "💡 Tip: Use 'docker-compose logs -f' to monitor all service logs"

Read-Host "Press Enter to continue"