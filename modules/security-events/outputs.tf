output "lambda_name" {
  description = "Security event Lambda function name"
  value       = var.enabled ? aws_lambda_function.this[0].function_name : null
}

output "rule_name" {
  description = "Security event EventBridge rule name"
  value       = var.enabled ? aws_cloudwatch_event_rule.this[0].name : null
}

output "unauthorized_rule_name" {
  description = "Unauthorized API EventBridge rule name"
  value       = length(aws_cloudwatch_event_rule.unauthorized_api) > 0 ? aws_cloudwatch_event_rule.unauthorized_api[0].name : null
}
