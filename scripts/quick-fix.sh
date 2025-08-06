#!/bin/bash
# Quick fix for Docker network label issue

echo "🔧 Quick Docker Network Fix"
echo "=========================="

# Stop services
echo "Stopping services..."
docker-compose down --remove-orphans

# Remove problematic network
echo "Removing problematic network..."
docker network rm esport-coach-network 2>/dev/null || true

# Clean up
echo "Cleaning up..."
docker network prune -f

# Start services (this will create the network properly)
echo "Starting services..."
docker-compose up -d

echo "✅ Quick fix complete! Check with: docker-compose ps"