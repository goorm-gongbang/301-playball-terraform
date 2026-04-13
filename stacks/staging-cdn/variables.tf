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
