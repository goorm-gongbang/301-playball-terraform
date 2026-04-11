#############################################
# Static Secrets - staging/prod 통합 시크릿
# 값은 AWS Console에서 직접 관리
# 동적 시크릿 (db, redis)은 각 environments/main.tf에서 관리
#############################################

locals {
  secrets = {
    ###########################################
    # Staging (12개)
    ###########################################
    "staging/argocd" = {
      environment = "staging"
      description = "ArgoCD: SSH key, OAuth, Discord webhook"
    }
    "staging/infra/oauth" = {
      environment = "staging"
      description = "Google OAuth (ArgoCD/Grafana)"
    }
    "staging/infra/oauth-teams" = {
      environment = "staging"
      description = "Admin Tools OAuth (CloudBeaver/Kiali)"
    }
    "staging/monitoring" = {
      environment = "staging"
      description = "Grafana admin + Discord alert webhooks"
    }
    "staging/ai-service" = {
      environment = "staging"
      description = "AI Defense: Redis, PG, ClickHouse, Auth-Guard, Internal API"
    }
    "staging/goormgb/clickhouse" = {
      environment = "staging"
      description = "ClickHouse server credentials (Pod)"
    }
    "staging/services/jwt" = {
      environment = "staging"
      description = "JWT RSA keys and configuration"
    }
    "staging/services/kafka" = {
      environment = "staging"
      description = "Kafka configuration for producer/consumer"
    }
    "staging/services/mail" = {
      environment = "staging"
      description = "Gmail SMTP credentials"
    }
    "staging/services/oauth/kakao" = {
      environment = "staging"
      description = "Kakao OAuth credentials"
    }

    ###########################################
    # Prod (12개)
    ###########################################
    "prod/argocd" = {
      environment = "prod"
      description = "ArgoCD: SSH key, OAuth, Discord webhook"
    }
    "prod/infra/oauth" = {
      environment = "prod"
      description = "Google OAuth (ArgoCD/Grafana)"
    }
    "prod/infra/oauth-teams" = {
      environment = "prod"
      description = "Admin Tools OAuth (CloudBeaver/Kiali)"
    }
    "prod/monitoring" = {
      environment = "prod"
      description = "Grafana admin + Discord alert webhooks"
    }
    "prod/ai-service" = {
      environment = "prod"
      description = "AI Defense: Redis, PG, ClickHouse, Auth-Guard, Internal API"
    }
    "prod/goormgb/clickhouse" = {
      environment = "prod"
      description = "ClickHouse server credentials (Pod)"
    }
    "prod/services/jwt" = {
      environment = "prod"
      description = "JWT RSA keys and configuration"
    }
    "prod/services/kafka" = {
      environment = "prod"
      description = "Kafka configuration for producer/consumer"
    }
    "prod/services/mail" = {
      environment = "prod"
      description = "Gmail SMTP credentials"
    }
    "prod/services/oauth/kakao" = {
      environment = "prod"
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
