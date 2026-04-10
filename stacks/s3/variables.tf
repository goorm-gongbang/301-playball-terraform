variable "project_name" {
  description = "Project name for bucket naming"
  type        = string
  default     = "goormgb"
}

variable "backup_lifecycle_rules" {
  description = "Lifecycle rules for backup bucket"
  type = list(object({
    id              = string
    prefix          = string
    expiration_days = number
  }))
  default = [
    { id = "dev-postgres-7days", prefix = "dev/postgres/", expiration_days = 7 },
    { id = "dev-logs-7days", prefix = "dev/logs/", expiration_days = 7 },
    { id = "staging-postgres-14days", prefix = "staging/postgres/", expiration_days = 14 },
    { id = "prod-postgres-14days", prefix = "prod/postgres/", expiration_days = 14 },
    { id = "staging-infra-logs-14days", prefix = "staging/logs/infra/", expiration_days = 14 },
    { id = "staging-service-logs-14days", prefix = "staging/logs/service/", expiration_days = 14 },
    { id = "prod-infra-logs-14days", prefix = "prod/logs/infra/", expiration_days = 14 },
    { id = "prod-service-logs-14days", prefix = "prod/logs/service/", expiration_days = 14 },
    { id = "prod-payment-logs-90days", prefix = "prod/logs/payment/", expiration_days = 90 },
  ]
}

variable "archive_lifecycle_rules" {
  description = "Lifecycle rules for archive bucket"
  type = list(object({
    id                 = string
    prefix             = string
    expiration_days    = number
    transition_days    = optional(number)
    transition_storage = optional(string)
  }))
  default = [
    { id = "member-retention-3years", prefix = "member-retention/", expiration_days = 1095, transition_days = 30, transition_storage = "DEEP_ARCHIVE" },
    { id = "member-retention-manifest-3years", prefix = "member-retention-manifest/", expiration_days = 1095, transition_days = 30, transition_storage = "DEEP_ARCHIVE" },
    { id = "commerce-retention-5years", prefix = "commerce-retention/", expiration_days = 1825, transition_days = 30, transition_storage = "DEEP_ARCHIVE" },
    { id = "commerce-retention-manifest-5years", prefix = "commerce-retention-manifest/", expiration_days = 1825, transition_days = 30, transition_storage = "DEEP_ARCHIVE" },
  ]
}
