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

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for worker nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for load balancers"
  type        = list(string)
}

variable "node_groups" {
  description = "Node group configurations"
  type = map(object({
    instance_type = string
    min_size     = number
    max_size     = number
    desired_size = number
  }))
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

# AWS EKS Implementation
resource "aws_iam_role" "cluster" {
  count = var.cloud_provider == "aws" ? 1 : 0
  
  name = "${var.cluster_name}-cluster-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  count = var.cloud_provider == "aws" ? 1 : 0
  
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster[0].name
}

resource "aws_iam_role" "node_group" {
  count = var.cloud_provider == "aws" ? 1 : 0
  
  name = "${var.cluster_name}-node-group-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_group_policies" {
  count = var.cloud_provider == "aws" ? length(local.node_group_policies) : 0
  
  policy_arn = local.node_group_policies[count.index]
  role       = aws_iam_role.node_group[0].name
}

locals {
  node_group_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]
}

resource "aws_security_group" "cluster" {
  count = var.cloud_provider == "aws" ? 1 : 0
  
  name_prefix = "${var.cluster_name}-cluster-sg"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

resource "aws_eks_cluster" "main" {
  count = var.cloud_provider == "aws" ? 1 : 0
  
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster[0].arn
  
  vpc_config {
    subnet_ids              = concat(var.subnet_ids, var.public_subnet_ids)
    security_group_ids      = [aws_security_group.cluster[0].id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }
  
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]
  
  tags = var.tags
}

resource "aws_eks_node_group" "main" {
  for_each = var.cloud_provider == "aws" ? var.node_groups : {}
  
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node_group[0].arn
  subnet_ids      = var.subnet_ids
  instance_types  = [each.value.instance_type]
  
  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }
  
  update_config {
    max_unavailable = 1
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.node_group_policies
  ]
  
  tags = merge(var.tags, {
    Name = "${var.cluster_name}-${each.key}"
  })
}

# EKS Add-ons
resource "aws_eks_addon" "csi_driver" {
  count = var.cloud_provider == "aws" ? 1 : 0
  
  cluster_name             = aws_eks_cluster.main[0].name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.24.0-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"
  
  depends_on = [aws_eks_node_group.main]
  
  tags = var.tags
}

resource "aws_eks_addon" "coredns" {
  count = var.cloud_provider == "aws" ? 1 : 0
  
  cluster_name             = aws_eks_cluster.main[0].name
  addon_name               = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  
  depends_on = [aws_eks_node_group.main]
  
  tags = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  count = var.cloud_provider == "aws" ? 1 : 0
  
  cluster_name             = aws_eks_cluster.main[0].name
  addon_name               = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  
  depends_on = [aws_eks_node_group.main]
  
  tags = var.tags
}

# Outputs
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value = var.cloud_provider == "aws" ? aws_eks_cluster.main[0].endpoint : null
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value = var.cloud_provider == "aws" ? aws_eks_cluster.main[0].vpc_config[0].cluster_security_group_id : null
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value = var.cloud_provider == "aws" ? aws_iam_role.cluster[0].name : null
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value = var.cloud_provider == "aws" ? aws_iam_role.cluster[0].arn : null
}

output "cluster_version" {
  description = "EKS cluster version"
  value = var.cloud_provider == "aws" ? aws_eks_cluster.main[0].version : null
}

output "cluster_name" {
  description = "EKS cluster name"
  value = var.cloud_provider == "aws" ? aws_eks_cluster.main[0].name : null
}

output "node_groups" {
  description = "EKS node groups"
  value = var.cloud_provider == "aws" ? {
    for k, v in aws_eks_node_group.main : k => {
      arn           = v.arn
      status        = v.status
      capacity_type = v.capacity_type
      instance_types = v.instance_types
    }
  } : {}
}

output "oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value = var.cloud_provider == "aws" ? aws_eks_cluster.main[0].identity[0].oidc[0].issuer : null
}