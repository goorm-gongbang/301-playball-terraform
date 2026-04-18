#############################################
# CloudFront - api.playball.one → ALB
#############################################

resource "aws_cloudfront_distribution" "api" {
  enabled         = true
  comment         = "API CDN - ${var.api_subdomain}.${var.domain_name}"
  aliases         = ["${var.api_subdomain}.${var.domain_name}"]
  price_class     = "PriceClass_200"
  is_ipv6_enabled = true

  # WAF 연결 (us-east-1에서 생성된 WAF WebACL)
  web_acl_id = aws_wafv2_web_acl.api.arn

  origin {
    domain_name = var.alb_dns
    origin_id   = "api-alb"

    # ALB 직접 접근 방지: 이 헤더 없으면 ALB에서 거부
    custom_header {
      name  = "X-Origin-Verify"
      value = var.origin_verify_secret
    }

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "api-alb"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudfront.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "api-prod-cloudfront"
  }

  depends_on = [aws_acm_certificate_validation.cloudfront]
}

#############################################
# Route53 alias - api.playball.one → CloudFront (root zone)
#############################################

resource "aws_route53_record" "api_alias" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "${var.api_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.api.domain_name
    zone_id                = aws_cloudfront_distribution.api.hosted_zone_id
    evaluate_target_health = false
  }
}
