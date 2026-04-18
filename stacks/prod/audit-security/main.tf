#############################################
# S3 Audit & Security Stack
# - audit-logs S3 bucket
# - CloudTrail
# - Security Events (EventBridge → Lambda → Discord)
# - Audit Events (S3 delete detection → Lambda → Discord)
#############################################

locals {
  project_name = "playball"
  aws_region   = "ap-northeast-2"
  account_id   = data.aws_caller_identity.current.account_id
  trail_arn    = "arn:aws:cloudtrail:${local.aws_region}:${local.account_id}:trail/${local.project_name}-audit-trail"
  monitored_bucket_names = [
    aws_s3_bucket.audit_logs.id,
    "playball-web-backup",
    "playball-retention-archive",
    "playball-prod-tfstate",
    "playball-staging-loki",
    "playball-staging-tempo",
    "playball-staging-thanos",
    "playball-prod-loki",
    "playball-prod-tempo",
    "playball-prod-thanos",
    "playball-staging-ai-audit",
    "playball-prod-ai-audit",
    "playball-staging-clickhouse",
    "playball-prod-clickhouse"
  ]
  observability_bucket_names = [
    "playball-staging-loki",
    "playball-staging-tempo",
    "playball-staging-thanos",
    "playball-prod-loki",
    "playball-prod-tempo",
    "playball-prod-thanos",
  ]
  tracked_s3_bucket_arns = [for name in local.monitored_bucket_names : "arn:aws:s3:::${name}"]
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

  tracked_s3_bucket_arns = local.tracked_s3_bucket_arns
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

  statement {
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
      values   = [local.trail_arn]
    }
  }

  statement {
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
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
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

  discord_secret_name   = var.monitoring_secret_name
  discord_username      = "playball-security-bot"
  critical_mention_text = var.critical_mention_text
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

  monitored_bucket_names     = local.monitored_bucket_names
  observability_bucket_names = local.observability_bucket_names

  discord_secret_name   = var.monitoring_secret_name
  discord_username      = "playball-audit-bot"
  critical_mention_text = var.critical_mention_text
}

#############################################
# Secret Change Events (EventBridge → Lambda → Discord)
#############################################

module "secret_change_events" {
  source = "../../modules/secret-change-events"

  project_name = local.project_name
  aws_region   = local.aws_region
  account_id   = local.account_id
  enabled      = true

  staging_discord_webhook_url = var.secret_change_staging_discord_webhook_url
  dev_discord_webhook_url     = var.secret_change_dev_discord_webhook_url
  discord_secret_name         = var.monitoring_secret_name
  staging_warning_webhook_key = "securityWarningWebhookUrl"
  staging_info_webhook_key    = "securityInfoWebhookUrl"
  dev_warning_webhook_key     = "warningWebhookUrl"
  dev_info_webhook_key        = "infoWebhookUrl"
  discord_username            = "playball-secret-bot"
}

#############################################
# Spot Interruption Events (EventBridge → Lambda → Discord)
#############################################

module "spot_interruption_events" {
  source = "../../modules/spot-interruption-events"

  project_name = local.project_name
  aws_region   = local.aws_region
  account_id   = local.account_id
  enabled      = true

  cluster_name        = var.cluster_name
  discord_username    = "playball-spot-bot"
  mention_text        = ""
  discord_webhook_url = "https://discord.com/api/webhooks/1484105176867536988/N3C_085Bf_sPF57n8mggbDIW8DDhGmJkcmN8O1jhoH5FNAS-0KjhgDOX5DZLNqdXdq2S"
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

output "secret_change_events_lambda_name" {
  value = module.secret_change_events.lambda_name
}

output "spot_interruption_events_lambda_name" {
  value = module.spot_interruption_events.lambda_name
}
