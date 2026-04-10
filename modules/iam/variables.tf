#############################################
# IAM Module - Variables
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

variable "team_prefix" {
  description = "Team prefix for IAM resources"
  type        = string
  default     = ""
}

variable "iam_users" {
  description = "List of IAM user names to create"
  type        = list(string)
  default     = []
}

variable "main_account_id" {
  description = "Main account ID for cross-account ECR access (optional)"
  type        = string
  default     = ""
}

#############################################
# EKS IRSA Variables
#############################################

variable "create_irsa_roles" {
  description = "Whether to create IRSA roles (set to true when EKS exists)"
  type        = bool
  default     = true
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = ""
}

variable "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
  default     = ""
}

variable "eks_oidc_provider" {
  description = "EKS OIDC provider URL (without https://)"
  type        = string
  default     = ""
}

#############################################
# Local - Name Prefix
#############################################

locals {
  name_prefix        = var.owner_name != "" ? "${var.owner_name}-${var.environment}" : var.environment
  name_slug          = replace(lower(local.name_prefix), "/[^a-z0-9-]/", "-")
  actual_team_prefix = var.team_prefix != "" ? var.team_prefix : local.name_slug
}
