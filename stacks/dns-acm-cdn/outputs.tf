output "staging_zone_id" {
  description = "Route53 zone ID for staging.playball.one (ca account)"
  value       = aws_route53_zone.staging.zone_id
}

output "staging_zone_name_servers" {
  description = "Name servers to register in the parent playball.one zone for delegation"
  value       = aws_route53_zone.staging.name_servers
}

output "acm_cloudfront_arn" {
  description = "ACM cert ARN (us-east-1) for CloudFront"
  value       = aws_acm_certificate.cloudfront.arn
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain"
  value       = aws_cloudfront_distribution.api.domain_name
}
