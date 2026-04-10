#############################################
# IAM Module - Main Resources
#############################################

data "aws_caller_identity" "current" {}

#############################################
# IAM Group
#############################################

resource "aws_iam_group" "team" {
  count = length(var.iam_users) > 0 ? 1 : 0
  name  = local.actual_team_prefix
}

#############################################
# IAM Users
#############################################

resource "aws_iam_user" "users" {
  for_each = toset(var.iam_users)
  name     = "${local.actual_team_prefix}_${each.key}"

  tags = {
    Name = "${local.actual_team_prefix}_${each.key}"
  }
}

resource "aws_iam_user_group_membership" "memberships" {
  for_each = toset(var.iam_users)
  user     = aws_iam_user.users[each.key].name
  groups   = [aws_iam_group.team[0].name]
}

#############################################
# IAM Roles - DevOps (EKS + ECR + SSM)
#############################################

resource "aws_iam_role" "devops" {
  count = length(var.iam_users) > 0 ? 1 : 0
  name  = "${local.actual_team_prefix}-devops-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = { Name = "${local.actual_team_prefix}-devops-role" }
}

resource "aws_iam_role_policy" "devops" {
  count = length(var.iam_users) > 0 ? 1 : 0
  name  = "${local.actual_team_prefix}-devops-policy"
  role  = aws_iam_role.devops[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EKSFullAccess"
        Effect   = "Allow"
        Action   = ["eks:*"]
        Resource = "*"
      },
      {
        Sid    = "ECRFullAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMAccess"
        Effect = "Allow"
        Action = [
          "ssm:StartSession",
          "ssm:TerminateSession",
          "ssm:ResumeSession",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2DescribeForSSM"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

#############################################
# IAM Roles - Developer (SSM only)
#############################################

resource "aws_iam_role" "developer" {
  count = length(var.iam_users) > 0 ? 1 : 0
  name  = "${local.actual_team_prefix}-developer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = { Name = "${local.actual_team_prefix}-developer-role" }
}

resource "aws_iam_role_policy" "developer" {
  count = length(var.iam_users) > 0 ? 1 : 0
  name  = "${local.actual_team_prefix}-developer-policy"
  role  = aws_iam_role.developer[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMBastionAccess"
        Effect = "Allow"
        Action = [
          "ssm:StartSession",
          "ssm:TerminateSession",
          "ssm:ResumeSession",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2DescribeForSSM"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

#############################################
# IAM Roles - Secure (CloudWatch/CloudTrail Read)
#############################################

resource "aws_iam_role" "secure" {
  count = length(var.iam_users) > 0 ? 1 : 0
  name  = "${local.actual_team_prefix}-secure-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = { Name = "${local.actual_team_prefix}-secure-role" }
}

resource "aws_iam_role_policy" "secure" {
  count = length(var.iam_users) > 0 ? 1 : 0
  name  = "${local.actual_team_prefix}-secure-policy"
  role  = aws_iam_role.secure[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsRead"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:GetQueryResults"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudTrailRead"
        Effect = "Allow"
        Action = [
          "cloudtrail:LookupEvents",
          "cloudtrail:DescribeTrails",
          "cloudtrail:GetTrailStatus"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchMetricsRead"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      }
    ]
  })
}

#############################################
# Group Policy - AssumeRole
#############################################

resource "aws_iam_group_policy" "team" {
  count = length(var.iam_users) > 0 ? 1 : 0
  name  = "${local.actual_team_prefix}-policy"
  group = aws_iam_group.team[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "AssumeRoles"
          Effect = "Allow"
          Action = "sts:AssumeRole"
          Resource = [
            aws_iam_role.devops[0].arn,
            aws_iam_role.developer[0].arn,
            aws_iam_role.secure[0].arn
          ]
        },
        {
          Sid    = "EKSDescribe"
          Effect = "Allow"
          Action = [
            "eks:DescribeCluster",
            "eks:ListClusters"
          ]
          Resource = "*"
        },
        {
          Sid    = "ECRCrossAccountAccess"
          Effect = "Allow"
          Action = [
            "ecr:GetAuthorizationToken"
          ]
          Resource = "*"
        }
      ],
      var.main_account_id != "" ? [
        {
          Sid    = "ECRPullFromMainAccount"
          Effect = "Allow"
          Action = [
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:DescribeRepositories",
            "ecr:ListImages"
          ]
          Resource = "arn:aws:ecr:${var.aws_region}:${var.main_account_id}:repository/*"
        }
      ] : []
    )
  })
}
