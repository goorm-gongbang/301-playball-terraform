#############################################
# Staging - Static Secrets
# 값은 AWS Console에서 직접 관리
# 동적 시크릿 (db, redis)은 environments/staging/main.tf에서 관리
#############################################

locals {
  secrets = {
    "staging/argocd" = {
      description = "ArgoCD: SSH key, OAuth, Discord webhook"
    }
    "staging/infra/oauth" = {
      description = "Google OAuth (ArgoCD/Grafana)"
    }
    "staging/infra/oauth-teams" = {
      description = "Admin Tools OAuth (CloudBeaver/Kiali)"
    }
    "staging/monitoring" = {
      description = "Grafana admin + Discord alert webhooks"
    }
    "staging/ai-service/common" = {
      description = "AI Defense: Redis, PG, ClickHouse, Auth-Guard, Internal API"
    }
    "staging/ai-service/clickhouse" = {
      description = "ClickHouse server credentials (Pod)"
    }
    "staging/services/jwt" = {
      description = "JWT RSA keys and configuration"
    }
    "staging/services/kafka" = {
      description = "Kafka configuration for producer/consumer"
    }
    "staging/services/mail" = {
      description = "Gmail SMTP credentials"
    }
    "staging/services/oauth/kakao" = {
      description = "Kakao OAuth credentials"
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

resource "aws_secretsmanager_secret_version" "kafka" {
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
