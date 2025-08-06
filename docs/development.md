# Development Guide - Esport Coach Connect

## Getting Started

This guide helps developers set up the Esport Coach Connect platform for local development, understand the codebase structure, and contribute effectively.

## Prerequisites

### Required Tools
- **Docker** (20.10+) and **Docker Compose** (2.0+)
- **Node.js** (18+ LTS) and **npm/yarn**
- **kubectl** (1.28+)
- **Kind** (for local Kubernetes)
- **Git** (2.30+)

### Optional Tools
- **Terraform** (1.5+) - for infrastructure management
- **Helm** (3.12+) - for Kubernetes package management
- **VSCode** with recommended extensions

### Recommended VSCode Extensions
```json
{
  "recommendations": [
    "ms-vscode.vscode-typescript-next",
    "ms-vscode.vscode-eslint",
    "ms-kubernetes-tools.vscode-kubernetes-tools",
    "hashicorp.terraform",
    "ms-vscode.docker",
    "bradlc.vscode-tailwindcss"
  ]
}
```

## Quick Setup

### 1. Clone and Setup
```bash
# Clone the repository
git clone <repository-url>
cd esport-coach-connect

# Make setup script executable
chmod +x scripts/setup-local-dev.sh

# Run setup (this will take 10-15 minutes)
./scripts/setup-local-dev.sh
```

### 2. Verify Installation
```bash
# Check Docker services
docker-compose ps

# Check Kubernetes pods
kubectl get pods -n esport-coach

# Test API Gateway
curl http://localhost:8080/health
```

## Project Structure

```
esport-coach-connect/
├── docs/                    # Documentation
├── infrastructure/          # Terraform IaC
│   ├── modules/            # Reusable Terraform modules
│   ├── environments/       # Environment-specific configs
│   └── main.tf            # Root Terraform config
├── kubernetes/             # Kubernetes manifests
│   ├── base/              # Base configurations
│   └── overlays/          # Environment-specific overlays
├── services/               # Microservices
│   ├── api-gateway/       # API Gateway service
│   ├── auth-service/      # Authentication service
│   ├── user-service/      # User management
│   ├── coach-service/     # Coach profiles & availability
│   ├── session-service/   # Booking & session management
│   ├── video-service/     # WebRTC video service
│   ├── messaging-service/ # Real-time messaging
│   ├── payment-service/   # Payment processing
│   ├── ratings-service/   # Reviews & ratings
│   └── search-service/    # Search & discovery
├── frontend/               # React web application
├── mobile/                # React Native mobile app
├── monitoring/            # Observability configurations
├── scripts/               # Utility scripts
├── local-dev/             # Local development configs
├── docker-compose.yml     # Local infrastructure services
└── README.md
```

## Development Workflow

### 1. Local Development Environment

#### Starting Services
```bash
# Start infrastructure services (PostgreSQL, Redis, etc.)
docker-compose up -d

# Start Kubernetes services (optional)
kubectl apply -k kubernetes/base/

# Develop specific service
cd services/auth-service
npm install
npm run dev
```

#### Environment Variables
Each service uses environment variables for configuration:

```bash
# services/auth-service/.env
NODE_ENV=development
DATABASE_URL=postgresql://admin:admin123@localhost:5432/esport_coach
REDIS_URL=redis://localhost:6379
JWT_SECRET=dev-secret-key
```

### 2. Service Development

#### Creating a New Service
```bash
# Use the service template
cp -r services/service-template services/new-service
cd services/new-service

# Update package.json
# Update Docker files
# Implement service logic
```

#### Service Structure
```
services/auth-service/
├── src/
│   ├── controllers/       # Request handlers
│   ├── services/         # Business logic
│   ├── models/          # Data models
│   ├── middleware/      # Express middleware
│   ├── routes/         # API routes
│   └── main.js        # Entry point
├── tests/
│   ├── unit/          # Unit tests
│   ├── integration/   # Integration tests
│   └── fixtures/     # Test data
├── package.json
├── Dockerfile
├── Dockerfile.dev
└── README.md
```

### 3. Database Development

#### Database Migrations
```bash
# Connect to local PostgreSQL
docker-compose exec postgres psql -U admin -d esport_coach

# Run migration scripts
psql -f scripts/migrations/001_initial_schema.sql
```

#### Schema Changes
1. Create migration file in `scripts/migrations/`
2. Test migration locally
3. Update seed data if needed
4. Update service models

### 4. API Development

#### API Standards
- **RESTful**: Use standard HTTP methods and status codes
- **JSON**: Accept and return JSON data
- **Versioning**: Use URL versioning (`/api/v1/`)
- **Error Handling**: Consistent error response format

```javascript
// Standard error response
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request data",
    "details": {
      "field": "email",
      "reason": "Invalid email format"
    }
  }
}
```

#### Authentication
```javascript
// Protected route example
app.get('/api/v1/profile', authenticateJWT, (req, res) => {
  // req.user contains decoded JWT payload
  res.json({ user: req.user });
});
```

### 5. Frontend Development

#### React Development
```bash
cd frontend/
npm install
npm start  # Starts on http://localhost:3000
```

#### Component Structure
```
frontend/src/
├── components/           # Reusable components
│   ├── common/          # Generic UI components
│   ├── forms/          # Form components
│   └── layout/         # Layout components
├── pages/              # Page components
├── hooks/              # Custom React hooks
├── services/           # API clients
├── store/             # State management
├── styles/            # CSS/Tailwind styles
└── utils/             # Utility functions
```

## Testing

