variable "domain_name" {
  description = "Root domain"
  type        = string
  default     = "playball.one"
}

variable "environment" {
  description = "Environment name (subdomain)"
  type        = string
  default     = "staging"
}

variable "alb_dns" {
  description = "EKS ALB DNS name (CloudFront origin)"
  type        = string
  default     = "k8s-stagingalb-4f414fcf8f-1423406747.ap-northeast-2.elb.amazonaws.com"
}

variable "realtime_log_config_arn" {
  description = "CloudFront Realtime Log Config ARN (environments/staging output에서 -var 로 주입). 미지정 시 RT 로그 비활성."
  type        = string
  default     = null
}

variable "origin_verify_secret" {
  description = "CloudFront → ALB 커스텀 헤더 비밀값 (ALB에서 검증)"
  type        = string
  sensitive   = true
  default     = "playball-staging-origin-verify-2026"
}
