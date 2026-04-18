#############################################
# SSO Permission Sets
#############################################
#
# 네이밍: {Env}-{Group}
#   CN  = DevOps/인프라 (AdministratorAccess)
#   Dev = 개발팀 (EKS/ECR/SSM/S3 제한)
#   SC  = 보안팀 (감사/모니터링)
#   AI  = AI팀 (AI 워크로드 한정)
#
# 계정별 배치:
#   본계정(497012402578): Dev-CN, Admin-Full
#   ca-staging(406223549139): Staging-CN, Staging-Dev, Staging-SC, Staging-AI
#   ca-prod(990521646433): Prod-CN, Prod-Dev, Prod-SC, Prod-AI
#
#############################################

locals {
  # S3 버킷 패턴
  s3_buckets = {
    dev = [
      "arn:aws:s3:::playball-dev-*",
      "arn:aws:s3:::playball-dev-*/*"
    ]
    staging = [
      "arn:aws:s3:::playball-staging-*",
      "arn:aws:s3:::playball-staging-*/*"
    ]
    prod = [
      "arn:aws:s3:::playball-prod-*",
      "arn:aws:s3:::playball-prod-*/*"
    ]
  }
}

#############################################
# Admin-Full (본계정 전용, 기존 유지)
#############################################

# Admin-Full은 콘솔에서 생성됨 — data source로 참조
data "aws_ssoadmin_permission_set" "admin_full" {
  instance_arn = local.sso_instance_arn
  name         = "Admin-Full"
}

#############################################
# CN Permission Sets (DevOps - AdministratorAccess)
#############################################

resource "aws_ssoadmin_permission_set" "dev_cn" {
  name             = "Dev-CN"
  description      = "CN team access on Management account - ECR and shared infra"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  tags = { Environment = "dev", Role = "cn" }
}

resource "aws_ssoadmin_managed_policy_attachment" "dev_cn_admin" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.dev_cn.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ssoadmin_permission_set" "staging_cn" {
  name             = "Staging-CN"
  description      = "staging CN - kubectl full, S3 full, Secrets read/write"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  tags = { Environment = "staging", Role = "cn" }
}

resource "aws_ssoadmin_managed_policy_attachment" "staging_cn_admin" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.staging_cn.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ssoadmin_permission_set" "prod_cn" {
  name             = "Prod-CN"
  description      = "prod CN - kubectl full, S3 full, Secrets read-only"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  tags = { Environment = "prod", Role = "cn" }
}

resource "aws_ssoadmin_managed_policy_attachment" "prod_cn_admin" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.prod_cn.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

#############################################
# Dev Permission Sets (개발팀 - 제한적 접근)
#############################################

resource "aws_ssoadmin_permission_set" "staging_dev" {
  name             = "Staging-Dev"
  description      = "staging Developer - SSM, Grafana, ArgoCD, S3/Secrets read-only"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  tags = { Environment = "staging", Role = "dev" }
}

