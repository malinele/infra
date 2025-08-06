#!/bin/bash

# Production deployment script for Esport Coach Connect
# This script deploys the platform to a production Kubernetes cluster

set -e

echo "🚀 Deploying Esport Coach Connect - Production Environment"
echo "========================================================="

# Configuration
ENVIRONMENT=${1:-prod}
REGION=${2:-us-east-1}
CLUSTER_NAME="esport-coach-cluster-${ENVIRONMENT}"

echo "🔧 Configuration:"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $REGION"
echo "  Cluster: $CLUSTER_NAME"
echo ""

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

check_command aws
check_command kubectl
check_command terraform
check_command helm

# Verify AWS credentials
echo ""
echo "🔑 Verifying AWS credentials..."
aws sts get-caller-identity > /dev/null
echo "✅ AWS credentials verified"

# Deploy infrastructure with Terraform
echo ""
echo "🏗️  Deploying infrastructure with Terraform..."
cd infrastructure/

# Initialize Terraform
terraform init

# Select workspace
terraform workspace select $ENVIRONMENT 2>/dev/null || terraform workspace new $ENVIRONMENT

# Plan and apply
echo "📋 Planning Terraform deployment..."
terraform plan -var-file="environments/${ENVIRONMENT}/terraform.tfvars"

read -p "Do you want to apply these changes? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

echo "🚀 Applying Terraform configuration..."
terraform apply -var-file="environments/${ENVIRONMENT}/terraform.tfvars" -auto-approve

# Get cluster connection info
echo ""
echo "☸️  Configuring kubectl for EKS cluster..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Verify cluster connection
kubectl cluster-info
echo "✅ Successfully connected to cluster"

cd ..

# Install monitoring stack with Helm
echo ""
echo "📊 Installing monitoring stack..."

# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

# Install Prometheus
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace esport-coach-monitoring \
  --create-namespace \
  --values monitoring/prometheus-values.yaml \
  --wait

# Install Jaeger
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace esport-coach-monitoring \
  --values monitoring/jaeger-values.yaml \
  --wait

# Install Loki
helm upgrade --install loki grafana/loki-stack \
  --namespace esport-coach-monitoring \
  --values monitoring/loki-values.yaml \
  --wait

echo "✅ Monitoring stack installed successfully"

# Deploy application
echo ""
echo "🚀 Deploying application services..."

# Apply Kubernetes manifests
kubectl apply -k kubernetes/overlays/${ENVIRONMENT}/

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --namespace esport-coach \
  --for=condition=available deployment \
  --all \
  --timeout=600s

# Get ingress information
echo ""
echo "🌐 Getting ingress information..."
INGRESS_HOST=$(kubectl get ingress -n esport-coach esport-coach-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$INGRESS_HOST" ]; then
    INGRESS_HOST=$(kubectl get ingress -n esport-coach esport-coach-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
fi

# Run smoke tests
echo ""
echo "🧪 Running smoke tests..."
cd scripts/
./smoke-tests.sh $INGRESS_HOST
cd ..

# Display deployment information
echo ""
echo "🎉 Deployment completed successfully!"
echo "====================================="
echo ""
echo "🌐 Application URLs:"
echo "  API Gateway: https://$INGRESS_HOST/api"
echo "  Frontend: https://$INGRESS_HOST"
echo ""
echo "📊 Monitoring URLs:"
echo "  Grafana: https://$INGRESS_HOST/grafana (admin/[check secrets])"
echo "  Prometheus: https://$INGRESS_HOST/prometheus"
echo "  Jaeger: https://$INGRESS_HOST/jaeger"
echo ""
echo "🔧 Management Commands:"
echo "  View pods: kubectl get pods -n esport-coach"
echo "  View logs: kubectl logs -f deployment/[service-name] -n esport-coach"
echo "  Scale service: kubectl scale deployment/[service-name] --replicas=[count] -n esport-coach"
echo ""
echo "📈 SLO Dashboards:"
echo "  API Latency: https://$INGRESS_HOST/grafana/d/api-latency"
echo "  Error Rates: https://$INGRESS_HOST/grafana/d/error-rates"
echo "  System Health: https://$INGRESS_HOST/grafana/d/system-health"
echo ""
echo "🛡️  Security:"
echo "  • TLS certificates are managed automatically"
echo "  • Network policies are enforced"
echo "  • RBAC is configured"
echo ""
echo "📚 Next Steps:"
echo "  1. Configure DNS to point to: $INGRESS_HOST"
echo "  2. Review monitoring dashboards"
echo "  3. Set up alerting rules"
echo "  4. Run full integration tests"
echo ""
echo "Deployment Summary:"
echo "  Environment: $ENVIRONMENT"
echo "  Cluster: $CLUSTER_NAME"
echo "  Region: $REGION"
echo "  Ingress: $INGRESS_HOST"
echo ""
echo "Happy launching! 🚀"