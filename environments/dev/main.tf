#############################################
# Dev Environment - Main Configuration
#############################################

#############################################
# Dynamic Secrets (인프라 연결 정보)
# 고정 시크릿은 stacks/secrets/ 에서 관리
#############################################

locals {
  dynamic_secrets = {
    "dev/services/db" = {
      description = "PostgreSQL database credentials"
    }
    "dev/services/redis" = {
      description = "Redis credentials (legacy)"
    }
    "dev/services/redis-cache" = {
      description = "Redis cache credentials"
    }
    "dev/services/redis-queue" = {
      description = "Redis queue credentials"
    }
    "dev/ai-service/redis" = {
      description = "AI Defense Redis connection"
    }
  }
}

resource "aws_secretsmanager_secret" "dynamic" {
  for_each = local.dynamic_secrets

  name        = each.key
  description = each.value.description

  tags = {
    Name        = each.key
    Environment = "dev"
    Type        = "dynamic"
  }

  lifecycle {
    ignore_changes = [description]
  }
}

resource "aws_secretsmanager_secret_version" "ai_redis" {
  secret_id = aws_secretsmanager_secret.dynamic["dev/ai-service/redis"].id
  secret_string = jsonencode({
    host = "redis-ai.data.svc.cluster.local"
    port = "6379"
  })

  lifecycle { ignore_changes = [secret_string] }
}
