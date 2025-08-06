# Setup script for local development environment - PowerShell version
# This script sets up the complete Esport Coach Connect platform locally

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
Write-ColorOutput Yellow "🚀 Setting up Esport Coach Connect - Local Development Environment"
Write-ColorOutput Yellow "=================================================================="

Write-Host ""
Write-ColorOutput Cyan "📋 Checking prerequisites..."

# Check Docker Desktop
try {
    $dockerVersion = docker --version
    Write-ColorOutput Green "✅ Docker is installed: $dockerVersion"
} catch {
    Write-ColorOutput Red "❌ Docker is not installed. Please install Docker Desktop first."
    Write-Host "   Download from: https://www.docker.com/products/docker-desktop/"
    Read-Host "Press Enter to exit"
    exit 1
}

# Check Docker Compose
try {
    $composeVersion = docker-compose --version
    Write-ColorOutput Green "✅ Docker Compose is available: $composeVersion"
} catch {
    Write-ColorOutput Red "❌ Docker Compose is not available. Please ensure Docker Desktop is properly installed."
    Read-Host "Press Enter to exit"
    exit 1
}

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
    Write-ColorOutput Yellow "ℹ️ Network already exists"
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

# Start infrastructure services
Write-Host ""
Write-ColorOutput Cyan "🐳 Starting infrastructure services..."
docker-compose up -d postgres redis elasticsearch nats minio

# Wait for services to be ready
Write-Host ""
Write-ColorOutput Yellow "⏳ Waiting for infrastructure services to be healthy..."
Write-Host "This may take 60-120 seconds..."

# Function to wait for service health
function Wait-ForServiceHealth {
    param($ServiceName, $MaxWaitMinutes = 2)
    
    $maxAttempts = $MaxWaitMinutes * 30  # 2 seconds per attempt
    $attempt = 1
    
    while ($attempt -le $maxAttempts) {
        $status = docker-compose ps $ServiceName | Select-String "Up \(healthy\)"
        if ($status) {
            Write-ColorOutput Green "✅ $ServiceName is ready"
            return $true
        }
        
        if (($attempt % 15) -eq 0) {
            Write-Host "Still waiting for $ServiceName... ($([math]::Round($attempt/30, 1)) minutes)" -ForegroundColor Gray
        }
        
        Start-Sleep -Seconds 2
        $attempt++
    }
    
    Write-ColorOutput Yellow "⚠️ $ServiceName may not be fully ready, but continuing..."
    return $false
}

# Check each infrastructure service
Wait-ForServiceHealth "postgres"

$services = @("redis", "nats")
foreach ($service in $services) {
    $status = docker-compose ps $service | Select-String "Up"
    if ($status) {
        Write-ColorOutput Green "✅ $service is running"
    } else {
        Write-ColorOutput Yellow "⚠️ $service might not be ready yet"
    }
}

# Check Elasticsearch separately (may take longer)
Write-Host "Checking Elasticsearch..." -ForegroundColor Yellow
$attempt = 1
$maxAttempts = 60

while ($attempt -le $maxAttempts) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9200/_cluster/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-ColorOutput Green "✅ Elasticsearch is ready"
        break
    } catch {
        if ($attempt -eq 20) {
            Write-Host "Still waiting for Elasticsearch... this can take 1-2 minutes" -ForegroundColor Gray
        }
        Start-Sleep -Seconds 3
        $attempt++
    }
    
    if ($attempt -gt $maxAttempts) {
        Write-ColorOutput Yellow "⚠️ Elasticsearch may not be fully ready, but continuing..."
    }
}

# Start application services
Write-Host ""
Write-ColorOutput Cyan "☸️ Starting application services..."
docker-compose up -d

# Wait for application services
Write-Host ""
Write-ColorOutput Yellow "⏳ Waiting for application services to start..."
Start-Sleep -Seconds 10

# Display access information
Write-Host ""
Write-ColorOutput Green "🎉 Setup complete! Here's how to access your services:"
Write-ColorOutput Green "=================================================="
Write-Host ""

Write-ColorOutput Cyan "Local Services:"
Write-Host "  📊 PostgreSQL:        localhost:5432 (admin/admin123)"
Write-Host "  🚀 Redis:             localhost:6379"
Write-Host "  🔍 Elasticsearch:     http://localhost:9200"
Write-Host "  💬 NATS Monitoring:   http://localhost:8222"
Write-Host "  📦 MinIO Console:     http://localhost:9001 (admin/admin123)"
Write-Host ""

Write-ColorOutput Cyan "Application Services:"
Write-Host "  🚪 API Gateway:       http://localhost:8080/api"
Write-Host "  🔐 Auth Service:      http://localhost:3001/health"
Write-Host "  👤 User Service:      http://localhost:3002/health"
Write-Host "  🎮 Coach Service:     http://localhost:3003/health"
Write-Host "  📅 Session Service:   http://localhost:3004/health"
Write-Host "  📹 Video Service:     http://localhost:3005/health"
Write-Host "  💬 Messaging Service: http://localhost:3006/health"
Write-Host "  💳 Payment Service:   http://localhost:3007/health"
Write-Host "  ⭐ Ratings Service:   http://localhost:3008/health"
Write-Host "  🔍 Search Service:    http://localhost:3009/health"
Write-Host ""

Write-ColorOutput Cyan "Useful Commands:"
Write-Host "  🔍 Check service status:    docker-compose ps"
Write-Host "  📊 View logs:               docker-compose logs -f [service]"
Write-Host "  🔄 Restart service:         docker-compose restart [service]"
Write-Host "  🛑 Stop all:                docker-compose down"
Write-Host "  🧪 Run tests:               .\scripts\smoke-tests.ps1"
Write-Host ""

Write-ColorOutput Cyan "🛠️ Development:"
Write-Host "  • Services are available for local development"
Write-Host "  • Modify code in services\ directory"
Write-Host "  • Use 'docker-compose restart [service]' to reload changes"
Write-Host ""

Write-Host "📚 Documentation: See docs\ directory for detailed guides"
Write-Host ""
Write-ColorOutput Green "Happy coding! 🚀"

# Run quick verification
Write-Host ""
Write-ColorOutput Cyan "🧪 Running quick verification..."
Start-Sleep -Seconds 5
try {
    & ".\scripts\smoke-tests.ps1" "localhost:8080" "http"
} catch {
    Write-ColorOutput Yellow "⚠️ Verification had some issues - services may still be starting up"
}

Read-Host "Press Enter to continue"