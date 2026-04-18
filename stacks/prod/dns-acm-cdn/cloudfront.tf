#############################################
# CloudFront - api.playball.one → ALB
#############################################

resource "aws_cloudfront_distribution" "api" {
  enabled         = true
  comment         = "API CDN - ${var.api_subdomain}.${var.domain_name}"
  aliases         = ["${var.api_subdomain}.${var.domain_name}"]
  price_class     = "PriceClass_200"
  is_ipv6_enabled = true

  origin {
    domain_name = var.alb_dns
    origin_id   = "api-alb"

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
