#############################################
# Ops Alerting Module - Outputs
#############################################

output "sns_warning_topic_arn" {
  description = "Warning SNS topic ARN"
  value       = aws_sns_topic.ops_warning.arn
}

output "sns_critical_topic_arn" {
  description = "Critical SNS topic ARN"
  value       = aws_sns_topic.ops_critical.arn
}

output "discord_lambda_function_name" {
  description = "Discord alarm Lambda function name"
  value       = aws_lambda_function.cloudwatch_alarm_discord.function_name
}

output "rds_backup_check_function_name" {
  description = "RDS backup checker Lambda function name"
  value       = aws_lambda_function.rds_backup_check.function_name
}
