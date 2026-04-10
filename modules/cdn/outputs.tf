#############################################
# CDN Module - Outputs
#############################################

output "cloudfront_id" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.api.id
}

output "cloudfront_arn" {
  description = "CloudFront Distribution ARN"
  value       = aws_cloudfront_distribution.api.arn
}

output "cloudfront_domain" {
  description = "CloudFront domain name (e.g. d2xxx.cloudfront.net)"
  value       = aws_cloudfront_distribution.api.domain_name
}

output "api_url" {
  description = "API URL (e.g. https://api.staging.playball.one)"
  value       = "https://${var.domain}"
}

output "alb_sg_id" {
  description = "Auto-discovered ALB Security Group ID"
  value       = data.aws_security_group.alb.id
}

output "waf_web_acl_arn" {
  description = "WAF WebACL ARN"
  value       = var.enable_waf ? module.waf[0].web_acl_arn : null
}
