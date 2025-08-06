# Esport Coach Connect

A comprehensive platform connecting esports players with professional coaches for 1-on-1 sessions.

## Architecture Overview

- **Frontend**: React SPA + React Native mobile app
- **Backend**: Microservices architecture (Node.js/NestJS)
- **Database**: PostgreSQL (primary), Redis (cache), Elasticsearch (search)
- **Message Queue**: NATS
- **Video**: WebRTC SFU (Janus)
- **Orchestration**: Kubernetes
- **Infrastructure**: Terraform (cloud-agnostic)
- **Monitoring**: Prometheus, Grafana, Loki, Jaeger

## Services

1. **Auth Service** - OIDC/OAuth2 authentication
2. **User Service** - User profiles and management
3. **Coach Service** - Coach profiles and availability
4. **Session Service** - Booking and scheduling
5. **Video Service** - WebRTC SFU control
6. **Messaging Service** - Chat and notifications
7. **Payment Service** - Payments and billing
8. **Ratings Service** - Reviews and ratings
9. **Search Service** - Coach discovery and filtering

## Quick Start

### **Cross-Platform Support** 🌐
Choose your operating system:

#### **Linux/Mac** 🐧🍎
```bash
# Setup everything
./scripts/setup-local-dev.sh

# Start development
./scripts/start-dev.sh

# Test everything  
./scripts/smoke-tests.sh
```

#### **Windows** 🪟
```batch
# Command Prompt
scripts\setup-local-dev.bat
scripts\start-dev.bat
scripts\smoke-tests.bat

# PowerShell (Recommended)
.\scripts\setup-local-dev.ps1
.\scripts\start-dev.ps1  
.\scripts\smoke-tests.ps1
```

### **Local Development**
```bash
# Start local development environment
cd local-dev
docker-compose up -d

# Access services
# - Frontend: http://localhost:3000
# - API Gateway: http://localhost:8080
# - Grafana: http://localhost:3001
```

### **Production Deployment**
```bash
# Deploy to Kubernetes
cd kubernetes
kubectl apply -k overlays/production
```

## Documentation

See `docs/` directory for detailed documentation:
- [Architecture](docs/architecture.md)
- [API Documentation](docs/api.md)
- [Deployment Guide](docs/deployment.md)
- [Development Setup](docs/development.md)

## SLOs

- **Availability**: ≥99.9% monthly
- **API Latency**: p95 <200ms
- **Video Join**: p95 <500ms
- **Payment Success**: ≥99.5%