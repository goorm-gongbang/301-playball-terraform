variable "bucket_lifecycle" {
  description = "Map of bucket name to lifecycle configuration"
  type = map(object({
    rule_id            = string
    expiration_days    = number
    transition_days    = optional(number)
    transition_storage = optional(string)
  }))
}
