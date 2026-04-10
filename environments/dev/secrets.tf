#############################################
# Secrets Manager - Dev Environment
# 값은 AWS Console에서 직접 관리
# Terraform은 빈 secret만 생성
#############################################

locals {
  secrets = {
    # ArgoCD
    "dev/argocd/github-ssh" = {
      description = "ArgoCD GitHub SSH key for repo access"
    }
    "dev/argocd/webhook-github" = {
      description = "ArgoCD GitHub webhook secret for auto-sync"
    }
    "dev/argocd/discord-webhook" = {
      description = "ArgoCD Discord webhooks for notifications (app + infra)"
    }

    # Monitoring
    "dev/monitoring/discord-webhook-alerts" = {
      description = "Discord webhooks for Prometheus/Alertmanager notifications"
      # keys: criticalWebhookUrl, warningWebhookUrl, infoWebhookUrl
    }
    "dev/monitoring/grafana" = {
      description = "Grafana admin credentials"
    }

    # Infra - OAuth
    "dev/infra/oauth/google" = {
      description = "Google OAuth credentials for ArgoCD/Grafana/infra-console"
      # keys: clientId, clientSecret, sessionKey
    }
    "dev/infra/oauth/swagger" = {
      description = "Google OAuth credentials for Swagger UI authentication"
      # keys: client_id, client_secret, cookie_secret, authenticated_emails
    }
    "dev/infra/oauth/teams-allow" = {
      description = "Google OAuth credentials for admin tools (RedisInsight, CloudBeaver, Kiali)"
      # keys: clientId, clientSecret, cookieSecret, allowedEmails
    }
    "dev/infra/cloudflare" = {
      description = "Cloudflare API credentials for DDNS"
    }
    "dev/infra/s3-backup" = {
      description = "S3 backup credentials"
    }

    # Services - DB
    "dev/services/db" = {
      description = "PostgreSQL database credentials"
      # keys: url, username, password, DB_ENCRYPTION_KEY
    }

    # Services - Redis
    "dev/services/redis" = {
      description = "Redis credentials (legacy)"
    }
    "dev/services/redis-cache" = {
      description = "Redis cache credentials"
    }
    "dev/services/redis-queue" = {
      description = "Redis queue credentials"
    }

    # Services - JWT
    "dev/services/jwt" = {
      description = "JWT RSA keys and configuration"
      # keys: JWT_PRIVATE_KEY, JWT_PUBLIC_KEY, JWT_ISSUER, JWT_ACCESS_TOKEN_*
    }

    # Services - OAuth
    "dev/services/oauth/kakao" = {
      description = "Kakao OAuth credentials"
    }
    "dev/oauth/rbac/argocd" = {
      description = "ArgoCD RBAC configuration"
    }

    # Services - AI
    "dev/ai-service/redis" = {
      description = "AI Defense Redis connection"
      # keys: host, port
    }

    # Services - Queue
    "dev/services/queue-jwt" = {
      description = "Queue service admission token configuration"
      # keys: ADMISSION_PRIVATE_KEY, ADMISSION_PUBLIC_KEY, ADMISSION_TOKEN_ISSUER
    }

    # Services - Internal API
    "dev/services/internal-api" = {
      description = "Internal API Key for AI Server ↔ Auth-Guard communication"
      # keys: INTERNAL_API_KEY
    }

    # Services - Kafka
    "dev/services/kafka" = {
      description = "Kafka configuration for producer/consumer"
    }

    # Services - Mail
    "dev/services/mail" = {
      description = "Gmail SMTP credentials for email notifications"
      # keys: MAIL_HOST, MAIL_PORT, MAIL_USERNAME, MAIL_PASSWORD
    }

    # Services - S3 QnA
    "dev/services/s3-qna" = {
      description = "S3 credentials for QnA file upload"
    }
  }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = local.secrets

  name        = each.key
  description = each.value.description

  tags = {
    Name        = each.key
    Environment = "dev"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [description]
  }
}

#############################################
# Secret Versions - Kafka (hardcoded config)
#############################################

resource "aws_secretsmanager_secret_version" "kafka" {
  secret_id = aws_secretsmanager_secret.this["dev/services/kafka"].id
  secret_string = jsonencode({
    KAFKA_BOOTSTRAP_SERVERS = "kafka-headless.data.svc.cluster.local:9092"

    KAFKA_PRODUCER_KEY_SERIALIZER   = "org.apache.kafka.common.serialization.StringSerializer"
    KAFKA_PRODUCER_VALUE_SERIALIZER = "org.springframework.kafka.support.serializer.JsonSerializer"
    KAFKA_PRODUCER_ACKS             = "all"

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
# Secret Versions - AI Service Redis
#############################################

resource "aws_secretsmanager_secret_version" "ai_redis" {
  secret_id = aws_secretsmanager_secret.this["dev/ai-service/redis"].id
  secret_string = jsonencode({
    host = "redis-ai.data.svc.cluster.local"
    port = "6379"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
