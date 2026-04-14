variable "domain_name" {
  description = "Root domain"
  type        = string
  default     = "playball.one"
}

variable "api_subdomain" {
  description = "API subdomain (FQDN: api.playball.one)"
  type        = string
  default     = "api"
}

variable "alb_dns" {
  description = "Origin ALB DNS name (우선 staging ALB 사용)"
  type        = string
  default     = "k8s-stagingalb-4f414fcf8f-1423406747.ap-northeast-2.elb.amazonaws.com"
}
