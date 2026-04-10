#############################################
# SSO Groups
#############################################

resource "aws_identitystore_group" "cn" {
  identity_store_id = local.identity_store_id
  display_name      = "CN"
  description       = "CN (Cloud Native) - DevOps/인프라 관리 권한"
}

resource "aws_identitystore_group" "dev" {
  identity_store_id = local.identity_store_id
  display_name      = "DEV"
  description       = "개발팀 - Developer 권한"
}

resource "aws_identitystore_group" "sc" {
  identity_store_id = local.identity_store_id
  display_name      = "SC"
  description       = "보안팀 - Security 권한"
}

resource "aws_identitystore_group" "fe" {
  identity_store_id = local.identity_store_id
  display_name      = "FE"
  description       = "프론트엔드팀 - Frontend 권한"
}

resource "aws_identitystore_group" "pm" {
  identity_store_id = local.identity_store_id
  display_name      = "PM"
  description       = "기획팀 - Project Manager 권한"
}

#############################################
# Group ID Outputs (for assignments)
#############################################

locals {
  group_ids = {
    CN  = aws_identitystore_group.cn.group_id
    DEV = aws_identitystore_group.dev.group_id
    SC  = aws_identitystore_group.sc.group_id
    FE  = aws_identitystore_group.fe.group_id
    PM  = aws_identitystore_group.pm.group_id
  }
}
