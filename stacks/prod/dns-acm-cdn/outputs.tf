output "acm_cloudfront_arn" {
  description = "ACM cert ARN (us-east-1) for CloudFront"
  value       = aws_acm_certificate.cloudfront.arn
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain"
  value       = aws_cloudfront_distribution.api.domain_name
}

output "api_fqdn" {
  description = "Public API FQDN"
  value       = "${var.api_subdomain}.${var.domain_name}"
}
