#############################################
# Realtime Stats Module - Variables
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
# Network (Lambda VPC 배치용)
#############################################

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (Lambda 배치)"
  type        = list(string)
}

#############################################
# Redis (ElastiCache)
#############################################

variable "redis_host" {
  description = "Redis endpoint"
  type        = string
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "redis_security_group_id" {
  description = "Redis security group ID (Lambda 접근 허용 추가)"
  type        = string
}

variable "redis_tls" {
  description = "Redis TLS 연결 사용 여부"
  type        = bool
  default     = false
}

#############################################
# CloudFront
#############################################

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (RT log 연결용)"
  type        = string
}

variable "sampling_rate" {
  description = "RT 로그 샘플링 비율 (1-100, 100=전체)"
  type        = number
  default     = 100
}

#############################################
# 봇 탐지 / Ratio 분석 임계치
#############################################

variable "bot_req_threshold" {
  description = "IP당 1분 요청 수 임계치 (초과 시 blocklist)"
  type        = number
  default     = 200
}

variable "bot_blocklist_ttl" {
  description = "blocklist TTL (초)"
  type        = number
  default     = 3600
}

variable "ratio_single_ip_attack" {
  description = "단일 IP 공격 판정 ratio (요청수/고유IP > 이 값)"
  type        = number
  default     = 50
}

variable "ratio_botnet_attack" {
  description = "봇넷 분산 공격 판정 ratio (요청수/고유IP < 이 값)"
  type        = number
  default     = 1.2
}

variable "min_requests_for_ratio" {
  description = "ratio 분석 최소 요청 수 (이하면 무시)"
  type        = number
  default     = 500
}

#############################################
# Demo Mode (k6 매크로로 유니크 IP 시뮬레이션)
# 콘솔에서 Lambda env 토글만으로 on/off 가능 (재배포 불필요)
#############################################

variable "demo_mode" {
  description = "true 로 두면 Lambda 가 DEMO_IP_HEADER(기본 x-client-ip) 값을 클라이언트 IP 로 간주해 집계. 운영 시 false 유지."
  type        = bool
  default     = false
}

variable "demo_ip_header" {
  description = "Demo 모드에서 읽을 헤더 이름 (소문자 기준)"
  type        = string
  default     = "x-client-ip"
}
