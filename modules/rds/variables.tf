#############################################
# RDS Module - Variables
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
  description = "Private subnet IDs for RDS"
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

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Max allocated storage in GB"
  type        = number
  default     = 50
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "goormgb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "goormgb_admin"
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "additional_secrets" {
  description = "Additional key-value pairs to store in the DB secret"
  type        = map(string)
  default     = {}

}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs export for PostgreSQL"
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds (0 to disable, 1/5/10/15/30/60)"
  type        = number
  default     = 0
}

variable "max_connections" {
  description = "Maximum number of database connections"
  type        = number
  default     = 100
}

variable "read_replica_enabled" {
  description = "Enable read replica"
  type        = bool
  default     = false
}

variable "read_replica_instance_class" {
  description = "Instance class for read replica (defaults to same as primary)"
  type        = string
  default     = ""
}

#############################################
# Local - Name Prefix & Slug
#############################################

locals {
  name_prefix = var.owner_name != "" ? "${var.owner_name}-${var.environment}" : var.environment
  name_slug   = replace(lower(local.name_prefix), "/[^a-z0-9-]/", "-")
}
