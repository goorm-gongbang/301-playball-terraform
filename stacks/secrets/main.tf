#############################################
# Static Secrets - 인프라 재생성과 무관
# 값은 AWS Console에서 직접 관리
#############################################

locals {
  secrets = {
    ###########################################
    # Dev - Infra
    ###########################################
    "dev/argocd/github-ssh" = {
      environment = "dev"
      description = "ArgoCD GitHub SSH key for repo access"
    }
    "dev/argocd/webhook-github" = {
      environment = "dev"
      description = "ArgoCD GitHub webhook secret for auto-sync"
    }
    "dev/argocd/discord-webhook" = {
      environment = "dev"
      description = "ArgoCD Discord webhooks for notifications (app + infra)"
    }
    "dev/monitoring/discord-webhook-alerts" = {
      environment = "dev"
      description = "Discord webhooks for Prometheus/Alertmanager notifications"
    }
    "dev/monitoring/grafana" = {
      environment = "dev"
      description = "Grafana admin credentials"
    }
    "dev/infra/oauth/google" = {
      environment = "dev"
      description = "Google OAuth credentials for ArgoCD/Grafana/infra-console"
    }
    "dev/infra/oauth/swagger" = {
      environment = "dev"
      description = "Google OAuth credentials for Swagger UI authentication"
    }
    "dev/infra/oauth/teams-allow" = {
      environment = "dev"
      description = "Google OAuth credentials for admin tools (RedisInsight, CloudBeaver, Kiali)"
    }
    "dev/infra/cloudflare" = {
      environment = "dev"
      description = "Cloudflare API credentials for DDNS"
    }
    "dev/infra/s3-backup" = {
      environment = "dev"
      description = "S3 backup credentials"
    }

    ###########################################
    # Dev - Services
    ###########################################
    "dev/services/jwt" = {
      environment = "dev"
      description = "JWT RSA keys and configuration"
    }
    "dev/services/oauth/kakao" = {
      environment = "dev"
      description = "Kakao OAuth credentials"
    }
    "dev/oauth/rbac/argocd" = {
      environment = "dev"
      description = "ArgoCD RBAC configuration"
    }
    "dev/services/queue-jwt" = {
      environment = "dev"
      description = "Queue service admission token configuration"
    }
    "dev/services/internal-api" = {
      environment = "dev"
      description = "Internal API Key for AI Server - Auth-Guard communication"
    }
    "dev/services/kafka" = {
      environment = "dev"
      description = "Kafka configuration for producer/consumer"
    }
    "dev/services/mail" = {
      environment = "dev"
      description = "Gmail SMTP credentials for email notifications"
    }
    "dev/services/s3-qna" = {
      environment = "dev"
      description = "S3 credentials for QnA file upload"
    }

    ###########################################
    # Staging - Infra
    ###########################################
    "staging/infra/oauth/teams-allow" = {
      environment = "staging"
      description = "Google OAuth credentials for admin tools (RedisInsight, CloudBeaver, Kiali)"
    }
    "staging/infra/ghcr" = {
      environment = "staging"
      description = "GHCR credentials for pulling private container images"
    }

    ###########################################
    # Staging - Services
    ###########################################
    "staging/services/internal-api" = {
      environment = "staging"
      description = "Internal API Key for AI Server - Auth-Guard communication"
    }
    "staging/services/kafka" = {
      environment = "staging"
      description = "Kafka configuration for producer/consumer"
    }
    "staging/services/s3-qna" = {
      environment = "staging"
      description = "S3 credentials for QnA file upload"
    }
    "staging/services/mail" = {
      environment = "staging"
      description = "Gmail SMTP credentials for email notifications"
    }
    "staging/ai-service/clickhouse" = {
      environment = "staging"
      description = "ClickHouse credentials for AI Defense observability warehouse"
    }
    "staging/goormgb/clickhouse" = {
      environment = "staging"
      description = "ClickHouse server credentials"
    }

    ###########################################
    # Prod - Infra
    ###########################################
    "prod/infra/oauth/teams-allow" = {
      environment = "prod"
      description = "Google OAuth credentials for admin tools"
    }
    "prod/infra/ghcr" = {
      environment = "prod"
      description = "GHCR credentials for pulling private container images"
    }
    "prod/monitoring/discord-webhook-alerts" = {
      environment = "prod"
      description = "Discord webhooks for Prometheus/Alertmanager notifications"
    }

    ###########################################
    # Prod - Services
    ###########################################
    "prod/services/internal-api" = {
      environment = "prod"
      description = "Internal API Key for AI Server - Auth-Guard communication"
    }
    "prod/services/kafka" = {
      environment = "prod"
      description = "Kafka configuration for producer/consumer"
    }
    "prod/services/mail" = {
      environment = "prod"
      description = "Gmail SMTP credentials for email notifications"
    }
    "prod/services/jwt" = {
      environment = "prod"
      description = "JWT RSA keys and configuration"
    }
    "prod/ai-service/clickhouse" = {
      environment = "prod"
      description = "ClickHouse credentials for AI Defense observability warehouse"
    }
    "prod/goormgb/clickhouse" = {
      environment = "prod"
      description = "ClickHouse server credentials"
    }
  }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = local.secrets

  name        = each.key
  description = each.value.description

  tags = {
    Name        = each.key
    Environment = each.value.environment
    Type        = "static"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [description]
  }
}

