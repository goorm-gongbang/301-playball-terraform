#############################################
# Audit Event Pipeline
# EventBridge → Lambda → S3 Summary + Discord
#############################################

locals {
  lambda_name = "${var.project_name}-audit-event-summary"
  rule_name   = "${var.project_name}-audit-log-events"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/audit-event-summary"
  output_path = "${path.module}/lambda/audit-event-summary.zip"
}

resource "aws_iam_role" "lambda" {
  count = var.enabled ? 1 : 0

  name = "${local.lambda_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.lambda_name}-role", Purpose = "audit-event-pipeline" }
}

resource "aws_iam_role_policy" "lambda" {
  count = var.enabled ? 1 : 0

  name = "${local.lambda_name}-policy"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowWriteAuditSummary"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.audit_logs_bucket_arn}/${var.summary_prefix}/*"
      },
      {
        Sid      = "AllowReadAuditBucketLocation"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation"]
        Resource = var.audit_logs_bucket_arn
      },
      {
        Sid      = "AllowLambdaLogging"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:*"
      },
      {
        Sid      = "AllowReadDiscordWebhookSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.discord_secret_name}*"
      }
    ]
  })
}

resource "aws_lambda_function" "this" {
  count = var.enabled ? 1 : 0

  function_name    = local.lambda_name
  role             = aws_iam_role.lambda[0].arn
  filename         = data.archive_file.lambda.output_path
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = var.lambda_timeout
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      AUDIT_BUCKET_NAME        = var.audit_logs_bucket_id
      SUMMARY_PREFIX           = var.summary_prefix
      DISCORD_WEBHOOK_URL      = var.discord_webhook_url
      DISCORD_SECRET_NAME      = var.discord_secret_name
      DISCORD_WEBHOOK_USERNAME = var.discord_username
      CRITICAL_WEBHOOK_KEY     = var.discord_critical_webhook_key
      WARNING_WEBHOOK_KEY      = var.discord_warning_webhook_key
      INFO_WEBHOOK_KEY         = var.discord_info_webhook_key
      CRITICAL_MENTION_TEXT    = var.critical_mention_text
    }
  }

  tags = { Name = local.lambda_name, Purpose = "audit-event-pipeline" }
}

resource "aws_cloudwatch_event_rule" "this" {
  count = var.enabled ? 1 : 0

  name        = local.rule_name
  description = "Capture S3 audit events routed through CloudTrail for audit summary storage"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource       = ["s3.amazonaws.com"]
      eventName         = var.event_names
      requestParameters = { bucketName = var.monitored_bucket_names }
    }
  })

  tags = { Name = local.rule_name, Purpose = "audit-event-pipeline" }
}

resource "aws_cloudwatch_event_target" "this" {
  count = var.enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.this[0].name
  target_id = "audit-event-summary-lambda"
  arn       = aws_lambda_function.this[0].arn
}

resource "aws_lambda_permission" "eventbridge" {
  count = var.enabled ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridgeAuditEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this[0].arn
}
