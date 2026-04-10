#############################################
# IAM Module - Outputs
#############################################

output "group_name" {
  description = "IAM group name"
  value       = length(aws_iam_group.team) > 0 ? aws_iam_group.team[0].name : null
}

output "user_arns" {
  description = "Map of IAM user ARNs"
  value       = { for k, v in aws_iam_user.users : k => v.arn }
}

output "user_names" {
  description = "Map of IAM user names"
  value       = { for k, v in aws_iam_user.users : k => v.name }
}

output "devops_role_arn" {
  description = "DevOps IAM role ARN"
  value       = length(aws_iam_role.devops) > 0 ? aws_iam_role.devops[0].arn : null
}

output "devops_role_name" {
  description = "DevOps IAM role name"
  value       = length(aws_iam_role.devops) > 0 ? aws_iam_role.devops[0].name : null
}

output "developer_role_arn" {
  description = "Developer IAM role ARN"
  value       = length(aws_iam_role.developer) > 0 ? aws_iam_role.developer[0].arn : null
}

output "secure_role_arn" {
  description = "Secure IAM role ARN"
  value       = length(aws_iam_role.secure) > 0 ? aws_iam_role.secure[0].arn : null
}

output "aws_lb_controller_role_arn" {
  description = "AWS Load Balancer Controller IAM role ARN"
  value       = length(aws_iam_role.aws_lb_controller) > 0 ? aws_iam_role.aws_lb_controller[0].arn : null
}

output "argocd_role_arn" {
  description = "ArgoCD IAM role ARN"
  value       = length(aws_iam_role.argocd) > 0 ? aws_iam_role.argocd[0].arn : null
}
