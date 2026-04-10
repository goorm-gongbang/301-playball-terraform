#############################################
# Ops Alerting Module - Variables
#############################################

variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string
}

variable "owner_name" {
  description = "Owner name for resource naming"
  type        = string
  default     = "goormgb"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

#############################################
# Discord
#############################################

variable "discord_secret_name" {
  description = "Secrets Manager에 저장된 Discord webhook URL 시크릿 이름"
  type        = string
}

variable "critical_mention_text" {
  description = "Critical 알람 시 Discord 멘션 텍스트"
  type        = string
  default     = "@개발팀 @admins"
}

#############################################
# Redis Alarms
#############################################

variable "redis_cache_cluster_id" {
  description = "ElastiCache cluster ID (e.g. goormgb-staging-redis-001)"
  type        = string
}

variable "redis_warning_threshold" {
  description = "Redis memory warning threshold (%)"
  type        = number
  default     = 80
}

variable "redis_critical_threshold" {
  description = "Redis memory critical threshold (%)"
  type        = number
  default     = 90
}

variable "alarms_enabled" {
  description = "CloudWatch alarm actions 활성화"
  type        = bool
  default     = true
}

#############################################
# RDS Backup Checker
#############################################

variable "rds_instance_identifier" {
  description = "RDS instance identifier"
  type        = string
}

variable "backup_s3_bucket" {
  description = "보조 백업 S3 bucket"
  type        = string
  default     = "playball-backup"
}

variable "backup_check_schedule" {
  description = "백업 체크 스케줄 (EventBridge cron)"
  type        = string
  default     = "cron(10 0 * * ? *)"
}

variable "snapshot_stale_hours" {
  description = "스냅샷이 오래됐다고 판단하는 시간"
  type        = number
  default     = 36
}

variable "dump_stale_hours" {
  description = "S3 덤프가 오래됐다고 판단하는 시간"
  type        = number
  default     = 36
}
