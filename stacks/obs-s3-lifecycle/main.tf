#############################################
# Observability S3 & Lifecycle
# - Loki / Tempo / Thanos S3 buckets (staging + prod)
# - S3 lifecycle policies
#############################################

locals {
  buckets = {
    "playball-staging-loki"   = { environment = "staging", service = "loki" }
    "playball-staging-tempo"  = { environment = "staging", service = "tempo" }
    "playball-staging-thanos"     = { environment = "staging", service = "thanos" }
    "playball-staging-clickhouse" = { environment = "staging", service = "clickhouse" }
    # Prod - 주석 해제하여 활성화
    # "playball-prod-loki"      = { environment = "prod", service = "loki" }
    # "playball-prod-tempo"     = { environment = "prod", service = "tempo" }
    # "playball-prod-thanos"    = { environment = "prod", service = "thanos" }
  }

  lifecycle_config = {
    "playball-staging-loki" = {
      rule_id         = "expiry-7days"
      expiration_days = 7
    }
    "playball-staging-tempo" = {
      rule_id         = "expiry-7days"
      expiration_days = 7
    }
    "playball-staging-thanos" = {
      rule_id         = "expiry-14days"
      expiration_days = 14
    }
    "playball-staging-clickhouse" = {
      rule_id         = "expiry-14days"
      expiration_days = 14
    }
    # Prod - 주석 해제하여 활성화
    # "playball-prod-loki" = {
    #   rule_id            = "expiry-90days"
    #   expiration_days    = 90
    #   transition_days    = 30
    #   transition_storage = "GLACIER"
    # }
    # "playball-prod-tempo" = {
    #   rule_id            = "expiry-90days"
    #   expiration_days    = 90
    #   transition_days    = 30
    #   transition_storage = "GLACIER"
    # }
    # "playball-prod-thanos" = {
    #   rule_id            = "expiry-180days"
    #   expiration_days    = 180
    #   transition_days    = 90
    #   transition_storage = "GLACIER"
    # }
  }
}

#############################################
# S3 Buckets
#############################################

resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket = each.key

  tags = {
    Name        = each.key
    Environment = each.value.environment
    Service     = each.value.service
    Purpose     = "observability"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.buckets

  bucket                  = aws_s3_bucket.this[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#############################################
# Lifecycle Policies
#############################################

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = local.lifecycle_config

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    id     = each.value.rule_id
    status = "Enabled"

    filter {
      prefix = ""
    }

    dynamic "transition" {
      for_each = lookup(each.value, "transition_days", null) != null ? [1] : []
      content {
        days          = each.value.transition_days
        storage_class = each.value.transition_storage
      }
    }

    expiration {
      days = each.value.expiration_days
    }
  }
}

#############################################
# Outputs
#############################################

output "bucket_ids" {
  description = "Observability S3 bucket IDs"
  value       = { for k, v in aws_s3_bucket.this : k => v.id }
}

output "bucket_arns" {
  description = "Observability S3 bucket ARNs"
  value       = { for k, v in aws_s3_bucket.this : k => v.arn }
}
