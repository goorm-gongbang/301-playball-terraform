#############################################
# WAF Module - CloudFront Protection
#
# CloudFront에 연결하는 WAF는 us-east-1에 생성 필수
# → 호출하는 쪽에서 us-east-1 provider를 전달해야 함
#
# 비용: WebACL $5/월 + Rule $1/월 + $0.6/백만 req
#############################################

locals {
  name_prefix = "${var.owner_name}-${var.environment}"
}

resource "aws_wafv2_web_acl" "this" {
  name        = "${local.name_prefix}-api-waf"
  description = "${var.environment} API WAF - CloudFront protection"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # ============================================
  # Geo Blocking - 허용 국가만 통과, 나머지 차단
  # ============================================
  dynamic "rule" {
    for_each = length(var.geo_allow_only) > 0 ? [1] : []
    content {
      name     = "geo-allow-only"
      priority = 0

      action {
        block {}
      }

      statement {
        not_statement {
          statement {
            geo_match_statement {
              country_codes = var.geo_allow_only
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.environment}-geo-block"
        sampled_requests_enabled   = true
      }
    }
  }

  # ============================================
  # Rate Limit - IP당 전역
  # ============================================
  rule {
    name     = "rate-limit-per-ip"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_global
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-rate-limit-ip"
      sampled_requests_enabled   = true
    }
  }

  # ============================================
  # Rate Limit - 인증 경로
  # ============================================
  rule {
    name     = "rate-limit-auth"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_auth
        aggregate_key_type = "IP"

        scope_down_statement {
          byte_match_statement {
            search_string         = var.rate_limit_auth_path
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
      metric_name                = "${var.environment}-rate-limit-auth"
      sampled_requests_enabled   = true
    }
  }

  # ============================================
  # AWS Managed Rules - Common Rule Set (무료)
  # ============================================
  dynamic "rule" {
    for_each = var.enable_common_ruleset ? [1] : []
    content {
      name     = "aws-managed-common"
      priority = 10

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"

          dynamic "scope_down_statement" {
            for_each = length(var.exclude_paths) > 0 ? [1] : []
            content {
              not_statement {
                statement {
                  byte_match_statement {
                    search_string         = var.exclude_paths[0]
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
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.environment}-aws-common"
        sampled_requests_enabled   = true
      }
    }
  }

  # ============================================
  # AWS Managed Rules - Known Bad Inputs (무료)
  # ============================================
  dynamic "rule" {
    for_each = var.enable_known_bad_inputs ? [1] : []
    content {
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
        metric_name                = "${var.environment}-aws-known-bad"
        sampled_requests_enabled   = true
      }
    }
  }

  # ============================================
  # AWS Managed Rules - SQL Injection (무료)
  # ============================================
  dynamic "rule" {
    for_each = var.enable_sqli_ruleset ? [1] : []
    content {
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
        metric_name                = "${var.environment}-aws-sqli"
        sampled_requests_enabled   = true
      }
    }
  }

  # ============================================
  # Size Constraint - 대용량 Body 차단
  # ============================================
  dynamic "rule" {
    for_each = var.max_body_size > 0 ? [1] : []
    content {
      name     = "size-constraint-body"
      priority = 20

      action {
        block {}
      }

      statement {
        size_constraint_statement {
          comparison_operator = "GT"
          size                = var.max_body_size

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
        metric_name                = "${var.environment}-size-constraint"
        sampled_requests_enabled   = true
      }
    }
  }

  # ============================================
  # [유료] Bot Control
  # ============================================
  dynamic "rule" {
    for_each = var.enable_bot_control ? [1] : []
    content {
      name     = "aws-managed-bot-control"
      priority = 5

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesBotControlRuleSet"
          vendor_name = "AWS"

          managed_rule_group_configs {
            aws_managed_rules_bot_control_rule_set {
              inspection_level = var.bot_control_level
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.environment}-bot-control"
        sampled_requests_enabled   = true
      }
    }
  }

  # ============================================
  # [유료] Account Takeover Prevention
  # ============================================
  dynamic "rule" {
    for_each = var.enable_atp ? [1] : []
    content {
      name     = "aws-managed-atp"
      priority = 6

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesATPRuleSet"
          vendor_name = "AWS"

          managed_rule_group_configs {
            aws_managed_rules_atp_rule_set {
              login_path = var.atp_login_path

              request_inspection {
                payload_type = "JSON"
                username_field {
                  identifier = "/authorizationCode"
                }
                password_field {
                  identifier = "/authorizationCode"
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.environment}-atp"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment}-api-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${local.name_prefix}-api-waf"
    Environment = var.environment
  }
}

#############################################
# WAF WebACL → CloudFront 연결
#############################################

resource "aws_wafv2_web_acl_association" "this" {
  resource_arn = var.cloudfront_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}
