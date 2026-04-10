#############################################
# Ops Alerting Module
# CloudWatch Alarm → SNS → Lambda → Discord
# Scheduled RDS backup/PITR checker → Discord
#############################################

locals {
  name_prefix = "${var.owner_name}-${var.environment}"
}

#############################################
# Lambda Archives
#############################################

data "archive_file" "cloudwatch_alarm_discord" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/cloudwatch-alarm-discord"
  output_path = "${path.module}/lambda/cloudwatch-alarm-discord.zip"
}

data "archive_file" "rds_backup_check" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/rds-backup-check"
  output_path = "${path.module}/lambda/rds-backup-check.zip"
}

#############################################
# SNS Topics
#############################################

resource "aws_sns_topic" "ops_warning" {
  name = "${local.name_prefix}-ops-warning"
}

resource "aws_sns_topic" "ops_critical" {
  name = "${local.name_prefix}-ops-critical"
}

#############################################
# Lambda — CloudWatch Alarm → Discord
#############################################

resource "aws_iam_role" "cloudwatch_alarm_discord" {
  name = "${local.name_prefix}-cloudwatch-alarm-discord-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudwatch_alarm_discord" {
  name = "${local.name_prefix}-cloudwatch-alarm-discord-policy"
  role = aws_iam_role.cloudwatch_alarm_discord.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.discord_secret_name}*"
      }
    ]
  })
}

resource "aws_lambda_function" "cloudwatch_alarm_discord" {
  function_name    = "${local.name_prefix}-cloudwatch-alarm-discord"
  role             = aws_iam_role.cloudwatch_alarm_discord.arn
  filename         = data.archive_file.cloudwatch_alarm_discord.output_path
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = data.archive_file.cloudwatch_alarm_discord.output_base64sha256

  environment {
    variables = {
      DISCORD_SECRET_NAME      = var.discord_secret_name
      DISCORD_WEBHOOK_USERNAME = "goormgb-aws-alert-bot"
      WARNING_WEBHOOK_KEY      = "warningWebhookUrl"
      CRITICAL_WEBHOOK_KEY     = "criticalWebhookUrl"
      INFO_WEBHOOK_KEY         = "infoWebhookUrl"
      CRITICAL_MENTION_TEXT    = var.critical_mention_text
      ENVIRONMENT              = var.environment
    }
  }
}

#############################################
# SNS → Lambda 연결
#############################################

resource "aws_sns_topic_subscription" "ops_warning_lambda" {
  topic_arn = aws_sns_topic.ops_warning.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.cloudwatch_alarm_discord.arn
}

resource "aws_sns_topic_subscription" "ops_critical_lambda" {
  topic_arn = aws_sns_topic.ops_critical.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.cloudwatch_alarm_discord.arn
}

resource "aws_lambda_permission" "ops_warning_sns" {
  statement_id  = "AllowExecutionFromOpsWarningSns"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudwatch_alarm_discord.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.ops_warning.arn
}

resource "aws_lambda_permission" "ops_critical_sns" {
  statement_id  = "AllowExecutionFromOpsCriticalSns"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudwatch_alarm_discord.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.ops_critical.arn
}

#############################################
# CloudWatch Alarms — Redis Memory
#############################################

resource "aws_cloudwatch_metric_alarm" "redis_memory_warning" {
  alarm_name          = "${local.name_prefix}-redis-memory-warning"
  alarm_description   = "Redis memory usage exceeded ${var.redis_warning_threshold}%"
  actions_enabled     = var.alarms_enabled
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = var.redis_warning_threshold
  treat_missing_data  = "missing"

  dimensions = {
    CacheClusterId = var.redis_cache_cluster_id
  }

  alarm_actions = [aws_sns_topic.ops_warning.arn]
  ok_actions    = [aws_sns_topic.ops_warning.arn]
}

resource "aws_cloudwatch_metric_alarm" "redis_memory_critical" {
  alarm_name          = "${local.name_prefix}-redis-memory-critical"
  alarm_description   = "Redis memory usage exceeded ${var.redis_critical_threshold}%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = var.redis_critical_threshold
  treat_missing_data  = "missing"

  dimensions = {
    CacheClusterId = var.redis_cache_cluster_id
  }

  alarm_actions = [aws_sns_topic.ops_critical.arn]
  ok_actions    = [aws_sns_topic.ops_critical.arn]
}

#############################################
# Lambda — RDS Backup Checker
#############################################

resource "aws_iam_role" "rds_backup_check" {
  name = "${local.name_prefix}-rds-backup-check-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "rds_backup_check" {
  name = "${local.name_prefix}-rds-backup-check-policy"
  role = aws_iam_role.rds_backup_check.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.discord_secret_name}*"
      },
      {
        Effect   = "Allow"
        Action   = ["rds:DescribeDBInstances", "rds:DescribeDBSnapshots"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${var.backup_s3_bucket}"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${var.backup_s3_bucket}/${var.environment}/postgres/*"
      }
    ]
  })
}

resource "aws_lambda_function" "rds_backup_check" {
  function_name    = "${local.name_prefix}-rds-backup-check"
  role             = aws_iam_role.rds_backup_check.arn
  filename         = data.archive_file.rds_backup_check.output_path
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = data.archive_file.rds_backup_check.output_base64sha256

  environment {
    variables = {
      DB_INSTANCE_IDENTIFIER   = var.rds_instance_identifier
      DISCORD_SECRET_NAME      = var.discord_secret_name
      DISCORD_WEBHOOK_USERNAME = "goormgb-rds-backup-bot"
      WARNING_WEBHOOK_KEY      = "warningWebhookUrl"
      CRITICAL_WEBHOOK_KEY     = "criticalWebhookUrl"
      CRITICAL_MENTION_TEXT    = var.critical_mention_text
      ENVIRONMENT              = var.environment
      SNAPSHOT_STALE_HOURS     = tostring(var.snapshot_stale_hours)
      DUMP_S3_BUCKET           = var.backup_s3_bucket
      DUMP_S3_PREFIX           = "${var.environment}/postgres/"
      DUMP_STALE_HOURS         = tostring(var.dump_stale_hours)
    }
  }
}

resource "aws_cloudwatch_event_rule" "rds_backup_check" {
  name                = "${local.name_prefix}-rds-backup-check"
  description         = "Daily ${var.environment} RDS backup/PITR state check"
  schedule_expression = var.backup_check_schedule
}

resource "aws_cloudwatch_event_target" "rds_backup_check" {
  rule      = aws_cloudwatch_event_rule.rds_backup_check.name
  target_id = "rds-backup-check-lambda"
  arn       = aws_lambda_function.rds_backup_check.arn
}

resource "aws_lambda_permission" "rds_backup_check_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridgeRdsBackupCheck"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_backup_check.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rds_backup_check.arn
}
