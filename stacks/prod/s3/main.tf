#############################################
# Prod S3 Buckets
#############################################

#############################################
# Monitoring Storage (Loki, Tempo, Thanos)
#############################################

resource "aws_s3_bucket" "loki" {
  bucket = "playball-prod-loki"
  tags   = { Name = "playball-prod-loki", Purpose = "loki-logs" }
}

resource "aws_s3_bucket" "tempo" {
  bucket = "playball-prod-tempo"
  tags   = { Name = "playball-prod-tempo", Purpose = "tempo-traces" }
}

resource "aws_s3_bucket" "thanos" {
  bucket = "playball-prod-thanos"
  tags   = { Name = "playball-prod-thanos", Purpose = "thanos-metrics" }
}

resource "aws_s3_bucket" "ai_audit" {
  bucket = "playball-prod-ai-audit"
  tags   = { Name = "playball-prod-ai-audit", Purpose = "ai-defense-audit" }
}

#############################################
# Backup Bucket (DB, Logs)
#############################################

resource "aws_s3_bucket" "backup" {
  bucket = "playball-prod-backup"
  tags   = { Name = "playball-prod-backup", Purpose = "db-logs-backup" }
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
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "prod-postgres-14days"
    status = "Enabled"
    filter { prefix = "postgres/" }
    expiration { days = 14 }
  }

  rule {
    id     = "prod-infra-logs-14days"
    status = "Enabled"
    filter { prefix = "logs/infra/" }
    expiration { days = 14 }
  }

  rule {
    id     = "prod-service-logs-14days"
    status = "Enabled"
    filter { prefix = "logs/service/" }
    expiration { days = 14 }
  }

  rule {
    id     = "prod-payment-logs-90days"
    status = "Enabled"
    filter { prefix = "logs/payment/" }
    expiration { days = 90 }
  }
}

#############################################
# Archive Bucket (법적 장기 보관)
#############################################

resource "aws_s3_bucket" "archive" {
  bucket = "playball-prod-retention-archive"
  tags   = { Name = "playball-prod-retention-archive", Purpose = "long-term-retention" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "archive" {
  bucket                  = aws_s3_bucket.archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "archive" {
  bucket = aws_s3_bucket.archive.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

  rule {
    id     = "member-retention-3years"
    status = "Enabled"
    filter { prefix = "member-retention/" }
    transition { days = 30, storage_class = "DEEP_ARCHIVE" }
    expiration { days = 1095 }
  }

  rule {
    id     = "commerce-retention-5years"
    status = "Enabled"
    filter { prefix = "commerce-retention/" }
    transition { days = 30, storage_class = "DEEP_ARCHIVE" }
    expiration { days = 1825 }
  }
}

#############################################
# Outputs
#############################################

output "loki_bucket" { value = aws_s3_bucket.loki.id }
output "tempo_bucket" { value = aws_s3_bucket.tempo.id }
output "thanos_bucket" { value = aws_s3_bucket.thanos.id }
output "ai_audit_bucket" { value = aws_s3_bucket.ai_audit.id }
output "backup_bucket" { value = aws_s3_bucket.backup.id }
output "archive_bucket" { value = aws_s3_bucket.archive.id }
