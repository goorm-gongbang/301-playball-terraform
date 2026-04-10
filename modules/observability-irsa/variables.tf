variable "owner_name" {
  description = "Project owner name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}

variable "oidc_provider" {
  description = "EKS OIDC provider URL (without https://)"
  type        = string
}

variable "s3_bucket_names" {
  description = "S3 bucket names for observability storage"
  type        = list(string)
}

variable "service_accounts" {
  description = "Map of service name to namespace/service_account for IRSA"
  type = map(object({
    namespace       = string
    service_account = string
  }))
  default = {
    loki = {
      namespace       = "monitoring"
      service_account = "loki"
    }
    tempo = {
      namespace       = "monitoring"
      service_account = "tempo"
    }
    thanos = {
      namespace       = "monitoring"
      service_account = "prometheus-prom"
    }
  }
}
