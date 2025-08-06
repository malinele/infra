# Infrastructure verification script for Windows PowerShell
# Verifies all components without requiring Docker/Kubernetes

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
Write-ColorOutput Cyan "🔍 Verifying Esport Coach Connect Infrastructure"
Write-ColorOutput Cyan "=============================================="

$ChecksPassed = 0
$ChecksFailed = 0

# Test function
function Invoke-Check {
    param(
        [string]$CheckName,
        [scriptblock]$CheckCommand
    )
    
    Write-Host "Checking $CheckName... " -NoNewline
    
    try {
        $result = & $CheckCommand
        if ($result -or $LASTEXITCODE -eq 0) {
            Write-ColorOutput Green "✅ PASS"
            $script:ChecksPassed++
            return $true
        } else {
            Write-ColorOutput Red "❌ FAIL"
            $script:ChecksFailed++
            return $false
        }
    } catch {
        Write-ColorOutput Red "❌ FAIL"
        $script:ChecksFailed++
        return $false
    }
}

Write-Host ""
Write-ColorOutput Cyan "📁 Checking project structure..."
Invoke-Check "Root directory" { Test-Path "." }
Invoke-Check "Services directory" { Test-Path "services" }
Invoke-Check "Infrastructure directory" { Test-Path "infrastructure" }
Invoke-Check "Kubernetes manifests" { Test-Path "kubernetes" }
Invoke-Check "Documentation" { Test-Path "docs" }
Invoke-Check "Scripts directory" { Test-Path "scripts" }

Write-Host ""
Write-ColorOutput Cyan "🛠️ Checking service implementations..."
$services = @("api-gateway", "auth-service", "user-service", "coach-service", "session-service", 
              "payment-service", "messaging-service", "ratings-service", "search-service", "video-service")

foreach ($service in $services) {
    Invoke-Check "$service package.json" { Test-Path "services\$service\package.json" }
    Invoke-Check "$service main file" { Test-Path "services\$service\src\main.js" }
    Invoke-Check "$service Dockerfile" { Test-Path "services\$service\Dockerfile.dev" }
}

Write-Host ""
Write-ColorOutput Cyan "🏗️ Checking Terraform infrastructure..."
Invoke-Check "Main Terraform config" { Test-Path "infrastructure\main.tf" }
Invoke-Check "Network module" { Test-Path "infrastructure\modules\network\main.tf" }
Invoke-Check "Kubernetes module" { Test-Path "infrastructure\modules\kubernetes\main.tf" }
Invoke-Check "Dev environment config" { Test-Path "infrastructure\environments\dev\terraform.tfvars" }
Invoke-Check "Prod environment config" { Test-Path "infrastructure\environments\prod\terraform.tfvars" }

Write-Host ""
Write-ColorOutput Cyan "☸️ Checking Kubernetes manifests..."
Invoke-Check "Base kustomization" { Test-Path "kubernetes\base\kustomization.yaml" }
Invoke-Check "Namespace definition" { Test-Path "kubernetes\base\namespace.yaml" }
Invoke-Check "ConfigMaps" { Test-Path "kubernetes\base\configmap.yaml" }
Invoke-Check "PostgreSQL deployment" { Test-Path "kubernetes\base\database\postgres.yaml" }
Invoke-Check "Redis deployment" { Test-Path "kubernetes\base\database\redis.yaml" }

Write-Host ""
Write-ColorOutput Cyan "📄 Checking documentation..."
Invoke-Check "Architecture docs" { Test-Path "docs\architecture.md" }
Invoke-Check "Development guide" { Test-Path "docs\development.md" }
Invoke-Check "Main README" { Test-Path "README.md" }

Write-Host ""
Write-ColorOutput Cyan "📦 Checking package configurations..."
$servicesWithDeps = @("api-gateway", "auth-service", "user-service", "coach-service", "session-service", "payment-service")
foreach ($service in $servicesWithDeps) {
    if (Test-Path "services\$service\package.json") {
        Invoke-Check "$service dependencies" { 
            $content = Get-Content "services\$service\package.json" -Raw
            $content -like "*express*"
        }
        Invoke-Check "$service scripts" { 
            $content = Get-Content "services\$service\package.json" -Raw
            $content -like "*dev*"
        }
    }
}

