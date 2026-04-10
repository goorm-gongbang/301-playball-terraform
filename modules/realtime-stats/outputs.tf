#############################################
# Realtime Stats Module - Outputs
#############################################

output "kinesis_stream_arn" {
  description = "Kinesis Data Stream ARN"
  value       = aws_kinesis_stream.cloudfront_logs.arn
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.realtime_stats.function_name
}

output "realtime_log_config_arn" {
  description = "CloudFront Realtime Log Config ARN (CloudFront에 연결 필요)"
  value       = aws_cloudfront_realtime_log_config.main.arn
}

output "cloudwatch_namespace" {
  description = "CloudWatch metric namespace"
  value       = "PlayBall/RealtimeStats"
}
