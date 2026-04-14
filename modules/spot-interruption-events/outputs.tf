output "lambda_name" {
  description = "Lambda function name"
  value       = try(aws_lambda_function.this[0].function_name, null)
}

output "lambda_arn" {
  description = "Lambda function ARN"
  value       = try(aws_lambda_function.this[0].arn, null)
}

output "interruption_rule_name" {
  description = "EventBridge rule name for spot interruption warnings"
  value       = try(aws_cloudwatch_event_rule.interruption[0].name, null)
}

output "rebalance_rule_name" {
  description = "EventBridge rule name for rebalance recommendations"
  value       = try(aws_cloudwatch_event_rule.rebalance[0].name, null)
}
