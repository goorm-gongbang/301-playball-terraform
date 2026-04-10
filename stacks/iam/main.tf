#############################################
# common/iam - IAM Groups & Policies
# CN 그룹 환경별 정책
#############################################

#############################################
# CN Group - Common Access (모든 환경 공통)
#############################################

resource "aws_iam_policy" "cn_common_access" {
  name        = "CN-Common-Access"
  description = "CN 그룹 공통 권한 (리소스 조회 등)"
  path        = "/common/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR 목록 조회
      {
        Sid    = "ECRListAccess"
        Effect = "Allow"
        Action = [
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      },
      # Secrets Manager 목록 조회
      {
        Sid    = "SecretsManagerList"
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      },
      # CloudWatch 기본 조회
      {
        Sid    = "CloudWatchReadOnly"
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListDashboards",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Purpose = "CN group common access"
  }
}

#############################################
# CN Group - Staging Access
#############################################

resource "aws_iam_policy" "cn_staging_access" {
  name        = "CN-Staging-Access"
  description = "CN 그룹의 staging 환경 접근 권한"
  path        = "/env/staging/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 - staging 백업
      {
        Sid      = "S3StagingBackup"
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "arn:aws:s3:::goormgb-backup/staging/*"
      },
      {
        Sid      = "S3StagingBackupList"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::goormgb-backup"
        Condition = {
          StringLike = {
            "s3:prefix" = ["staging/*"]
          }
        }
      },
      # Secrets Manager - staging
      {
        Sid      = "SecretsManagerStaging"
        Effect   = "Allow"
        Action   = "secretsmanager:*"
        Resource = "arn:aws:secretsmanager:*:*:secret:staging/*"
      },
      # ECR - staging repos
      {
        Sid      = "ECRStagingFull"
        Effect   = "Allow"
        Action   = "ecr:*"
        Resource = "arn:aws:ecr:*:*:repository/playball/*"
      },
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      # EKS - staging 클러스터
      {
        Sid    = "EKSStagingAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi",
          "eks:ListNodegroups",
          "eks:DescribeNodegroup"
        ]
        Resource = "arn:aws:eks:*:*:cluster/*staging*"
      },
      # RDS - staging
      {
        Sid    = "RDSStagingAccess"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:DescribeDBSnapshots",
          "rds:ListTagsForResource"
        ]
        Resource = "arn:aws:rds:*:*:db:*staging*"
      },
      # ElastiCache - staging
      {
        Sid    = "ElastiCacheStagingAccess"
        Effect = "Allow"
        Action = [
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeReplicationGroups",
          "elasticache:ListTagsForResource"
        ]
        Resource = "*"
      },
      # CloudWatch Logs - staging
      {
        Sid      = "CloudWatchLogsStaging"
        Effect   = "Allow"
        Action   = "logs:*"
        Resource = "arn:aws:logs:*:*:log-group:*staging*"
      },
      # VPC/EC2 조회
      {
        Sid      = "EC2ReadOnly"
        Effect   = "Allow"
        Action   = "ec2:Describe*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = "staging"
    Purpose     = "CN group staging access"
  }
}

#############################################
# CN Group - Prod Access (Read-Only)
#############################################

resource "aws_iam_policy" "cn_prod_access" {
  name        = "CN-Prod-Access"
  description = "CN 그룹의 prod 환경 접근 권한 (읽기 전용)"
  path        = "/env/prod/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Secrets Manager - prod (읽기만)
      {
        Sid    = "SecretsManagerProdRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:prod/*"
      },
      # EKS - prod 클러스터 (조회만)
      {
        Sid    = "EKSProdReadOnly"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "arn:aws:eks:*:*:cluster/*prod*"
      },
      # RDS - prod (조회만)
      {
        Sid    = "RDSProdReadOnly"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "arn:aws:rds:*:*:db:*prod*"
      },
      # CloudWatch - prod 모니터링
      {
        Sid    = "CloudWatchProdRead"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = "prod"
    Purpose     = "CN group prod read-only access"
  }
}

#############################################
# CN Group Policy Attachments
#############################################

resource "aws_iam_group_policy_attachment" "cn_common" {
  group      = "CN"
  policy_arn = aws_iam_policy.cn_common_access.arn
}

resource "aws_iam_group_policy_attachment" "cn_staging" {
  group      = "CN"
  policy_arn = aws_iam_policy.cn_staging_access.arn
}

resource "aws_iam_group_policy_attachment" "cn_prod" {
  group      = "CN"
  policy_arn = aws_iam_policy.cn_prod_access.arn
}
