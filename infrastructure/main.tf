terraform {
  required_version = ">= 1.5"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# Variables for cloud provider selection
variable "cloud_provider" {
  description = "Cloud provider to use (aws, gcp, azure, onprem)"
  type        = string
  default     = "aws"
  
  validation {
    condition     = contains(["aws", "gcp", "azure", "onprem"], var.cloud_provider)
    error_message = "Cloud provider must be one of: aws, gcp, azure, onprem."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "Cloud region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "esport-coach-cluster"
}

# Locals for cloud-specific configurations
locals {
  common_tags = {
    Project     = "esport-coach-connect"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
  
  cluster_config = {
    name    = "${var.cluster_name}-${var.environment}"
    region  = var.region
    version = "1.28"
  }
}

# Network module (cloud-agnostic interface)
module "network" {
  source = "./modules/network"
  
  cloud_provider = var.cloud_provider
  environment    = var.environment
  region        = var.region
  
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = 3
  
  tags = local.common_tags
}

# Kubernetes cluster module (cloud-agnostic interface)
module "kubernetes" {
  source = "./modules/kubernetes"
  
  cloud_provider = var.cloud_provider
  environment    = var.environment
  region        = var.region
  
  cluster_name    = local.cluster_config.name
  cluster_version = local.cluster_config.version
  
  # Network configuration from network module
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
  public_subnet_ids  = module.network.public_subnet_ids
  
  # Node groups
  node_groups = {
    general = {
      instance_type = "t3.medium"
      min_size     = 2
      max_size     = 10
      desired_size = 3
    }
    compute = {
      instance_type = "c5.large"
      min_size     = 1
      max_size     = 5
      desired_size = 2
    }
  }
  
  tags = local.common_tags
  
  depends_on = [module.network]
}

# Database module (cloud-agnostic)
module "database" {
  source = "./modules/database"
  
  cloud_provider = var.cloud_provider
  environment    = var.environment
  region        = var.region
  
  # PostgreSQL configuration
  postgres_config = {
    instance_class    = "db.t3.micro"
    allocated_storage = 20
    engine_version   = "15.4"
    database_name    = "esport_coach"
    username         = "admin"
  }
  
  # Redis configuration
  redis_config = {
    node_type      = "cache.t3.micro"
    num_cache_nodes = 1
    engine_version = "7.0"
  }
  
  # Network configuration
  vpc_id           = module.network.vpc_id
  subnet_ids       = module.network.private_subnet_ids
  security_group_id = module.network.database_security_group_id
  
  tags = local.common_tags
  
  depends_on = [module.network]
}

# Object storage module
module "storage" {
  source = "./modules/storage"
  
  cloud_provider = var.cloud_provider
  environment    = var.environment
  region        = var.region
  
  buckets = {
    recordings = {
      versioning = true
      lifecycle_rules = {
        archive_after_days = 90
        delete_after_days  = 365
      }
    }
    uploads = {
      versioning = false
      public_access = false
    }
  }
  
  tags = local.common_tags
}

# Monitoring module
module "monitoring" {
  source = "./modules/monitoring"
  
  cloud_provider = var.cloud_provider
  environment    = var.environment
  region        = var.region
  
  cluster_name = local.cluster_config.name
  
  # Prometheus configuration
  prometheus_config = {
    retention_days = 30
    storage_size  = "50Gi"
  }
  
  # Grafana configuration
  grafana_config = {
    admin_password = var.grafana_admin_password
  }
  
  tags = local.common_tags
  
  depends_on = [module.kubernetes]
}

# Outputs
output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = module.kubernetes.cluster_endpoint
  sensitive   = true
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = module.kubernetes.cluster_name
}

output "database_endpoints" {
  description = "Database connection endpoints"
  value       = module.database.endpoints
  sensitive   = true
}

output "storage_buckets" {
  description = "Created storage buckets"
  value       = module.storage.bucket_names
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

# Variables for sensitive data
variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin123"
}