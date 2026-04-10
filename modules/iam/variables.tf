variable "project_name" {
  description = "Project name for account alias and resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "cn_members" {
  description = "Map of CN team IAM users"
  type        = map(object({}))
  default = {
    ash      = {}
    "7eehy3" = {}
    wonny    = {}
  }
}

variable "s3_full_access_bucket_arns" {
  description = "S3 bucket ARNs for CN group full access"
  type        = list(string)
}

variable "backup_bucket_name" {
  description = "Backup S3 bucket name for bot-kubeadm policies"
  type        = string
}
