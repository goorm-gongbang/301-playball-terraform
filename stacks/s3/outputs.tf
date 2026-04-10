output "backup_bucket_id" {
  description = "Backup bucket ID"
  value       = aws_s3_bucket.backup.id
}

output "backup_bucket_arn" {
  description = "Backup bucket ARN"
  value       = aws_s3_bucket.backup.arn
}

output "audit_logs_bucket_id" {
  description = "Audit logs bucket ID"
  value       = aws_s3_bucket.audit_logs.id
}

output "audit_logs_bucket_arn" {
  description = "Audit logs bucket ARN"
  value       = aws_s3_bucket.audit_logs.arn
}

output "archive_bucket_id" {
  description = "Archive bucket ID"
  value       = aws_s3_bucket.archive.id
}

output "archive_bucket_arn" {
  description = "Archive bucket ARN"
  value       = aws_s3_bucket.archive.arn
}

output "assets_bucket_id" {
  description = "Assets bucket ID"
  value       = aws_s3_bucket.assets.id
}

output "assets_bucket_arn" {
  description = "Assets bucket ARN"
  value       = aws_s3_bucket.assets.arn
}

output "ai_data_bucket_id" {
  description = "AI data bucket ID"
  value       = aws_s3_bucket.ai_data.id
}

output "ai_data_bucket_arn" {
  description = "AI data bucket ARN"
  value       = aws_s3_bucket.ai_data.arn
}

output "ai_backup_bucket_id" {
  description = "AI backup bucket ID"
  value       = aws_s3_bucket.ai_backup.id
}

output "ai_backup_bucket_arn" {
  description = "AI backup bucket ARN"
  value       = aws_s3_bucket.ai_backup.arn
}

output "all_bucket_arns" {
  description = "All S3 bucket ARNs"
  value = [
    aws_s3_bucket.backup.arn,
    aws_s3_bucket.audit_logs.arn,
    aws_s3_bucket.archive.arn,
    aws_s3_bucket.assets.arn,
    aws_s3_bucket.ai_data.arn,
    aws_s3_bucket.ai_backup.arn,
  ]
}
