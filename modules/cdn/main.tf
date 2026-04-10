#############################################
# CDN Module - CloudFront + WAF + ALB SG
#
# API를 CloudFront로 감싸고, WAF 붙이고,
# ALB SG를 CloudFront + 팀원 IP만 허용으로 제한
#
# CloudFront/WAF는 us-east-1 필수
# → 호출 시 aws.us_east_1 provider 전달 필요
#############################################

locals {
  name_prefix = "${var.owner_name}-${var.environment}"
}

#############################################
# 1. CloudFront Distribution
#############################################

resource "aws_cloudfront_distribution" "api" {
  enabled         = true
  comment         = "API CDN - ${var.environment} (${var.domain})"
  aliases         = [var.domain]
  price_class     = var.price_class
  is_ipv6_enabled = true

  # WAF 연결
  web_acl_id = var.enable_waf ? module.waf[0].web_acl_arn : null

  origin {
    domain_name = var.alb_dns
    origin_id   = "api-alb-${var.environment}"

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
    target_origin_id       = "api-alb-${var.environment}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # API는 캐싱 비활성화
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name        = "${local.name_prefix}-api-cloudfront"
    Environment = var.environment
  }
}

#############################################
# 2. Route53 Record → CloudFront
#############################################

resource "aws_route53_record" "api" {
  zone_id = var.route53_zone_id
  name    = var.route53_record_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.api.domain_name
    zone_id                = aws_cloudfront_distribution.api.hosted_zone_id
    evaluate_target_health = false
  }
}

#############################################
# 3. WAF (모듈 호출)
#############################################

module "waf" {
  count  = var.enable_waf ? 1 : 0
  source = "../waf"

  environment    = var.environment
  owner_name     = var.owner_name
  cloudfront_arn = aws_cloudfront_distribution.api.arn

  geo_allow_only    = var.waf_geo_allow_only
  rate_limit_global = var.waf_rate_limit_global
  rate_limit_auth   = var.waf_rate_limit_auth
  max_body_size     = var.waf_max_body_size
  exclude_paths     = var.waf_exclude_paths

  enable_bot_control = var.waf_enable_bot_control
  enable_atp         = var.waf_enable_atp
}

#############################################
# 4. ALB Security Group - CloudFront + 팀원 IP만
#############################################

# ALB를 태그 기반 자동 발견
data "aws_lb" "alb" {
  tags = {
    "elbv2.k8s.aws/cluster" = var.eks_cluster_name
    "ingress.k8s.aws/stack" = var.alb_ingress_stack
  }
}

data "aws_security_group" "alb" {
  filter {
    name   = "group-id"
    values = data.aws_lb.alb.security_groups
  }

  filter {
    name   = "group-name"
    values = ["k8s-${replace(var.alb_ingress_stack, "-", "")}-*"]
  }
}

# CloudFront Managed Prefix List
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# CloudFront → ALB
resource "aws_vpc_security_group_ingress_rule" "cloudfront" {
  security_group_id = data.aws_security_group.alb.id
  description       = "CloudFront origin-facing"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
}

# 팀원 IP → ALB (모니터링 도구 직접 접근)
resource "aws_vpc_security_group_ingress_rule" "admin" {
  for_each = toset(var.admin_allowed_ips)

  security_group_id = data.aws_security_group.alb.id
  description       = "Admin access - ${each.value}"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}
