#############################################
# EKS Module - Main Resources
#############################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_full_name
  cluster_version = var.cluster_version

  # Addon은 별도 리소스로 관리 (순서 제어 가능)
  bootstrap_self_managed_addons            = false
  cluster_addons                           = {}
  enable_cluster_creator_admin_permissions = false
  iam_role_use_name_prefix                 = false
  iam_role_name                            = local.cluster_iam_role_name

  # Access Entries (use static booleans for plan-time evaluation)
  access_entries = merge(
    var.enable_devops_role_access ? {
      devops_role = {
        principal_arn = var.devops_role_arn
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    } : {},
    var.enable_devops_user_access ? {
      devops_user = {
        principal_arn = var.devops_user_arn
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    } : {}
  )

  # VPC
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Cluster Endpoint
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access      = true

  # Cluster Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # OIDC Provider (for IRSA)
  enable_irsa = true

  # Cluster Security Group Rules
  cluster_security_group_additional_rules = merge(
    # Bastion ingress (optional - only if bastion SG provided)
    var.bastion_security_group_id != "" ? {
      bastion_ingress = {
        description              = "Bastion to EKS API"
        protocol                 = "tcp"
        from_port                = 443
        to_port                  = 443
        type                     = "ingress"
        source_security_group_id = var.bastion_security_group_id
      }
    } : {},
    # Always-present rules
    {
      egress_all = {
        description = "Cluster all egress"
        protocol    = "-1"
        from_port   = 0
        to_port     = 0
        type        = "egress"
        cidr_blocks = ["0.0.0.0/0"]
      }
      # ALB Ingress Controller (target-type: ip) - ALB가 Pod IP로 직접 통신
      alb_ingress = {
        description = "ALB to Pods (target-type: ip)"
        protocol    = "tcp"
        from_port   = 0
        to_port     = 65535
        type        = "ingress"
        cidr_blocks = var.vpc_cidr_blocks
      }
    }
  )

  # EKS Managed Node Groups - 외부 리소스로 분리 (순서 제어)
  eks_managed_node_groups = {}

  tags = {
    Name = local.cluster_full_name
  }
}

#############################################
# Core EKS Addons (순서 제어)
#############################################

# 1. VPC CNI - 가장 먼저 (Pod 네트워킹)
# Note: vpc-cni는 기본 tolerations 사용 (모든 taint 허용)
# Prometheus 메트릭 활성화 (awscni_* 메트릭)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = module.eks.cluster_name
  addon_name   = "vpc-cni"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "${local.name_prefix}-vpc-cni-addon"
  }
}

# 2. kube-proxy - VPC CNI 다음
# Note: kube-proxy는 configuration_values로 tolerations 지원 안 함 (기본 내장)
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = module.eks.cluster_name
  addon_name   = "kube-proxy"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "${local.name_prefix}-kube-proxy-addon"
  }

  depends_on = [aws_eks_addon.vpc_cni]
}

#############################################
# Addon 안정화 대기 (Race Condition 방지)
#############################################

resource "time_sleep" "wait_for_core_addons" {
  create_duration = "30s"

  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy
  ]
}

#############################################
# Node Group IAM Role (외부 관리)
#############################################

resource "aws_iam_role" "node_infra" {
  name = local.infra_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Sid = "EKSNodeAssumeRole"
      }
    ]
  })

  force_detach_policies = true

  tags = {
    Name = local.infra_role_name
  }
}

resource "aws_iam_role_policy_attachment" "node_infra_worker" {
  role       = aws_iam_role.node_infra.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_infra_cni" {
  role       = aws_iam_role.node_infra.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_infra_ecr" {
  role       = aws_iam_role.node_infra.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_infra_ebs_csi" {
  role       = aws_iam_role.node_infra.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "node_infra_ssm" {
  role       = aws_iam_role.node_infra.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#############################################
# Launch Templates (IMDS hop limit = 2 for pod access)
#############################################

resource "aws_launch_template" "infra" {
  name_prefix = "${local.name_slug}-infra-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # EC2 인스턴스에 Name 태그 추가
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}-infra-node"
    }
  }

  tags = {
    Name = "${local.name_prefix}-infra-lt"
  }
}

resource "aws_launch_template" "monitoring" {
  name_prefix = "${local.name_slug}-monitoring-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}-monitoring-node"
    }
  }

  tags = {
    Name = "${local.name_prefix}-monitoring-lt"
  }
}

