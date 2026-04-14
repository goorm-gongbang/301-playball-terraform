#############################################
# EC2 Spot Interruption Alert Pipeline
# EventBridge (Spot Interruption Warning / Rebalance Recommendation)
#   -> Lambda -> Discord
#
# NOTE: Karpenter module (modules/karpenter) also subscribes the same
# events into its interruption SQS for graceful drain. EventBridge
# supports multiple rules on the same detail-type, so this module adds
# its own rules independent of Karpenter's drain path.
#############################################

locals {
  lambda_name       = "${var.project_name}-spot-event-discord"
  interruption_rule = "${var.project_name}-spot-interruption-warning"
  rebalance_rule    = "${var.project_name}-spot-rebalance-recommendation"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/spot-event-discord"
  output_path = "${path.module}/lambda/spot-event-discord.zip"
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

  tags = { Name = "${local.lambda_name}-role", Purpose = "spot-interruption-pipeline" }
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
        Sid      = "AllowDescribeInstance"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
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
  timeout          = 10
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      DISCORD_WEBHOOK_URL      = var.discord_webhook_url
      DISCORD_WEBHOOK_USERNAME = var.discord_username
      MENTION_TEXT             = var.mention_text
      CLUSTER_NAME             = var.cluster_name
    }
  }

  tags = { Name = local.lambda_name, Purpose = "spot-interruption-pipeline" }
}

resource "aws_cloudwatch_event_rule" "interruption" {
  count = var.enabled ? 1 : 0

  name        = local.interruption_rule
  description = "EC2 Spot Instance Interruption Warning -> Discord"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = { Name = local.interruption_rule, Purpose = "spot-interruption-pipeline" }
}

resource "aws_cloudwatch_event_rule" "rebalance" {
  count = var.enabled ? 1 : 0

  name        = local.rebalance_rule
  description = "EC2 Instance Rebalance Recommendation -> Discord"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = { Name = local.rebalance_rule, Purpose = "spot-interruption-pipeline" }
}

resource "aws_cloudwatch_event_target" "interruption" {
  count = var.enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.interruption[0].name
  target_id = "spot-interruption-discord-lambda"
  arn       = aws_lambda_function.this[0].arn
}

resource "aws_cloudwatch_event_target" "rebalance" {
  count = var.enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.rebalance[0].name
  target_id = "spot-rebalance-discord-lambda"
  arn       = aws_lambda_function.this[0].arn
}

resource "aws_lambda_permission" "interruption" {
  count = var.enabled ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridgeSpotInterruption"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.interruption[0].arn
}

resource "aws_lambda_permission" "rebalance" {
  count = var.enabled ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridgeSpotRebalance"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rebalance[0].arn
}
