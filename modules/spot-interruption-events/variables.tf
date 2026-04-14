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
  description = "Enable spot interruption event pipeline"
  type        = bool
  default     = true
}

variable "discord_webhook_url" {
  description = "Discord webhook URL for spot interruption notifications"
  type        = string
}

variable "discord_username" {
  description = "Discord bot username"
  type        = string
  default     = "playball-spot-bot"
}

variable "mention_text" {
  description = "Discord mention text prepended to messages"
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "EKS cluster name to include in notifications"
  type        = string
  default     = ""
}
