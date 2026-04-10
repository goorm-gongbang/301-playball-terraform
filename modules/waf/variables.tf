#############################################
# WAF Module - Variables
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

variable "cloudfront_arn" {
  description = "CloudFront distribution ARN to associate WAF"
  type        = string
}

#############################################
# Geo Blocking
#############################################

variable "geo_allow_only" {
  description = "허용할 국가 코드 목록 (이외 차단). 빈 배열이면 Geo blocking 비활성화"
  type        = list(string)
  default     = ["KR"]
}

#############################################
# Rate Limiting
#############################################

variable "rate_limit_global" {
  description = "IP당 5분 요청 한도 (전체)"
  type        = number
  default     = 1500 # 분당 300
}

variable "rate_limit_auth" {
  description = "IP당 5분 요청 한도 (/auth/ 경로)"
  type        = number
  default     = 50 # 분당 10
}

variable "rate_limit_auth_path" {
  description = "인증 경로 패턴"
  type        = string
  default     = "/auth/"
}

#############################################
# Managed Rules
#############################################

variable "enable_common_ruleset" {
  description = "AWS Managed Common Rule Set (무료, OWASP Top 10)"
  type        = bool
  default     = true
}

variable "enable_known_bad_inputs" {
  description = "AWS Managed Known Bad Inputs (무료, Log4Shell 등)"
  type        = bool
  default     = true
}

variable "enable_sqli_ruleset" {
  description = "AWS Managed SQL Injection Rule Set (무료)"
  type        = bool
  default     = true
}

#############################################
# Size Constraint
#############################################

variable "max_body_size" {
  description = "최대 허용 body 크기 (bytes). 0이면 비활성화"
  type        = number
  default     = 8192 # 8KB
}

#############################################
# Exclude Paths
#############################################

variable "exclude_paths" {
  description = "WAF 규칙 제외 경로 목록"
  type        = list(string)
  default     = ["/load-test/"]
}

#############################################
# [유료] Bot Control
#############################################

variable "enable_bot_control" {
  description = "AWS Bot Control ($10/월 + $1/백만 req)"
  type        = bool
  default     = false
}

variable "bot_control_level" {
  description = "Bot Control 검사 수준 (COMMON: $1/백만, TARGETED: $10/백만)"
  type        = string
  default     = "COMMON"
}

#############################################
# [유료] Account Takeover Prevention
#############################################

variable "enable_atp" {
  description = "AWS Account Takeover Prevention ($10/월 + $1/천 로그인)"
  type        = bool
  default     = false
}

variable "atp_login_path" {
  description = "ATP 로그인 경로"
  type        = string
  default     = "/auth/kakao/login"
}
