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
# Bastion
#############################################

output "bastion_instance_id" {
  description = "Bastion instance ID (SSM 접속용)"
  value       = module.bastion.instance_id
}

output "bastion_ssm_command" {
  description = "SSM 접속 명령어"
  value       = module.bastion.ssm_command
}

#############################################
# EKS - Cluster
#############################################

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority" {
  description = "EKS cluster CA certificate (base64)"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

#############################################
# EKS - Security Groups
#############################################

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "eks_node_security_group_id" {
  description = "EKS node security group ID (공통)"
  value       = module.eks.node_security_group_id
}

#############################################
# EKS - IRSA Roles
#############################################

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "eks_oidc_provider" {
  description = "OIDC provider URL (without https://)"
  value       = module.eks.oidc_provider
}

output "irsa_roles" {
  description = "IRSA role ARNs 전체"
  value = {
    ebs_csi          = module.eks.ebs_csi_irsa_role_arn
    external_secrets = module.eks.external_secrets_irsa_role_arn
    external_dns     = module.eks.external_dns_irsa_role_arn
    aws_lb_controller = module.eks.aws_lb_controller_irsa_role_arn
    grafana_cloudwatch = module.eks.grafana_cloudwatch_irsa_role_arn
    rds_backup       = module.eks.rds_backup_irsa_role_arn
    ai_defense       = module.eks.ai_defense_irsa_role_arn
    observability    = module.observability_irsa.role_arns
  }
}

#############################################
# EKS - Karpenter
#############################################

output "karpenter" {
  description = "Karpenter 설정 정보"
  value = {
    irsa_role_arn       = module.karpenter.controller_irsa_role_arn
    node_role_arn       = module.karpenter.node_iam_role_arn
    instance_profile    = module.karpenter.node_instance_profile_name
    interruption_queue  = module.karpenter.interruption_queue_name
  }
}

# Bootstrap 호환 (개별 output)
output "karpenter_irsa_role_arn" {
  value = module.karpenter.controller_irsa_role_arn
}
output "karpenter_queue_name" {
  value = module.karpenter.interruption_queue_name
}
output "eks_external_secrets_irsa_role_arn" {
  value = module.eks.external_secrets_irsa_role_arn
}
output "rds_address" {
  value = module.rds.address
}
output "redis_endpoint" {
  value = module.elasticache.redis_endpoint
}

#############################################
# RDS (PostgreSQL)
#############################################

output "rds" {
  description = "RDS 접속 정보"
  value = {
    endpoint    = module.rds.endpoint
    address     = module.rds.address
    port        = 5432
    db_name     = module.rds.db_name
    username    = module.rds.username
    secret_arn  = module.rds.master_user_secret_arn
  }
}

#############################################
# ElastiCache (Redis)
#############################################

output "redis" {
  description = "Redis 접속 정보"
  value = {
    endpoint = module.elasticache.redis_endpoint
    url      = module.elasticache.redis_url
    port     = 6379
  }
}

#############################################
# Security Summary
#############################################

output "security_summary" {
  description = "보안 설정 요약"
  value = {
    eks_public_access  = "팀 IP 3개 제한"
    eks_private_access = true
    eks_audit_logging  = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    rds_encryption     = true
    rds_multi_az       = false
    rds_deletion_protection = false
    redis_tls          = true
    bastion_ssh        = "비활성화 (SSM 전용)"
  }
}
