output "cn_group_arn" {
  description = "CN IAM Group ARN"
  value       = aws_iam_group.cn.arn
}

output "cn_group_name" {
  description = "CN IAM Group name"
  value       = aws_iam_group.cn.name
}

output "cicd_bots_group_name" {
  description = "CICD Bots group name"
  value       = aws_iam_group.cicd_bots.name
}

output "cn_common_access_policy_arn" {
  description = "CN common access policy ARN"
  value       = aws_iam_policy.cn_common_access.arn
}
