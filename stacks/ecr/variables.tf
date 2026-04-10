#############################################
# common/ecr - Variables
#############################################

variable "web_services" {
  description = "Web services for ECR repositories"
  type        = list(string)
  default = [
    "api-gateway",
    "auth-guard",
    "order-core",
    "queue",
    "seat"
  ]
}

variable "ai_services" {
  description = "AI services for ECR repositories"
  type        = list(string)
  default = [
    "defense",
    "authz-adapter"
  ]
}

#############################################
# Cross-Account Access
#############################################

variable "cross_account_ids" {
  description = "AWS Account IDs allowed to pull images"
  type        = list(string)
  default     = []
}

variable "cross_account_node_roles" {
  description = "Map of account_id to list of node role names"
  type        = map(list(string))
  default     = {}
  # 예: {
  #   "274130523831" = ["ktcloud_team4_260204-karpenter-node"]
  # }
}
