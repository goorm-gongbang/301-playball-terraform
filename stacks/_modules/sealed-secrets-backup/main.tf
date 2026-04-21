#############################################
# Sealed Secrets Key Backup Module
# Sealing key를 SSM Parameter Store에 백업
# SSM Standard tier = 무료
#############################################

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "parameter_prefix" {
  description = "SSM Parameter Store prefix"
  type        = string
  default     = "/sealed-secrets"
}

resource "aws_ssm_parameter" "sealing_key" {
  name        = "${var.parameter_prefix}/${var.environment}/sealing-key"
  description = "Sealed Secrets controller private key backup (${var.environment})"
  type        = "SecureString"
  value       = "PLACEHOLDER - kubeseal 설치 후 키 백업 필요"

  tags = {
    Name        = "sealed-secrets-key-${var.environment}"
    Environment = var.environment
    Purpose     = "sealed-secrets-key-backup"
  }

  lifecycle {
    ignore_changes = [value]
  }
}

output "sealing_key_parameter_name" {
  value = aws_ssm_parameter.sealing_key.name
}

output "sealing_key_parameter_arn" {
  value = aws_ssm_parameter.sealing_key.arn
}
