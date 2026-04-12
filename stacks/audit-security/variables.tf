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
