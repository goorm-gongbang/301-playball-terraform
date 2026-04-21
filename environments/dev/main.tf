#############################################
# Dev Environment - Main Configuration
#############################################

# [DEPRECATED] Dynamic Secrets (AWS Secrets Manager)
# ESO + SM → Sealed Secrets로 전환 완료
# wonny 계정 SM에 남아있는 dev/services, dev/ai-service, dev/infra는
# Sealed Secrets 마이그레이션 완료 후 삭제 예정
#
# locals {
#   dynamic_secrets = {
#     "dev/services/db"        = { description = "PostgreSQL database credentials" }
#     "dev/services/redis"     = { description = "Redis credentials (legacy)" }
#     "dev/services/redis-cache" = { description = "Redis cache credentials" }
#     "dev/services/redis-queue" = { description = "Redis queue credentials" }
#     "dev/ai-service/redis"   = { description = "AI Defense Redis connection" }
#   }
# }
