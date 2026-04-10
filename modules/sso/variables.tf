#############################################
# SSO (IAM Identity Center) Module - Variables
#############################################

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

#############################################
# Permission Sets
#############################################

variable "session_duration" {
  description = "Session duration for permission sets"
  type        = string
  default     = "PT8H"
}

#############################################
# Groups
#############################################

variable "groups" {
  description = "Map of groups to create"
  type = map(object({
    display_name = string
    description  = string
  }))
  default = {
    devops = {
      display_name = "DevOps"
      description  = "DevOps team - full access"
    }
    developers = {
      display_name = "Developers"
      description  = "Developer team - limited access"
    }
    readonly = {
      display_name = "ReadOnly"
      description  = "Read-only access"
    }
  }
}

#############################################
# Users
#############################################

variable "users" {
  description = "Map of users to create"
  type = map(object({
    display_name = string
    given_name   = string
    family_name  = string
    email        = string
    groups       = list(string)
  }))
  default = {}
}

#############################################
# Account Assignments
#############################################

variable "account_assignments" {
  description = "Map of account assignments"
  type = map(object({
    account_id     = string
    permission_set = string # admin, devops, developer, readonly
    principal_type = string # GROUP or USER
    principal_name = string # group key or user key
  }))
  default = {}
}
