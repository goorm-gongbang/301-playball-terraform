#############################################
# Secret Change Event Pipeline
# EventBridge → Lambda → Discord (masked value preview)
#############################################

locals {
  lambda_name = "${var.project_name}-secret-change-discord"
  rule_name   = "${var.project_name}-secret-change-events"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/secret-change-discord"
  output_path = "${path.module}/lambda/secret-change-discord.zip"
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

  tags = { Name = "${local.lambda_name}-role", Purpose = "secret-change-pipeline" }
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
        Sid      = "AllowReadSecretValues"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:*"
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
      STAGING_DISCORD_WEBHOOK_URL = var.staging_discord_webhook_url
      DEV_DISCORD_WEBHOOK_URL     = var.dev_discord_webhook_url
      DISCORD_WEBHOOK_USERNAME    = var.discord_username
    }
  }

  tags = { Name = local.lambda_name, Purpose = "secret-change-pipeline" }
}

resource "aws_cloudwatch_event_rule" "this" {
  count = var.enabled ? 1 : 0

  name        = local.rule_name
  description = "Capture Secrets Manager change events and notify Discord with masked value preview"

  event_pattern = jsonencode({
    source      = ["aws.secretsmanager"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["secretsmanager.amazonaws.com"]
      eventName   = var.event_names
    }
  })

  tags = { Name = local.rule_name, Purpose = "secret-change-pipeline" }
}

resource "aws_cloudwatch_event_target" "this" {
  count = var.enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.this[0].name
  target_id = "secret-change-discord-lambda"
  arn       = aws_lambda_function.this[0].arn
}

resource "aws_lambda_permission" "eventbridge" {
  count = var.enabled ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridgeSecretChangeEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this[0].arn
}
