#############################################
# SSO Account Assignments
#############################################
#
# 그룹 → Permission Set → 계정 할당
#
# 본계정(497012402578): Dev-CN
# ca-staging(406223549139): Staging-CN, Staging-Dev, Staging-SC, Staging-AI
# ca-prod(990521646433): Prod-CN, Prod-Dev, Prod-SC, Prod-AI
#
#############################################

#############################################
# 본계정 (497012402578) - Dev
#############################################

# CN 그룹 → Dev-CN
resource "aws_ssoadmin_account_assignment" "cn_dev_cn" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.dev_cn.arn

  principal_id   = aws_identitystore_group.cn.group_id
  principal_type = "GROUP"

  target_id   = local.account_id
  target_type = "AWS_ACCOUNT"
}

#############################################
# ca-staging (406223549139)
#############################################

# CN 그룹 → Staging-CN
resource "aws_ssoadmin_account_assignment" "cn_staging_cn" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.staging_cn.arn

  principal_id   = aws_identitystore_group.cn.group_id
  principal_type = "GROUP"

  target_id   = var.staging_account_id
  target_type = "AWS_ACCOUNT"
}

# DEV 그룹 → Staging-Dev
resource "aws_ssoadmin_account_assignment" "dev_staging_dev" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.staging_dev.arn

  principal_id   = aws_identitystore_group.dev.group_id
  principal_type = "GROUP"

  target_id   = var.staging_account_id
  target_type = "AWS_ACCOUNT"
}

# SC 그룹 → Staging-SC
resource "aws_ssoadmin_account_assignment" "sc_staging_sc" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.staging_sc.arn

  principal_id   = aws_identitystore_group.sc.group_id
  principal_type = "GROUP"

  target_id   = var.staging_account_id
  target_type = "AWS_ACCOUNT"
}

# AI 그룹 → Staging-AI
resource "aws_ssoadmin_account_assignment" "ai_staging_ai" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.staging_ai.arn

  principal_id   = aws_identitystore_group.ai.group_id
  principal_type = "GROUP"

  target_id   = var.staging_account_id
  target_type = "AWS_ACCOUNT"
}

#############################################
# ca-prod (990521646433)
#############################################

# CN 그룹 → Prod-CN
resource "aws_ssoadmin_account_assignment" "cn_prod_cn" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.prod_cn.arn

  principal_id   = aws_identitystore_group.cn.group_id
  principal_type = "GROUP"

  target_id   = var.prod_account_id
  target_type = "AWS_ACCOUNT"
}

# DEV 그룹 → Prod-Dev
resource "aws_ssoadmin_account_assignment" "dev_prod_dev" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.prod_dev.arn

  principal_id   = aws_identitystore_group.dev.group_id
  principal_type = "GROUP"

  target_id   = var.prod_account_id
  target_type = "AWS_ACCOUNT"
}

# SC 그룹 → Prod-SC
resource "aws_ssoadmin_account_assignment" "sc_prod_sc" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.prod_sc.arn

  principal_id   = aws_identitystore_group.sc.group_id
  principal_type = "GROUP"

  target_id   = var.prod_account_id
  target_type = "AWS_ACCOUNT"
}

# AI 그룹 → Prod-AI
resource "aws_ssoadmin_account_assignment" "ai_prod_ai" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.prod_ai.arn

  principal_id   = aws_identitystore_group.ai.group_id
  principal_type = "GROUP"

  target_id   = var.prod_account_id
  target_type = "AWS_ACCOUNT"
}
