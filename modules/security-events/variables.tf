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
  description = "Enable security event pipeline"
  type        = bool
  default     = true
}

variable "console_event_names" {
  description = "Console sign-in event names to capture"
  type        = list(string)
  default     = ["ConsoleLogin"]
}

variable "api_event_names" {
  description = "CloudTrail API event names to capture"
  type        = list(string)
  default = [
    "CreateAccessKey", "UpdateAccessKey", "DeleteAccessKey",
    "CreateLoginProfile", "UpdateLoginProfile",
    "AttachUserPolicy", "PutUserPolicy",
    "AttachRolePolicy", "PutRolePolicy",
    "CreatePolicyVersion", "SetDefaultPolicyVersion",
    "AuthorizeSecurityGroupIngress", "AuthorizeSecurityGroupEgress",
    "UpdateTrail", "PutEventSelectors", "PutInsightSelectors",
    "StartLogging", "StopLogging", "DeleteTrail",
    "PutBucketPolicy", "DeleteBucketPolicy",
    "PutBucketPublicAccessBlock", "DeleteBucketPublicAccessBlock",
    "PutBucketAcl", "PutBucketEncryption", "DeleteBucketEncryption",
    "ModifyDBInstance", "DeleteDBSnapshot", "ModifyDBSnapshotAttribute"
  ]
}

variable "sensitive_ports" {
  description = "Ports treated as sensitive for security group changes"
  type        = list(number)
  default     = [22, 80, 443, 3306, 3389, 5432, 6379]
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
  default     = "goormgb-security-bot"
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
