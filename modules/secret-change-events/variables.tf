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
  description = "Enable secret change event pipeline"
  type        = bool
  default     = true
}

variable "event_names" {
  description = "Secrets Manager API event names to capture"
  type        = list(string)
  default = [
    "PutSecretValue",
    "UpdateSecret",
    "CreateSecret",
    "DeleteSecret",
    "RestoreSecret"
  ]
}

variable "staging_discord_webhook_url" {
  description = "Discord webhook URL for staging/prod secret change notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "dev_discord_webhook_url" {
  description = "Discord webhook URL for dev secret change notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "discord_secret_name" {
  description = "Secrets Manager secret name containing Discord webhook URLs"
  type        = string
  default     = ""
}

variable "staging_warning_webhook_key" {
  description = "Webhook key for staging/prod warning notifications"
  type        = string
  default     = "securityWarningWebhookUrl"
}

variable "staging_info_webhook_key" {
  description = "Webhook key for staging/prod info notifications"
  type        = string
  default     = "securityInfoWebhookUrl"
}

variable "dev_warning_webhook_key" {
  description = "Webhook key for dev warning notifications"
  type        = string
  default     = "warningWebhookUrl"
}

variable "dev_info_webhook_key" {
  description = "Webhook key for dev info notifications"
  type        = string
  default     = "infoWebhookUrl"
}

variable "discord_username" {
  description = "Discord bot username"
  type        = string
  default     = "playball-secret-bot"
}
