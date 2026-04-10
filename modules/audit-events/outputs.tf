output "lambda_name" {
  description = "Audit event Lambda function name"
  value       = var.enabled ? aws_lambda_function.this[0].function_name : null
}

output "rule_name" {
  description = "Audit event EventBridge rule name"
  value       = var.enabled ? aws_cloudwatch_event_rule.this[0].name : null
}