Write-Host ""
Write-ColorOutput Cyan "🔧 Checking configuration files..."
Invoke-Check "Docker Compose" { Test-Path "docker-compose.yml" }
Invoke-Check "DB init script" { Test-Path "scripts\init-db.sql" }
Invoke-Check "GitIgnore" { Test-Path ".gitignore" }
Invoke-Check "Environment example" { Test-Path ".env.example" }

Write-Host ""
Write-ColorOutput Cyan "🧪 Testing script files..."
$scripts = @("start-dev.bat", "start-dev.ps1", "smoke-tests.bat", "smoke-tests.ps1", 
             "verify-infrastructure.bat", "verify-infrastructure.ps1")
foreach ($script in $scripts) {
    Invoke-Check "$script exists" { Test-Path "scripts\$script" }
}

Write-Host ""
Write-ColorOutput Cyan "✅ Validating configuration syntax..."

# Check JSON files
$jsonFiles = Get-ChildItem -Recurse -Filter "*.json" -Exclude "node_modules" | Where-Object { $_.FullName -notlike "*node_modules*" }
foreach ($jsonFile in $jsonFiles) {
    $filename = $jsonFile.Name
    Invoke-Check "JSON: $filename" {
        try {
            $content = Get-Content $jsonFile.FullName -Raw
            $json = ConvertFrom-Json $content
            $true
        } catch {
            $false
        }
    }
}

# Check YAML files (basic syntax check)
$yamlFiles = Get-ChildItem -Recurse -Include "*.yaml", "*.yml" | Where-Object { $_.FullName -notlike "*node_modules*" }
foreach ($yamlFile in $yamlFiles) {
    $filename = $yamlFile.Name
    Invoke-Check "YAML: $filename" {
        try {
            $content = Get-Content $yamlFile.FullName -Raw
            # Basic YAML syntax check - look for tabs (not allowed in YAML)
            if ($content -match "`t") {
                $false
            } else {
                $true
            }
        } catch {
            $false
        }
    }
}

Write-Host ""
Write-ColorOutput Cyan "📦 Checking installed dependencies..."
$servicesWithNodeModules = @()
foreach ($service in $services) {
    if (Test-Path "services\$service\node_modules") {
        $servicesWithNodeModules += $service
        Invoke-Check "$service node_modules" { Test-Path "services\$service\node_modules" }
    }
}

if ($servicesWithNodeModules.Count -gt 0) {
    Write-ColorOutput Green "✅ Found installed dependencies for: $($servicesWithNodeModules -join ', ')"
} else {
    Write-ColorOutput Yellow "ℹ️ No installed dependencies found (normal for fresh setup)"
}

# Summary
Write-Host ""
Write-ColorOutput Cyan "📊 Verification Summary"
Write-ColorOutput Cyan "====================="
Write-ColorOutput Green "Checks Passed: $ChecksPassed"
Write-ColorOutput Red "Checks Failed: $ChecksFailed"
Write-Host "Total Checks: $($ChecksPassed + $ChecksFailed)"

if ($ChecksFailed -eq 0) {
    Write-Host ""
    Write-ColorOutput Green "🎉 All infrastructure checks passed!"
    Write-Host "The Esport Coach Connect platform infrastructure is properly set up."
    Write-Host ""
    Write-ColorOutput Cyan "🚀 Next steps:"
    Write-Host "  1. Install Docker Desktop"
    Write-Host "  2. Run: .\scripts\start-dev.ps1"
    Write-Host "  3. Access services at http://localhost:8080"
    exit 0
} elseif ($ChecksFailed -lt 5) {
    Write-Host ""
    Write-ColorOutput Yellow "⚠️ Minor issues detected."
    Write-Host "Infrastructure is mostly complete but some components may need attention."
    exit 0
} else {
    Write-Host ""
    Write-ColorOutput Red "❌ Multiple verification failures."
    Write-Host "Please review the failed checks and fix the issues."
    exit 1
}

Read-Host "Press Enter to continue"