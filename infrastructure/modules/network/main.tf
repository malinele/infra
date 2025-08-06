variable "cloud_provider" {
  description = "Cloud provider"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "Cloud region"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Number of availability zones"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

# Data source for availability zones
locals {
  az_count = min(var.availability_zones, 3)
  
  # Cloud provider specific configurations
  provider_configs = {
    aws = {
      vpc_cidr = var.vpc_cidr
      azs      = slice(data.aws_availability_zones.available[0].names, 0, local.az_count)
    }
    gcp = {
      vpc_cidr = var.vpc_cidr
      azs      = slice(data.google_compute_zones.available[0].names, 0, local.az_count)
    }
    azure = {
      vpc_cidr = var.vpc_cidr
      azs      = slice(data.azurerm_availability_set.available[0].platform_fault_domain_count, 0, local.az_count)
    }
    onprem = {
      vpc_cidr = var.vpc_cidr
      azs      = ["zone-a", "zone-b", "zone-c"]
    }
  }
  
  config = local.provider_configs[var.cloud_provider]
}

# AWS Implementation
resource "aws_vpc" "main" {
  count = var.cloud_provider == "aws" ? 1 : 0
  
  cidr_block           = local.config.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(var.tags, {
    Name = "esport-coach-vpc-${var.environment}"
  })
}

resource "aws_internet_gateway" "main" {
  count = var.cloud_provider == "aws" ? 1 : 0
  
  vpc_id = aws_vpc.main[0].id
  
  tags = merge(var.tags, {
    Name = "esport-coach-igw-${var.environment}"
  })
}

resource "aws_subnet" "public" {
  count = var.cloud_provider == "aws" ? local.az_count : 0
  
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(local.config.vpc_cidr, 8, count.index)
  availability_zone       = local.config.azs[count.index]
  map_public_ip_on_launch = true
  
  tags = merge(var.tags, {
    Name = "esport-coach-public-subnet-${count.index + 1}-${var.environment}"
    Type = "public"
  })
}

resource "aws_subnet" "private" {
  count = var.cloud_provider == "aws" ? local.az_count : 0
  
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(local.config.vpc_cidr, 8, count.index + local.az_count)
  availability_zone = local.config.azs[count.index]
  
  tags = merge(var.tags, {
    Name = "esport-coach-private-subnet-${count.index + 1}-${var.environment}"
    Type = "private"
  })
}

# NAT Gateways for private subnets
resource "aws_eip" "nat" {
  count = var.cloud_provider == "aws" ? local.az_count : 0
  
  domain = "vpc"
  
  tags = merge(var.tags, {
    Name = "esport-coach-nat-eip-${count.index + 1}-${var.environment}"
  })
  
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = var.cloud_provider == "aws" ? local.az_count : 0
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = merge(var.tags, {
    Name = "esport-coach-nat-gw-${count.index + 1}-${var.environment}"
  })
  
  depends_on = [aws_internet_gateway.main]
}

# Route tables
resource "aws_route_table" "public" {
  count = var.cloud_provider == "aws" ? 1 : 0
  
  vpc_id = aws_vpc.main[0].id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }
  
  tags = merge(var.tags, {
    Name = "esport-coach-public-rt-${var.environment}"
  })
}

resource "aws_route_table" "private" {
  count = var.cloud_provider == "aws" ? local.az_count : 0
  
  vpc_id = aws_vpc.main[0].id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  
  tags = merge(var.tags, {
    Name = "esport-coach-private-rt-${count.index + 1}-${var.environment}"
  })
}

# Route table associations
resource "aws_route_table_association" "public" {
  count = var.cloud_provider == "aws" ? local.az_count : 0
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count = var.cloud_provider == "aws" ? local.az_count : 0
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security Groups
resource "aws_security_group" "database" {
  count = var.cloud_provider == "aws" ? 1 : 0
  
  name_prefix = "esport-coach-db-${var.environment}"
  vpc_id      = aws_vpc.main[0].id
  
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.config.vpc_cidr]
  }
  
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [local.config.vpc_cidr]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.tags, {
    Name = "esport-coach-db-sg-${var.environment}"
  })
}

# Data sources
data "aws_availability_zones" "available" {
  count = var.cloud_provider == "aws" ? 1 : 0
  state = "available"
}

# Placeholder for other cloud providers
# GCP, Azure, and on-premises implementations would go here

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value = var.cloud_provider == "aws" ? aws_vpc.main[0].id : null
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value = var.cloud_provider == "aws" ? aws_subnet.public[*].id : []
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value = var.cloud_provider == "aws" ? aws_subnet.private[*].id : []
}

output "database_security_group_id" {
  description = "Database security group ID"
  value = var.cloud_provider == "aws" ? aws_security_group.database[0].id : null
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value = var.cloud_provider == "aws" ? aws_internet_gateway.main[0].id : null
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value = var.cloud_provider == "aws" ? aws_nat_gateway.main[*].id : []
}