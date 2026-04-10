#############################################
# S3 Bucket Module - Variables
#############################################

variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "purpose" {
  description = "Bucket purpose tag"
  type        = string
  default     = ""
}

variable "extra_tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "enable_tls_policy" {
  description = "TLS 강제 정책 활성화"
  type        = bool
  default     = true
}

variable "additional_policy_statements" {
  description = "추가 버킷 정책 statement"
  type        = list(any)
  default     = []
}

variable "enable_versioning" {
  description = "버전 관리 활성화"
  type        = bool
  default     = false
}

variable "lifecycle_rules" {
  description = "라이프사이클 규칙 목록"
  type        = list(any)
  default     = []
}
