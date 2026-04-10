output "trail_arn" {
  description = "CloudTrail ARN"
  value       = var.enabled ? aws_cloudtrail.this[0].arn : null
}

output "trail_name" {
  description = "CloudTrail name"
  value       = var.enabled ? aws_cloudtrail.this[0].name : null
}

output "log_group_name" {
  description = "CloudWatch Logs group name"
  value       = var.enabled ? aws_cloudwatch_log_group.this[0].name : null
}

output "source_arn" {
  description = "CloudTrail source ARN for S3 bucket policy"
  value       = var.enabled ? aws_cloudtrail.this[0].arn : null
}
