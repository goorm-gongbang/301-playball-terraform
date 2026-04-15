#############################################
# EKS Module - Outputs
#############################################

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster CA certificate"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "EKS node security group ID"
  value       = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider" {
  description = "OIDC provider URL (without https://)"
  value       = module.eks.oidc_provider
}

output "cluster_iam_role_arn" {
  description = "EKS cluster IAM role ARN"
  value       = module.eks.cluster_iam_role_arn
}

output "eks_managed_node_groups" {
  description = "EKS managed node groups (외부 관리)"
  value = {
    infra = {
      node_group_name = aws_eks_node_group.infra.node_group_name
      arn             = aws_eks_node_group.infra.arn
      status          = aws_eks_node_group.infra.status
      iam_role_arn    = aws_iam_role.node_infra.arn
      iam_role_name   = aws_iam_role.node_infra.name
    }
    monitoring = {
      node_group_name = aws_eks_node_group.monitoring.node_group_name
      arn             = aws_eks_node_group.monitoring.arn
      status          = aws_eks_node_group.monitoring.status
      iam_role_arn    = aws_iam_role.node_monitoring.arn
      iam_role_name   = aws_iam_role.node_monitoring.name
    }
    apps = {
      node_group_name = aws_eks_node_group.apps.node_group_name
      arn             = aws_eks_node_group.apps.arn
      status          = aws_eks_node_group.apps.status
      iam_role_arn    = aws_iam_role.node_apps.arn
      iam_role_name   = aws_iam_role.node_apps.name
    }
  }
}

output "ebs_csi_irsa_role_arn" {
  description = "EBS CSI driver IRSA role ARN"
  value       = module.ebs_csi_driver_irsa.iam_role_arn
}

output "external_secrets_irsa_role_arn" {
  description = "External Secrets IRSA role ARN"
  value       = module.external_secrets_irsa.iam_role_arn
}

output "external_dns_irsa_role_arn" {
  description = "External DNS IRSA role ARN"
  value       = module.external_dns_irsa.iam_role_arn
}

output "aws_lb_controller_irsa_role_arn" {
  description = "AWS Load Balancer Controller IRSA role ARN"
  value       = module.aws_lb_controller_irsa.iam_role_arn
}

output "grafana_cloudwatch_irsa_role_arn" {
  description = "Grafana CloudWatch IRSA role ARN"
  value       = module.grafana_cloudwatch_irsa.iam_role_arn
}

output "rds_backup_irsa_role_arn" {
  description = "RDS Backup IRSA role ARN"
  value       = module.rds_backup_irsa.iam_role_arn
}

output "logs_backup_irsa_role_arn" {
  description = "Logs Backup IRSA role ARN"
  value       = module.logs_backup_irsa.iam_role_arn
}

output "ai_defense_irsa_role_arn" {
  description = "AI Defense IRSA role ARN (S3 audit archive)"
  value       = module.ai_defense_irsa.iam_role_arn
}

#############################################
# EKS Addons
#############################################

output "cluster_addons" {
  description = "EKS cluster addons (별도 리소스로 관리)"
  value = {
    vpc_cni = {
      name    = aws_eks_addon.vpc_cni.addon_name
      version = aws_eks_addon.vpc_cni.addon_version
      arn     = aws_eks_addon.vpc_cni.arn
    }
    kube_proxy = {
      name    = aws_eks_addon.kube_proxy.addon_name
      version = aws_eks_addon.kube_proxy.addon_version
      arn     = aws_eks_addon.kube_proxy.arn
    }
    coredns = {
      name    = aws_eks_addon.coredns.addon_name
      version = aws_eks_addon.coredns.addon_version
      arn     = aws_eks_addon.coredns.arn
    }
    ebs_csi_driver = {
      name    = aws_eks_addon.ebs_csi_driver.addon_name
      version = aws_eks_addon.ebs_csi_driver.addon_version
      arn     = aws_eks_addon.ebs_csi_driver.arn
    }
  }
}
