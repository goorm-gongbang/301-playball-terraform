#############################################
# SSO Account Assignments
#############################################
#
# 그룹 + Permission Set → 계정 할당
#
#############################################

#############################################
# Main Account (406223549139) - Dev, Staging
#############################################

# CN 그룹 → DevOps-Dev
resource "aws_ssoadmin_account_assignment" "cn_devops_dev" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.devops["dev"].arn

  principal_id   = aws_identitystore_group.cn.group_id
  principal_type = "GROUP"

  target_id   = local.account_id
  target_type = "AWS_ACCOUNT"
}

# CN 그룹 → DevOps-Staging
resource "aws_ssoadmin_account_assignment" "cn_devops_staging" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.devops["staging"].arn

  principal_id   = aws_identitystore_group.cn.group_id
  principal_type = "GROUP"

  target_id   = local.account_id
  target_type = "AWS_ACCOUNT"
}

# DEV 그룹 → Developer-Staging
resource "aws_ssoadmin_account_assignment" "dev_developer_staging" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer["staging"].arn

  principal_id   = aws_identitystore_group.dev.group_id
  principal_type = "GROUP"

  target_id   = local.account_id
  target_type = "AWS_ACCOUNT"
}

#############################################
# Prod Account (406223549139)
#############################################

# CN 그룹 → DevOps-Prod
resource "aws_ssoadmin_account_assignment" "cn_devops_prod" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.devops["prod"].arn

  principal_id   = aws_identitystore_group.cn.group_id
  principal_type = "GROUP"

  target_id   = var.prod_account_id
  target_type = "AWS_ACCOUNT"
}

# DEV 그룹 → Developer-Prod
resource "aws_ssoadmin_account_assignment" "dev_developer_prod" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer["prod"].arn

  principal_id   = aws_identitystore_group.dev.group_id
  principal_type = "GROUP"

  target_id   = var.prod_account_id
  target_type = "AWS_ACCOUNT"
}

# SC 그룹 → Security-Prod
resource "aws_ssoadmin_account_assignment" "sc_security_prod" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security["prod"].arn

  principal_id   = aws_identitystore_group.sc.group_id
  principal_type = "GROUP"

  target_id   = var.prod_account_id
  target_type = "AWS_ACCOUNT"
}

#############################################
# FE 그룹 → FE-Access (Main Account)
#############################################

resource "aws_ssoadmin_account_assignment" "fe_access" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.frontend.arn

  principal_id   = aws_identitystore_group.fe.group_id
  principal_type = "GROUP"

  target_id   = local.account_id
  target_type = "AWS_ACCOUNT"
}

#############################################
# PM 그룹 → PM-Access (Main Account)
#############################################

resource "aws_ssoadmin_account_assignment" "pm_access" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.pm.arn

  principal_id   = aws_identitystore_group.pm.group_id
  principal_type = "GROUP"

  target_id   = local.account_id
  target_type = "AWS_ACCOUNT"
}
