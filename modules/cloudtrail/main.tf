#############################################
# CloudTrail Module
# Audit trail → S3 + CloudWatch Logs
#############################################

resource "aws_cloudwatch_log_group" "this" {
  count = var.enabled ? 1 : 0

  name              = "/aws/cloudtrail/${var.project_name}/audit"
  retention_in_days = var.log_retention_days

  tags = {
    Name    = "/aws/cloudtrail/${var.project_name}/audit"
    Purpose = "cloudtrail-search-and-investigation"
  }
}

resource "aws_iam_role" "cloudwatch" {
  count = var.enabled ? 1 : 0

  name = "${var.project_name}-audit-trail-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name    = "${var.project_name}-audit-trail-cloudwatch-role"
    Purpose = "cloudtrail-cloudwatch-delivery"
  }
}

resource "aws_iam_role_policy" "cloudwatch" {
  count = var.enabled ? 1 : 0

  name = "${var.project_name}-audit-trail-cloudwatch-policy"
  role = aws_iam_role.cloudwatch[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowCloudTrailDeliveryToLogs"
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.this[0].arn}:log-stream:*"
    }]
  })
}

resource "aws_cloudtrail" "this" {
  count = var.enabled ? 1 : 0

  name                          = "${var.project_name}-audit-trail"
  s3_bucket_name                = var.audit_logs_bucket_id
  s3_key_prefix                 = var.s3_key_prefix
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.this[0].arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudwatch[0].arn
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  enable_logging                = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = [for arn in var.tracked_s3_bucket_arns : "${arn}/"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  insight_selector {
    insight_type = "ApiErrorRateInsight"
  }

  tags = {
    Name    = "${var.project_name}-audit-trail"
    Purpose = "audit-log-collection"
  }
}
