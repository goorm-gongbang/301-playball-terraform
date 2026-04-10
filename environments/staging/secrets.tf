#############################################
# Secrets Manager - Staging Environment
# 값은 AWS Console에서 직접 관리
# Terraform은 빈 secret만 생성
#############################################

locals {
  secrets = {
    # Infra - OAuth Teams Allow (Admin Tools)
    # RedisInsight, CloudBeaver, Kiali 등 관리 도구 공통
    "staging/infra/oauth/teams-allow" = {
      description = "Google OAuth credentials for admin tools (RedisInsight, CloudBeaver, Kiali)"
      # keys: clientId, clientSecret, cookieSecret, allowedEmails
    }

    # Services - AI Server ↔ Auth-Guard 통신
    "staging/services/internal-api" = {
      description = "Internal API Key for AI Server - Auth-Guard communication"
      # keys: INTERNAL_API_KEY
    }

    # Infra - GHCR (GitHub Container Registry)
    "staging/infra/ghcr" = {
      description = "GHCR credentials for pulling private container images"
      # keys: username, token
    }

    # Kafka - Producer/Consumer 설정
    "staging/services/kafka" = {
      description = "Kafka configuration for producer/consumer"
      # keys: KAFKA_BOOTSTRAP_SERVERS, KAFKA_PRODUCER_*, KAFKA_CONSUMER_*
    }

    # S3 QnA - 문의 파일 업로드용
    "staging/services/s3-qna" = {
      description = "S3 credentials for QnA file upload"
      # keys: S3_BUCKET, S3_REGION, S3_PREFIX, AWS_ACCESS_KEY, AWS_SECRET_KEY
    }

    # Mail (Gmail SMTP)
    "staging/services/mail" = {
      description = "Gmail SMTP credentials for email notifications"
      # keys: MAIL_HOST, MAIL_PORT, MAIL_USERNAME, MAIL_PASSWORD
    }

    # Note: staging/argocd/oauth 이미 존재 (ArgoCD, Grafana, infra-console 공유)
    # AWS Console에서 sessionKey 추가 필요
    # keys: clientId, clientSecret, sessionKey

    # AI Service - Redis
    "staging/ai-service/redis" = {
      description = "Redis connection for AI Defense session storage"
      # keys: host, port
    }

    # AI Service - PostgreSQL (RDS)
    "staging/ai-service/postgres" = {
      description = "PostgreSQL connection for AI Defense policy control-plane"
      # keys: host, port, username, password, dbname
    }

    # AI Service - ClickHouse
    "staging/ai-service/clickhouse" = {
      description = "ClickHouse credentials for AI Defense observability warehouse"
      # keys: user, password
    }

    # ClickHouse Pod credentials (for StatefulSet)
    "staging/goormgb/clickhouse" = {
      description = "ClickHouse server credentials"
      # keys: CLICKHOUSE_USER, CLICKHOUSE_PASSWORD
    }
  }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = local.secrets

  name        = each.key
  description = each.value.description

  tags = {
    Name        = each.key
    Environment = "staging"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [description]
  }
}

#############################################
# Secret Versions - Kafka
#############################################

resource "aws_secretsmanager_secret_version" "kafka" {
  secret_id = aws_secretsmanager_secret.this["staging/services/kafka"].id
  secret_string = jsonencode({
    # Bootstrap
    KAFKA_BOOTSTRAP_SERVERS = "kafka-headless.data.svc.cluster.local:9092"

    # Producer
    KAFKA_PRODUCER_KEY_SERIALIZER   = "org.apache.kafka.common.serialization.StringSerializer"
    KAFKA_PRODUCER_VALUE_SERIALIZER = "org.springframework.kafka.support.serializer.JsonSerializer"
    KAFKA_PRODUCER_ACKS             = "all"

    # Consumer
    KAFKA_CONSUMER_KEY_DESERIALIZER   = "org.apache.kafka.common.serialization.StringDeserializer"
    KAFKA_CONSUMER_VALUE_DESERIALIZER = "org.springframework.kafka.support.serializer.JsonDeserializer"
    KAFKA_CONSUMER_AUTO_OFFSET_RESET  = "earliest"
    KAFKA_CONSUMER_TRUSTED_PACKAGES   = "com.goormgb.be.*"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

#############################################
# Secret Versions - AI Service
#############################################

resource "aws_secretsmanager_secret_version" "ai_redis" {
  secret_id = aws_secretsmanager_secret.this["staging/ai-service/redis"].id
  secret_string = jsonencode({
    host = "goormgb-staging-redis.xxxxxx.apn2.cache.amazonaws.com"
    port = "6379"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_version" "ai_postgres" {
  secret_id = aws_secretsmanager_secret.this["staging/ai-service/postgres"].id
  secret_string = jsonencode({
    host     = "goormgb-staging-rds.xxxxxx.ap-northeast-2.rds.amazonaws.com"
    port     = "5432"
    username = "ai_defense"
    password = "CHANGE_ME_IN_CONSOLE"
    dbname   = "ai_defense"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_version" "ai_clickhouse" {
  secret_id = aws_secretsmanager_secret.this["staging/ai-service/clickhouse"].id
  secret_string = jsonencode({
    user     = "default"
    password = "CHANGE_ME_IN_CONSOLE"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_version" "clickhouse_pod" {
  secret_id = aws_secretsmanager_secret.this["staging/goormgb/clickhouse"].id
  secret_string = jsonencode({
    CLICKHOUSE_USER     = "default"
    CLICKHOUSE_PASSWORD = "CHANGE_ME_IN_CONSOLE"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