#############################################
# Secret Versions - Kafka (hardcoded config)
#############################################

resource "aws_secretsmanager_secret_version" "dev_kafka" {
  secret_id = aws_secretsmanager_secret.this["dev/services/kafka"].id
  secret_string = jsonencode({
    KAFKA_BOOTSTRAP_SERVERS           = "kafka-headless.data.svc.cluster.local:9092"
    KAFKA_PRODUCER_KEY_SERIALIZER     = "org.apache.kafka.common.serialization.StringSerializer"
    KAFKA_PRODUCER_VALUE_SERIALIZER   = "org.springframework.kafka.support.serializer.JsonSerializer"
    KAFKA_PRODUCER_ACKS               = "all"
    KAFKA_CONSUMER_KEY_DESERIALIZER   = "org.apache.kafka.common.serialization.StringDeserializer"
    KAFKA_CONSUMER_VALUE_DESERIALIZER = "org.springframework.kafka.support.serializer.JsonDeserializer"
    KAFKA_CONSUMER_AUTO_OFFSET_RESET  = "earliest"
    KAFKA_CONSUMER_TRUSTED_PACKAGES   = "com.goormgb.be.*"
  })

  lifecycle { ignore_changes = [secret_string] }
}

resource "aws_secretsmanager_secret_version" "staging_kafka" {
  secret_id = aws_secretsmanager_secret.this["staging/services/kafka"].id
  secret_string = jsonencode({
    KAFKA_BOOTSTRAP_SERVERS           = "kafka-headless.data.svc.cluster.local:9092"
    KAFKA_PRODUCER_KEY_SERIALIZER     = "org.apache.kafka.common.serialization.StringSerializer"
    KAFKA_PRODUCER_VALUE_SERIALIZER   = "org.springframework.kafka.support.serializer.JsonSerializer"
    KAFKA_PRODUCER_ACKS               = "all"
    KAFKA_CONSUMER_KEY_DESERIALIZER   = "org.apache.kafka.common.serialization.StringDeserializer"
    KAFKA_CONSUMER_VALUE_DESERIALIZER = "org.springframework.kafka.support.serializer.JsonDeserializer"
    KAFKA_CONSUMER_AUTO_OFFSET_RESET  = "earliest"
    KAFKA_CONSUMER_TRUSTED_PACKAGES   = "com.goormgb.be.*"
  })

  lifecycle { ignore_changes = [secret_string] }
}

resource "aws_secretsmanager_secret_version" "prod_kafka" {
  secret_id = aws_secretsmanager_secret.this["prod/services/kafka"].id
  secret_string = jsonencode({
    KAFKA_BOOTSTRAP_SERVERS           = "kafka-headless.data.svc.cluster.local:9092"
    KAFKA_PRODUCER_KEY_SERIALIZER     = "org.apache.kafka.common.serialization.StringSerializer"
    KAFKA_PRODUCER_VALUE_SERIALIZER   = "org.springframework.kafka.support.serializer.JsonSerializer"
    KAFKA_PRODUCER_ACKS               = "all"
    KAFKA_CONSUMER_KEY_DESERIALIZER   = "org.apache.kafka.common.serialization.StringDeserializer"
    KAFKA_CONSUMER_VALUE_DESERIALIZER = "org.springframework.kafka.support.serializer.JsonDeserializer"
    KAFKA_CONSUMER_AUTO_OFFSET_RESET  = "earliest"
    KAFKA_CONSUMER_TRUSTED_PACKAGES   = "com.goormgb.be.*"
  })

  lifecycle { ignore_changes = [secret_string] }
}
