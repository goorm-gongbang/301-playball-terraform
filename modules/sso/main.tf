#############################################
# SSO (IAM Identity Center) Module
#############################################

data "aws_ssoadmin_instances" "main" {}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
}

#############################################
# Permission Sets
#############################################

# Administrator Access
resource "aws_ssoadmin_permission_set" "admin" {
  instance_arn     = local.instance_arn
  name             = "AdministratorAccess"
  description      = "Full administrator access"
  session_duration = var.session_duration
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# DevOps Access (EKS + ECR + SSM)
resource "aws_ssoadmin_permission_set" "devops" {
  instance_arn     = local.instance_arn
  name             = "DevOpsAccess"
  description      = "DevOps access - EKS, ECR, SSM"
  session_duration = var.session_duration
}

resource "aws_ssoadmin_permission_set_inline_policy" "devops" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.devops.arn

  inline_policy = jsonencode({
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
          "ecr:ListImages",
          "ecr:CreateRepository",
          "ecr:DeleteRepository"
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
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      }
    ]
  })
}

# Developer Access (SSM only)
resource "aws_ssoadmin_permission_set" "developer" {
  instance_arn     = local.instance_arn
  name             = "DeveloperAccess"
  description      = "Developer access - SSM to bastion"
  session_duration = var.session_duration
}

resource "aws_ssoadmin_permission_set_inline_policy" "developer" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn

  inline_policy = jsonencode({
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

# ReadOnly Access
resource "aws_ssoadmin_permission_set" "readonly" {
  instance_arn     = local.instance_arn
  name             = "ReadOnlyAccess"
  description      = "Read-only access"
  session_duration = var.session_duration
}

resource "aws_ssoadmin_managed_policy_attachment" "readonly" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

#############################################
# Groups
#############################################

resource "aws_identitystore_group" "groups" {
  for_each = var.groups

  identity_store_id = local.identity_store_id
  display_name      = each.value.display_name
  description       = each.value.description
}

#############################################
# Users
#############################################

resource "aws_identitystore_user" "users" {
  for_each = var.users

  identity_store_id = local.identity_store_id
  user_name         = each.key
  display_name      = each.value.display_name

  name {
    given_name  = each.value.given_name
    family_name = each.value.family_name
  }

  emails {
    value   = each.value.email
    primary = true
  }
}

# User Group Memberships
resource "aws_identitystore_group_membership" "memberships" {
  for_each = {
    for item in flatten([
      for user_key, user in var.users : [
        for group in user.groups : {
          user_key  = user_key
          group_key = group
        }
      ]
    ]) : "${item.user_key}-${item.group_key}" => item
  }

  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.groups[each.value.group_key].group_id
  member_id         = aws_identitystore_user.users[each.value.user_key].user_id
}

#############################################
# Account Assignments
#############################################

locals {
  permission_set_arns = {
    admin     = aws_ssoadmin_permission_set.admin.arn
    devops    = aws_ssoadmin_permission_set.devops.arn
    developer = aws_ssoadmin_permission_set.developer.arn
    readonly  = aws_ssoadmin_permission_set.readonly.arn
  }
}

resource "aws_ssoadmin_account_assignment" "assignments" {
  for_each = var.account_assignments

  instance_arn       = local.instance_arn
  permission_set_arn = local.permission_set_arns[each.value.permission_set]

  principal_id   = each.value.principal_type == "GROUP" ? aws_identitystore_group.groups[each.value.principal_name].group_id : aws_identitystore_user.users[each.value.principal_name].user_id
  principal_type = each.value.principal_type

  target_id   = each.value.account_id
  target_type = "AWS_ACCOUNT"
}
