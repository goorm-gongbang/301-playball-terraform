#############################################
# CDN Module - Variables
#############################################

variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string
}

variable "owner_name" {
  description = "Owner name for resource naming"
  type        = string
  default     = "goormgb"
}

#############################################
# CloudFront
#############################################

variable "domain" {
  description = "API 도메인 (e.g. api.staging.goormgb.help)"
  type        = string
}

variable "alb_dns" {
  description = "Origin ALB DNS name"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM 인증서 ARN (us-east-1, CloudFront용)"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_200"
}

#############################################
# Route53 (CloudFront alias 레코드)
#############################################

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
}

variable "route53_record_name" {
  description = "Route53 record name (e.g. api)"
  type        = string
  default     = "api"
}

#############################################
# ALB Security Group
#############################################

variable "eks_cluster_name" {
  description = "EKS cluster name (ALB 태그 자동 발견용)"
  type        = string
}

variable "alb_ingress_stack" {
  description = "AWS LB Controller ingress stack tag"
  type        = string
}

variable "admin_allowed_ips" {
  description = "팀원 공인 IP (모니터링 도구 직접 접근용)"
  type        = list(string)
  default     = []
}

#############################################
# WAF
#############################################

variable "enable_waf" {
  description = "WAF WebACL 활성화"
  type        = bool
  default     = true
}

variable "waf_geo_allow_only" {
  description = "허용할 국가 코드 (이외 차단)"
  type        = list(string)
  default     = ["KR"]
}

variable "waf_rate_limit_global" {
  description = "IP당 5분 요청 한도"
  type        = number
  default     = 1500
}

variable "waf_rate_limit_auth" {
  description = "/auth/ IP당 5분 요청 한도"
  type        = number
  default     = 50
}

variable "waf_max_body_size" {
  description = "최대 body 크기 (bytes)"
  type        = number
  default     = 8192
}

variable "waf_exclude_paths" {
  description = "WAF 제외 경로"
  type        = list(string)
  default     = []
}

variable "waf_enable_bot_control" {
  description = "[유료] Bot Control 활성화"
  type        = bool
  default     = false
}

variable "waf_enable_atp" {
  description = "[유료] Account Takeover Prevention 활성화"
  type        = bool
  default     = false
}

#############################################
# Realtime Stats
#############################################

variable "realtime_log_config_arn" {
  description = "CloudFront Realtime Log Config ARN (null이면 비활성화)"
  type        = string
  default     = null
}
