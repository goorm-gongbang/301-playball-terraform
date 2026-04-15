variable "secret_change_staging_discord_webhook_url" {
  description = "Discord webhook URL for staging/prod secret change notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "secret_change_dev_discord_webhook_url" {
  description = "Discord webhook URL for dev secret change notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "monitoring_secret_name" {
  description = "Secrets Manager secret name containing Discord webhook URLs"
  type        = string
  default     = "staging/monitoring"
}

variable "critical_mention_text" {
  description = "Mention text prepended to critical alerts"
  type        = string
  default     = "@개발팀 @admins"
}

variable "cluster_name" {
  description = "Cluster name for spot interruption alerts"
  type        = string
  default     = "goormgb-staging-eks"
}
