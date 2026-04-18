variable "domain_name" {
  description = "Root domain"
  type        = string
  default     = "playball.one"
}

variable "default_ttl" {
  description = "기본 TTL (이관 기간에는 짧게 유지)"
  type        = number
  default     = 300
}

#############################################
# External integrations
#############################################

variable "vercel_apex_ip" {
  description = "Vercel anycast IP for apex (playball.one)"
  type        = string
  default     = "216.198.79.1"
}

variable "vercel_cname_target" {
  description = "Vercel CNAME target for www subdomain"
  type        = string
  default     = "cname.vercel-dns.com"
}

variable "netlify_guide_cname" {
  description = "Netlify CNAME for guide.playball.one"
  type        = string
  default     = "playball-guide.netlify.app"
}

variable "assets_cloudfront_domain" {
  description = "Assets CloudFront distribution domain (본계정 유지)"
  type        = string
  default     = "d1woqaiqw3rezq.cloudfront.net"
}

variable "google_site_verification" {
  description = "Google site verification TXT value"
  type        = string
  default     = "google-site-verification=y_Neg8u8YPqOdsULfVnQfQeAFep3wixAbV6EImVYDG8"
}

#############################################
# ACM DNS validation records (본계정 us-east-1 ACM 유지용)
# assets CloudFront 가 본계정 us-east-1 cert 를 사용 중 → 검증 레코드 유지
#############################################

variable "acm_validation_records" {
  description = "본계정 ACM 검증 CNAME 레코드들 (도메인 유지 필요 시)"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "_8c35fcd679e5b54ffddf3150ca6f4646.playball.one"
      value = "_5a67eb171ba38367eec6c075061da247.jkddzztszm.acm-validations.aws."
    },
    {
      name  = "_9bb9e7867735977d012a63bc006a7ace.playball.one"
      value = "_086c15fbc0137c8e1f83d06e2bc6cefb.jkddzztszm.acm-validations.aws."
    },
  ]
}