### 1. Unit Tests
```bash
# Run tests for specific service
cd services/auth-service
npm test

# Run tests with coverage
npm run test:coverage

# Watch mode for development
npm run test:watch
```

### 2. Integration Tests
```bash
# Start test environment
docker-compose -f docker-compose.test.yml up -d

# Run integration tests
npm run test:integration
```

### 3. End-to-End Tests
```bash
# Start full environment
./scripts/setup-local-dev.sh

# Run E2E tests
cd tests/e2e
npm test
```

### 4. Load Testing
```bash
# Install k6
# Run load tests
k6 run tests/load/booking-flow.js
```

## Code Quality

### 1. Linting and Formatting
```bash
# ESLint for JavaScript/TypeScript
npm run lint
npm run lint:fix

# Prettier for code formatting
npm run format

# Pre-commit hooks
npx husky install
```

### 2. Code Review Checklist
- [ ] Tests written and passing
- [ ] Code follows style guidelines
- [ ] Security considerations addressed
- [ ] Performance implications considered
- [ ] Documentation updated
- [ ] Error handling implemented
- [ ] Logging added

## Debugging

### 1. Service Debugging
```bash
# View service logs
docker-compose logs -f auth-service

# Debug with Node.js inspector
npm run debug  # Service runs on debug port 9229

# Kubernetes debugging
kubectl logs -f deployment/auth-service -n esport-coach
kubectl exec -it deployment/auth-service -n esport-coach -- /bin/sh
```

### 2. Database Debugging
```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U admin -d esport_coach

# View slow queries
SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;

# Check Redis cache
docker-compose exec redis redis-cli
```

### 3. Network Debugging
```bash
# Test internal service communication
kubectl run debug --image=nicolaka/netshoot -it --rm

# Check ingress
kubectl describe ingress -n esport-coach
```

## Performance Optimization

### 1. Database Optimization
```sql
-- Add indexes for common queries
CREATE INDEX idx_bookings_coach_time ON bookings(coach_id, starts_at);

-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM bookings WHERE coach_id = $1;
```

### 2. Caching Strategy
```javascript
// Redis caching example
const cachedData = await redis.get(`coach:${coachId}`);
if (cachedData) {
  return JSON.parse(cachedData);
}

const data = await database.getCoach(coachId);
await redis.setex(`coach:${coachId}`, 300, JSON.stringify(data));
return data;
```

### 3. API Optimization
- Use pagination for list endpoints
- Implement field selection
- Add response compression
- Use connection pooling

## Security Best Practices

### 1. Input Validation
```javascript
const { body, validationResult } = require('express-validator');

app.post('/api/v1/users',
  body('email').isEmail(),
  body('password').isLength({ min: 8 }),
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    // Process request
  }
);
```

### 2. Authentication Security
- Use bcrypt for password hashing
- Implement JWT token rotation
- Add rate limiting
- Use HTTPS everywhere

### 3. Data Protection
- Encrypt sensitive data at rest
- Use parameterized queries
- Implement proper CORS
- Add security headers

## Monitoring and Observability

### 1. Metrics Collection
```javascript
const prometheus = require('prom-client');

const httpRequests = new prometheus.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status']
});

app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequests.labels(req.method, req.route?.path, res.statusCode).inc();
  });
  next();
});
```

### 2. Structured Logging
```javascript
const winston = require('winston');

const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console()
  ]
});

logger.info('User created', { 
  userId: user.id, 
  email: user.email,
  requestId: req.requestId 
});
```

### 3. Health Checks
```javascript
app.get('/health', async (req, res) => {
  const checks = {
    database: await checkDatabase(),
    redis: await checkRedis(),
    nats: await checkNATS()
  };
  
  const healthy = Object.values(checks).every(check => check.status === 'ok');
  
  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'healthy' : 'unhealthy',
    checks,
    timestamp: new Date().toISOString()
  });
});
```

## Troubleshooting

### Common Issues

#### Database Connection Issues
```bash
# Check database status
docker-compose ps postgres

# View database logs
docker-compose logs postgres

# Test connection
docker-compose exec postgres psql -U admin -d esport_coach -c "SELECT 1;"
```

#### Service Discovery Issues
```bash
# Check Kubernetes DNS
kubectl run debug --image=busybox -it --rm -- nslookup auth-service.esport-coach.svc.cluster.local

# Check service endpoints
kubectl get endpoints -n esport-coach
```

#### Memory/Performance Issues
```bash
# Check resource usage
kubectl top pods -n esport-coach

# Check Node.js memory usage
node --max-old-space-size=4096 src/main.js
```

## Contributing

### 1. Development Process
1. Create feature branch from `main`
2. Develop feature with tests
3. Run quality checks locally
4. Create pull request
5. Address review feedback
6. Merge after approval

### 2. Commit Guidelines
```
feat: add user authentication endpoint
fix: resolve session booking race condition
docs: update API documentation
test: add integration tests for coach service
```

### 3. Pull Request Template
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Breaking changes documented
- [ ] Security implications reviewed
- [ ] Performance impact considered

## Resources

### Documentation
- [API Documentation](./api.md)
- [Deployment Guide](./deployment.md)
- [Architecture Overview](./architecture.md)

### External Resources
- [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [PostgreSQL Performance](https://www.postgresql.org/docs/current/performance-tips.html)

### Team Communication
- **Slack**: `#esport-coach-dev`
- **Issues**: GitHub Issues
- **Wiki**: Team documentation

---

Happy coding! 🚀 If you have questions, check the documentation or reach out to the team.