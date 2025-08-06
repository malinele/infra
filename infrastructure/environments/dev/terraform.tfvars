# Development environment configuration
cloud_provider = "aws"
environment    = "dev"
region        = "us-east-1"
cluster_name  = "esport-coach-cluster"

# Grafana admin password (should be stored in environment variables or secrets manager)
grafana_admin_password = "admin123"

# Override default configurations for dev environment
# vpc_cidr = "10.0.0.0/16"
# availability_zones = 2