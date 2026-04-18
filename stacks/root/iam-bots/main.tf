#############################################
# Account Settings & CICD Bot Policies
#############################################

locals {
  account_id    = data.aws_caller_identity.current.account_id
  aws_region    = "ap-northeast-2"
  backup_bucket = "playball-web-backup"
}

#############################################
# Account Alias & Password Policy
#############################################

resource "aws_iam_account_alias" "this" {
  account_alias = "goormgb"
}

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
# bot-kubeadm - Dev Access
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
        Resource = "arn:aws:s3:::${local.backup_bucket}/dev/*"
      },
      {
        Sid       = "S3ListBucket"
        Effect    = "Allow"
        Action    = "s3:ListBucket"
        Resource  = "arn:aws:s3:::${local.backup_bucket}"
        Condition = { StringLike = { "s3:prefix" = ["dev/*"] } }
      },
      {
        Sid      = "SecretsManagerAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${local.aws_region}:${local.account_id}:secret:dev/*"
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
        Resource = "arn:aws:ecr:${local.aws_region}:${local.account_id}:repository/*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "bot_kubeadm_dev" {
  user       = aws_iam_user.bot_kubeadm.name
  policy_arn = aws_iam_policy.bot_kubeadm_dev.arn
}

#############################################
# bot-kubeadm - Staging Access
#############################################

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
        Resource = "arn:aws:s3:::${local.backup_bucket}/staging/logs/infra/*"
      },
      {
        Sid      = "S3StagingServiceLogsAccess"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${local.backup_bucket}/staging/logs/service/*"
      },
      {
        Sid       = "S3ListStagingLogsBucket"
        Effect    = "Allow"
        Action    = "s3:ListBucket"
        Resource  = "arn:aws:s3:::${local.backup_bucket}"
        Condition = { StringLike = { "s3:prefix" = ["staging/logs/infra/*", "staging/logs/service/*"] } }
      },
      {
        Sid      = "SecretsManagerStagingAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${local.aws_region}:${local.account_id}:secret:staging/*"
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
        Resource = "arn:aws:ecr:${local.aws_region}:${local.account_id}:repository/*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "bot_kubeadm_staging" {
  user       = aws_iam_user.bot_kubeadm.name
  policy_arn = aws_iam_policy.bot_kubeadm_staging.arn
}
