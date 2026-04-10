#############################################
# Variables
#############################################

variable "domain_name" {
  description = "Root domain name"
  type        = string
  default     = "goormgb.help"
}

variable "enable_acm" {
  description = "ACM 인증서 생성 여부 (Porkbun NS 설정 후 true로 변경)"
  type        = bool
  default     = false
}

variable "staging_zone_name_servers" {
  description = "Name servers for staging.goormgb.help zone (dns/staging에서 output 복사)"
  type        = list(string)
  default     = []
}

variable "prod_zone_name_servers" {
  description = "Name servers for prod.goormgb.help zone"
  type        = list(string)
  default     = []
}

variable "pentest_zone_name_servers" {
  description = "Name servers for pentest.goormgb.help zone (306-pen-testing에서 output 복사)"
  type        = list(string)
  default     = []
}

variable "loadtest_zone_name_servers" {
  description = "Name servers for loadtest.goormgb.help zone (305-k6-operators에서 output 복사)"
  type        = list(string)
  default     = []
}

variable "vercel_ip" {
  description = "Vercel A record IP for root domain"
  type        = string
  default     = "216.198.79.1"
}

variable "netlify_guide_cname" {
  description = "Netlify CNAME for guide subdomain"
  type        = string
  default     = "playball-guide.netlify.app"
}

# NOTE: prod_alb_dns → environments/prod/config.yaml로 이동됨
