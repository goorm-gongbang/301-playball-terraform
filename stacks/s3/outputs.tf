output "backup_bucket_id" {
  description = "Backup bucket ID"
  value       = aws_s3_bucket.backup.id
}

output "backup_bucket_arn" {
  description = "Backup bucket ARN"
  value       = aws_s3_bucket.backup.arn
}

output "archive_bucket_id" {
  description = "Archive bucket ID"
  value       = aws_s3_bucket.archive.id
}

output "archive_bucket_arn" {
  description = "Archive bucket ARN"
  value       = aws_s3_bucket.archive.arn
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
