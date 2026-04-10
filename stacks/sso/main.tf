#############################################
# AWS IAM Identity Center (SSO) Configuration
#############################################
#
# 구조:
# - Groups: DEV, PM, CS, CN, DevOps
# - Permission Sets: DevOps-Dev, DevOps-Staging, Developer-Dev, Developer-Staging, ReadOnly
# - 봇 계정 (bot-*)은 기존 IAM 유지
#
#############################################

data "aws_caller_identity" "current" {}

data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn  = one(data.aws_ssoadmin_instances.this.arns)
  identity_store_id = one(data.aws_ssoadmin_instances.this.identity_store_ids)
  account_id        = data.aws_caller_identity.current.account_id
}
