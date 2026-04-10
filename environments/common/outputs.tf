#############################################
# Common Environment - Outputs
#############################################

# S3
output "s3_backup_bucket" {
  description = "Operations backup bucket name"
  value       = module.s3.backup_bucket_id
}

output "s3_audit_logs_bucket" {
  description = "Audit logs bucket name"
  value       = module.s3.audit_logs_bucket_id
}

output "s3_archive_bucket" {
  description = "Long-term archive bucket name"
  value       = module.s3.archive_bucket_id
}

output "s3_assets_bucket" {
  description = "Static assets bucket name"
  value       = module.s3.assets_bucket_id
}

output "s3_ai_data_bucket" {
  description = "AI data bucket name"
  value       = module.s3.ai_data_bucket_id
}

output "s3_ai_backup_bucket" {
  description = "AI backup bucket name"
  value       = module.s3.ai_backup_bucket_id
}

# IAM
output "iam_group_cn_arn" {
  description = "CN IAM Group ARN"
  value       = module.account_iam.cn_group_arn
}

# CloudTrail
output "audit_cloudtrail_trail_arn" {
  description = "Dedicated audit CloudTrail ARN"
  value       = module.cloudtrail.trail_arn
}

output "audit_cloudtrail_log_group_name" {
  description = "CloudWatch Logs group name for audit CloudTrail"
  value       = module.cloudtrail.log_group_name
}

# Security Events
output "security_event_pipeline_lambda_name" {
  description = "Security event Discord Lambda name"
  value       = module.security_events.lambda_name
}

output "security_event_pipeline_rule_name" {
  description = "Security event EventBridge rule name"
  value       = module.security_events.rule_name
}

# Audit Events
output "audit_event_pipeline_lambda_name" {
  description = "Audit event summary Lambda name"
  value       = module.audit_events.lambda_name
}

output "audit_event_pipeline_rule_name" {
  description = "Audit event EventBridge rule name"
  value       = module.audit_events.rule_name
}

# ACM
output "acm_certificate_arn" {
  description = "The ARN of the ACM certificate"
  value       = module.acm.acm_certificate_arn
}
