#############################################
# S3 Stack
# - backup (운영 백업, 환경별 lifecycle)
# - archive (장기 보관, DEEP_ARCHIVE)
# - ai-data (AI팀 데이터)
# - ai-backup (AI팀 백업)
#############################################

#############################################
# Backup Bucket
#############################################

resource "aws_s3_bucket" "backup" {
  bucket = "${var.project_name}-backup"
  tags   = { Name = "${var.project_name}-backup", Purpose = "operations-backup" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket                  = aws_s3_bucket.backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "backup" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [aws_s3_bucket.backup.arn, "${aws_s3_bucket.backup.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "backup" {
  bucket = aws_s3_bucket.backup.id
  policy = data.aws_iam_policy_document.backup.json
}

resource "aws_s3_bucket_lifecycle_configuration" "backup" {
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
  bucket = "${var.project_name}-archive"
  tags   = { Name = "${var.project_name}-archive", Purpose = "long-term-retention" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "archive" {
  bucket                  = aws_s3_bucket.archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "archive" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [aws_s3_bucket.archive.arn, "${aws_s3_bucket.archive.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "archive" {
  bucket = aws_s3_bucket.archive.id
  policy = data.aws_iam_policy_document.archive.json
}

resource "aws_s3_bucket_versioning" "archive" {
  bucket = aws_s3_bucket.archive.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

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
# AI Data Bucket
#############################################

resource "aws_s3_bucket" "ai_data" {
  bucket = "${var.project_name}-ai-data"
  tags   = { Name = "${var.project_name}-ai-data", Team = "AI" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ai_data" {
  bucket = aws_s3_bucket.ai_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ai_data" {
  bucket                  = aws_s3_bucket.ai_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#############################################
# AI Backup Bucket
#############################################

resource "aws_s3_bucket" "ai_backup" {
  bucket = "${var.project_name}-ai-backup"
  tags   = { Name = "${var.project_name}-ai-backup", Team = "AI" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ai_backup" {
  bucket = aws_s3_bucket.ai_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ai_backup" {
  bucket                  = aws_s3_bucket.ai_backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
