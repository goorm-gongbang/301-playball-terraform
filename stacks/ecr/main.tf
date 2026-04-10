#############################################
# common/ecr - ECR Repositories
# 모든 환경에서 공용 사용
#############################################

locals {
  # Cross-account principals
  cross_account_principals = flatten([
    for account_id, roles in var.cross_account_node_roles : [
      for role in roles : "arn:aws:iam::${account_id}:role/${role}"
    ]
  ])
}

#############################################
# Web Services ECR
#############################################

resource "aws_ecr_repository" "web" {
  for_each = toset(var.web_services)

  name                 = "playball/web/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # 이미지 있어도 삭제 가능

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name    = "playball/web/${each.key}"
    Service = each.key
    Type    = "web"
  }
}

resource "aws_ecr_lifecycle_policy" "web" {
  for_each = toset(var.web_services)

  repository = aws_ecr_repository.web[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

#############################################
# AI Services ECR
#############################################

resource "aws_ecr_repository" "ai" {
  for_each = toset(var.ai_services)

  name                 = "playball/ai/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # 이미지 있어도 삭제 가능

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name    = "playball/ai/${each.key}"
    Service = each.key
    Type    = "ai"
  }
}

resource "aws_ecr_lifecycle_policy" "ai" {
  for_each = toset(var.ai_services)

  repository = aws_ecr_repository.ai[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

#############################################
# Cross-Account Repository Policy
#############################################

resource "aws_ecr_repository_policy" "web_cross_account" {
  for_each = length(local.cross_account_principals) > 0 ? toset(var.web_services) : []

  repository = aws_ecr_repository.web[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = local.cross_account_principals
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

resource "aws_ecr_repository_policy" "ai_cross_account" {
  for_each = length(local.cross_account_principals) > 0 ? toset(var.ai_services) : []

  repository = aws_ecr_repository.ai[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = local.cross_account_principals
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

#############################################
# Staging ECR Cross-Account Policy
# 기존 staging/ prefix ECR repos에 cross-account 허용
#############################################

locals {
  staging_web_services = ["api-gateway", "auth-guard", "order-core", "queue", "seat"]
  staging_ai_services  = ["defense", "authz-adapter"]
}

resource "aws_ecr_repository_policy" "staging_web_cross_account" {
  for_each = length(local.cross_account_principals) > 0 ? toset(local.staging_web_services) : []

  repository = "staging/playball/web/${each.key}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = local.cross_account_principals
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

resource "aws_ecr_repository_policy" "staging_ai_cross_account" {
  for_each = length(local.cross_account_principals) > 0 ? toset(local.staging_ai_services) : []

  repository = "staging/playball/ai/${each.key}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = local.cross_account_principals
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
