#############################################
# Karpenter Module - Main Resources
#############################################

data "aws_caller_identity" "current" {}

#############################################
# Karpenter IRSA (IAM Role for Service Account)
#############################################

module "karpenter_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name_slug}-karpenter-controller"

  attach_karpenter_controller_policy = true

  karpenter_controller_cluster_name       = var.eks_cluster_name
  karpenter_controller_node_iam_role_arns = [module.karpenter_node_iam.iam_role_arn]
  karpenter_sqs_queue_arn                 = aws_sqs_queue.karpenter_interruption.arn

  oidc_providers = {
    main = {
      provider_arn               = var.eks_oidc_provider_arn
      namespace_service_accounts = ["${local.karpenter_namespace}:${local.karpenter_service_account}"]
    }
  }

  tags = {
    Name = "${local.name_prefix}-karpenter-controller"
  }
}

#############################################
# Karpenter Controller - Additional IAM Policy
#############################################

resource "aws_iam_role_policy" "karpenter_controller_additional" {
  name = "${local.name_slug}-karpenter-controller-additional"
  role = module.karpenter_irsa.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowInstanceProfileManagement"
        Effect = "Allow"
        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:ListInstanceProfiles",
          "iam:ListInstanceProfilesForRole",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*"
      },
      {
        Sid      = "AllowPassRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = module.karpenter_node_iam.iam_role_arn
      },
      {
        Sid    = "AllowEC2Operations"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      }
    ]
  })
}

#############################################
# Karpenter Node IAM Role
#############################################

module "karpenter_node_iam" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role = true
  role_name   = "${local.name_slug}-karpenter-node"

  role_requires_mfa = false

  trusted_role_services = ["ec2.amazonaws.com"]

  # Use static count to avoid "value depends on resource attributes" error
  number_of_custom_role_policy_arns = var.enable_ecr_cross_account ? 5 : 4

  custom_role_policy_arns = var.enable_ecr_cross_account ? [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    var.ecr_cross_account_policy_arn,
    ] : [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]

  tags = {
    Name = "${local.name_prefix}-karpenter-node"
  }
}

#############################################
# Karpenter Node Instance Profile
#############################################

resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${local.name_slug}-karpenter-node"
  role = module.karpenter_node_iam.iam_role_name

  tags = {
    Name = "${local.name_prefix}-karpenter-node"
  }
}

#############################################
# SQS Queue for Spot Interruption Handling
#############################################

resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${local.name_slug}-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = {
    Name = "${local.name_prefix}-karpenter-interruption"
  }
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["events.amazonaws.com", "sqs.amazonaws.com"]
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter_interruption.arn
      }
    ]
  })
}

#############################################
# EventBridge Rules for Spot Interruption
#############################################

resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  name        = "${local.name_slug}-karpenter-spot-interruption"
  description = "Karpenter Spot Instance Interruption Warning"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = {
    Name = "${local.name_prefix}-karpenter-spot-interruption"
  }
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  rule      = aws_cloudwatch_event_rule.karpenter_spot_interruption.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_instance_rebalance" {
  name        = "${local.name_slug}-karpenter-instance-rebalance"
  description = "Karpenter Instance Rebalance Recommendation"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = {
    Name = "${local.name_prefix}-karpenter-instance-rebalance"
  }
}

resource "aws_cloudwatch_event_target" "karpenter_instance_rebalance" {
  rule      = aws_cloudwatch_event_rule.karpenter_instance_rebalance.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_scheduled_change" {
  name        = "${local.name_slug}-karpenter-scheduled-change"
  description = "Karpenter AWS Health Scheduled Change"

  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })

  tags = {
    Name = "${local.name_prefix}-karpenter-scheduled-change"
  }
}

resource "aws_cloudwatch_event_target" "karpenter_scheduled_change" {
  rule      = aws_cloudwatch_event_rule.karpenter_scheduled_change.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_instance_state_change" {
  name        = "${local.name_slug}-karpenter-instance-state-change"
  description = "Karpenter EC2 Instance State-change Notification"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })

  tags = {
    Name = "${local.name_prefix}-karpenter-instance-state-change"
  }
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state_change" {
  rule      = aws_cloudwatch_event_rule.karpenter_instance_state_change.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

#############################################
# EKS Access Entry for Karpenter Nodes
#############################################

resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = var.eks_cluster_name
  principal_arn = module.karpenter_node_iam.iam_role_arn
  type          = "EC2_LINUX"

  tags = {
    Name = "${local.name_prefix}-karpenter-node-access"
  }
}
