# Production environment configuration
cloud_provider = "aws"
environment    = "prod"
region        = "us-east-1"
cluster_name  = "esport-coach-cluster"

# Grafana admin password (should be stored in AWS Secrets Manager)
# grafana_admin_password = "CHANGE_ME"

# Production optimized configurations
# vpc_cidr = "10.1.0.0/16"
# availability_zones = 3

# Larger instance types for production
# node_groups = {
#   general = {
#     instance_type = "t3.large"
#     min_size     = 3
#     max_size     = 15
#     desired_size = 5
#   }
#   compute = {
#     instance_type = "c5.xlarge"
#     min_size     = 2
#     max_size     = 10
#     desired_size = 3
#   }
# }