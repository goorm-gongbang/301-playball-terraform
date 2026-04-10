#############################################
# Bastion Module - Outputs
#############################################

output "instance_id" {
  description = "Bastion instance ID"
  value       = aws_instance.bastion.id
}

output "private_ip" {
  description = "Bastion private IP"
  value       = aws_instance.bastion.private_ip
}

output "public_ip" {
  description = "Bastion public IP"
  value       = aws_instance.bastion.public_ip
}

output "security_group_id" {
  description = "Bastion security group ID"
  value       = aws_security_group.bastion.id
}

output "iam_role_arn" {
  description = "Bastion IAM role ARN"
  value       = aws_iam_role.bastion.arn
}

output "iam_role_name" {
  description = "Bastion IAM role name"
  value       = aws_iam_role.bastion.name
}

output "ssm_command" {
  description = "SSM command to connect"
  value       = "aws ssm start-session --target ${aws_instance.bastion.id}"
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_eip.bastion.public_ip
}
