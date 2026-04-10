#############################################
# RDS Module - Outputs
#############################################

output "endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "RDS address (hostname only)"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "RDS port"
  value       = aws_db_instance.main.port
}

output "identifier" {
  description = "RDS identifier"
  value       = aws_db_instance.main.identifier
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "username" {
  description = "Master username"
  value       = aws_db_instance.main.username
}

output "security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

#############################################
# Secrets Manager
#############################################

output "master_user_secret_arn" {
  description = "Secrets Manager ARN for master user password"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "master_user_secret_name" {
  description = "Secrets Manager name for master user password"
  value       = aws_secretsmanager_secret.db_password.name
}

output "master_password" {
  description = "Master password (use with caution)"
  value       = random_password.master.result
  sensitive   = true
}
