#############################################
# Karpenter Module - Variables
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

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}

variable "ecr_cross_account_policy_arn" {
  description = "ECR cross-account pull policy ARN (optional)"
  type        = string
  default     = ""
}

variable "enable_ecr_cross_account" {
  description = "Whether to enable ECR cross-account access (static boolean for plan-time)"
  type        = bool
  default     = false
}

#############################################
# Local - Name Prefix & Slug
#############################################

locals {
  name_prefix = var.owner_name != "" ? "${var.owner_name}-${var.environment}" : var.environment
  name_slug   = replace(lower(local.name_prefix), "/[^a-z0-9-]/", "-")

  karpenter_namespace       = "karpenter"
  karpenter_service_account = "karpenter"
}