resource "aws_ssoadmin_permission_set_inline_policy" "staging_dev" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.staging_dev.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSReadAccess"
        Effect = "Allow"
        Action = ["eks:Describe*", "eks:List*", "eks:AccessKubernetesApi"]
        Resource = "*"
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:DescribeRepositories", "ecr:ListImages"]
        Resource = "*"
      },
      {
        Sid    = "SSMSession"
        Effect = "Allow"
        Action = ["ssm:StartSession", "ssm:TerminateSession", "ssm:ResumeSession", "ssm:DescribeSessions"]
        Resource = "*"
      },
      {
        Sid      = "S3Access"
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = local.s3_buckets["staging"]
      },
      {
        Sid    = "S3List"
        Effect = "Allow"
        Action = ["s3:ListAllMyBuckets", "s3:GetBucketLocation"]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchRead"
        Effect = "Allow"
        Action = ["logs:Describe*", "logs:Get*", "logs:FilterLogEvents", "cloudwatch:GetMetricData", "cloudwatch:ListMetrics"]
        Resource = "*"
      },
      {
        Sid    = "EC2ReadOnly"
        Effect = "Allow"
        Action = ["ec2:Describe*"]
        Resource = "*"
      },
      {
        Sid    = "RDSRead"
        Effect = "Allow"
        Action = ["rds:Describe*", "rds:List*"]
        Resource = "*"
      },
      {
        Sid    = "ElastiCacheRead"
        Effect = "Allow"
        Action = ["elasticache:Describe*", "elasticache:List*"]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = ["secretsmanager:ListSecrets", "secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = ["arn:aws:secretsmanager:ap-northeast-2:*:secret:staging/*"]
      }
    ]
  })
}

resource "aws_ssoadmin_permission_set" "prod_dev" {
  name             = "Prod-Dev"
  description      = "prod Developer - SSM, Grafana, ArgoCD, S3/Secrets read-only"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  tags = { Environment = "prod", Role = "dev" }
}

resource "aws_ssoadmin_permission_set_inline_policy" "prod_dev" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.prod_dev.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSReadAccess"
        Effect = "Allow"
        Action = ["eks:Describe*", "eks:List*", "eks:AccessKubernetesApi"]
        Resource = "*"
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:DescribeRepositories", "ecr:ListImages"]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchRead"
        Effect = "Allow"
        Action = ["logs:Describe*", "logs:Get*", "logs:FilterLogEvents", "cloudwatch:GetMetricData", "cloudwatch:ListMetrics"]
        Resource = "*"
      },
      {
        Sid    = "EC2ReadOnly"
        Effect = "Allow"
        Action = ["ec2:Describe*"]
        Resource = "*"
      },
      {
        Sid      = "S3Read"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = local.s3_buckets["prod"]
      },
      {
        Sid    = "S3List"
        Effect = "Allow"
        Action = ["s3:ListAllMyBuckets", "s3:GetBucketLocation"]
        Resource = "*"
      },
      {
        Sid    = "RDSRead"
        Effect = "Allow"
        Action = ["rds:Describe*", "rds:List*"]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = ["secretsmanager:ListSecrets", "secretsmanager:DescribeSecret"]
        Resource = "*"
      }
    ]
  })
}

#############################################
# SC Permission Sets (보안팀)
#############################################

resource "aws_ssoadmin_permission_set" "staging_sc" {
  name             = "Staging-SC"
  description      = "staging Security - Secrets management, CloudTrail, GuardDuty, Security Hub"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  tags = { Environment = "staging", Role = "sc" }
}

resource "aws_ssoadmin_permission_set_inline_policy" "staging_sc" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.staging_sc.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecurityAudit"
        Effect = "Allow"
        Action = ["iam:Get*", "iam:List*", "iam:GenerateCredentialReport"]
        Resource = "*"
      },
      {
        Sid      = "CloudTrailAccess"
        Effect   = "Allow"
        Action   = ["cloudtrail:*"]
        Resource = "*"
      },
      {
        Sid      = "GuardDutyAccess"
        Effect   = "Allow"
        Action   = ["guardduty:*"]
        Resource = "*"
      },
      {
        Sid      = "CloudWatchAccess"
        Effect   = "Allow"
        Action   = ["logs:*", "cloudwatch:*"]
        Resource = "*"
      },
      {
        Sid    = "EC2SecurityGroups"
        Effect = "Allow"
        Action = ["ec2:Describe*"]
        Resource = "*"
      },
      {
        Sid      = "SecretsManagerRead"
        Effect   = "Allow"
        Action   = ["secretsmanager:Describe*", "secretsmanager:List*"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_ssoadmin_permission_set" "prod_sc" {
  name             = "Prod-SC"
  description      = "prod Security - Secrets management, CloudTrail, GuardDuty, Security Hub"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  tags = { Environment = "prod", Role = "sc" }
}

resource "aws_ssoadmin_permission_set_inline_policy" "prod_sc" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.prod_sc.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecurityAudit"
        Effect = "Allow"
        Action = ["iam:Get*", "iam:List*", "iam:GenerateCredentialReport"]
        Resource = "*"
      },
      {
        Sid      = "CloudTrailAccess"
        Effect   = "Allow"
        Action   = ["cloudtrail:*"]
        Resource = "*"
      },
      {
        Sid      = "GuardDutyAccess"
        Effect   = "Allow"
        Action   = ["guardduty:*"]
        Resource = "*"
      },
      {
        Sid      = "CloudWatchAccess"
        Effect   = "Allow"
        Action   = ["logs:*", "cloudwatch:*"]
        Resource = "*"
      },
      {
        Sid    = "EC2SecurityGroups"
        Effect = "Allow"
        Action = ["ec2:Describe*"]
        Resource = "*"
      },
      {
        Sid      = "SecretsManagerRead"
        Effect   = "Allow"
        Action   = ["secretsmanager:Describe*", "secretsmanager:List*"]
        Resource = "*"
      }
    ]
  })
}

#############################################
# AI Permission Sets (AI팀)
#############################################

resource "aws_ssoadmin_permission_set" "staging_ai" {
  name             = "Staging-AI"
  description      = "staging AI - SSM, Grafana, ArgoCD, AI S3/Secrets read-only"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  tags = { Environment = "staging", Role = "ai" }
}

resource "aws_ssoadmin_permission_set_inline_policy" "staging_ai" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.staging_ai.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSReadAccess"
        Effect = "Allow"
        Action = ["eks:Describe*", "eks:List*", "eks:AccessKubernetesApi"]
        Resource = "*"
      },
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = ["ecr:*"]
        Resource = ["arn:aws:ecr:ap-northeast-2:*:repository/staging/playball/ai/*"]
      },
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid      = "S3AIAccess"
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = ["arn:aws:s3:::playball-staging-ai-*", "arn:aws:s3:::playball-staging-ai-*/*"]
      },
      {
        Sid    = "CloudWatchRead"
        Effect = "Allow"
        Action = ["logs:Describe*", "logs:Get*", "logs:FilterLogEvents", "cloudwatch:GetMetricData", "cloudwatch:ListMetrics"]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerAI"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = ["arn:aws:secretsmanager:ap-northeast-2:*:secret:staging/ai-service/*"]
      }
    ]
  })
}

resource "aws_ssoadmin_permission_set" "prod_ai" {
  name             = "Prod-AI"
  description      = "prod AI - SSM, Grafana, ArgoCD, AI S3/Secrets read-only"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  tags = { Environment = "prod", Role = "ai" }
}

resource "aws_ssoadmin_permission_set_inline_policy" "prod_ai" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.prod_ai.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSReadAccess"
        Effect = "Allow"
        Action = ["eks:Describe*", "eks:List*", "eks:AccessKubernetesApi"]
        Resource = "*"
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:DescribeRepositories", "ecr:ListImages"]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchRead"
        Effect = "Allow"
        Action = ["logs:Describe*", "logs:Get*", "logs:FilterLogEvents", "cloudwatch:GetMetricData", "cloudwatch:ListMetrics"]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerAI"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = ["arn:aws:secretsmanager:ap-northeast-2:*:secret:prod/ai-service/*"]
      }
    ]
  })
}

