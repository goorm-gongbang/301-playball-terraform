#############################################
# Secrets Module
# Static secrets — 값은 AWS Console에서 직접 관리
#############################################

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "secrets" {
  description = "Map of secret names (without env prefix) to descriptions"
  type        = map(string)
}

variable "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers"
  type        = string
  default     = "kafka-headless.data.svc.cluster.local:9092"
}

variable "enable_kafka_secret" {
  description = "Whether to create kafka secret version with default config"
  type        = bool
  default     = true
}

locals {
  secret_map = {
    for name, desc in var.secrets :
    "${var.environment}/${name}" => { description = desc }
  }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = local.secret_map

  name        = each.key
  description = each.value.description

  tags = {
    Name        = each.key
    Environment = var.environment
    Type        = "static"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [description]
  }
}

resource "aws_secretsmanager_secret_version" "kafka" {
  count = var.enable_kafka_secret ? 1 : 0

  secret_id = aws_secretsmanager_secret.this["${var.environment}/services/kafka"].id
  secret_string = jsonencode({
    KAFKA_BOOTSTRAP_SERVERS           = var.kafka_bootstrap_servers
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

output "secret_arns" {
  value = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}
