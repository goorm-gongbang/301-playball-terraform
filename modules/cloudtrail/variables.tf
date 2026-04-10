variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "enabled" {
  description = "Enable CloudTrail"
  type        = bool
  default     = true
}

variable "audit_logs_bucket_id" {
  description = "S3 bucket ID for CloudTrail log delivery"
  type        = string
}

variable "s3_key_prefix" {
  description = "S3 key prefix for CloudTrail logs"
  type        = string
  default     = "cloudtrail"
}

variable "tracked_s3_bucket_arns" {
  description = "List of S3 bucket ARNs to track data events"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 90
}
