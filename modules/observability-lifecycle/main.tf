#############################################
# Observability Object Storage Lifecycle
# Loki / Tempo / Thanos S3 lifecycle management
#############################################

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = var.bucket_lifecycle

  bucket = each.key

  rule {
    id     = each.value.rule_id
    status = "Enabled"

    filter {
      prefix = ""
    }

    dynamic "transition" {
      for_each = each.value.transition_days == null ? [] : [1]
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
