#############################################
# SSO Permission Sets
#############################################
#
# 환경별 권한 분리:
# - DevOps: EKS, ECR, SSM, S3 전체
# - Developer: EKS 읽기, ECR pull, SSM, S3 제한
# - ReadOnly: CloudWatch, 로그 조회
#
#############################################

locals {
  devops_environments    = toset(var.devops_environments)
  developer_environments = toset(var.developer_environments)
  security_environments  = toset(var.security_environments)

  # S3 버킷 패턴 - 와일드카드 대신 명시적 버킷 지정
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
# DevOps Permission Sets (환경별)
#############################################

resource "aws_ssoadmin_permission_set" "devops" {
  for_each = local.devops_environments

  name             = "DevOps-${title(each.key)}"
  description      = "DevOps Full Access for ${title(each.key)} environment"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = {
    Environment = each.key
    Role        = "devops"
  }
}

# DevOps - AdministratorAccess (Full Access)
# TODO: TEMP - prod는 나중에 권한 축소 예정
resource "aws_ssoadmin_managed_policy_attachment" "devops_admin" {
  for_each = local.devops_environments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.devops[each.key].arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ssoadmin_permission_set_inline_policy" "devops" {
  for_each = local.devops_environments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.devops[each.key].arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EKSFullAccess"
        Effect   = "Allow"
        Action   = ["eks:*"]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Environment" = [each.key, title(each.key), upper(each.key)]
          }
        }
      },
      {
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = ["eks:Describe*", "eks:List*"]
        Resource = "*"
      },
      {
        Sid      = "ECRFullAccess"
        Effect   = "Allow"
        Action   = ["ecr:*"]
        Resource = "*"
      },
      {
        Sid      = "SSMFullAccess"
        Effect   = "Allow"
        Action   = ["ssm:*"]
        Resource = "*"
      },
      {
        Sid      = "S3Access"
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = local.s3_buckets[each.key]
      },
      {
        Sid      = "CloudWatchAccess"
        Effect   = "Allow"
        Action   = ["logs:*", "cloudwatch:*"]
        Resource = "*"
      },
      {
        Sid      = "EC2Describe"
        Effect   = "Allow"
        Action   = ["ec2:Describe*"]
        Resource = "*"
      }
    ]
  })
}

#############################################
# Developer Permission Sets (환경별)
#############################################

