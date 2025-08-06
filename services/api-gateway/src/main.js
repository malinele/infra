const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Limit each IP to 1000 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'api-gateway',
    timestamp: new Date().toISOString()
  });
});

// Service routes
const services = {
  auth: process.env.AUTH_SERVICE_URL || 'http://auth-service:3001',
  users: process.env.USER_SERVICE_URL || 'http://user-service:3002',
  coaches: process.env.COACH_SERVICE_URL || 'http://coach-service:3003',
  sessions: process.env.SESSION_SERVICE_URL || 'http://session-service:3004',
  video: process.env.VIDEO_SERVICE_URL || 'http://video-service:3005',
  messaging: process.env.MESSAGING_SERVICE_URL || 'http://messaging-service:3006',
  payments: process.env.PAYMENT_SERVICE_URL || 'http://payment-service:3007',
  ratings: process.env.RATINGS_SERVICE_URL || 'http://ratings-service:3008',
  search: process.env.SEARCH_SERVICE_URL || 'http://search-service:3009'
};

// Proxy middleware (placeholder - would use http-proxy-middleware in production)
app.use('/api/auth', (req, res) => {
  res.json({ message: `Proxying to ${services.auth}${req.path}`, method: req.method });
});

app.use('/api/users', (req, res) => {
  res.json({ message: `Proxying to ${services.users}${req.path}`, method: req.method });
});

app.use('/api/coaches', (req, res) => {
  res.json({ message: `Proxying to ${services.coaches}${req.path}`, method: req.method });
});

app.use('/api/sessions', (req, res) => {
  res.json({ message: `Proxying to ${services.sessions}${req.path}`, method: req.method });
});

app.use('/api/video', (req, res) => {
  res.json({ message: `Proxying to ${services.video}${req.path}`, method: req.method });
});

app.use('/api/messages', (req, res) => {
  res.json({ message: `Proxying to ${services.messaging}${req.path}`, method: req.method });
});

app.use('/api/payments', (req, res) => {
  res.json({ message: `Proxying to ${services.payments}${req.path}`, method: req.method });
});

app.use('/api/ratings', (req, res) => {
  res.json({ message: `Proxying to ${services.ratings}${req.path}`, method: req.method });
});

app.use('/api/search', (req, res) => {
  res.json({ message: `Proxying to ${services.search}${req.path}`, method: req.method });
});

// Health check endpoint that checks all services
app.get('/api/health', async (req, res) => {
  const healthChecks = {};
  
  // Check each service health
  for (const [serviceName, serviceUrl] of Object.entries(services)) {
    try {
      // In a real implementation, you'd make HTTP requests to each service
      // For now, we'll just return a mock response
      healthChecks[serviceName] = {
        status: 'healthy',
        url: serviceUrl,
        responseTime: Math.floor(Math.random() * 50) + 10 // Mock response time
      };
    } catch (error) {
      healthChecks[serviceName] = {
        status: 'unhealthy',
        url: serviceUrl,
        error: error.message
      };
    }
  }
  
  const overallHealth = Object.values(healthChecks).every(check => check.status === 'healthy');
  
  res.status(overallHealth ? 200 : 503).json({
    status: overallHealth ? 'healthy' : 'degraded',
    services: healthChecks,
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`API Gateway running on port ${PORT}`);
  console.log('Service URLs:', services);
});

module.exports = app;