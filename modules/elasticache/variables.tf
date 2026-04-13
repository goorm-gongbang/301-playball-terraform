#############################################
# ElastiCache Module - Variables
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

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ElastiCache"
  type        = list(string)
}

variable "eks_security_group_id" {
  description = "EKS cluster security group ID (optional, use vpc_cidr instead)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "VPC CIDR for EKS pod access (alternative to security group)"
  type        = string
  default     = ""
}

variable "bastion_security_group_id" {
  description = "Bastion security group ID (optional)"
  type        = string
  default     = ""
}

#############################################
# Redis Configuration
#############################################

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_family" {
  description = "Redis parameter group family"
  type        = string
  default     = "redis7"
}

variable "node_type" {
  description = "Node type for Redis"
  type        = string
  default     = "cache.t4g.micro"
}

variable "num_cache_clusters" {
  description = "Number of cache clusters (1=no replica, 2=primary+replica)"
  type        = number
  default     = 1 # Staging: 1, Prod: 2
}

variable "snapshot_retention" {
  description = "Snapshot retention (days, 0=disabled)"
  type        = number
  default     = 1
}

variable "transit_encryption_enabled" {
  description = "Enable in-transit encryption (TLS). Requires cluster recreation if changed."
  type        = bool
  default     = false
}

variable "transit_encryption_mode" {
  description = "TLS mode: 'preferred' (TLS+non-TLS both open) or 'required' (TLS only)"
  type        = string
  default     = "preferred"
}

#############################################
# Local - Name Prefix & Slug
#############################################

locals {
  name_prefix = var.owner_name != "" ? "${var.owner_name}-${var.environment}" : var.environment
  name_slug   = replace(lower(local.name_prefix), "/[^a-z0-9-]/", "-")
}