resource "aws_ssoadmin_permission_set" "developer" {
  for_each = local.developer_environments

  name             = "Developer-${title(each.key)}"
  description      = "Developer permissions for ${title(each.key)} environment"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = {
    Environment = each.key
    Role        = "developer"
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "developer" {
  for_each = local.developer_environments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer[each.key].arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSListClusters"
        Effect = "Allow"
        Action = [
          "eks:ListClusters",
          "eks:DescribeClusterVersions"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSClusterAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:AccessKubernetesApi",
          "eks:ListNodegroups",
          "eks:DescribeNodegroup",
          "eks:ListAddons",
          "eks:DescribeAddon",
          "eks:ListFargateProfiles",
          "eks:DescribeFargateProfile",
          "eks:DescribeUpdate"
        ]
        Resource = [
          "arn:aws:eks:ap-northeast-2:*:cluster/goormgb-${each.key}-eks",
          "arn:aws:eks:ap-northeast-2:*:nodegroup/goormgb-${each.key}-eks/*/*",
          "arn:aws:eks:ap-northeast-2:*:addon/goormgb-${each.key}-eks/*/*",
          "arn:aws:eks:ap-northeast-2:*:fargateprofile/goormgb-${each.key}-eks/*/*"
        ]
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMSessionToBastion"
        Effect = "Allow"
        Action = [
          "ssm:StartSession"
        ]
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringEquals = {
            "ssm:resourceTag/SSMAccess" = "dba-developer"
          }
        }
      },
      {
        Sid    = "SSMSessionDocument"
        Effect = "Allow"
        Action = [
          "ssm:StartSession"
        ]
        Resource = [
          "arn:aws:ssm:*:*:document/AWS-StartInteractiveCommand",
          "arn:aws:ssm:*::document/AWS-StartInteractiveCommand"
        ]
      },
      {
        Sid    = "SSMSessionManage"
        Effect = "Allow"
        Action = [
          "ssm:TerminateSession",
          "ssm:ResumeSession",
          "ssm:DescribeSessions"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = each.key == "staging" ? ["s3:*"] : [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = local.s3_buckets[each.key]
      },
      {
        Sid    = "S3SharedBuckets"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::playball-assets",
          "arn:aws:s3:::playball-assets/*",
          "arn:aws:s3:::playball-web-backup/${each.key}/*",
          "arn:aws:s3:::playball-web-backup",
        ]
      },
      {
        Sid    = "S3ListBuckets"
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchRead"
        Effect = "Allow"
        Action = [
          "logs:Describe*",
          "logs:Get*",
          "logs:FilterLogEvents",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2ReadOnly"
        Effect = "Allow"
        Action = [
          "ec2:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSList"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:DescribeDBSubnetGroups",
          "rds:DescribeDBParameterGroups",
          "rds:DescribeDBClusterParameterGroups"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSAccess"
        Effect = "Allow"
        Action = each.key == "staging" ? [
          "rds:Describe*",
          "rds:List*",
          "rds:ModifyDBInstance",
          "rds:ModifyDBCluster",
          "rds:RebootDBInstance",
          "rds:RebootDBCluster",
          "rds:StartDBInstance",
          "rds:StartDBCluster",
          "rds:StopDBInstance",
          "rds:StopDBCluster"
          ] : [
          "rds:Describe*",
          "rds:List*"
        ]
        Resource = [
          "arn:aws:rds:ap-northeast-2:*:db:*${each.key}*",
          "arn:aws:rds:ap-northeast-2:*:cluster:*${each.key}*"
        ]
      },
      {
        Sid    = "ElastiCacheList"
        Effect = "Allow"
        Action = [
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeReplicationGroups",
          "elasticache:DescribeCacheSubnetGroups",
          "elasticache:DescribeCacheParameterGroups"
        ]
        Resource = "*"
      },
      {
        Sid    = "ElastiCacheAccess"
        Effect = "Allow"
        Action = each.key == "staging" ? [
          "elasticache:*"
          ] : [
          "elasticache:Describe*",
          "elasticache:List*"
        ]
        Resource = [
          "arn:aws:elasticache:ap-northeast-2:*:replicationgroup:*${each.key}*",
          "arn:aws:elasticache:ap-northeast-2:*:cluster:*${each.key}*"
        ]
      },
      {
        Sid    = "SecretsManagerList"
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = each.key == "staging" ? [
          "secretsmanager:*"
          ] : [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:ap-northeast-2:*:secret:${each.key}/*",
          "arn:aws:secretsmanager:ap-northeast-2:*:secret:common/*"
        ]
      },
    ]
  })
}


#############################################
# Security Permission Sets (환경별)
#############################################

resource "aws_ssoadmin_permission_set" "security" {
  for_each = local.security_environments

  name             = "Security-${title(each.key)}"
  description      = "Security permissions for ${title(each.key)} environment"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = {
    Environment = each.key
    Role        = "security"
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "security" {
  for_each = local.security_environments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security[each.key].arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecurityAuditAccess"
        Effect = "Allow"
        Action = [
          "iam:Get*",
          "iam:List*",
          "iam:GenerateCredentialReport",
          "iam:GenerateServiceLastAccessedDetails"
        ]
        Resource = "*"
      },
      {
        Sid      = "CloudTrailAccess"
        Effect   = "Allow"
        Action   = ["cloudtrail:*"]
        Resource = "*"
      },
      {
        Sid      = "ConfigAccess"
        Effect   = "Allow"
        Action   = ["config:*"]
        Resource = "*"
      },
      {
        Sid      = "GuardDutyAccess"
        Effect   = "Allow"
        Action   = ["guardduty:*"]
        Resource = "*"
      },
      {
        Sid      = "SecurityHubAccess"
        Effect   = "Allow"
        Action   = ["securityhub:*"]
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
        Action = [
          "ec2:Describe*",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress"
        ]
        Resource = "*"
      },
      {
        Sid      = "KMSAccess"
        Effect   = "Allow"
        Action   = ["kms:Describe*", "kms:List*", "kms:GetKeyPolicy"]
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
# Frontend Permission Set (전체 환경)
#############################################

resource "aws_ssoadmin_permission_set" "frontend" {
  name             = "FE-Access"
  description      = "Frontend team permissions - CloudWatch, S3 read access"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = {
    Role = "frontend"
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "frontend" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.frontend.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchRead"
        Effect = "Allow"
        Action = [
          "logs:Describe*",
          "logs:Get*",
          "logs:FilterLogEvents",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListDashboards"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3ListBuckets"
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3ReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::playball-assets",
          "arn:aws:s3:::playball-assets/*"
        ]
      }
    ]
  })
}

#############################################
# Project Manager Permission Set (전체 환경)
#############################################

resource "aws_ssoadmin_permission_set" "pm" {
  name             = "PM-Access"
  description      = "Project Manager permissions - CloudWatch, Billing, Cost Explorer"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = {
    Role = "pm"
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "pm" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.pm.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchRead"
        Effect = "Allow"
        Action = [
          "logs:Describe*",
          "logs:Get*",
          "logs:FilterLogEvents",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListDashboards"
        ]
        Resource = "*"
      },
      {
        Sid    = "BillingRead"
        Effect = "Allow"
        Action = [
          "aws-portal:ViewBilling",
          "aws-portal:ViewUsage",
          "budgets:ViewBudget",
          "budgets:DescribeBudget*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CostExplorerRead"
        Effect = "Allow"
        Action = [
          "ce:Describe*",
          "ce:Get*",
          "ce:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CostAndUsageReport"
        Effect = "Allow"
        Action = [
          "cur:DescribeReportDefinitions",
          "cur:GetClassicReport",
          "cur:GetUsageReport"
        ]
        Resource = "*"
      }
    ]
  })
}
