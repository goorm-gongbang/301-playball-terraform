#############################################
# Observability S3 Lifecycle Module
# 환경별 Loki/Tempo/Thanos/ClickHouse/AI-Audit 버킷 lifecycle
#############################################

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "playball"
}

variable "buckets" {
  description = "Map of bucket suffix to lifecycle config"
  type = map(object({
    expiration_days    = number
    transition_days    = optional(number)
    transition_storage = optional(string)
  }))
}

locals {
  prefix = "${var.project}-${var.environment}"
}

data "aws_s3_bucket" "this" {
  for_each = var.buckets
  bucket   = "${local.prefix}-${each.key}"
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = var.buckets
  bucket   = data.aws_s3_bucket.this[each.key].id

  rule {
    id     = "expiry-${each.value.expiration_days}days"
    status = "Enabled"
    filter { prefix = "" }

    dynamic "transition" {
      for_each = each.value.transition_days != null ? [1] : []
      content {
        days          = each.value.transition_days
        storage_class = each.value.transition_storage
      }
    }

    expiration { days = each.value.expiration_days }
  }
}
