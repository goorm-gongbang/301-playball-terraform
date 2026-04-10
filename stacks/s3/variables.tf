variable "project_name" {
  description = "Project name for bucket naming"
  type        = string
}

variable "cloudtrail_source_arns" {
  description = "CloudTrail ARNs allowed to write to audit logs bucket"
  type        = list(string)
  default     = []
}

variable "cloudtrail_prefix" {
  description = "S3 key prefix for CloudTrail logs"
  type        = string
  default     = "cloudtrail"
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

variable "audit_logs_lifecycle_rules" {
  description = "Lifecycle rules for audit logs bucket"
  type = list(object({
    id                 = string
    prefix             = string
    expiration_days    = number
    transition_days    = optional(number)
    transition_storage = optional(string)
  }))
  default = [
    { id = "cloudtrail-400days", prefix = "cloudtrail/", expiration_days = 400, transition_days = 30, transition_storage = "GLACIER" },
    { id = "cloudtrail-digest-400days", prefix = "cloudtrail-digest/", expiration_days = 400, transition_days = 30, transition_storage = "GLACIER" },
    { id = "legacy-cloudtrail-management-events-400days", prefix = "legacy-cloudtrail/management-events/", expiration_days = 400, transition_days = 30, transition_storage = "GLACIER" },
    { id = "audit-reports-400days", prefix = "audit-reports/", expiration_days = 400, transition_days = 30, transition_storage = "GLACIER" },
    { id = "lifecycle-expiration-summary-400days", prefix = "lifecycle-expiration-summary/", expiration_days = 400, transition_days = 30, transition_storage = "GLACIER" },
    { id = "pis-access-730days", prefix = "pis-access/", expiration_days = 730, transition_days = 30, transition_storage = "GLACIER" },
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