resource "aws_launch_template" "apps" {
  name_prefix = "${local.name_slug}-apps-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "${local.name_prefix}-apps-lt"
  }
}

#############################################
# EKS Managed Node Group - Infra (외부 관리)
#############################################

resource "aws_eks_node_group" "infra" {
  cluster_name    = module.eks.cluster_name
  node_group_name_prefix = var.owner_name != "" ? "${var.owner_name}-infra-ng-" : "infra-ng-"
  node_role_arn   = aws_iam_role.node_infra.arn
  subnet_ids      = var.private_subnet_ids

  ami_type       = "AL2023_ARM_64_STANDARD"
  instance_types = var.infra_instance_types
  capacity_type  = var.infra_capacity_type

  launch_template {
    id      = aws_launch_template.infra.id
    version = aws_launch_template.infra.latest_version
  }

  scaling_config {
    min_size     = var.infra_min_size
    max_size     = var.infra_max_size
    desired_size = var.infra_desired_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  labels = {
    "arch"          = "arm64"
    "role"          = "infra"
    "capacity-type" = "on-demand"
    "workload"      = "infra"
    "owner"         = var.owner_name
  }

  taint {
    key    = "role"
    value  = "infra"
    effect = "NO_SCHEDULE"
  }

  tags = {
    Name = var.owner_name != "" ? "${var.owner_name}-infra-ng" : "infra-ng"
  }

  lifecycle {
    create_before_destroy = true
  }

  # 핵심: vpc-cni, kube-proxy addon + 30초 대기 후 노드그룹 생성
  depends_on = [
    time_sleep.wait_for_core_addons,
    aws_iam_role_policy_attachment.node_infra_worker,
    aws_iam_role_policy_attachment.node_infra_cni,
    aws_iam_role_policy_attachment.node_infra_ecr,
    aws_iam_role_policy_attachment.node_infra_ebs_csi,
    aws_iam_role_policy_attachment.node_infra_ssm
  ]
}

#############################################
# Node Group IAM Role - Monitoring
#############################################

resource "aws_iam_role" "node_monitoring" {
  name = local.monitoring_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Sid = "EKSNodeAssumeRole"
      }
    ]
  })

  force_detach_policies = true

  tags = {
    Name = local.monitoring_role_name
  }
}

resource "aws_iam_role_policy_attachment" "node_monitoring_worker" {
  role       = aws_iam_role.node_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_monitoring_cni" {
  role       = aws_iam_role.node_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_monitoring_ecr" {
  role       = aws_iam_role.node_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_monitoring_ebs_csi" {
  role       = aws_iam_role.node_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "node_monitoring_ssm" {
  role       = aws_iam_role.node_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#############################################
# EKS Managed Node Group - Monitoring
#############################################

resource "aws_eks_node_group" "monitoring" {
  cluster_name    = module.eks.cluster_name
  node_group_name_prefix = var.owner_name != "" ? "${var.owner_name}-monitoring-ng-" : "monitoring-ng-"
  node_role_arn   = aws_iam_role.node_monitoring.arn
  subnet_ids      = var.private_subnet_ids

  ami_type       = "AL2023_ARM_64_STANDARD"
  instance_types = var.monitoring_instance_types
  capacity_type  = var.monitoring_capacity_type

  launch_template {
    id      = aws_launch_template.monitoring.id
    version = aws_launch_template.monitoring.latest_version
  }

  scaling_config {
    min_size     = var.monitoring_min_size
    max_size     = var.monitoring_max_size
    desired_size = var.monitoring_desired_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  labels = {
    "arch"          = "arm64"
    "role"          = "monitoring"
    "capacity-type" = lower(var.monitoring_capacity_type)
    "workload"      = "monitoring"
    "owner"         = var.owner_name
  }

  taint {
    key    = "role"
    value  = "monitoring"
    effect = "NO_SCHEDULE"
  }

  tags = {
    Name = var.owner_name != "" ? "${var.owner_name}-monitoring-ng" : "monitoring-ng"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    time_sleep.wait_for_core_addons,
    aws_iam_role_policy_attachment.node_monitoring_worker,
    aws_iam_role_policy_attachment.node_monitoring_cni,
    aws_iam_role_policy_attachment.node_monitoring_ecr,
    aws_iam_role_policy_attachment.node_monitoring_ebs_csi,
    aws_iam_role_policy_attachment.node_monitoring_ssm
  ]
}

#############################################
# Node Group IAM Role - Apps
#############################################

resource "aws_iam_role" "node_apps" {
  name = local.apps_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Sid = "EKSNodeAssumeRole"
      }
    ]
  })

  force_detach_policies = true

  tags = {
    Name = local.apps_role_name
  }
}

