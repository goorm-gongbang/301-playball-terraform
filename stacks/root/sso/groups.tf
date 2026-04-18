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


resource "aws_identitystore_group" "ai" {
  identity_store_id = local.identity_store_id
  display_name      = "AI"
  description       = "AI팀 - AI/ML 워크로드 권한"
}

resource "aws_identitystore_group" "pen" {
  identity_store_id = local.identity_store_id
  display_name      = "PEN"
  description       = "침투테스트팀 - Pentest/Security 감사 권한"
}

#############################################
# Group ID Outputs (for assignments)
#############################################

locals {
  group_ids = {
    CN  = aws_identitystore_group.cn.group_id
    DEV = aws_identitystore_group.dev.group_id
    SC  = aws_identitystore_group.sc.group_id
    AI  = aws_identitystore_group.ai.group_id
    PEN = aws_identitystore_group.pen.group_id
  }
}
