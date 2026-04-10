#############################################
# DNS Module - Route53 Zone + ACM Certificates
#############################################

locals {
  subdomain = "${var.environment}.${var.domain_name}"
}

#############################################
# Route53 Hosted Zone
#############################################

resource "aws_route53_zone" "this" {
  name = local.subdomain

  tags = {
    Name        = local.subdomain
    Environment = var.environment
  }
}

#############################################
# ACM Certificate - ap-northeast-2 (ALB용)
#############################################

resource "aws_acm_certificate" "seoul" {
  domain_name               = local.subdomain
  subject_alternative_names = ["*.${local.subdomain}"]
  validation_method         = "DNS"

  tags = {
    Name        = "${local.subdomain}-cert"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation_seoul" {
  for_each = {
    for dvo in aws_acm_certificate.seoul.domain_validation_options : dvo.domain_name => {
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
  zone_id         = aws_route53_zone.this.zone_id
}

resource "aws_acm_certificate_validation" "seoul" {
  certificate_arn         = aws_acm_certificate.seoul.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_seoul : record.fqdn]
}

#############################################
# ACM Certificate - us-east-1 (CloudFront용)
#############################################

resource "aws_acm_certificate" "cloudfront" {
  provider = aws.us_east_1

  domain_name               = local.subdomain
  subject_alternative_names = ["*.${local.subdomain}"]
  validation_method         = "DNS"

  tags = {
    Name        = "${local.subdomain}-cloudfront-cert"
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
  zone_id         = aws_route53_zone.this.zone_id
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_cloudfront : record.fqdn]
}

#############################################
# Frontend Record (Vercel)
#############################################

resource "aws_route53_record" "frontend" {
  count = var.vercel_ip != "" ? 1 : 0

  zone_id = aws_route53_zone.this.zone_id
  name    = ""
  type    = "A"
  ttl     = 300
  records = [var.vercel_ip]
}

resource "aws_route53_record" "frontend_www" {
  count = var.vercel_cname != "" ? 1 : 0

  zone_id = aws_route53_zone.this.zone_id
  name    = "www"
  type    = "CNAME"
  ttl     = 300
  records = [var.vercel_cname]
}