resource "aws_iam_role_policy_attachment" "node_apps_worker" {
  role       = aws_iam_role.node_apps.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_apps_cni" {
  role       = aws_iam_role.node_apps.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_apps_ecr" {
  role       = aws_iam_role.node_apps.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_apps_ebs_csi" {
  role       = aws_iam_role.node_apps.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "node_apps_ssm" {
  role       = aws_iam_role.node_apps.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#############################################
# EKS Managed Node Group - Apps (taint 없음)
#############################################

resource "aws_eks_node_group" "apps" {
  cluster_name    = module.eks.cluster_name
  node_group_name_prefix = "${var.owner_name}-${var.environment}-apps-ng-"
  node_role_arn   = aws_iam_role.node_apps.arn
  subnet_ids      = var.private_subnet_ids

  ami_type       = "AL2023_ARM_64_STANDARD"
  instance_types = var.apps_instance_types
  capacity_type  = var.apps_capacity_type

  launch_template {
    id      = aws_launch_template.apps.id
    version = aws_launch_template.apps.latest_version
  }

  scaling_config {
    min_size     = var.apps_min_size
    max_size     = var.apps_max_size
    desired_size = var.apps_desired_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  labels = {
    "arch"          = "arm64"
    "role"          = "app"
    "capacity-type" = lower(var.apps_capacity_type)
    "workload"      = "app"
    "owner"         = var.owner_name
  }

  # apps 노드그룹은 taint 없음 (일반 워크로드용)

  tags = {
    Name = var.owner_name != "" ? "${var.owner_name}-staging-apps-ng" : "staging-apps-ng"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    time_sleep.wait_for_core_addons,
    aws_iam_role_policy_attachment.node_apps_worker,
    aws_iam_role_policy_attachment.node_apps_cni,
    aws_iam_role_policy_attachment.node_apps_ecr,
    aws_iam_role_policy_attachment.node_apps_ebs_csi,
    aws_iam_role_policy_attachment.node_apps_ssm
  ]
}

# 3. CoreDNS - 노드그룹 생성 후 (infra 노드에 배치)
resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_name
  addon_name   = "coredns"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    tolerations = [
      {
        key      = "role"
        operator = "Equal"
        value    = "infra"
        effect   = "NoSchedule"
      }
    ]
    nodeSelector = {
      role = "infra"
    }
  })

  tags = {
    Name = "${local.name_prefix}-coredns-addon"
  }

  # 핵심: infra 노드그룹이 Ready 된 후에 CoreDNS 설치
  depends_on = [aws_eks_node_group.infra]
}

#############################################
# EBS CSI Driver IRSA
#############################################

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = local.ebs_csi_irsa_role_name

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = {
    Name = "${local.name_prefix}-ebs-csi-irsa"
  }
}

#############################################
# EBS CSI Driver Addon
#############################################

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_addon_version
  service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    controller = {
      tolerations = [
        {
          key      = "role"
          operator = "Equal"
          value    = "infra"
          effect   = "NoSchedule"
        }
      ]
      nodeSelector = {
        role = "infra"
      }
    }
    node = {
      tolerations = [
        {
          key      = "role"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ]
    }
  })

  tags = {
    Name = "${local.name_prefix}-ebs-csi-addon"
  }

  depends_on = [aws_eks_addon.coredns]
}

# gp3 StorageClass는 ArgoCD (eso-config)에서 생성
# - Private EKS는 terraform에서 kubernetes provider 연결 불가
# - bastion에서 kubectl 또는 ArgoCD로 생성

#############################################
# External Secrets IRSA
#############################################

module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name_slug}-external-secrets-irsa"

  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = var.secrets_manager_arns

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

  tags = {
    Name = "${local.name_prefix}-external-secrets-irsa"
  }
}

#############################################
# External DNS IRSA
#############################################

module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name_slug}-external-dns"

  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = ["arn:aws:route53:::hostedzone/*"]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }

  tags = {
    Name = "${local.name_prefix}-external-dns"
  }
}

#############################################
# AWS Load Balancer Controller IRSA
#############################################

module "aws_lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name_slug}-aws-lb-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Name = "${local.name_prefix}-aws-lb-controller"
  }
}

#############################################
# Grafana CloudWatch IRSA
#############################################

