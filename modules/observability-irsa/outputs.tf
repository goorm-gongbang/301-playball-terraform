output "role_arns" {
  description = "Map of service name to IAM role ARN"
  value       = { for k, v in aws_iam_role.this : k => v.arn }
}

output "policy_arn" {
  description = "S3 access policy ARN"
  value       = aws_iam_policy.s3.arn
}
