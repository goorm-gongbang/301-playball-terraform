#############################################
# Staging Environment - Outputs
#############################################

#############################################
# VPC
#############################################

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

#############################################
# EKS
#############################################

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

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "eks_node_security_group_id" {
  description = "EKS node security group ID"
  value       = module.eks.node_security_group_id
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "eks_oidc_provider" {
  description = "OIDC provider URL (without https://)"
  value       = module.eks.oidc_provider
}

output "eks_ebs_csi_irsa_role_arn" {
  description = "EBS CSI driver IRSA role ARN"
  value       = module.eks.ebs_csi_irsa_role_arn
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

output "rds_backup_irsa_role_arn" {
  description = "RDS Backup IRSA role ARN"
  value       = module.eks.rds_backup_irsa_role_arn
}

output "ai_defense_irsa_role_arn" {
  description = "AI Defense IRSA role ARN (S3 audit archive)"
  value       = module.eks.ai_defense_irsa_role_arn
}

#############################################
# ElastiCache (Redis)
#############################################

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = module.elasticache.redis_endpoint
}

output "redis_url" {
  description = "Redis URL for applications"
  value       = module.elasticache.redis_url
}

#############################################
# RDS (PostgreSQL)
#############################################

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

output "rds_secret_arn" {
  description = "Secrets Manager ARN for DB password"
  value       = module.rds.master_user_secret_arn
}

#############################################
# Karpenter
#############################################

output "karpenter_irsa_role_arn" {
  description = "Karpenter controller IRSA role ARN"
  value       = module.karpenter.controller_irsa_role_arn
}

output "karpenter_node_role_arn" {
  description = "Karpenter node IAM role ARN"
  value       = module.karpenter.node_iam_role_arn
}

output "karpenter_instance_profile_name" {
  description = "Karpenter node instance profile name"
  value       = module.karpenter.node_instance_profile_name
}

output "karpenter_queue_name" {
  description = "Karpenter interruption SQS queue name"
  value       = module.karpenter.interruption_queue_name
}
