#############################################
# DNS Module - Outputs
#############################################

output "zone_id" {
  description = "Route53 Hosted Zone ID"
  value       = aws_route53_zone.this.zone_id
}

output "zone_name_servers" {
  description = "Route53 name servers (root zone NS에 등록 필요)"
  value       = aws_route53_zone.this.name_servers
}

output "acm_seoul_arn" {
  description = "ACM Certificate ARN (ap-northeast-2, ALB용)"
  value       = aws_acm_certificate.seoul.arn
}

output "acm_cloudfront_arn" {
  description = "ACM Certificate ARN (us-east-1, CloudFront용)"
  value       = aws_acm_certificate.cloudfront.arn
}
