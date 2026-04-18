#############################################
# Staging S3 Buckets
#############################################

#############################################
# Monitoring Storage (Loki, Tempo, Thanos)
#############################################

resource "aws_s3_bucket" "loki" {
  bucket = "playball-staging-loki"
  tags   = { Name = "playball-staging-loki", Purpose = "loki-logs" }
}

resource "aws_s3_bucket" "tempo" {
  bucket = "playball-staging-tempo"
  tags   = { Name = "playball-staging-tempo", Purpose = "tempo-traces" }
}

resource "aws_s3_bucket" "thanos" {
  bucket = "playball-staging-thanos"
  tags   = { Name = "playball-staging-thanos", Purpose = "thanos-metrics" }
}

resource "aws_s3_bucket" "ai_audit" {
  bucket = "playball-staging-ai-audit"
  tags   = { Name = "playball-staging-ai-audit", Purpose = "ai-defense-audit" }
}

#############################################
# Backup Bucket (DB, Logs)
#############################################

resource "aws_s3_bucket" "backup" {
  bucket = "playball-staging-backup"
  tags   = { Name = "playball-staging-backup", Purpose = "db-logs-backup" }
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
    id     = "staging-postgres-14days"
    status = "Enabled"
    filter { prefix = "postgres/" }
    expiration { days = 14 }
  }

  rule {
    id     = "staging-infra-logs-14days"
    status = "Enabled"
    filter { prefix = "logs/infra/" }
    expiration { days = 14 }
  }

  rule {
    id     = "staging-service-logs-14days"
    status = "Enabled"
    filter { prefix = "logs/service/" }
    expiration { days = 14 }
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