resource "aws_iam_policy" "grafana_cloudwatch" {
  name        = "${local.name_slug}-grafana-cloudwatch"
  description = "Allow Grafana to read CloudWatch metrics (RDS, ElastiCache)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetInsightRuleReport"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:GetLogGroupFields",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2Describe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeTags",
          "ec2:DescribeInstances",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      },
      {
        Sid    = "TagResources"
        Effect = "Allow"
        Action = [
          "tag:GetResources"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSDescribe"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:DescribeDBClusterParameters",
          "rds:DescribeDBInstanceAutomatedBackups",
          "rds:DescribeDBLogFiles",
          "rds:DescribeDBParameterGroups",
          "rds:DescribeDBParameters",
          "rds:DescribeDBSnapshots",
          "rds:DescribeDBSubnetGroups",
          "rds:DescribeEventCategories",
          "rds:DescribeEvents",
          "rds:DescribeOptionGroups",
          "rds:DescribeOrderableDBInstanceOptions",
          "rds:DescribePendingMaintenanceActions",
          "rds:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "ElastiCacheDescribe"
        Effect = "Allow"
        Action = [
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeCacheEngineVersions",
          "elasticache:DescribeCacheParameterGroups",
          "elasticache:DescribeCacheParameters",
          "elasticache:DescribeCacheSecurityGroups",
          "elasticache:DescribeCacheSubnetGroups",
          "elasticache:DescribeEngineDefaultParameters",
          "elasticache:DescribeEvents",
          "elasticache:DescribeReplicationGroups",
          "elasticache:DescribeReservedCacheNodes",
          "elasticache:DescribeReservedCacheNodesOfferings",
          "elasticache:DescribeSnapshots",
          "elasticache:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-grafana-cloudwatch"
  }
}

module "grafana_cloudwatch_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name_slug}-grafana-cloudwatch"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["monitoring:grafana"]
    }
  }

  tags = {
    Name = "${local.name_prefix}-grafana-cloudwatch"
  }
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  role       = module.grafana_cloudwatch_irsa.iam_role_name
  policy_arn = aws_iam_policy.grafana_cloudwatch.arn
}

#############################################
# ECR Cross-Account Pull (optional)
#############################################

resource "aws_iam_policy" "ecr_cross_account_pull" {
  count = var.main_account_id != "" ? 1 : 0

  name        = "${local.name_slug}-ecr-cross-account-pull"
  description = "Allow pulling images from main account ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${var.main_account_id}:repository/*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      }
    ]
  })
}

# ECR Cross-Account Pull (optional) - infra 노드에 적용
resource "aws_iam_role_policy_attachment" "node_ecr_cross_account" {
  count = var.main_account_id != "" ? 1 : 0

  role       = aws_iam_role.node_infra.name
  policy_arn = aws_iam_policy.ecr_cross_account_pull[0].arn
}

#############################################
# RDS Backup IRSA (S3 Write Access)
#############################################

resource "aws_iam_policy" "rds_backup" {
  name        = "${local.name_slug}-rds-backup"
  description = "Allow RDS backup CronJob to write to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3WriteBackup"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::playball-web-backup",
          "arn:aws:s3:::playball-web-backup/${var.environment}/postgres/*"
        ]
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-rds-backup"
  }
}

module "rds_backup_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name_slug}-rds-backup"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["data:rds-backup"]
    }
  }

  tags = {
    Name = "${local.name_prefix}-rds-backup"
  }
}

resource "aws_iam_role_policy_attachment" "rds_backup" {
  role       = module.rds_backup_irsa.iam_role_name
  policy_arn = aws_iam_policy.rds_backup.arn
}

#############################################
# AI Defense IRSA (S3 Audit Archive)
#############################################

resource "aws_iam_policy" "ai_defense" {
  name        = "${local.name_slug}-ai-defense"
  description = "AI Defense S3 audit archive access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3AuditArchive"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::playball-staging-ai-audit",
          "arn:aws:s3:::playball-staging-ai-audit/*"
        ]
      }
    ]
  })
}

module "ai_defense_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name_slug}-ai-defense"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["staging-ai:ai-defense"]
    }
  }

  tags = {
    Name = "${local.name_prefix}-ai-defense"
  }
}

resource "aws_iam_role_policy_attachment" "ai_defense" {
  role       = module.ai_defense_irsa.iam_role_name
  policy_arn = aws_iam_policy.ai_defense.arn
}
