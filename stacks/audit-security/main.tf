#############################################
# S3 Audit & Security Stack
# - audit-logs S3 bucket
# - CloudTrail
# - Security Events (EventBridge → Lambda → Discord)
# - Audit Events (S3 delete detection → Lambda → Discord)
#############################################

locals {
  project_name = "goormgb"
  aws_region   = "ap-northeast-2"
  account_id   = data.aws_caller_identity.current.account_id
}

#############################################
# S3: Audit Logs Bucket
#############################################

module "cloudtrail" {
  source = "../../modules/cloudtrail"

  project_name = local.project_name
  aws_region   = local.aws_region
  enabled      = true

  audit_logs_bucket_id = aws_s3_bucket.audit_logs.id
  s3_key_prefix        = "cloudtrail"
  log_retention_days   = 90

  tracked_s3_bucket_arns = [
    aws_s3_bucket.audit_logs.arn
  ]
}

resource "aws_s3_bucket" "audit_logs" {
  bucket = "${local.project_name}-audit-logs"
  tags   = { Name = "${local.project_name}-audit-logs", Purpose = "audit-log-archive" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket                  = aws_s3_bucket.audit_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "audit_logs" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [aws_s3_bucket.audit_logs.arn, "${aws_s3_bucket.audit_logs.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  dynamic "statement" {
    for_each = module.cloudtrail.source_arn != null ? [1] : []
    content {
      sid    = "AWSCloudTrailAclCheck"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["cloudtrail.amazonaws.com"]
      }

      actions   = ["s3:GetBucketAcl"]
      resources = [aws_s3_bucket.audit_logs.arn]

      condition {
        test     = "StringEquals"
        variable = "aws:SourceArn"
        values   = [module.cloudtrail.source_arn]
      }
    }
  }

  dynamic "statement" {
    for_each = module.cloudtrail.source_arn != null ? [1] : []
    content {
      sid    = "AWSCloudTrailWrite"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["cloudtrail.amazonaws.com"]
      }

      actions   = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.audit_logs.arn}/cloudtrail/AWSLogs/${local.account_id}/*"]

      condition {
        test     = "StringEquals"
        variable = "s3:x-amz-acl"
        values   = ["bucket-owner-full-control"]
      }

      condition {
        test     = "StringEquals"
        variable = "aws:SourceArn"
        values   = [module.cloudtrail.source_arn]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  policy = data.aws_iam_policy_document.audit_logs.json
}

resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    id     = "cloudtrail-400days"
    status = "Enabled"
    filter { prefix = "cloudtrail/" }
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
    expiration { days = 400 }
  }

  rule {
    id     = "cloudtrail-digest-400days"
    status = "Enabled"
    filter { prefix = "cloudtrail-digest/" }
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
    expiration { days = 400 }
  }

  rule {
    id     = "legacy-cloudtrail-management-events-400days"
    status = "Enabled"
    filter { prefix = "legacy-cloudtrail/management-events/" }
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
    expiration { days = 400 }
  }

  rule {
    id     = "audit-reports-400days"
    status = "Enabled"
    filter { prefix = "audit-reports/" }
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
    expiration { days = 400 }
  }

  rule {
    id     = "lifecycle-expiration-summary-400days"
    status = "Enabled"
    filter { prefix = "lifecycle-expiration-summary/" }
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
    expiration { days = 400 }
  }

  rule {
    id     = "pis-access-730days"
    status = "Enabled"
    filter { prefix = "pis-access/" }
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
    expiration { days = 730 }
  }
}

#############################################
# Security Events (EventBridge → Lambda → Discord)
#############################################

module "security_events" {
  source = "../../modules/security-events"

  project_name = local.project_name
  aws_region   = local.aws_region
  account_id   = local.account_id
  enabled      = true

  discord_secret_name   = "staging/monitoring/discord-webhook-alerts"
  discord_username      = "playball-security-bot"
  critical_mention_text = "@개발팀 @admins"
}

#############################################
# Audit Events (S3 delete → Lambda → Discord + S3)
#############################################

module "audit_events" {
  source = "../../modules/audit-events"

  project_name = local.project_name
  aws_region   = local.aws_region
  account_id   = local.account_id
  enabled      = true

  audit_logs_bucket_id  = aws_s3_bucket.audit_logs.id
  audit_logs_bucket_arn = aws_s3_bucket.audit_logs.arn
  summary_prefix        = "lifecycle-expiration-summary"

  monitored_bucket_names = [
    "playball-backup",
    "playball-audit-logs",
    "playball-archive",
    "playball-ai-data",
    "playball-ai-backup"
  ]

  discord_secret_name   = "staging/monitoring/discord-webhook-alerts"
  discord_username      = "playball-audit-bot"
  critical_mention_text = "@개발팀 @admins"
}

#############################################
# Outputs
#############################################

output "audit_logs_bucket_id" {
  value = aws_s3_bucket.audit_logs.id
}

output "audit_logs_bucket_arn" {
  value = aws_s3_bucket.audit_logs.arn
}

output "cloudtrail_trail_arn" {
  value = module.cloudtrail.trail_arn
}

output "security_events_lambda_name" {
  value = module.security_events.lambda_name
}

output "audit_events_lambda_name" {
  value = module.audit_events.lambda_name
}
