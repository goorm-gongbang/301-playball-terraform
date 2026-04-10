#############################################
# DNS Module - Variables
#############################################

variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string
}

variable "domain_name" {
  description = "Root domain name"
  type        = string
  default     = "goormgb.help"
}

variable "vercel_ip" {
  description = "Vercel A record IP for frontend"
  type        = string
  default     = ""
}

variable "vercel_cname" {
  description = "Vercel CNAME target for www"
  type        = string
  default     = ""
}
