output "lambda_name" {
  description = "Secret change Lambda function name"
  value       = var.enabled ? aws_lambda_function.this[0].function_name : null
}

output "rule_name" {
  description = "Secret change EventBridge rule name"
  value       = var.enabled ? aws_cloudwatch_event_rule.this[0].name : null
}
