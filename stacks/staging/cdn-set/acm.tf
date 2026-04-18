#############################################
# ACM - us-east-1 (CloudFront viewer cert)
# api.staging.playball.one 만 필요 (와일드카드는 나중에 서비스 확장 시)
#############################################

resource "aws_acm_certificate" "cloudfront" {
  provider = aws.us_east_1

  domain_name       = "api.${var.environment}.${var.domain_name}"
  validation_method = "DNS"

  tags = {
    Name        = "api.${var.environment}.${var.domain_name}-cloudfront"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation_cloudfront" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.staging.zone_id
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation_cloudfront : r.fqdn]
}
