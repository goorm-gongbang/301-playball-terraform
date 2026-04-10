#############################################
# Prod Environment - Outputs
#############################################

# VPC
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_eip" {
  description = "NAT Gateway Elastic IP"
  value       = module.vpc.nat_gateway_public_ip
}

# EKS
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority" {
  description = "EKS cluster CA certificate (base64)"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "eks_external_secrets_irsa_role_arn" {
  description = "External Secrets IRSA role ARN"
  value       = module.eks.external_secrets_irsa_role_arn
}

output "eks_external_dns_irsa_role_arn" {
  description = "External DNS IRSA role ARN"
  value       = module.eks.external_dns_irsa_role_arn
}

output "eks_aws_lb_controller_irsa_role_arn" {
  description = "AWS Load Balancer Controller IRSA role ARN"
  value       = module.eks.aws_lb_controller_irsa_role_arn
}

output "grafana_cloudwatch_irsa_role_arn" {
  description = "Grafana CloudWatch IRSA role ARN"
  value       = module.eks.grafana_cloudwatch_irsa_role_arn
}

# Observability IRSA
output "observability_irsa_role_arns" {
  description = "Observability IRSA role ARNs (loki, tempo, thanos)"
  value       = module.observability_irsa.role_arns
}

# Bastion
output "bastion_instance_id" {
  description = "Bastion instance ID"
  value       = module.bastion.instance_id
}

output "bastion_ssm_command" {
  description = "SSM command to connect to bastion"
  value       = module.bastion.ssm_command
}

# Redis
output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = module.elasticache.redis_endpoint
}

# ACM
output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = data.aws_acm_certificate.common.arn
}

# RDS
output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
}

output "rds_address" {
  description = "RDS address (hostname only)"
  value       = module.rds.address
}

output "rds_db_name" {
  description = "Database name"
  value       = module.rds.db_name
}

output "rds_username" {
  description = "Database master username"
  value       = module.rds.username
}

# Karpenter
output "karpenter_irsa_role_arn" {
  description = "Karpenter controller IRSA role ARN"
  value       = module.karpenter.controller_irsa_role_arn
}

output "karpenter_node_role_arn" {
  description = "Karpenter node IAM role ARN"
  value       = module.karpenter.node_iam_role_arn
}

output "karpenter_queue_name" {
  description = "Karpenter interruption SQS queue name"
  value       = module.karpenter.interruption_queue_name
}
