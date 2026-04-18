#############################################
# S3 Module — 환경별 버킷 생성
#############################################

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "project" {
  description = "Project name for bucket prefix"
  type        = string
  default     = "playball"
}

variable "enable_monitoring_buckets" {
  description = "Create Loki/Tempo/Thanos buckets"
  type        = bool
  default     = true
}

variable "enable_ai_audit_bucket" {
  description = "Create AI audit bucket"
  type        = bool
  default     = true
}

variable "enable_archive_bucket" {
  description = "Create long-term retention archive bucket"
  type        = bool
  default     = false
}

variable "backup_lifecycle_rules" {
  description = "Lifecycle rules for backup bucket"
  type = list(object({
    id              = string
    prefix          = string
    expiration_days = number
  }))
  default = []
}

variable "archive_lifecycle_rules" {
  description = "Lifecycle rules for archive bucket"
  type = list(object({
    id                 = string
    prefix             = string
    expiration_days    = number
    transition_days    = optional(number)
    transition_storage = optional(string)
  }))
  default = []
}

locals {
  prefix = "${var.project}-${var.environment}"
}

#############################################
# Monitoring Storage
#############################################

resource "aws_s3_bucket" "loki" {
  count  = var.enable_monitoring_buckets ? 1 : 0
  bucket = "${local.prefix}-loki"
  tags   = { Name = "${local.prefix}-loki", Purpose = "loki-logs" }
}

resource "aws_s3_bucket" "tempo" {
  count  = var.enable_monitoring_buckets ? 1 : 0
  bucket = "${local.prefix}-tempo"
  tags   = { Name = "${local.prefix}-tempo", Purpose = "tempo-traces" }
}

resource "aws_s3_bucket" "thanos" {
  count  = var.enable_monitoring_buckets ? 1 : 0
  bucket = "${local.prefix}-thanos"
  tags   = { Name = "${local.prefix}-thanos", Purpose = "thanos-metrics" }
}

resource "aws_s3_bucket" "ai_audit" {
  count  = var.enable_ai_audit_bucket ? 1 : 0
  bucket = "${local.prefix}-ai-audit"
  tags   = { Name = "${local.prefix}-ai-audit", Purpose = "ai-defense-audit" }
}

#############################################
# Backup Bucket
#############################################

resource "aws_s3_bucket" "backup" {
  bucket = "${local.prefix}-backup"
  tags   = { Name = "${local.prefix}-backup", Purpose = "db-logs-backup" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket                  = aws_s3_bucket.backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  count  = length(var.backup_lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.backup.id

  dynamic "rule" {
    for_each = var.backup_lifecycle_rules
    content {
      id     = rule.value.id
      status = "Enabled"
      filter { prefix = rule.value.prefix }
      expiration { days = rule.value.expiration_days }
    }
  }
}

#############################################
# Archive Bucket
#############################################

resource "aws_s3_bucket" "archive" {
  count  = var.enable_archive_bucket ? 1 : 0
  bucket = "${local.prefix}-retention-archive"
  tags   = { Name = "${local.prefix}-retention-archive", Purpose = "long-term-retention" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  count  = var.enable_archive_bucket ? 1 : 0
  bucket = aws_s3_bucket.archive[0].id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "archive" {
  count                   = var.enable_archive_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.archive[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "archive" {
  count  = var.enable_archive_bucket ? 1 : 0
  bucket = aws_s3_bucket.archive[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "archive" {
  count  = var.enable_archive_bucket && length(var.archive_lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.archive[0].id

  dynamic "rule" {
    for_each = var.archive_lifecycle_rules
    content {
      id     = rule.value.id
      status = "Enabled"
      filter { prefix = rule.value.prefix }

      dynamic "transition" {
        for_each = rule.value.transition_days != null ? [1] : []
        content {
          days          = rule.value.transition_days
          storage_class = rule.value.transition_storage
        }
      }

      expiration { days = rule.value.expiration_days }
    }
  }
}

#############################################
# Outputs
#############################################

output "loki_bucket" { value = var.enable_monitoring_buckets ? aws_s3_bucket.loki[0].id : null }
output "tempo_bucket" { value = var.enable_monitoring_buckets ? aws_s3_bucket.tempo[0].id : null }
output "thanos_bucket" { value = var.enable_monitoring_buckets ? aws_s3_bucket.thanos[0].id : null }
output "ai_audit_bucket" { value = var.enable_ai_audit_bucket ? aws_s3_bucket.ai_audit[0].id : null }
output "backup_bucket" { value = aws_s3_bucket.backup.id }
output "archive_bucket" { value = var.enable_archive_bucket ? aws_s3_bucket.archive[0].id : null }
