#############################################
# SSO Module - Outputs
#############################################

output "instance_arn" {
  description = "SSO instance ARN"
  value       = local.instance_arn
}

output "identity_store_id" {
  description = "Identity Store ID"
  value       = local.identity_store_id
}

output "permission_set_arns" {
  description = "Permission Set ARNs"
  value = {
    admin     = aws_ssoadmin_permission_set.admin.arn
    devops    = aws_ssoadmin_permission_set.devops.arn
    developer = aws_ssoadmin_permission_set.developer.arn
    readonly  = aws_ssoadmin_permission_set.readonly.arn
  }
}

output "group_ids" {
  description = "Group IDs"
  value       = { for k, v in aws_identitystore_group.groups : k => v.group_id }
}

output "user_ids" {
  description = "User IDs"
  value       = { for k, v in aws_identitystore_user.users : k => v.user_id }
}

output "sso_start_url" {
  description = "SSO Start URL (Portal)"
  value       = "https://${tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]}.awsapps.com/start"
}
