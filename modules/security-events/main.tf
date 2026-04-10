#############################################
# Security Event Alert Pipeline
# EventBridge → Lambda → Discord
#############################################

locals {
  lambda_name                     = "${var.project_name}-security-event-discord"
  rule_name                       = "${var.project_name}-security-critical-events"
  unauthorized_rule_name          = "${var.project_name}-security-unauthorized-api-calls"
  enable_unauthorized_api_alerts  = false
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/security-event-discord"
  output_path = "${path.module}/lambda/security-event-discord.zip"
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

  tags = { Name = "${local.lambda_name}-role", Purpose = "security-event-pipeline" }
}

resource "aws_iam_role_policy" "lambda" {
  count = var.enabled ? 1 : 0

  name = "${local.lambda_name}-policy"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
  timeout          = 30
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      DISCORD_WEBHOOK_URL      = var.discord_webhook_url
      DISCORD_SECRET_NAME      = var.discord_secret_name
      DISCORD_WEBHOOK_USERNAME = var.discord_username
      CRITICAL_WEBHOOK_KEY     = var.discord_critical_webhook_key
      WARNING_WEBHOOK_KEY      = var.discord_warning_webhook_key
      INFO_WEBHOOK_KEY         = var.discord_info_webhook_key
      CRITICAL_MENTION_TEXT    = var.critical_mention_text
      SENSITIVE_PORTS          = join(",", [for p in var.sensitive_ports : tostring(p)])
    }
  }

  tags = { Name = local.lambda_name, Purpose = "security-event-pipeline" }
}

resource "aws_cloudwatch_event_rule" "this" {
  count = var.enabled ? 1 : 0

  name        = local.rule_name
  description = "Capture critical CloudTrail-backed security events and notify Discord"

  event_pattern = jsonencode({
    detail-type = ["AWS Console Sign In via CloudTrail", "AWS API Call via CloudTrail"]
    detail      = { eventName = concat(var.console_event_names, var.api_event_names) }
  })

  tags = { Name = local.rule_name, Purpose = "security-event-pipeline" }
}

resource "aws_cloudwatch_event_rule" "unauthorized_api" {
  count = var.enabled && local.enable_unauthorized_api_alerts ? 1 : 0

  name        = local.unauthorized_rule_name
  description = "Capture unauthorized or access denied AWS API calls and notify Discord"

  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      errorCode = ["AccessDenied", "AccessDeniedException", "Client.UnauthorizedOperation", "UnauthorizedOperation"]
    }
  })

  tags = { Name = local.unauthorized_rule_name, Purpose = "security-event-pipeline" }
}

resource "aws_cloudwatch_event_target" "this" {
  count = var.enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.this[0].name
  target_id = "security-event-discord-lambda"
  arn       = aws_lambda_function.this[0].arn
}

resource "aws_cloudwatch_event_target" "unauthorized_api" {
  count = var.enabled && local.enable_unauthorized_api_alerts ? 1 : 0

  rule      = aws_cloudwatch_event_rule.unauthorized_api[0].name
  target_id = "security-unauthorized-discord-lambda"
  arn       = aws_lambda_function.this[0].arn
}

resource "aws_lambda_permission" "eventbridge" {
  count = var.enabled ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridgeSecurityEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this[0].arn
}

resource "aws_lambda_permission" "unauthorized_api" {
  count = var.enabled && local.enable_unauthorized_api_alerts ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridgeUnauthorizedApiSecurityEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.unauthorized_api[0].arn
}
