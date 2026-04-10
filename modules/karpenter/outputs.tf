#############################################
# Karpenter Module - Outputs
#############################################

output "controller_irsa_role_arn" {
  description = "Karpenter controller IRSA role ARN"
  value       = module.karpenter_irsa.iam_role_arn
}

output "controller_irsa_role_name" {
  description = "Karpenter controller IRSA role name"
  value       = module.karpenter_irsa.iam_role_name
}

output "node_iam_role_arn" {
  description = "Karpenter node IAM role ARN"
  value       = module.karpenter_node_iam.iam_role_arn
}

output "node_iam_role_name" {
  description = "Karpenter node IAM role name"
  value       = module.karpenter_node_iam.iam_role_name
}

output "node_instance_profile_name" {
  description = "Karpenter node instance profile name"
  value       = aws_iam_instance_profile.karpenter_node.name
}

output "interruption_queue_arn" {
  description = "SQS queue ARN for Karpenter interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.arn
}

output "interruption_queue_name" {
  description = "SQS queue name for Karpenter interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.name
}
