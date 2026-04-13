#############################################
# VPC Module - Variables
#############################################

variable "owner_name" {
  description = "Owner name for resource naming (optional - if empty, uses environment only)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "eks_cluster_name" {
  description = "EKS cluster name for subnet tagging"
  type        = string
}

variable "enable_karpenter_discovery" {
  description = "Enable karpenter.sh/discovery tag on private subnets"
  type        = bool
  default     = true
}

variable "enable_multi_az_nat" {
  description = "Create one NAT Gateway per AZ for HA (true) or single NAT for cost savings (false)"
  type        = bool
  default     = false
}

variable "vpc_endpoints" {
  description = "List of VPC interface endpoints to create (e.g., ecr.api, ecr.dkr, logs, sts)"
  type        = list(string)
  default     = []
}

#############################################
# Local - Name Prefix
#############################################

locals {
  name_prefix = var.owner_name != "" ? "${var.owner_name}-${var.environment}" : var.environment
}
