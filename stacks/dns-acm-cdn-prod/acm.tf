#############################################
# ACM - us-east-1 (CloudFront viewer cert)
# api.playball.one
#############################################

resource "aws_acm_certificate" "cloudfront" {
  provider = aws.us_east_1

  domain_name       = "${var.api_subdomain}.${var.domain_name}"
  validation_method = "DNS"

  tags = {
    Name = "${var.api_subdomain}.${var.domain_name}-cloudfront"
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
  zone_id         = data.aws_route53_zone.root.zone_id
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation_cloudfront : r.fqdn]
}
