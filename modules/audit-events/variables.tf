variable "project_name" {
  description = "Project name for resource naming"
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

variable "enabled" {
  description = "Enable audit event pipeline"
  type        = bool
  default     = true
}

variable "audit_logs_bucket_id" {
  description = "Audit logs S3 bucket ID"
  type        = string
}

variable "audit_logs_bucket_arn" {
  description = "Audit logs S3 bucket ARN"
  type        = string
}

variable "summary_prefix" {
  description = "S3 prefix for audit event summaries"
  type        = string
  default     = "lifecycle-expiration-summary"
}

variable "monitored_bucket_names" {
  description = "S3 bucket names to monitor for delete events"
  type        = list(string)
  default     = []
}

variable "event_names" {
  description = "S3 API event names to capture"
  type        = list(string)
  default     = ["DeleteObject", "DeleteObjects"]
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "discord_webhook_url" {
  description = "Discord webhook URL"
  type        = string
  default     = ""
  sensitive   = true
}

variable "discord_secret_name" {
  description = "Secrets Manager secret name for Discord webhooks"
  type        = string
  default     = "staging/monitoring/discord-webhook-alerts"
}

variable "discord_username" {
  description = "Discord bot username"
  type        = string
  default     = "playball-audit-bot"
}

variable "discord_critical_webhook_key" {
  description = "Secret JSON key for critical notifications"
  type        = string
  default     = "securityCriticalWebhookUrl"
}

variable "discord_warning_webhook_key" {
  description = "Secret JSON key for warning notifications"
  type        = string
  default     = "securityWarningWebhookUrl"
}

variable "discord_info_webhook_key" {
  description = "Secret JSON key for info notifications"
  type        = string
  default     = "securityInfoWebhookUrl"
}

variable "critical_mention_text" {
  description = "Mention text for critical notifications"
  type        = string
  default     = "@개발팀 @admins"
}
