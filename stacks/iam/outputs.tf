#############################################
# common/iam - Outputs
#############################################

output "cn_common_policy_arn" {
  description = "CN Common Access policy ARN"
  value       = aws_iam_policy.cn_common_access.arn
}

output "cn_staging_policy_arn" {
  description = "CN Staging Access policy ARN"
  value       = aws_iam_policy.cn_staging_access.arn
}

output "cn_prod_policy_arn" {
  description = "CN Prod Access policy ARN"
  value       = aws_iam_policy.cn_prod_access.arn
}
