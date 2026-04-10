#############################################
# SSO Outputs
#############################################

output "sso_start_url" {
  description = "SSO 로그인 URL"
  value       = "https://${local.identity_store_id}.awsapps.com/start"
}

output "sso_groups" {
  description = "SSO Groups"
  value = {
    CN  = aws_identitystore_group.cn.group_id
    DEV = aws_identitystore_group.dev.group_id
    SC  = aws_identitystore_group.sc.group_id
  }
}

output "permission_sets" {
  description = "Permission Sets"
  value = {
    devops_dev        = aws_ssoadmin_permission_set.devops["dev"].name
    devops_staging    = aws_ssoadmin_permission_set.devops["staging"].name
    devops_prod       = aws_ssoadmin_permission_set.devops["prod"].name
    developer_staging = aws_ssoadmin_permission_set.developer["staging"].name
    developer_prod    = aws_ssoadmin_permission_set.developer["prod"].name
    security_prod     = aws_ssoadmin_permission_set.security["prod"].name
  }
}

output "sso_users" {
  description = "SSO Users"
  value       = [for u in aws_identitystore_user.users : u.user_name]
}

output "cli_config_example" {
  description = "AWS CLI SSO 설정 예시"
  value       = <<-EOT
    # ~/.aws/config 에 추가:

    [profile goormgb-dev]
    sso_start_url = https://${local.identity_store_id}.awsapps.com/start
    sso_region = ap-northeast-2
    sso_account_id = ${local.account_id}
    sso_role_name = DevOps-Dev
    region = ap-northeast-2

    [profile goormgb-staging]
    sso_start_url = https://${local.identity_store_id}.awsapps.com/start
    sso_region = ap-northeast-2
    sso_account_id = ${local.account_id}
    sso_role_name = DevOps-Staging
    region = ap-northeast-2

    [profile goormgb-prod]
    sso_start_url = https://${local.identity_store_id}.awsapps.com/start
    sso_region = ap-northeast-2
    sso_account_id = ${var.prod_account_id}
    sso_role_name = DevOps-Prod
    region = ap-northeast-2

    # 로그인: aws sso login --profile goormgb-prod
  EOT
}
