#############################################
# EKS Module - Variables
#############################################

variable "owner_name" {
  description = "Owner name for resource naming (optional)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS"
  type        = list(string)
}

variable "bastion_security_group_id" {
  description = "Bastion security group ID for API access (optional)"
  type        = string
  default     = ""
}

variable "vpc_cidr_blocks" {
  description = "VPC CIDR blocks for ALB to Pod communication (target-type: ip)"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs to attach to EKS nodes (for RDS/Redis access)"
  type        = list(string)
  default     = []
}

variable "cluster_name" {
  description = "EKS cluster name suffix"
  type        = string
  default     = "eks"
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.34"
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to EKS API"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to access EKS public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

#############################################
# Node Group Variables - Monitoring (t4g.xlarge)
#############################################

variable "monitoring_instance_types" {
  description = "Instance types for monitoring node group"
  type        = list(string)
  default     = ["t4g.xlarge"]
}

variable "monitoring_capacity_type" {
  description = "Capacity type for monitoring node group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "monitoring_min_size" {
  description = "Minimum size for monitoring node group"
  type        = number
  default     = 1
}

variable "monitoring_max_size" {
  description = "Maximum size for monitoring node group"
  type        = number
  default     = 2
}

variable "monitoring_desired_size" {
  description = "Desired size for monitoring node group"
  type        = number
  default     = 1
}

#############################################
# Node Group Variables - Infra (t4g.large) - ArgoCD + Istio + Karpenter
#############################################

variable "infra_instance_types" {
  description = "Instance types for infra node group"
  type        = list(string)
  default     = ["t4g.large"]
}

variable "infra_capacity_type" {
  description = "Capacity type for infra node group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "infra_min_size" {
  description = "Minimum size for infra node group"
  type        = number
  default     = 1
}

variable "infra_max_size" {
  description = "Maximum size for infra node group"
  type        = number
  default     = 2
}

variable "infra_desired_size" {
  description = "Desired size for infra node group"
  type        = number
  default     = 1
}

variable "infra_subnet_ids" {
  description = "Subnet IDs for infra node group (defaults to private_subnet_ids if empty). Pin to single AZ for stateful workloads."
  type        = list(string)
  default     = []
}

#############################################
# Node Group Variables - Apps (on-demand, app workloads)
#############################################

variable "apps_instance_types" {
  description = "Instance types for apps node group"
  type        = list(string)
  default     = ["t4g.xlarge"]
}

variable "apps_capacity_type" {
  description = "Capacity type for apps node group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "apps_min_size" {
  description = "Minimum size for apps node group"
  type        = number
  default     = 1
}

variable "apps_max_size" {
  description = "Maximum size for apps node group"
  type        = number
  default     = 3
}

variable "apps_desired_size" {
  description = "Desired size for apps node group"
  type        = number
  default     = 1
}

#############################################
# IRSA Variables
#############################################

variable "main_account_id" {
  description = "Main account ID for cross-account ECR access (optional)"
  type        = string
  default     = ""
}

variable "secrets_manager_arns" {
  description = "Secrets Manager ARNs for External Secrets"
  type        = list(string)
  default     = []
}

variable "ebs_csi_addon_version" {
  description = "EBS CSI Driver addon version"
  type        = string
  default     = null # null = latest version
}

#############################################
# Access Entries
#############################################

variable "enable_devops_role_access" {
  description = "Enable DevOps IAM Role access to EKS (static boolean for plan-time)"
  type        = bool
  default     = false
}

variable "devops_role_arn" {
  description = "DevOps IAM Role ARN for EKS access"
  type        = string
  default     = ""
}

variable "enable_devops_user_access" {
  description = "Enable DevOps IAM User access to EKS (static boolean for plan-time)"
  type        = bool
  default     = false
}

variable "devops_user_arn" {
  description = "DevOps IAM User ARN for EKS access"
  type        = string
  default     = ""
}

#############################################
# Local - Name Prefix & Slug
#############################################

locals {
  name_prefix            = var.owner_name != "" ? "${var.owner_name}-${var.environment}" : var.environment
  name_slug              = replace(lower(local.name_prefix), "/[^a-z0-9-]/", "-")
  cluster_full_name      = "${local.name_slug}-${var.cluster_name}"
  cluster_iam_role_name  = "${local.name_slug}-${var.cluster_name}-cluster"
  monitoring_role_name   = "${local.name_slug}-monitoring-node-role"
  infra_role_name        = "${local.name_slug}-infra-node-role"
  apps_role_name         = "${local.name_slug}-apps-node-role"
  ebs_csi_irsa_role_name = "${local.name_slug}-ebs-csi-irsa"
}
