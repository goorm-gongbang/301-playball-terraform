#############################################
# WAF - CloudFront Protection (Staging)
# CloudFront용 WAF는 us-east-1에 생성 필수
#
# 비용: WebACL $5/월 + Rule $1/월 + $0.6/백만 req
#############################################

resource "aws_wafv2_web_acl" "api" {
  provider    = aws.us_east_1
  name        = "playball-staging-api-waf"
  description = "Staging API WAF - CloudFront protection"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # ============================================
  # Geo Blocking - 한국만 허용
  # ============================================
  rule {
    name     = "geo-allow-korea-only"
    priority = 0

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          geo_match_statement {
            country_codes = ["KR"]
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "staging-geo-block"
      sampled_requests_enabled   = true
    }
  }

  # ============================================
  # Rate Limit - IP당 전역 (5분간 1500회)
  # ============================================
  rule {
    name     = "rate-limit-per-ip"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1500
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "staging-rate-limit-ip"
      sampled_requests_enabled   = true
    }
  }

  # ============================================
  # Rate Limit - 인증 경로 (5분간 50회)
  # ============================================
  rule {
    name     = "rate-limit-auth"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 50
        aggregate_key_type = "IP"

        scope_down_statement {
          byte_match_statement {
            search_string         = "/auth/"
            positional_constraint = "STARTS_WITH"

            field_to_match {
              uri_path {}
            }

            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "staging-rate-limit-auth"
      sampled_requests_enabled   = true
    }
  }

  # ============================================
  # AWS Managed Rules - Common Rule Set (무료)
  # ============================================
  rule {
    name     = "aws-managed-common"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "staging-aws-common"
      sampled_requests_enabled   = true
    }
  }

  # ============================================
  # AWS Managed Rules - Known Bad Inputs (무료)
  # ============================================
  rule {
    name     = "aws-managed-known-bad-inputs"
    priority = 11

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "staging-aws-known-bad"
      sampled_requests_enabled   = true
    }
  }

  # ============================================
  # AWS Managed Rules - SQL Injection (무료)
  # ============================================
  rule {
    name     = "aws-managed-sqli"
    priority = 12

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "staging-aws-sqli"
      sampled_requests_enabled   = true
    }
  }

  # ============================================
  # Body Size 제한 (8KB)
  # ============================================
  rule {
    name     = "size-constraint-body"
    priority = 20

    action {
      block {}
    }

    statement {
      size_constraint_statement {
        comparison_operator = "GT"
        size                = 8192

        field_to_match {
          body {
            oversize_handling = "MATCH"
          }
        }

        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "staging-size-constraint"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "staging-api-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "playball-staging-api-waf"
    Environment = "staging"
  }
}
