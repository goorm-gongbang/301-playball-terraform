#############################################
# Account IAM Module
# Password policy, groups, users, policies
#############################################

resource "aws_iam_account_alias" "this" {
  account_alias = var.project_name
}

#############################################
# Account Password Policy
#############################################

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 12
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 5
}

#############################################
# Cost Explorer Read Policy
#############################################

resource "aws_iam_policy" "cost_explorer_read" {
  name        = "CostExplorerReadOnly"
  description = "Cost Explorer 및 Cost Management 콘솔 읽기 권한"
  path        = "/common/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CostExplorerReadAccess"
        Effect   = "Allow"
        Action   = ["ce:Describe*", "ce:Get*", "ce:List*"]
        Resource = "*"
      },
      {
        Sid      = "CostAndUsageReportReadAccess"
        Effect   = "Allow"
        Action   = ["cur:DescribeReportDefinitions", "cur:GetClassicReport", "cur:GetClassicReportPreferences", "cur:GetUsageReport"]
        Resource = "*"
      },
      {
        Sid      = "CostOptimizationHubReadAccess"
        Effect   = "Allow"
        Action   = ["cost-optimization-hub:Get*", "cost-optimization-hub:List*"]
        Resource = "*"
      },
      {
        Sid      = "SavingsPlansReadAccess"
        Effect   = "Allow"
        Action   = ["savingsplans:Describe*", "savingsplans:List*"]
        Resource = "*"
      },
      {
        Sid      = "ComputeOptimizerReadAccess"
        Effect   = "Allow"
        Action   = ["compute-optimizer:Get*", "compute-optimizer:Describe*"]
        Resource = "*"
      }
    ]
  })
}

#############################################
# IAM Group: CN (Cloud Native)
#############################################

resource "aws_iam_group" "cn" {
  name = "CN"
  path = "/teams/"
}

resource "aws_iam_user" "cn" {
  for_each = var.cn_members

  name = each.key
  path = "/teams/cn/"
  tags = { Team = "CN" }
}

resource "aws_iam_group_membership" "cn" {
  name  = "cn-membership"
  group = aws_iam_group.cn.name
  users = [for user in aws_iam_user.cn : user.name]
}

resource "aws_iam_group_policy_attachment" "cn_billing" {
  group      = aws_iam_group.cn.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
}

resource "aws_iam_group_policy_attachment" "cn_iam" {
  group      = aws_iam_group.cn.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

resource "aws_iam_group_policy_attachment" "cn_cost_explorer" {
  group      = aws_iam_group.cn.name
  policy_arn = aws_iam_policy.cost_explorer_read.arn
}

#############################################
# CN Common Access Policy
#############################################

resource "aws_iam_policy" "cn_common_access" {
  name        = "CN-Common-Access"
  description = "CN 그룹 공통 리소스 접근 권한"
  path        = "/teams/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3ListAllBuckets"
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets", "s3:GetBucketLocation"]
        Resource = "*"
      },
      {
        Sid      = "S3BucketsFullAccess"
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = flatten([for arn in var.s3_full_access_bucket_arns : [arn, "${arn}/*"]])
      },
      {
        Sid      = "ECRListRepositories"
        Effect   = "Allow"
        Action   = ["ecr:DescribeRepositories", "ecr:DescribeRegistry", "ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid      = "SecretsManagerList"
        Effect   = "Allow"
        Action   = ["secretsmanager:ListSecrets"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "cn_common_access" {
  group      = aws_iam_group.cn.name
  policy_arn = aws_iam_policy.cn_common_access.arn
}

#############################################
# IAM Group: CICD Bots
#############################################

resource "aws_iam_group" "cicd_bots" {
  name = "CICD-Bots-Group"
  path = "/system/"
}

resource "aws_iam_user" "bot_teamcity" {
  name = "bot-teamcity"
  path = "/system/"
  tags = { Purpose = "TeamCity CI/CD" }
}

resource "aws_iam_user" "bot_argocd" {
  name = "bot-argocd"
  path = "/system/"
  tags = { Purpose = "ArgoCD GitOps" }
}

resource "aws_iam_user" "bot_kubeadm" {
  name = "bot-kubeadm"
  path = "/system/"
  tags = { Purpose = "Kubeadm K8s Backup" }
}

resource "aws_iam_group_membership" "cicd_bots" {
  name  = "cicd-bots-membership"
  group = aws_iam_group.cicd_bots.name
  users = [aws_iam_user.bot_teamcity.name, aws_iam_user.bot_argocd.name]
}

resource "aws_iam_group_policy_attachment" "cicd_bots_ecr" {
  group      = aws_iam_group.cicd_bots.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

#############################################
# IAM Group: temp
#############################################

resource "aws_iam_group" "temp" {
  name = "temp"
  path = "/"
}

resource "aws_iam_user" "mighty" {
  name = "mighty"
  path = "/"
  tags = { Purpose = "Temporary Admin" }
}

resource "aws_iam_group_membership" "temp" {
  name  = "temp-membership"
  group = aws_iam_group.temp.name
  users = [aws_iam_user.mighty.name]
}

#############################################
# bot-kubeadm Policies
#############################################

resource "aws_iam_policy" "bot_kubeadm_dev" {
  name        = "bot-kubeadm-dev-access"
  description = "bot-kubeadm access for dev environment backup and secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3BackupAccess"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.backup_bucket_name}/dev/*"
      },
      {
        Sid      = "S3ListBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${var.backup_bucket_name}"
        Condition = { StringLike = { "s3:prefix" = ["dev/*"] } }
      },
      {
        Sid      = "SecretsManagerAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:dev/*"
      },
      {
        Sid      = "ECRAuthToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid      = "ECRPullAccess"
        Effect   = "Allow"
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
        Resource = "arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "bot_kubeadm_dev" {
  user       = aws_iam_user.bot_kubeadm.name
  policy_arn = aws_iam_policy.bot_kubeadm_dev.arn
}

resource "aws_iam_policy" "bot_kubeadm_staging" {
  name        = "bot-kubeadm-staging-access"
  description = "bot-kubeadm access for staging log backup and secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3StagingInfraLogsAccess"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.backup_bucket_name}/staging/logs/infra/*"
      },
      {
        Sid      = "S3StagingServiceLogsAccess"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.backup_bucket_name}/staging/logs/service/*"
      },
      {
        Sid      = "S3ListStagingLogsBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${var.backup_bucket_name}"
        Condition = { StringLike = { "s3:prefix" = ["staging/logs/infra/*", "staging/logs/service/*"] } }
      },
      {
        Sid      = "SecretsManagerStagingAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:staging/*"
      },
      {
        Sid      = "ECRAuthToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid      = "ECRPullAccess"
        Effect   = "Allow"
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
        Resource = "arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "bot_kubeadm_staging" {
  user       = aws_iam_user.bot_kubeadm.name
  policy_arn = aws_iam_policy.bot_kubeadm_staging.arn
}
