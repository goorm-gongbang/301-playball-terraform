#############################################
# SSO Variables
# 참고: sso_instance_arn과 identity_store_id는 data source에서 자동 조회
#############################################

variable "management_account_id" {
  description = "Management Account ID"
  type        = string
  # terraform.tfvars에서 설정
}

#############################################
# SSO Users - 기존 IAM 사용자 기반
#############################################

variable "sso_users" {
  description = "SSO users to create"
  type = map(object({
    display_name = string
    email        = string
    groups       = list(string)
  }))
  # terraform.tfvars에서 설정
}

#############################################
# Environment Settings
#############################################

variable "devops_environments" {
  description = "Environments for DevOps permission sets"
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

variable "developer_environments" {
  description = "Environments for Developer permission sets"
  type        = list(string)
  default     = ["staging", "prod"]
}

variable "security_environments" {
  description = "Environments for Security permission sets"
  type        = list(string)
  default     = ["prod"]
}

variable "prod_account_id" {
  description = "Production account ID"
  type        = string
  default     = "406223549139"
}
