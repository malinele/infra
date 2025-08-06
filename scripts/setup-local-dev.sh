#!/bin/bash

# Setup script for local development environment
# This script sets up the complete Esport Coach Connect platform locally

set -e

echo "🚀 Setting up Esport Coach Connect - Local Development Environment"
echo "=================================================================="

# Check prerequisites
echo "📋 Checking prerequisites..."

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 is required but not installed. Please install it first."
        exit 1
    else
        echo "✅ $1 is installed"
    fi
}

check_command docker
check_command docker-compose
check_command kubectl
check_command kind

# Create kind cluster for local Kubernetes
echo ""
echo "🔧 Setting up local Kubernetes cluster with Kind..."

if kind get clusters | grep -q "esport-coach-dev"; then
    echo "✅ Kind cluster 'esport-coach-dev' already exists"
else
    cat <<EOF | kind create cluster --name esport-coach-dev --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
- role: worker
- role: worker
EOF
    echo "✅ Kind cluster created successfully"
fi

# Set kubectl context
kubectl config use-context kind-esport-coach-dev

# Install NGINX Ingress Controller
echo ""
echo "🔧 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
echo "⏳ Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Start local services with Docker Compose
echo ""
echo "🐳 Starting local services with Docker Compose..."
cd "$(dirname "$0")/.."

# Create network if it doesn't exist
docker network create esport-coach-network 2>/dev/null || echo "Network already exists"

# Start infrastructure services
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be healthy..."
timeout=60
count=0
while [ $count -lt $timeout ]; do
    if docker-compose ps | grep -q "Up (healthy)" || [ $count -eq 0 ]; then
        sleep 2
        count=$((count + 2))
        if [ $((count % 10)) -eq 0 ]; then
            echo "Still waiting... ($count/${timeout}s)"
        fi
    else
        break
    fi
done

# Check service health
echo ""
echo "🏥 Checking service health..."
services=("postgres" "redis" "elasticsearch" "nats" "minio")
for service in "${services[@]}"; do
    if docker-compose ps $service | grep -q "Up (healthy)"; then
        echo "✅ $service is healthy"
    else
        echo "⚠️  $service might not be fully ready yet"
    fi
done

# Deploy application to Kubernetes
echo ""
echo "☸️  Deploying application to Kubernetes..."
kubectl apply -k kubernetes/base/

# Wait for deployments to be ready
echo "⏳ Waiting for application deployments..."
kubectl wait --namespace esport-coach \
  --for=condition=available deployment \
  --all \
  --timeout=300s 2>/dev/null || echo "Some deployments may still be starting up"

# Display access information
echo ""
echo "🎉 Setup complete! Here's how to access your services:"
echo "=================================================="
echo ""
echo "Local Services (Docker Compose):"
echo "  📊 Grafana: http://localhost:3001 (admin/admin123)"
echo "  🗄️  MinIO Console: http://localhost:9001 (admin/admin123)"
echo "  🔍 Elasticsearch: http://localhost:9200"
echo "  💬 NATS Monitoring: http://localhost:8222"
echo ""
echo "Kubernetes Services:"
echo "  🚪 API Gateway: http://localhost:8080/api"
echo "  📋 Kubernetes Dashboard: kubectl proxy (then http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)"
echo ""
echo "Useful Commands:"
echo "  🔍 Check service status: docker-compose ps"
echo "  📊 View logs: docker-compose logs -f [service]"
echo "  ☸️  View K8s pods: kubectl get pods -n esport-coach"
echo "  🔗 Port forward services: kubectl port-forward -n esport-coach service/[service-name] [local-port]:[service-port]"
echo ""
echo "🛠️  Development:"
echo "  • Services are available for local development"
echo "  • Modify code in services/ directory"
echo "  • Use 'docker-compose restart [service]' to reload changes"
echo "  • Use 'kubectl rollout restart deployment/[service] -n esport-coach' for K8s deployments"
echo ""
echo "📚 Documentation: See docs/ directory for detailed guides"
echo ""
echo "Happy coding! 🚀"